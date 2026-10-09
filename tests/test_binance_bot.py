import ast
import copy
import io
import math
import traceback
import unittest
import uuid
from contextlib import redirect_stdout
from datetime import datetime, timedelta
from pathlib import Path
from types import SimpleNamespace



SOURCE_PATH = Path(__file__).resolve().parents[1] / 'script' / 'binance.py'
SOURCE_TREE = ast.parse(SOURCE_PATH.read_text(encoding='utf-8'))
FUNCTION_NODES = [copy.deepcopy(node) for node in SOURCE_TREE.body if isinstance(node, (ast.FunctionDef, ast.ClassDef))]
MAIN_TRY = next(node for node in SOURCE_TREE.body if isinstance(node, ast.Try))
CONFIG_ASSIGNMENTS = [
    copy.deepcopy(node)
    for node in SOURCE_TREE.body
    if isinstance(node, ast.Assign)
    and any(isinstance(target, ast.Name) and target.id in {
        'coinsymbols', 'cashsymbols', 'symbol', 'leverage', 'movingAveragePeriod',
        'stopLimitLevelNum', 'avoidInsufficientErrorRatio', 'minOrderQuantityLimit',
    } for target in node.targets)
]


def linear_fit(values, sample, degree):
    mean_x = sum(values) / float(len(values))
    mean_y = sum(sample) / float(len(sample))
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(values, sample))
    slope /= sum((x - mean_x) ** 2 for x in values)
    return slope, mean_y - slope * mean_x


def isolated_namespace():
    module = ast.parse('')
    module.body = copy.deepcopy(FUNCTION_NODES)
    env = {
        'math': math,
        'np': SimpleNamespace(arange=lambda count: list(range(count)), array=list, polyfit=linear_fit),
        'datetime': datetime,
        'timedelta': timedelta,
        'time': SimpleNamespace(sleep=lambda _seconds: None),
        'traceback': traceback,
        'uuid': uuid,
    }
    exec(compile(module, str(SOURCE_PATH), 'exec'), env)
    return env


def run_actual_main(env):
    wrapper = ast.parse('def _run_actual_main():\n    pass\n')
    wrapper.body[0].body = CONFIG_ASSIGNMENTS + [copy.deepcopy(MAIN_TRY)]
    ast.fix_missing_locations(wrapper)
    exec(compile(wrapper, str(SOURCE_PATH), 'exec'), env)
    with redirect_stdout(io.StringIO()):
        env['_run_actual_main']()


def candle(index, close, close_time):
    return [0, '0', '0', '0', str(close), '0', close_time]


def full_stop(algo_id, trigger, **fields):
    order = {'algoId': algo_id, 'symbol': 'BTCUSDT', 'side': 'SELL', 'type': 'STOP_MARKET',
             'closePosition': True, 'triggerPrice': str(trigger), 'algoStatus': 'NEW',
             'positionSide': 'BOTH', 'workingType': 'MARK_PRICE'}
    order.update(fields)
    return order


class AlgoExchange:
    """Stateful exchange model: full-close duplication and flat pre-arming are rejected."""

    def __init__(self, env, orders=()):
        self.env = env
        self.orders = {order['algoId']: dict(order) for order in orders}
        self.events = []
        self.position = 1.0
        self.mark = 110.0
        self.create_modes = []
        self.cancel_mode = 'accepted'
        self.query_failure = False
        self.ordinary = []
        self.bulk_modes = {}
        env.update({
            'getCurrentPosition': self.get_position,
            'getCurrentFutureMarkPrice': lambda _symbol: {'markPrice': str(self.mark)},
            'getAllAlgoOpenOrders': self.open_orders,
            'getAlgoOrder': self.query,
            'setPositionClosePrice': self.create,
            'cancelAlgoOrder': self.cancel,
            'setStopLimitPrice': self.create_partial,
            'getAllOpenOrders': lambda: list(self.ordinary),
            'closeAllOpenOrders': lambda symbols=None: self.cancel_all('ordinary', symbols),
            'closeAllAlgoOpenOrders': lambda symbols=None: self.cancel_all('algo', symbols),
        })

    def get_position(self, _symbol):
        return [{'symbol': 'BTCUSDT', 'positionSide': 'BOTH', 'positionAmt': str(self.position)}]

    def open_orders(self):
        return [dict(order) for order in self.orders.values() if order['algoStatus'] == 'NEW']

    def query(self, _symbol, algoId=None, clientAlgoId=None):
        if self.query_failure:
            raise TimeoutError('query unavailable')
        order = self.orders.get(algoId) if algoId is not None else next(
            (order for order in self.orders.values() if order.get('clientAlgoId') == clientAlgoId), None)
        if order is None:
            raise self.env['BinanceAPIError'](400, -2013, 'Order does not exist')
        return dict(order)

    def create(self, symbol, side, trigger, working, client_id):
        self.events.append(('create', float(trigger), client_id))
        if self.position <= 0:
            raise self.env['BinanceAPIError'](400, -4509, 'Position does not exist')
        if any(order['symbol'] == symbol and order['side'] == side and order.get('closePosition')
               for order in self.open_orders()):
            raise self.env['BinanceAPIError'](400, -4130, 'Existing full-close order')
        mode = self.create_modes.pop(0) if self.create_modes else 'accepted'
        if mode == 'rejected':
            raise self.env['BinanceAPIError'](400, -1111, 'Invalid precision')
        if mode == 'timeout_rejected':
            raise TimeoutError('create timed out without acceptance')
        if mode == 'api_unknown_rejected':
            raise self.env['BinanceAPIError'](400, -1007, 'Execution status unknown')
        if mode == 'server_rejected':
            raise self.env['BinanceAPIError'](503, -1000, 'Execution status unknown')
        algo_id = max(self.orders, default=100) + 1
        order = full_stop(algo_id, trigger, symbol=symbol, side=side,
                          workingType=working, clientAlgoId=client_id)
        self.orders[algo_id] = order
        if mode == 'timeout_accepted':
            raise TimeoutError('create timed out after acceptance')
        if mode == 'invalid_response_accepted':
            return {}
        return dict(order)

    def cancel(self, _symbol, algo_id):
        self.events.append(('cancel', algo_id))
        if self.cancel_mode == 'rejected':
            raise self.env['BinanceAPIError'](400, -2011, 'Cancel rejected')
        if self.cancel_mode == 'timeout_rejected':
            raise TimeoutError('cancel timed out without acceptance')
        self.orders[algo_id]['algoStatus'] = 'CANCELED'
        if self.cancel_mode == 'flat_after_cancel':
            self.position = 0.0
        if self.cancel_mode == 'timeout_accepted':
            raise TimeoutError('cancel timed out after acceptance')

    def create_partial(self, symbol, side, trigger, quantity, working, _match):
        self.events.append(('partial', float(trigger), float(quantity)))
        algo_id = max(self.orders, default=100) + 1
        order = full_stop(algo_id, trigger, symbol=symbol, side=side, workingType=working,
                          type='STOP', closePosition=False, reduceOnly=True, quantity=str(quantity))
        self.orders[algo_id] = order
        return dict(order)

    def cancel_all(self, kind, symbols):
        for symbol in symbols:
            self.events.append(('bulk_' + kind, symbol))
            mode = self.bulk_modes.get((kind, symbol), 'accepted')
            if mode == 'rejected':
                raise self.env['BinanceAPIError'](400, -2011, 'Cancel rejected')
            if mode == 'timeout_rejected':
                raise TimeoutError('cancel-all not accepted')
            if kind == 'ordinary':
                self.ordinary = [order for order in self.ordinary if order['symbol'] != symbol]
            else:
                for order in self.orders.values():
                    if order['symbol'] == symbol and order['algoStatus'] == 'NEW':
                        order['algoStatus'] = 'CANCELED'
            if mode == 'timeout_accepted':
                raise TimeoutError('cancel-all accepted')


class BinanceBotTests(unittest.TestCase):
    def setUp(self):
        self.env = isolated_namespace()

    def test_confirmed_mark_window_uses_closed_closes_and_prior_close_disparity(self):
        for period in (30, 60):
            candles = [candle(i, 100 + i, i) for i in range(period + 6)]
            result = self.env['analyzeClosedMarkCandles'](candles, period + 4, period)
            closed = [100 + i for i in range(period + 4)]
            expected_average = sum(closed[-period:]) / float(period)
            self.assertAlmostEqual(result['averagePrice'], expected_average)
            self.assertEqual(result['lastClosedPrice'], closed[-1])
            self.assertAlmostEqual(result['disparity'], closed[-1] / expected_average * 100)
            self.assertEqual(len(result['averagePriceList']), 5)

    def test_server_time_is_captured_before_candle_snapshot(self):
        calls = []
        env = self.env
        env['getCurrentTime'] = lambda: calls.append('time') or 1000
        env['getCoinFutureMarkPriceHistory'] = lambda symbol, interval, count: (
            calls.append(('history', count)) or [candle(i, 100 + i, i) for i in range(count)]
        )
        env['getClosedDailyMarkAnalysis']('BTCUSDT', 60)
        self.assertEqual(calls, ['time', ('history', 66)])

    def test_ratio_strategy_and_incremental_funding_budget(self):
        determine = self.env['determineInvestInfo']
        self.assertEqual(determine(99, {'total': 10000}, True, 3)['future'], 0)
        plan = self.env['getBuyFundingPlan']({'future': 5000}, 10000, 1)
        self.assertEqual(plan, {'buyBudget': 5000.0, 'remainingSpot': 5000.0})
        plan = self.env['getBuyFundingPlan']({'future': 10000}, 10000, 1)
        self.assertEqual(plan, {'buyBudget': 10000.0, 'remainingSpot': 0.0})
        plan = self.env['getBuyFundingPlan']({'future': 1500}, 3000, 1)
        self.assertEqual(plan['buyBudget'], 1500.0)
        self.assertEqual(plan['remainingSpot'], 1500.0)
        self.assertEqual(self.env['getBuyFundingPlan']({'future': 0}, 3000, 1)['buyBudget'], 0.0)

    def test_transfer_amount_is_floored_to_eight_decimals(self):
        requests = []
        self.env['spotURL'] = 'https://api.binance.com'
        self.env['getCurrentTime'] = lambda: 123
        self.env['requestData'] = lambda *args: requests.append(args) or {'tranId': 1}
        self.env['transfer']('main', 'umfuture', 'USDT', 5000.061728395)
        self.assertIn('amount=5000.06172839&', requests[0][3])
        self.env['transfer']('main', 'umfuture', 'BNB', 0.00000001)
        self.assertIn('amount=0.00000001&', requests[1][3])

    def test_partial_fill_bnb_budget_requires_confirmed_quantities_and_fees(self):
        order = {'status': 'CANCELED', 'origQty': '100', 'executedQty': '50', 'cumQuote': '7350'}
        trades = [{'qty': '25', 'commission': '1.47', 'commissionAsset': 'USDT'},
                  {'qty': '25', 'commission': '1.47', 'commissionAsset': 'USDT'}]
        fee = self.env['getConfirmedFutureUsdtCommission'](order, trades)
        self.assertAlmostEqual(fee, 2.94)
        self.assertAlmostEqual(self.env['getBnbQuoteBudget'](order, 5000, 3, 200, fee), 47.06)
        self.assertEqual(self.env['getBnbQuoteBudget'](
            dict(order, status='PARTIALLY_FILLED'), 5000, 3, 200, fee), 0.0)
        self.assertIsNone(self.env['getConfirmedFutureUsdtCommission'](order, trades[:1]))
        self.assertIsNone(self.env['getConfirmedFutureUsdtCommission'](
            order, [{'qty': '50', 'commission': '1', 'commissionAsset': ''}]))
        self.assertEqual(self.env['getConfirmedNetBnbPurchase'](
            {'status': 'CANCELED', 'executedQty': '1'},
            [{'qty': '1', 'commission': '0.001', 'commissionAsset': 'BNB'}]), 0.999)

    def test_spot_bnb_quote_respects_market_minimum_and_fails_closed(self):
        good_info = {'symbols': [{
            'symbol': 'BNBUSDT', 'quoteAssetPrecision': 2,
            'filters': [
                {'filterType': 'NOTIONAL', 'minNotional': '5', 'applyMinToMarket': True},
                {'filterType': 'MARKET_LOT_SIZE', 'minQty': '0.001'},
            ],
        }]}
        quote = self.env['getSpotMarketQuoteBudget'](good_info, 10.129, 9.99, 500)
        self.assertEqual(quote, 9.99)
        self.assertEqual(self.env['getSpotMarketQuoteBudget'](good_info, 4.99, 100, 500), 0.0)
        missing_minimum = {'symbols': [{'symbol': 'BNBUSDT', 'filters': [
            {'filterType': 'MARKET_LOT_SIZE', 'minQty': '0'},
        ]}]}
        self.assertEqual(self.env['getSpotMarketQuoteBudget'](missing_minimum, 25, 25, 500), 0.0)

    def test_stop_replacement_failure_keeps_existing_full_close_protection(self):
        exchange = AlgoExchange(self.env, [full_stop(41, 80)])
        with self.assertRaises(RuntimeError):
            self.env['refreshPositionStops']('BTCUSDT', 100, 90, 1)
        self.assertEqual(exchange.events, [])
        self.assertEqual(exchange.open_orders()[0]['algoId'], 41)

    def test_startup_cancels_both_endpoints_for_union_of_all_futures_symbols(self):
        ordinary_cancel = self.env['closeAllOpenOrders']
        algo_cancel = self.env['closeAllAlgoOpenOrders']
        exchange = AlgoExchange(self.env, [full_stop(41, 99, symbol='ETHUSDT')])
        exchange.ordinary = [{'symbol': 'XRPUSDT', 'orderId': 11}]
        self.env.update({'closeAllOpenOrders': ordinary_cancel, 'closeAllAlgoOpenOrders': algo_cancel,
                         'futureURL': 'https://fapi.binance.com', 'getCurrentTime': lambda: 123})
        requests = []

        def request_data(_host, path, method, message):
            symbol = message.split('&')[0].split('=')[1]
            requests.append((path, method, symbol))
            exchange.cancel_all('algo' if path.endswith('/algoOpenOrders') else 'ordinary', [symbol])
            return {'code': 200}

        self.env['requestData'] = request_data
        self.env['cancelAllFutureOrders']()
        self.assertEqual(requests, [
            ('/fapi/v1/algoOpenOrders', 'delete', 'ETHUSDT'),
            ('/fapi/v1/allOpenOrders', 'delete', 'ETHUSDT'),
            ('/fapi/v1/algoOpenOrders', 'delete', 'XRPUSDT'),
            ('/fapi/v1/allOpenOrders', 'delete', 'XRPUSDT'),
        ])
        self.assertFalse(exchange.open_orders())
        self.assertFalse(exchange.ordinary)

    def test_cancel_all_reconciles_accepted_timeout_without_repeating_delete(self):
        exchange = AlgoExchange(self.env, [full_stop(41, 99)])
        exchange.ordinary = [{'symbol': 'BTCUSDT', 'orderId': 11}]
        exchange.bulk_modes = {('algo', 'BTCUSDT'): 'timeout_accepted',
                               ('ordinary', 'BTCUSDT'): 'timeout_accepted'}
        self.env['cancelAllFutureOrders']()
        self.assertEqual(exchange.events, [('bulk_algo', 'BTCUSDT'), ('bulk_ordinary', 'BTCUSDT')])
        self.assertFalse(exchange.open_orders())
        self.assertFalse(exchange.ordinary)

    def test_cancel_all_rejected_or_unaccepted_timeout_blocks_strategy(self):
        for kind in ('ordinary', 'algo'):
            for mode in ('rejected', 'timeout_rejected'):
                with self.subTest(kind=kind, mode=mode):
                    env = isolated_namespace()
                    exchange = AlgoExchange(env, [full_stop(41, 99)])
                    exchange.ordinary = [{'symbol': 'BTCUSDT', 'orderId': 11}]
                    exchange.bulk_modes[(kind, 'BTCUSDT')] = mode
                    with self.assertRaisesRegex(RuntimeError, 'cancel-all incomplete'):
                        env['cancelAllFutureOrders']()
                    self.assertEqual(len(exchange.events), 2)

    def test_cancel_all_unresolved_read_blocks_strategy(self):
        exchange = AlgoExchange(self.env, [full_stop(41, 99)])
        reads = [0]

        def read_algo():
            reads[0] += 1
            if reads[0] > 1:
                raise TimeoutError('Cannot confirm empty account')
            return exchange.open_orders()

        self.env['getAllAlgoOpenOrders'] = read_algo
        with self.assertRaises(TimeoutError):
            self.env['cancelAllFutureOrders']()

    def test_changed_daily_ma_resets_old_stop_then_reuses_within_each_run(self):
        exchange = AlgoExchange(self.env, [full_stop(41, 90)])
        for average in (100, 102):
            self.env['cancelAllFutureOrders']()
            self.env['ensureFullCloseStop']('BTCUSDT', 110, average)
            self.env['refreshPositionStops']('BTCUSDT', 110, average, 1)
            writes = list(exchange.events)
            self.env['refreshPositionStops']('BTCUSDT', 110, average, 1)
            self.assertEqual(exchange.events, writes)
            full = [order for order in exchange.open_orders() if order.get('closePosition')]
            self.assertEqual(len(full), 1)
            self.assertEqual(float(full[0]['triggerPrice']), math.floor(average * 0.99))
        self.assertEqual(sum(event[0] == 'create' for event in exchange.events), 2)

    def test_stop_creation_timeout_or_incomplete_response_reconciles_accepted_order(self):
        for mode in ('timeout_accepted', 'invalid_response_accepted'):
            with self.subTest(mode=mode):
                env = isolated_namespace()
                exchange = AlgoExchange(env)
                exchange.create_modes = [mode]
                order, created = env['ensureFullCloseStop']('BTCUSDT', 110, 100)
                self.assertTrue(created)
                self.assertEqual(order['algoStatus'], 'NEW')
                env['ensureFullCloseStop']('BTCUSDT', 110, 100)
                self.assertEqual(sum(event[0] == 'create' for event in exchange.events), 1)

    def test_unaccepted_or_unresolved_stop_creation_never_blindly_retries(self):
        for mode in ('rejected', 'timeout_rejected', 'api_unknown_rejected', 'server_rejected'):
            with self.subTest(mode=mode):
                env = isolated_namespace()
                exchange = AlgoExchange(env)
                exchange.create_modes = [mode]
                with self.assertRaises(RuntimeError):
                    env['ensureFullCloseStop']('BTCUSDT', 110, 100)
                self.assertEqual(len(exchange.events), 1)
        exchange = AlgoExchange(self.env)
        exchange.create_modes = ['timeout_accepted']
        exchange.query_failure = True
        with self.assertRaisesRegex(RuntimeError, 'outcome unknown'):
            self.env['ensureFullCloseStop']('BTCUSDT', 110, 100)
        self.assertEqual(len(exchange.events), 1)
        self.assertEqual(len(exchange.open_orders()), 1)

    def test_flat_or_immediately_triggering_stop_never_posts(self):
        exchange = AlgoExchange(self.env)
        exchange.position = 0
        with self.assertRaisesRegex(RuntimeError, 'positive one-way'):
            self.env['ensureFullCloseStop']('BTCUSDT', 110, 100)
        exchange.position = 1
        exchange.mark = 99
        with self.assertRaisesRegex(RuntimeError, 'mark price'):
            self.env['ensureFullCloseStop']('BTCUSDT', 110, 100)
        self.assertFalse(exchange.events)

    def test_partial_stop_uses_current_mark_instead_of_spot(self):
        exchange = AlgoExchange(self.env)
        exchange.mark = 99.5
        self.env['refreshPositionStops']('BTCUSDT', 110, 100, 1)
        self.assertEqual(sum(event[0] == 'create' for event in exchange.events), 1)
        self.assertFalse(any(event[0] == 'partial' for event in exchange.events))

    def test_stop_reuse_requires_one_way_mark_price_contract(self):
        for field, value in (('positionSide', 'LONG'), ('workingType', 'CONTRACT_PRICE'),
                             ('symbol', 'ETHUSDT'), ('side', 'BUY'), ('type', 'TAKE_PROFIT_MARKET')):
            with self.subTest(field=field):
                self.assertFalse(self.env['isConfirmedFullCloseStop'](full_stop(41, 99, **{field: value}), 'BTCUSDT', 99))

    def test_main_cancels_all_orders_and_protects_existing_position_before_balances(self):
        state = self._run_mocked_main(0.5, initial_position=0.25,
                                     initial_algo_orders=[full_stop(41, 88, symbol='ETHUSDT'), full_stop(42, 87)],
                                     initial_ordinary_orders=[{'symbol': 'XRPUSDT', 'orderId': 1}])
        stop_index = next(i for i, event in enumerate(state['events']) if event[0] == 'full_stop')
        last_cancel = max(i for i, event in enumerate(state['events']) if event[0].startswith('bulk_'))
        first_balance = next(i for i, event in enumerate(state['events']) if event[0] == 'account_change')
        self.assertLess(last_cancel, stop_index)
        self.assertLess(stop_index, first_balance)
        self.assertEqual(sum(event[0] == 'full_stop' for event in state['events']), 1)
        self.assertFalse(state['spot_cancels'])

    def test_main_cancel_failure_raises_before_strategy_or_financial_writes(self):
        for failed_read in (False, True):
            state = self._run_mocked_main(0.5, initial_algo_orders=[full_stop(41, 88)],
                                         fail_startup_cancel=not failed_read, fail_cancel_confirmation=failed_read,
                                         expect_failure=True)
            self.assertFalse(state['analysis_periods'])
            self.assertFalse(state['transfers'])
            self.assertFalse(state['spot_quote_buys'])
            self.assertFalse(state['earn_deposits'])
            self.assertFalse(state['leverage_calls'])

    def test_consecutive_no_buy_daily_main_runs_replace_changed_ma_after_clear_all(self):
        prior_orders = [full_stop(41, 80)]
        for average in (90.04, 92.04):
            state = self._run_mocked_main(0, initial_position=1,
                                         initial_algo_orders=prior_orders, buy_budget=0,
                                         average_price=average)
            full = [order for order in state['algo_orders'] if order.get('closePosition')]
            self.assertEqual(len(full), 1)
            self.assertEqual(float(full[0]['triggerPrice']), math.floor(math.floor(average * 10) / 10 * 0.99))
            self.assertEqual(sum(event[0] == 'full_stop' for event in state['events']), 1)
            prior_orders = state['algo_orders']

    def test_actual_main_buys_only_increment_and_sweeps_unallocated_usdt(self):
        for fill_ratio in (1.0, 0.5, 0.0):
            with self.subTest(fill_ratio=fill_ratio):
                self._run_mocked_main(fill_ratio)
        self._run_mocked_main(1.0, bnb_minimum=100)

    def test_existing_position_is_protected_before_additional_buy(self):
        state = self._run_mocked_main(0.5, initial_position=0.25)
        submit_index = next(i for i, event in enumerate(state['events']) if event[0] == 'submit')
        stop_index = next(i for i, event in enumerate(state['events']) if event[0] == 'full_stop')
        self.assertLess(stop_index, submit_index)
        self.assertGreater(state['events'][stop_index][1], 0)

    def test_partial_fill_is_protected_before_waiting_for_order_remainder(self):
        state = self._run_mocked_main(0.5)
        submit_index = next(i for i, event in enumerate(state['events']) if event[0] == 'submit')
        stop_index = next(i for i, event in enumerate(state['events']) if event[0] == 'full_stop')
        first_wait_index = next(i for i, event in enumerate(state['events']) if event[0] == 'sleep')
        settled_message_index = next(i for i, event in enumerate(state['events'])
                                     if event[0] == 'message' and i > submit_index)
        self.assertLess(submit_index, stop_index)
        self.assertLess(stop_index, first_wait_index)
        self.assertLess(stop_index, settled_message_index)

    def test_later_fill_reinstalls_a_full_stop_that_no_longer_exists(self):
        state = self._run_mocked_main(
            0.5, fill_progress=[0.25, 0.5], clear_stop_on_fill_increase=True,
        )
        self.assertEqual(sum(event[0] == 'full_stop' for event in state['events']), 2)

    def test_fill_waits_for_lagging_position_snapshot_before_protection(self):
        state = self._run_mocked_main(1.0, position_lag=2)
        stop_index = next(i for i, event in enumerate(state['events']) if event[0] == 'full_stop')
        position_queries_before_stop = [event for i, event in enumerate(state['events'])
                                        if i < stop_index and event[0] == 'position_query' and event[1] > 0]
        self.assertGreaterEqual(len(position_queries_before_stop), 3)

    def test_stop_failure_cancels_only_the_open_buy_and_skips_fees_and_earn(self):
        state = self._run_mocked_main(0.5, fail_full_stop=True, expect_failure=True)
        self.assertEqual(state['order_cancels'], [('BTCUSDT', 700, None)])
        self.assertFalse(state['spot_quote_buys'])
        self.assertFalse(state['earn_deposits'])
        self.assertFalse(any(row[2] == 'BNB' for row in state['transfers']))
        self.assertTrue(any(str(message).startswith('Failed to finish') for message in state['messages']))

    def test_unconfirmed_position_after_fill_cancels_open_buy_and_fails_closed(self):
        state = self._run_mocked_main(0.5, position_lag=3, expect_failure=True)
        self.assertEqual(state['order_cancels'], [('BTCUSDT', 700, None)])
        self.assertFalse(state['algo_orders'])
        self.assertFalse(state['spot_quote_buys'])
        self.assertFalse(state['earn_deposits'])
        self.assertTrue(any(str(message).startswith('Failed to finish') for message in state['messages']))

    def _run_mocked_main(self, fill_ratio, bnb_minimum=5, initial_position=0.0,
                         position_lag=0, fail_full_stop=False, expect_failure=False,
                         fill_progress=None, clear_stop_on_fill_increase=False,
                         initial_algo_orders=(), initial_ordinary_orders=(),
                         fail_startup_cancel=False, fail_cancel_confirmation=False,
                         buy_budget=5000, average_price=90.04):
        env = self.env
        state = {
            'spot_usdt': 10000.0,
            'future_withdrawable': 0.0,
            'future_account_calls': 0,
            'position_calls': 0,
            'position_queries_after_fill': 0,
            'order_queries': 0,
            'requested_qty': 0.0,
            'order_cancels': [],
            'transfers': [],
            'spot_quote_buys': [],
            'earn_deposits': [],
            'leverage_calls': [],
            'analysis_periods': [],
            'messages': [],
            'bnb_minimum': bnb_minimum,
            'algo_orders': list(initial_algo_orders),
            'algo_history': {order['algoId']: dict(order) for order in initial_algo_orders},
            'ordinary_orders': list(initial_ordinary_orders),
            'algo_reads': 0,
            'fail_startup_cancel': fail_startup_cancel,
            'fail_cancel_confirmation': fail_cancel_confirmation,
            'spot_cancels': [],
            'algo_cancels': [],
            'events': [],
            'new_bnb': 0.0,
            'initial_position': initial_position,
            'actual_position': initial_position,
            'position_lag': position_lag,
            'position_lag_remaining': 0,
            'fail_full_stop': fail_full_stop,
            'order_cancel_requested': False,
            'fill_progress': fill_progress or [fill_ratio],
            'last_executed_qty': 0.0,
            'clear_stop_on_fill_increase': clear_stop_on_fill_increase,
        }
        env.update({
            'loadConfig': lambda: None,
            'getClosedDailyMarkAnalysis': lambda _symbol, period: (
                state['analysis_periods'].append(period) or {
                    'averagePrice': average_price, 'averagePriceList': [89.9, 89.95, 90, 90.01, average_price],
                    'lastClosedPrice': 91, 'disparity': 101, 'isIncreasing': True,
                }
            ),
            'getAccountChange': lambda *args: state['events'].append(('account_change',)) or {
                'future': buy_budget, 'earn': 10000 - buy_budget, 'investRatio': 0.5, 'total': 10000, 'spot': 0,
            },
            'getCurrentPrice': lambda symbol=None: {'price': '500'} if symbol == 'BNBUSDT' else {'price': '100.09'},
            'getCurrentFutureMarkPrice': lambda _symbol: {'markPrice': '100'},
            'getFutureAccount': lambda: self._future_account(state),
            'getAccount': lambda: {'balances': [
                {'asset': 'USDT', 'free': str(state['spot_usdt'])},
                {'asset': 'BNB', 'free': str(state['new_bnb'])},
            ]},
            'getAllOpenOrders': lambda: list(state['ordinary_orders']),
            'getCurrentPosition': lambda _symbol: self._position(state),
            'getFuturePositionMode': lambda: {'dualSidePosition': False},
            'changeFutureLeverage': lambda _symbol, lev: state['leverage_calls'].append(lev) or {'leverage': lev},
            'getAllAlgoOpenOrders': lambda: self._read_algos(state),
            'closeAllOpenOrders': lambda symbols=None: self._bulk_cancel(state, 'ordinary', symbols),
            'closeAllAlgoOpenOrders': lambda symbols=None: self._bulk_cancel(state, 'algo', symbols),
            'getAlgoOrder': lambda symbol, algoId=None, clientAlgoId=None: self._query_algo(state, algoId, clientAlgoId),
            'setPositionClosePrice': lambda symbol, side, stop, _working, client: self._add_full_stop(state, symbol, side, stop, client),
            'setStopLimitPrice': lambda symbol, side, stop, qty, _working, _match: self._add_partial_stop(state, symbol, side, stop, qty),
            'cancelAlgoOrder': lambda symbol, algo_id: self._cancel_algo(state, symbol, algo_id),
            'orderFutureWithTimeLimit': lambda symbol, side, qty, price, _days, _client: self._submit_future(state, symbol, side, qty, price),
            'getFutureOrder': lambda _symbol, orderId=None, clientOrderId=None: self._query_future(state, fill_ratio),
            'cancelFutureOrder': lambda symbol, orderId=None, clientOrderId=None: self._cancel_future(state, symbol, orderId, clientOrderId),
            'getFutureUserTrades': lambda _symbol, _order: self._future_trades(state, fill_ratio),
            'getSpotExchangeInfo': lambda _symbol: self._spot_exchange_info(state),
            'getSpotOrder': lambda _symbol, _client: {},
            'cancelSpotOrder': lambda *args, **kwargs: state['spot_cancels'].append((args, kwargs)),
            'getSpotUserTrades': lambda *args: [],
            'orderSpotMarketByQuoteAmount': lambda symbol, quote, client: self._buy_spot_bnb(state, symbol, quote, client),
            'transfer': lambda source, target, asset, amount: self._transfer(state, source, target, asset, amount),
            'getFlexibleSimpleEarnList': lambda _asset: {'rows': [{'asset': 'USDT', 'productId': 'usdt-flex'}]},
            'subscribeFlexibleSimpleEarnProduct': lambda _product, amount: state['earn_deposits'].append(float(amount)) or {'success': True},
            'redeemFlexibleSimpleEarnProduct': lambda *args: {'success': True},
            'sendMessage': lambda message, **_kwargs: self._send_message(state, message),
        })
        env['time'] = SimpleNamespace(clock=0)

        def sleep(seconds):
            state['events'].append(('sleep', seconds))
            env['time'].clock += seconds

        env['time'].sleep = sleep
        env['time'].monotonic = lambda: env['time'].clock
        env['getCurrentTime'] = lambda: 123456789
        if expect_failure:
            with self.assertRaises(Exception):
                run_actual_main(env)
        else:
            run_actual_main(env)
        failed = any(str(message).startswith('Failed to finish') for message in state['messages'])
        self.assertEqual(failed, expect_failure)
        if expect_failure:
            return state
        self.assertEqual(state['analysis_periods'], [60])
        self.assertEqual(state['leverage_calls'], [3] if buy_budget else [])
        if not buy_budget:
            self.assertFalse(state['transfers'])
            self.assertFalse(state.get('submitted'))
            self.assertFalse(state['spot_quote_buys'])
            self.assertEqual(state['earn_deposits'], [10000.0])
            return state
        self.assertAlmostEqual(state['transfers'][0][3], 5000.0)
        self.assertEqual(state['transfers'][0][:3], ('main', 'umfuture', 'USDT'))
        future_order = [order for order in state.get('submitted', [])]
        self.assertEqual(len(future_order), 1)
        self.assertAlmostEqual(future_order[0][2], 147.0)
        self.assertEqual(future_order[0][1], 'BUY')
        self.assertEqual(len(state['order_cancels']), 1 if fill_ratio < 1 else 0)
        if fill_ratio == 0:
            self.assertFalse(state['spot_quote_buys'])
            self.assertFalse(any(row[2] == 'BNB' for row in state['transfers']))
            self.assertEqual(state['earn_deposits'], [10000.0])
            self.assertFalse(state['algo_orders'])
            self.assertFalse(state['algo_cancels'])
        elif bnb_minimum > 5:
            self.assertFalse(state['spot_quote_buys'])
            self.assertFalse(any(row[2] == 'BNB' for row in state['transfers']))
            self.assertEqual(len(state['earn_deposits']), 1)
            self.assertAlmostEqual(state['earn_deposits'][0], 5094.12)
            self.assertFalse(state['algo_cancels'])
        else:
            expected_bnb_budget = 94.11 if fill_ratio == 1 else 47.05
            self.assertEqual(len(state['spot_quote_buys']), 1)
            self.assertAlmostEqual(state['spot_quote_buys'][0][1], expected_bnb_budget)
            self.assertLessEqual(state['transfers'][1][3], 94.12 if fill_ratio == 1 else 47.06)
            self.assertEqual(len(state['earn_deposits']), 1)
            self.assertAlmostEqual(state['earn_deposits'][0], 5000.01 if fill_ratio == 1 else 7500.01)
            bnb_transfers = [row for row in state['transfers'] if row[2] == 'BNB']
            self.assertEqual(len(bnb_transfers), 1)
            self.assertAlmostEqual(bnb_transfers[0][3], state['new_bnb'])
            self.assertFalse(state['algo_cancels'])
        return state

    @staticmethod
    def _future_account(state):
        state['future_account_calls'] += 1
        return {'assets': [
            {'asset': 'USDT', 'maxWithdrawAmount': str(state['future_withdrawable'])},
            {'asset': 'BNB', 'maxWithdrawAmount': '7'},
        ]}

    @staticmethod
    def _send_message(state, message):
        state['messages'].append(message)
        state['events'].append(('message', message))

    @staticmethod
    def _position(state):
        state['position_calls'] += 1
        state['events'].append(('position_query', state['actual_position']))
        if state['actual_position']<=0:
            return []
        if state['position_lag_remaining']>0:
            state['position_lag_remaining']-=1
            state['position_queries_after_fill']+=1
            return []
        if state['requested_qty']>0:
            state['position_queries_after_fill']+=1
        return [{'symbol': 'BTCUSDT', 'positionSide': 'BOTH', 'positionAmt': str(state['actual_position'])}]

    @staticmethod
    def _add_full_stop(state, symbol, side, stop, client):
        if state['actual_position']<=0:
            raise RuntimeError('Binance API error -4509: closePosition requires an open position')
        if state['fail_full_stop']:
            raise RuntimeError('Could not create full-close stop')
        if any(order.get('symbol') == symbol and order.get('side') == side and order.get('closePosition')
               for order in state['algo_orders']):
            raise RuntimeError('Binance API error -4130: existing full-close stop')
        state['events'].append(('full_stop', state['actual_position']))
        order = full_stop(max(state['algo_history'], default=499) + 1, stop,
                          symbol=symbol, side=side, clientAlgoId=client)
        state['algo_orders'].append(order)
        state['algo_history'][order['algoId']] = order
        return order

    @staticmethod
    def _add_partial_stop(state, symbol, side, stop, qty):
        order = {'algoId': max(state['algo_history'], default=499) + 1, 'symbol': symbol, 'side': side, 'type': 'STOP',
                 'reduceOnly': True, 'quantity': str(qty), 'triggerPrice': str(stop), 'algoStatus': 'NEW',
                 'positionSide': 'BOTH', 'workingType': 'MARK_PRICE'}
        state['algo_orders'].append(order)
        state['algo_history'][order['algoId']] = order
        return order

    @staticmethod
    def _cancel_algo(state, symbol, algo_id):
        state['algo_cancels'].append((symbol, algo_id))
        state['algo_orders'] = [order for order in state['algo_orders'] if order.get('algoId') != algo_id]

    @staticmethod
    def _read_algos(state):
        state['algo_reads'] += 1
        if state['fail_cancel_confirmation'] and state['algo_reads'] > 1:
            raise TimeoutError('Cannot confirm all cancellations')
        return list(state['algo_orders'])

    @staticmethod
    def _bulk_cancel(state, kind, symbols):
        for symbol in symbols:
            state['events'].append(('bulk_' + kind, symbol))
            if state['fail_startup_cancel']:
                raise TimeoutError('Cancellation was not accepted')
            if kind == 'ordinary':
                state['ordinary_orders'] = [order for order in state['ordinary_orders'] if order['symbol'] != symbol]
            else:
                state['algo_orders'] = [order for order in state['algo_orders'] if order['symbol'] != symbol]

    def _query_algo(self, state, algo_id, client_id):
        order = state['algo_history'].get(algo_id) if algo_id is not None else next(
            (order for order in state['algo_history'].values() if order.get('clientAlgoId') == client_id), None)
        if order is None:
            raise self.env['BinanceAPIError'](400, -2013, 'Order does not exist')
        return dict(order)

    @staticmethod
    def _submit_future(state, symbol, side, qty, price):
        state['requested_qty'] = float(qty)
        state['events'].append(('submit', symbol, side, float(qty)))
        state['submitted'] = [(symbol, side, float(qty), float(price))]
        return {'symbol': symbol, 'side': side, 'status': 'NEW', 'orderId': 700,
                'origQty': str(qty), 'executedQty': '0'}

    @staticmethod
    def _query_future(state, fill_ratio):
        state['order_queries'] += 1
        ratio = state['fill_progress'][min(state['order_queries'] - 1, len(state['fill_progress']) - 1)]
        qty = state['requested_qty'] * ratio
        if qty>state['last_executed_qty'] and state['last_executed_qty']>0 and state['clear_stop_on_fill_increase']:
            state['algo_orders']=[order for order in state['algo_orders'] if not order.get('closePosition')]
        state['last_executed_qty']=qty
        if qty>0:
            state['actual_position']=state['initial_position']+qty
            if state['position_queries_after_fill']==0:
                state['position_lag_remaining']=state['position_lag']
        else:
            state['actual_position']=state['initial_position']
        state['events'].append(('order_query', qty))
        quote = qty * 100
        if state['order_cancel_requested']:
            status='CANCELED'
        else:
            status = 'FILLED' if ratio == 1 else ('PARTIALLY_FILLED' if ratio > 0 else 'NEW')
        state['future_withdrawable'] = (5000.0 if fill_ratio == 0 else
                                        5000.0 * (1 - fill_ratio) + 5000.0 * fill_ratio - quote / 3 - quote * 0.0004)
        return {'symbol': 'BTCUSDT', 'status': status, 'orderId': 700,
                'origQty': str(state['requested_qty']), 'executedQty': str(qty),
                'cumQuote': str(quote), 'avgPrice': '100'}

    @staticmethod
    def _cancel_future(state, symbol, order_id, client_order_id):
        state['order_cancels'].append((symbol, order_id, client_order_id))
        state['order_cancel_requested']=True

    @staticmethod
    def _future_trades(state, fill_ratio):
        qty = state['requested_qty'] * fill_ratio
        return [] if qty <= 0 else [{'qty': str(qty), 'commission': str(qty * 100 * 0.0004), 'commissionAsset': 'USDT'}]

    @staticmethod
    def _spot_exchange_info(state):
        return {'symbols': [{'symbol': 'BNBUSDT', 'quoteAssetPrecision': 2, 'filters': [
            {'filterType': 'NOTIONAL', 'minNotional': str(state['bnb_minimum']), 'applyMinToMarket': True},
            {'filterType': 'MARKET_LOT_SIZE', 'minQty': '0.001'},
        ]}]}

    @staticmethod
    def _buy_spot_bnb(state, symbol, quote, client):
        state['spot_quote_buys'].append((symbol, float(quote), client))
        state['spot_usdt'] -= float(quote)
        qty = float(quote) / 500.0
        fee = 0.0001
        net = qty - fee
        state['new_bnb'] += net
        return {'symbol': symbol, 'status': 'FILLED', 'orderId': 800,
                'executedQty': str(qty), 'fills': [{'qty': str(qty), 'commission': str(fee), 'commissionAsset': 'BNB'}]}

    @staticmethod
    def _transfer(state, source, target, asset, amount):
        amount = float(amount)
        state['transfers'].append((source, target, asset, amount))
        if source == 'main' and target == 'umfuture' and asset == 'USDT':
            state['spot_usdt'] -= amount
        elif source == 'umfuture' and target == 'main' and asset == 'USDT':
            state['spot_usdt'] += amount
            state['future_withdrawable'] = max(0.0, state['future_withdrawable'] - amount)
        elif source == 'main' and target == 'umfuture' and asset == 'BNB':
            pass
        return {'tranId': 1}


if __name__ == '__main__':
    unittest.main()

import ast
import copy
import io
import math
import traceback
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timedelta
from pathlib import Path
from types import SimpleNamespace



SOURCE_PATH = Path(__file__).resolve().parents[1] / 'script' / 'binance.py'
SOURCE_TREE = ast.parse(SOURCE_PATH.read_text(encoding='utf-8'))
FUNCTION_NODES = [copy.deepcopy(node) for node in SOURCE_TREE.body if isinstance(node, ast.FunctionDef)]
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
        old_stop = {'algoId': 41, 'symbol': 'BTCUSDT', 'side': 'SELL', 'type': 'STOP_MARKET',
                    'closePosition': True, 'triggerPrice': '80', 'algoStatus': 'NEW'}
        canceled = []
        self.env['getAllAlgoOpenOrders'] = lambda: [old_stop]
        self.env['setPositionClosePrice'] = lambda *args: {}
        self.env['cancelAlgoOrder'] = lambda *args: canceled.append(args)
        with self.assertRaises(RuntimeError):
            self.env['refreshPositionStops']('BTCUSDT', 100, 90, 1)
        self.assertEqual(canceled, [])
        self.assertEqual(old_stop['algoId'], 41)

    def test_actual_main_buys_only_increment_and_sweeps_unallocated_usdt(self):
        for fill_ratio in (1.0, 0.5, 0.0):
            with self.subTest(fill_ratio=fill_ratio):
                self._run_mocked_main(fill_ratio)
        self._run_mocked_main(1.0, bnb_minimum=100)

    def _run_mocked_main(self, fill_ratio, bnb_minimum=5):
        env = self.env
        state = {
            'spot_usdt': 10000.0,
            'future_withdrawable': 0.0,
            'future_account_calls': 0,
            'position_calls': 0,
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
            'algo_orders': [],
            'algo_cancels': [],
            'new_bnb': 0.0,
        }
        env.update({
            'loadConfig': lambda: None,
            'getClosedDailyMarkAnalysis': lambda _symbol, period: (
                state['analysis_periods'].append(period) or {
                    'averagePrice': 90.04, 'averagePriceList': [89.9, 89.95, 90, 90.01, 90.04],
                    'lastClosedPrice': 91, 'disparity': 101, 'isIncreasing': True,
                }
            ),
            'getAccountChange': lambda *args: {
                'future': 5000, 'earn': 5000, 'investRatio': 0.5, 'total': 10000, 'spot': 0,
            },
            'getCurrentPrice': lambda symbol=None: {'price': '500'} if symbol == 'BNBUSDT' else {'price': '100.09'},
            'getCurrentFutureMarkPrice': lambda _symbol: {'markPrice': '100'},
            'getFutureAccount': lambda: self._future_account(state),
            'getAccount': lambda: {'balances': [
                {'asset': 'USDT', 'free': str(state['spot_usdt'])},
                {'asset': 'BNB', 'free': str(state['new_bnb'])},
            ]},
            'getAllOpenOrders': lambda: [],
            'getCurrentPosition': lambda _symbol: self._position(state, fill_ratio),
            'getFuturePositionMode': lambda: {'dualSidePosition': False},
            'changeFutureLeverage': lambda _symbol, lev: state['leverage_calls'].append(lev) or {'leverage': lev},
            'getAllAlgoOpenOrders': lambda: list(state['algo_orders']),
            'setPositionClosePrice': lambda symbol, side, stop, _working: self._add_full_stop(state, symbol, side, stop),
            'setStopLimitPrice': lambda symbol, side, stop, qty, _working, _match: self._add_partial_stop(state, symbol, side, stop, qty),
            'cancelAlgoOrder': lambda symbol, algo_id: self._cancel_algo(state, symbol, algo_id),
            'orderFutureWithTimeLimit': lambda symbol, side, qty, price, _days, _client: self._submit_future(state, symbol, side, qty, price),
            'getFutureOrder': lambda _symbol, orderId=None, clientOrderId=None: self._query_future(state, fill_ratio),
            'cancelFutureOrder': lambda symbol, orderId=None, clientOrderId=None: state['order_cancels'].append((symbol, orderId, clientOrderId)),
            'getFutureUserTrades': lambda _symbol, _order: self._future_trades(state, fill_ratio),
            'getSpotExchangeInfo': lambda _symbol: self._spot_exchange_info(state),
            'getSpotOrder': lambda _symbol, _client: {},
            'cancelSpotOrder': lambda *args, **kwargs: None,
            'getSpotUserTrades': lambda *args: [],
            'orderSpotMarketByQuoteAmount': lambda symbol, quote, client: self._buy_spot_bnb(state, symbol, quote, client),
            'transfer': lambda source, target, asset, amount: self._transfer(state, source, target, asset, amount),
            'getFlexibleSimpleEarnList': lambda _asset: {'rows': [{'asset': 'USDT', 'productId': 'usdt-flex'}]},
            'subscribeFlexibleSimpleEarnProduct': lambda _product, amount: state['earn_deposits'].append(float(amount)) or {'success': True},
            'redeemFlexibleSimpleEarnProduct': lambda *args: {'success': True},
            'sendMessage': lambda message, **_kwargs: state['messages'].append(message),
        })
        env['time'] = SimpleNamespace(sleep=lambda _seconds: None)
        env['getCurrentTime'] = lambda: 123456789
        run_actual_main(env)

        self.assertEqual(state['analysis_periods'], [60])
        self.assertEqual(state['leverage_calls'], [3])
        self.assertFalse(any(str(message).startswith('Failed to finish') for message in state['messages']))
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
            self.assertEqual(state['algo_cancels'], [('BTCUSDT', 500)])
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

    @staticmethod
    def _future_account(state):
        state['future_account_calls'] += 1
        return {'assets': [
            {'asset': 'USDT', 'maxWithdrawAmount': str(state['future_withdrawable'])},
            {'asset': 'BNB', 'maxWithdrawAmount': '7'},
        ]}

    @staticmethod
    def _position(state, fill_ratio):
        state['position_calls'] += 1
        if state['position_calls'] == 1 or fill_ratio == 0:
            return []
        return [{'symbol': 'BTCUSDT', 'positionSide': 'BOTH', 'positionAmt': str(state['requested_qty'] * fill_ratio)}]

    @staticmethod
    def _add_full_stop(state, symbol, side, stop):
        order = {'algoId': 500, 'symbol': symbol, 'side': side, 'type': 'STOP_MARKET',
                 'closePosition': True, 'triggerPrice': str(stop), 'algoStatus': 'NEW'}
        state['algo_orders'].append(order)
        return order

    @staticmethod
    def _add_partial_stop(state, symbol, side, stop, qty):
        order = {'algoId': 501, 'symbol': symbol, 'side': side, 'type': 'STOP',
                 'reduceOnly': True, 'quantity': str(qty), 'triggerPrice': str(stop), 'algoStatus': 'NEW'}
        state['algo_orders'].append(order)
        return order

    @staticmethod
    def _cancel_algo(state, symbol, algo_id):
        state['algo_cancels'].append((symbol, algo_id))
        state['algo_orders'] = [order for order in state['algo_orders'] if order.get('algoId') != algo_id]

    @staticmethod
    def _submit_future(state, symbol, side, qty, price):
        state['requested_qty'] = float(qty)
        state['submitted'] = [(symbol, side, float(qty), float(price))]
        return {'symbol': symbol, 'side': side, 'status': 'NEW', 'orderId': 700,
                'origQty': str(qty), 'executedQty': '0'}

    @staticmethod
    def _query_future(state, fill_ratio):
        state['order_queries'] += 1
        qty = state['requested_qty'] * fill_ratio
        quote = qty * 100
        status = 'FILLED' if fill_ratio == 1 else ('PARTIALLY_FILLED' if fill_ratio > 0 else 'NEW')
        if state['order_queries'] > 1:
            status = 'CANCELED'
        state['future_withdrawable'] = (5000.0 if fill_ratio == 0 else
                                        5000.0 * (1 - fill_ratio) + 5000.0 * fill_ratio - quote / 3 - quote * 0.0004)
        return {'symbol': 'BTCUSDT', 'status': status, 'orderId': 700,
                'origQty': str(state['requested_qty']), 'executedQty': str(qty),
                'cumQuote': str(quote), 'avgPrice': '100'}

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

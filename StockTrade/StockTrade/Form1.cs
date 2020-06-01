using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using AxKHOpenAPILib;

namespace StockTrade
{
    public partial class Form1 : Form
    {
        public Dictionary<string,stockInfo> stocksToBuy;
        public List<stockBalance> stockBalanceList;
        public List<outstanding> outstandingList;
        public List<stockInfo> stockList;
        public List<AutoTradingRule> autoTradingRuleList;
        int autoSreenNumber = 1000;
        int autoRuleID = 0;
        string currentCondition = "";
        public static string ACCOUNT_NUMBER = "";
        DBManager DB;
        GetListFromR Rprogram;

        public Form1()
        {
            InitializeComponent();
            DB = new DBManager();
            balanceCheckButton.Click += ButtonClicked;
            stockSearchButton.Click += ButtonClicked;
            buyButton.Click += ButtonClicked;
            sellButton.Click += ButtonClicked;
            setAutoTradingRuleButton.Click += ButtonClicked;
            startAutoTradingButton.Click += ButtonClicked;
            outstandingDataGridView.SelectionChanged += dataGridViewSelectionChanged;
            orderFixButton.Click += ButtonClicked;
            orderCancelButton.Click += ButtonClicked;
            stopAutoTradingButton.Click += ButtonClicked;
            sellAllStockButton.Click += ButtonClicked;
            balanceDataGridView.SelectionChanged += dataGridViewSelectionChanged;
            limitPriceNumericUpDown.ValueChanged += setBuyingPerStock;
            limitNumberNumericUpDown.ValueChanged += setBuyingPerStock;
            axKHOpenAPI1.OnReceiveTrData += onRecieveTrData;
            axKHOpenAPI1.OnReceiveChejanData += onReceiveChejanData;
            axKHOpenAPI1.OnReceiveTrCondition += onReceiveTrCondition;
            axKHOpenAPI1.OnReceiveRealCondition += onReceiveRealCondition;
            axKHOpenAPI1.OnReceiveRealData += onReceiveRealData;
            axKHOpenAPI1.CommConnect();
            axKHOpenAPI1.OnEventConnect += onEventConnect;
            Rprogram = new GetListFromR();
        }

        public void setBuyingPerStock(object sender, EventArgs e)
        {
            if (sender.Equals(limitPriceNumericUpDown))
            {
                long limitPrice = long.Parse(limitPriceNumericUpDown.Value.ToString());
                long limitNumber = long.Parse(limitNumberNumericUpDown.Value.ToString());
                if (limitPrice > 0 && limitNumber > 0)
                {
                    long limitBuyingPerStock = limitPrice / limitNumber;
                    limitBuyingPerStockLabel.Text = limitBuyingPerStock.ToString();
                }
            }
            else if (sender.Equals(limitNumberNumericUpDown))
            {
                long limitPrice = long.Parse(limitPriceNumericUpDown.Value.ToString());
                long limitNumber = long.Parse(limitNumberNumericUpDown.Value.ToString());
                if (limitPrice > 0 && limitNumber > 0)
                {
                    long limitBuyingPerStock = limitPrice / limitNumber;
                    limitBuyingPerStockLabel.Text = limitBuyingPerStock.ToString();
                }
            }
        }

        private void onReceiveTrCondition(object sender, _DKHOpenAPIEvents_OnReceiveTrConditionEvent e)
        {
            if (e.strCodeList.Length > 0)
            {
                string stockCodeList = e.strCodeList.Remove(e.strCodeList.Length - 1);
                int stockCount = stockCodeList.Split(';').Length;
                if (stockCount <= 100)
                {
                    axKHOpenAPI1.CommKwRqData(stockCodeList, 0, stockCount, 0, "조건검색종목", "5100");
                }
                if (e.nNext != 0)
                {
                    axKHOpenAPI1.SendCondition("5101", e.strConditionName, e.nIndex, 1);
                }
            }
            else if (e.strCodeList.Length == 0)
            {
                MessageBox.Show("검색된 종목이 없습니다.");
            }
        }

        private void dataGridViewSelectionChanged(object sender, EventArgs e)
        {
            if (sender.Equals(balanceDataGridView))
            {
                int rowIndex = balanceDataGridView.SelectedCells[0].RowIndex;
                if (balanceDataGridView.SelectedCells.Count > 0)
                {
                    string[] currentPriceArray = balanceDataGridView["현재가", rowIndex].Value.ToString().Split(',');
                    string stockCode = balanceDataGridView["종목코드", rowIndex].Value.ToString().Replace("A", "");
                    string stockNumber = balanceDataGridView["수량", rowIndex].Value.ToString();
                    string currentPrice = "";
                    for (int i = 0; i < currentPriceArray.Length; i++)
                    {
                        currentPrice = currentPrice + currentPriceArray[i];
                    }
                    stockCodeLabel.Text = stockCode;
                    orderPriceNumericUpDown.Value = long.Parse(currentPrice);
                    orderNumberNumericUpDown.Value = long.Parse(stockNumber);
                }
            }
            else if (sender.Equals(outstandingDataGridView))
            {
                if (outstandingDataGridView.SelectedCells.Count > 0)
                {
                    int rowIndex = outstandingDataGridView.SelectedCells[0].RowIndex;
                    string[] outstandingPriceArray = outstandingDataGridView["주문가격", rowIndex].Value.ToString().Split(',');
                    string outstandingStockCode = outstandingDataGridView["종목코드", rowIndex].Value.ToString();
                    string outstandingStockNumber = outstandingDataGridView["미체결수량", rowIndex].Value.ToString();
                    string outstandingPrice = "";
                    for (int i = 0; i < outstandingPriceArray.Length; i++)
                    {
                        outstandingPrice = outstandingPrice + outstandingPriceArray[i];
                    }
                    stockCodeLabel.Text = outstandingStockCode;
                    orderPriceNumericUpDown.Value = long.Parse(outstandingPrice);
                    orderNumberNumericUpDown.Value = long.Parse(outstandingStockNumber);
                }
            }
        }

        private void onReceiveChejanData(object sender, _DKHOpenAPIEvents_OnReceiveChejanDataEvent e)
        {
            if (e.sGubun == "0")//주문 접수 , 체결시
            {
                string orderNumber = axKHOpenAPI1.GetChejanData(9203);
                string orderStatus = axKHOpenAPI1.GetChejanData(913);
                string orderStockName = axKHOpenAPI1.GetChejanData(302);
                string orderStockNumber = axKHOpenAPI1.GetChejanData(900);
                long orderPrice = long.Parse(axKHOpenAPI1.GetChejanData(901));
                string orderType = axKHOpenAPI1.GetChejanData(905);

                orderRecordListBox.Items.Add("주문번호 : " + orderNumber + " | " + "주문상태 : " + orderStatus);
                orderRecordListBox.Items.Add("종목명 : " + orderStockName + " | " + "주문수량 : " + orderStockNumber);
                orderRecordListBox.Items.Add("주문가격 : " + String.Format("{0:#,###}", orderPrice));
                orderRecordListBox.Items.Add("주문구분 : " + orderType);
                orderRecordListBox.Items.Add("----------------------------------------------------");
            }
            else if (e.sGubun == "1")//국내주식 잔고전달
            {
                string stockName = axKHOpenAPI1.GetChejanData(302);
                long currentPrice = long.Parse(axKHOpenAPI1.GetChejanData(10).Replace("-", ""));

                string profitRate = axKHOpenAPI1.GetChejanData(8019);
                long totalBuyingPrice = long.Parse(axKHOpenAPI1.GetChejanData(932));
                long profitMoney = long.Parse(axKHOpenAPI1.GetChejanData(950));

                todayProfitLabel.Text = String.Format("{0:#,###}", profitMoney);
                todayProfitRateLabel.Text = profitRate;
            }
        }

        private void onRecieveTrData(object sender, _DKHOpenAPIEvents_OnReceiveTrDataEvent e)
        {
            switch (e.sRQName)
            {
                case "계좌평가잔고내역요청":
                    string stockCode;
                    string stockName;
                    int stockPrice;
                    long totalBuyingAmount = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "총매입금액"));
                    long totalEstimatedAmount = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "총평가금액"));
                    totalBuyLabel.Text = String.Format("{0:#,###}", totalBuyingAmount);
                    totalEstimateLabel.Text = String.Format("{0:#,###}", totalEstimatedAmount);
                    break;
                case "계좌평가현황요청":
                    long deposit = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "예수금"));
                    long todayProfit = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "당일투자손익"));
                    double todayProfitRate = double.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "당일손익율"));

                    depositLabel.Text = String.Format("{0:#,###}", deposit);
                    todayProfitLabel.Text = String.Format("{0:#,###}", todayProfit);
                    todayProfitRateLabel.Text = String.Format("{0:#.##}", todayProfitRate);

                    int count = axKHOpenAPI1.GetRepeatCnt(e.sTrCode, e.sRQName);
                    stockBalanceList = new List<stockBalance>();
                    for (int i = 0; i < count; i++)
                    {
                        stockCode = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종목코드").TrimStart('0');
                        stockName = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종목명").Trim();
                        long number = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "보유수량"));
                        long buyingMoney = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "매입금액"));
                        long currentPrice = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "현재가").Replace("-", ""));
                        long estimatedProfit = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "손익금액"));
                        double estimatedProfitRate = double.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "손익율"));

                        stockBalanceList.Add(new stockBalance(stockCode, stockName, number, String.Format("{0:#,###}", buyingMoney), String.Format("{0:#,###}", currentPrice), estimatedProfit, String.Format("{0:f2}", estimatedProfitRate)));
                    }
                    balanceDataGridView.DataSource = stockBalanceList;
                    break;
                case "실시간미체결요청":
                    count = axKHOpenAPI1.GetRepeatCnt(e.sTrCode, e.sRQName);
                    outstandingList = new List<outstanding>();
                    for (int i = 0; i < count; i++)
                    {
                        string orderCode = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "주문번호")).ToString();
                        stockCode = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종목코드").Trim();
                        stockName = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종목명").Trim();
                        int orderNumber = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "주문수량"));
                        int orderPrice = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "주문가격"));
                        int outstandingNumber = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "미체결수량"));
                        int currentPrice = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "현재가").Replace("-", ""));
                        string orderGubun = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "주문구분").Trim();
                        string orderTime = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "시간").Trim();

                        outstandingList.Add(new outstanding(orderCode, stockCode, stockName, orderNumber, String.Format("{0:#,###}", orderPrice), String.Format("{0:#,###}", currentPrice), outstandingNumber, orderGubun, orderTime));
                    }
                    outstandingDataGridView.DataSource = outstandingList;
                    break;
                case "종목정보요청":
                    string currentStockPrice = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "현재가");
                    orderPriceNumericUpDown.Value = long.Parse(currentStockPrice.Replace("-", ""));
                    break;
                case "조건검색종목":
                    count = axKHOpenAPI1.GetRepeatCnt(e.sTrCode, e.sRQName);//조건식으로 검색되는 종목의 개수
                    foreach(var rule in autoTradingRuleList)
                    {
                        if (rule.상태 != "시작") continue;
                        int autoTradingRuleID = rule.번호;
                        int autoOrderPricePerStock = rule.종목당매수금액;
                        int autoTradingLimitOrderNumber = rule.제한종목개수;
                        string autoBuyOrderType = rule.매수거래구분;
                        string[] autoBuyOrderArray = autoBuyOrderType.Split(':');
                    }
                    if (autoRuleDataGridView.Rows.Count > 0)//선택된 DataGridView 셀을 체크
                    {
                        int rowIndex = autoRuleDataGridView.SelectedCells[0].RowIndex;
                        int autoTradingRuleID = int.Parse(autoRuleDataGridView["거래규칙_번호", rowIndex].Value.ToString());
                        int autoOrderPricePerStock = int.Parse(autoRuleDataGridView["거래규칙_종목당_매수금액", rowIndex].Value.ToString());
                        int autoTradingLimitOrderNumber = int.Parse(autoRuleDataGridView["거래규칙_매입제한_종목_개수", rowIndex].Value.ToString());
                        string autoBuyOrderType = autoRuleDataGridView["거래규칙_매수_거래구분", rowIndex].Value.ToString();
                        string[] autoBuyOrderArray = autoBuyOrderType.Split(':');
                        string autoRuleStatus = autoRuleDataGridView["거래규칙_상태", rowIndex].Value.ToString();
                        int autoRuleListIndex = autoTradingRuleList.FindIndex(o => o.번호 == autoRuleID);
                        if (autoRuleStatus == "시작" && accountComboBox.Text.Length > 0)//거래규칙 상태가 "시작"이면
                        {
                            ACCOUNT_NUMBER = accountComboBox.Text;
                            for (int i = 0; i < count; i++)
                            {
                                if (i > autoTradingLimitOrderNumber)//제한 종목개수 초과하면 break;
                                    break;
                                else
                                {
                                    stockCode = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종목코드").Trim();
                                    stockName = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종목명").Trim();
                                    stockPrice = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "현재가").Replace("-", ""));
                                    if (autoOrderPricePerStock > stockPrice)
                                    {
                                        int orderNumber = autoOrderPricePerStock / stockPrice;
                                        axKHOpenAPI1.SendOrder("자동거래매수주문", "5149", ACCOUNT_NUMBER, 1, stockCode, orderNumber, stockPrice, autoBuyOrderArray[0], "");
                                        autoTradingRuleList[autoRuleListIndex].autoTradingPurchaseStockList.Add(new AutoTradingPurchaseStock(stockCode, stockPrice, 0));
                                    }
                                }
                            }
                        }
                    }
                    break;
                case "자동거래2차매수":
                    stockPrice = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "현재가").Replace("-", ""));
                    stockCode = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "종목코드").Trim();
                    int ruleIndex = autoTradingRuleList.FindIndex(o => o.키움조건식 == currentCondition);

                    if (autoTradingRuleList[ruleIndex].autoTradingPurchaseStockList.Count < autoTradingRuleList[ruleIndex].제한종목개수 && autoTradingRuleList[ruleIndex].종목당매수금액 > stockPrice)
                    {
                        if (accountComboBox.Text.Length > 0 && autoTradingRuleList[ruleIndex].상태 == "시작")
                        {
                            int autoOrderPricePerStock = autoTradingRuleList[ruleIndex].종목당매수금액;
                            int orderNumber = autoOrderPricePerStock / stockPrice;
                            ACCOUNT_NUMBER = accountComboBox.Text;
                            string[] autoOrderTypeArray = autoTradingRuleList[ruleIndex].매수거래구분.Split(':');

                            axKHOpenAPI1.SendOrder("자동거래2차매수주문", "5154", ACCOUNT_NUMBER, 1, stockCode, orderNumber, stockPrice, autoOrderTypeArray[0], "");
                            autoTradingRuleList[ruleIndex].autoTradingPurchaseStockList.Add(new AutoTradingPurchaseStock(stockCode, stockPrice, 0));
                        }
                    }
                    break;
            }
        }
        public void onReceiveRealCondition(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveRealConditionEvent e)
        {
            if (e.strType == "I")
            {
                string stockName = axKHOpenAPI1.GetMasterCodeName(e.sTrCode);
                insertListBox.Items.Add("종목편입| 조건인덱스 : " + e.strConditionIndex + " | 종목코드 : " + e.sTrCode + " | " + "종목명 : " + stockName);
                currentCondition = e.strConditionIndex + ":" + e.strConditionName;
                axKHOpenAPI1.SetInputValue("종목코드", e.sTrCode);
                axKHOpenAPI1.CommRqData("자동거래2차매수", "opt10001", 0, "5152");
            }
            else if (e.strType == "D")
            {
                string stockName = axKHOpenAPI1.GetMasterCodeName(e.sTrCode);
                deleteListBox.Items.Add("종목이탈| 조건인덱스 : " + e.strConditionIndex + " | 종목코드 : " + e.sTrCode + " | " + "종목명 : " + stockName);
            }
        }
        public void onReceiveRealData(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveRealDataEvent e)
        {
            for (int i = 0; i < autoTradingRuleList.Count; i++)
            {
                if (autoTradingRuleList[i].상태 == "시작")
                {
                    double profitRate = autoTradingRuleList[i].이익률 * 0.01;
                    double lossRate = autoTradingRuleList[i].손절률 * 0.01;

                    for (int j = 0; j < autoTradingRuleList[i].autoTradingPurchaseStockList.Count; j++)
                    {
                        autoTradingRuleList[i].autoTradingPurchaseStockList[j].currentPrice = int.Parse(axKHOpenAPI1.GetCommRealData(e.sRealKey, 10));
                        autoTradingRuleList[i].autoTradingPurchaseStockList[j].boughtCount = int.Parse(axKHOpenAPI1.GetCommRealData(e.sRealKey, 930));

                        string stockCode = autoTradingRuleList[i].autoTradingPurchaseStockList[j].stockCode;
                        int currentPrice = autoTradingRuleList[i].autoTradingPurchaseStockList[j].currentPrice;
                        int boughtPrice = autoTradingRuleList[i].autoTradingPurchaseStockList[j].boughtPrice;
                        int boughtCount = autoTradingRuleList[i].autoTradingPurchaseStockList[j].boughtCount;
                        string orderType = autoTradingRuleList[i].매도거래구분;
                        string[] orderTypeArray = orderType.Split(':');

                        if (profitRate > 0 &&  currentPrice == (boughtPrice + (boughtPrice * profitRate)))
                        {
                            axKHOpenAPI1.SendOrder("이익율매도주문", "8889", ACCOUNT_NUMBER, 2, stockCode, boughtCount, currentPrice, orderTypeArray[0], "");
                        }
                        else if (lossRate > 0 && currentPrice == (boughtPrice - (boughtPrice * lossRate)))
                        {
                            axKHOpenAPI1.SendOrder("손절율매도주문", "8789", ACCOUNT_NUMBER, 2, stockCode, boughtCount, currentPrice, orderTypeArray[0], "");
                        }
                    }
                }
            }
        }
        private void ButtonClicked(object sender, EventArgs e)
        {
            if (sender.Equals(balanceCheckButton)) getBalanceInfo();
            else if (sender.Equals(stockSearchButton)) searchStockInfo();
            else if (sender.Equals(buyButton)) buyStocks();
            else if (sender.Equals(sellButton)) sellStocks();
            else if (sender.Equals(setAutoTradingRuleButton)) setAutoTradingRule();
            else if (sender.Equals(orderFixButton)) fixOrder();
            else if (sender.Equals(orderCancelButton)) cancelOrder();
            else if (sender.Equals(startAutoTradingButton)) startAutoTrading();
            else if (sender.Equals(stopAutoTradingButton)) stopAutoTrading();
            else if (sender.Equals(sellAllStockButton)) sellAllStocks();
        }
        void startAutoTrading()
        {
            foreach(DataGridViewRow row in autoRuleDataGridView.Rows)
            {
                if (row.Cells["거래규칙_상태"].Value.ToString() != "시작") continue;
                var newRule = new AutoTradingRule(int.Parse(row.Cells[0].Value.ToString()),
                    row.Cells[1].Value.ToString(), row.Cells[2].Value.ToString(),
                    long.Parse(row.Cells[3].Value.ToString()), int.Parse(row.Cells[4].Value.ToString()),
                    int.Parse(row.Cells[5].Value.ToString()), row.Cells[6].Value.ToString(),
                    row.Cells[7].Value.ToString(), double.Parse(row.Cells[8].Value.ToString()),
                    double.Parse(row.Cells[8].Value.ToString()), DateTime.Parse(row.Cells[9].ToString()),
                    row.Cells[9].Value.ToString());
                autoTradingRuleList.Add(newRule);
                string autoTradingCondition = row.Cells["거래규칙_조건식"].Value.ToString();

                //R 조건검색 데이터 추가
                DataTable RcorpList = Rprogram.getCorpTable(row.Cells[1].Value.ToString());
                //사야할 리스트에 추가
                foreach(DataRow corp in RcorpList.Rows)
                {
                    string code = corp["종목코드"].ToString();
                    string name = corp["종목이름"].ToString();
                    int price = newRule.종목당매수금액;
                    if (stocksToBuy.Keys.Contains(code)) stocksToBuy[code].remainingPrice += price;
                    else stocksToBuy.Add(code, new stockInfo(code, name, price));
                }
                //현재 잔고 검색
                axKHOpenAPI1.CommRqData("계좌평가현황요청", "opw00004", 0, "4000");

                if (autoTradingCondition != null)
                {
                    string[] autoTradingArray = autoTradingCondition.Split(':');
                    autoSreenNumber++;
                    string scrNumber = autoSreenNumber.ToString();
                    axKHOpenAPI1.SendCondition(scrNumber, autoTradingArray[1], int.Parse(autoTradingArray[0]), 0);
                    axKHOpenAPI1.SendCondition(scrNumber, autoTradingArray[1], int.Parse(autoTradingArray[0]), 1);
                }
            }
        }
        void stopAutoTrading()
        {
            foreach (DataGridViewRow row in autoRuleDataGridView.Rows)
                row.Cells["거래규칙_상태"].Value = "정지";
        }
        void sellAllStocks()
        {
            foreach(var rule in autoTradingRuleList)
            {
                foreach(var list in rule.autoTradingPurchaseStockList)
                {
                    string stockCode = list.stockCode;
                    int boughtCount = list.boughtCount;
                    int currentPrice = list.boughtPrice;
                    axKHOpenAPI1.SendOrder("전체청산주문", "9999", ACCOUNT_NUMBER, 2, stockCode, boughtCount, currentPrice, "03", "");
                }
            }
        }
        void fixOrder()
        {
            string accountNubmer = accountComboBox.Text;
            if (outstandingDataGridView.SelectedCells.Count > 0 && accountNubmer.Length > 0)
            {
                int rowIndex = outstandingDataGridView.SelectedCells[0].RowIndex;
                string orderType = outstandingDataGridView["주문구분", rowIndex].Value.ToString();
                string tradingType = orderComboBox.Text;
                string stockCode = outstandingDataGridView["종목코드", rowIndex].Value.ToString();
                int orderNumber = int.Parse(orderNumberNumericUpDown.Value.ToString());
                int orderPrice = int.Parse(orderPriceNumericUpDown.Value.ToString());
                string orderCode = outstandingDataGridView["주문번호", rowIndex].Value.ToString();

                if (orderType.Length > 0 && tradingType.Length > 0 && stockCode.Length > 0 && orderNumber > 0 && orderPrice > 0 && orderCode.Length > 0)
                {
                    string[] tradingTypeArray = tradingType.Split(':');
                    if (orderType == "-매도")
                    {
                        axKHOpenAPI1.SendOrder("종목주문정정", "1430", accountNubmer, 6, stockCode, orderNumber, orderPrice, tradingTypeArray[0], orderCode);
                        MessageBox.Show("정정요청 완료");
                    }
                    else if (orderType == "+매수")
                    {
                        axKHOpenAPI1.SendOrder("종목주문정정", "1430", accountNubmer, 5, stockCode, orderNumber, orderPrice, tradingTypeArray[0], orderCode);
                        MessageBox.Show("정정요청 완료");
                    }
                }
            }
        }
        void cancelOrder()
        {
            if (outstandingDataGridView.SelectedCells.Count > 0)
            {
                string accountNubmer = accountComboBox.Text;
                if (outstandingDataGridView.SelectedCells.Count > 0 && accountNubmer.Length > 0)
                {
                    int rowIndex = outstandingDataGridView.SelectedCells[0].RowIndex;
                    string orderType = outstandingDataGridView["주문구분", rowIndex].Value.ToString();
                    string tradingType = orderComboBox.Text;
                    string stockCode = outstandingDataGridView["종목코드", rowIndex].Value.ToString();
                    int orderNumber = int.Parse(orderNumberNumericUpDown.Value.ToString());
                    int orderPrice = int.Parse(orderPriceNumericUpDown.Value.ToString());
                    string orderCode = outstandingDataGridView["주문번호", rowIndex].Value.ToString();

                    if (orderType.Length > 0 && tradingType.Length > 0 && stockCode.Length > 0 && orderNumber > 0 && orderPrice > 0 && orderCode.Length > 0)
                    {
                        string[] tradingTypeArray = tradingType.Split(':');
                        if (orderType == "-매도")
                        {
                            axKHOpenAPI1.SendOrder("종목주문정정", "1430", accountNubmer, 4, stockCode, orderNumber, orderPrice, tradingTypeArray[0], orderCode);
                            MessageBox.Show("취소요청 완료");
                        }
                        else if (orderType == "+매수")
                        {
                            axKHOpenAPI1.SendOrder("종목주문정정", "1430", accountNubmer, 3, stockCode, orderNumber, orderPrice, tradingTypeArray[0], orderCode);
                            MessageBox.Show("취소요청 완료");
                        }
                    }
                }
            }
        }
        void setAutoTradingRule()
        {
            string selectedCondition = conditionComboBox.Text;//조건식 선택
            int limitBuyingStockPrice = int.Parse(limitPriceNumericUpDown.Value.ToString());//매입제한 금액
            int limitBuyingStockNumber = int.Parse(limitNumberNumericUpDown.Value.ToString());//매입 제한 종목개수
            int limitBuyingPerStock = int.Parse(limitBuyingPerStockLabel.Text.ToString());//종목당 매수금액
            string autoBuyingOrderType = autoBuyOrderComboBox.Text;//매수 거래구분

            double profitRate = double.Parse(limitProfitRateNumericUpDown.Value.ToString());//이익률
            double lossRate = double.Parse(limitLossRateNumericUpDown.Value.ToString());//손절률
            string autoSellingOrderType = autoSellOrderComboBox.Text;//매도 거래구분
            string status = "정지";

            if (selectedCondition.Length > 0 && limitBuyingStockPrice > 0 && limitBuyingStockNumber > 0 &&
                limitBuyingPerStock > 0 && autoBuyingOrderType.Length > 0 && profitRate > 0 &&
                lossRate != 0 && autoSellingOrderType.Length > 0)
            {
                autoRuleID++;
                string[] conditionName = selectedCondition.Split(':');

                autoRuleDataGridView.Rows.Add();
                autoRuleDataGridView["거래규칙_번호", autoRuleDataGridView.Rows.Count - 1].Value = autoRuleID;
                autoRuleDataGridView["거래규칙_조건식", autoRuleDataGridView.Rows.Count - 1].Value = selectedCondition;
                autoRuleDataGridView["거래규칙_매입제한_금액", autoRuleDataGridView.Rows.Count - 1].Value = limitBuyingStockPrice;
                autoRuleDataGridView["거래규칙_매입제한_종목_개수", autoRuleDataGridView.Rows.Count - 1].Value = limitBuyingStockNumber;
                autoRuleDataGridView["거래규칙_종목당_매수금액", autoRuleDataGridView.Rows.Count - 1].Value = limitBuyingPerStock;
                autoRuleDataGridView["거래규칙_매수_거래구분", autoRuleDataGridView.Rows.Count - 1].Value = autoBuyingOrderType;
                autoRuleDataGridView["거래규칙_매도_거래구분", autoRuleDataGridView.Rows.Count - 1].Value = autoSellingOrderType;
                autoRuleDataGridView["거래규칙_이익률", autoRuleDataGridView.Rows.Count - 1].Value = profitRate;
                autoRuleDataGridView["거래규칙_손절률", autoRuleDataGridView.Rows.Count - 1].Value = lossRate;
                autoRuleDataGridView["거래규칙_상태", autoRuleDataGridView.Rows.Count - 1].Value = status;

                MessageBox.Show("설정완료");
            }
            else if (selectedCondition.Length == 0 || limitBuyingStockPrice == 0 || limitBuyingStockNumber == 0 ||
                limitBuyingPerStock == 0 || autoBuyingOrderType.Length == 0 || profitRate == 0 ||
                lossRate == 0 || autoSellingOrderType.Length == 0)
            {
                MessageBox.Show("거래규칙 값을 모두 입력하세요");
            }
        }
        void sellStocks()
        {
            string accountNumber = accountComboBox.Text;//계좌번호
            string stockCode = stockCodeLabel.Text;//종목코드
            string sellOrderType = orderComboBox.Text;//거래구분
            int sellOrderPrice = int.Parse(orderPriceNumericUpDown.Value.ToString());
            int sellOrderNumber = int.Parse(orderNumberNumericUpDown.Value.ToString());

            if (accountNumber.Length > 0 && sellOrderType.Length > 0 && stockCode.Length > 0 && sellOrderPrice > 0 && sellOrderNumber > 0)
            {
                string[] orderType = sellOrderType.Split(':');
                axKHOpenAPI1.SendOrder("신규종목매도주문", "8289", accountNumber, 2, stockCode, sellOrderNumber, sellOrderPrice, orderType[0], "");
            }
        }
        void buyStocks()
        {
            string buyOrderType = orderComboBox.Text;
            int buyOrderPrice = int.Parse(orderPriceNumericUpDown.Value.ToString());
            int buyOrderNumber = int.Parse(orderNumberNumericUpDown.Value.ToString());
            string accountNumber = accountComboBox.Text;
            string stockCode = stockCodeLabel.Text;

            if (buyOrderType.Length > 0 && buyOrderPrice > 0 && buyOrderNumber > 0 && accountNumber.Length > 0 && stockCode.Length > 0)
            {
                string[] orderType = buyOrderType.Split(':');
                axKHOpenAPI1.SendOrder("신규종목매수주문", "8249", accountNumber, 1, stockCode, buyOrderNumber, buyOrderPrice, orderType[0], "");
            }
        }
        void searchStockInfo()
        {
            string stockName = stockTextBox.Text;
            int index = stockList.FindIndex(o => o.stockName == stockName);
            string stockCode = stockList[index].stockCode;
            stockCodeLabel.Text = stockCode;

            axKHOpenAPI1.SetInputValue("종목코드", stockCode);
            axKHOpenAPI1.CommRqData("종목정보요청", "opt10001", 0, "5000");
        }
        void getBalanceInfo()
        {
            if (accountComboBox.Text.Length == 0 || passwordTextBox.Text.Length == 0) return;
            string accountNumber = accountComboBox.Text;
            string password = passwordTextBox.Text;
            axKHOpenAPI1.SetInputValue("계좌번호", accountNumber);
            axKHOpenAPI1.SetInputValue("비밀번호", password);
            axKHOpenAPI1.SetInputValue("비밀번호입력매체구분", "00");
            axKHOpenAPI1.SetInputValue("조회구분", "1");
            axKHOpenAPI1.CommRqData("계좌평가잔고내역요청", "opw00018", 0, "8100");

            axKHOpenAPI1.SetInputValue("계좌번호", accountNumber);
            axKHOpenAPI1.SetInputValue("비밀번호", password);
            axKHOpenAPI1.SetInputValue("상장폐지조회구분", "0");
            axKHOpenAPI1.SetInputValue("비밀번호입력매체구분", "00");
            axKHOpenAPI1.CommRqData("계좌평가현황요청", "opw00004", 0, "4000");

            axKHOpenAPI1.SetInputValue("계좌번호", accountNumber);
            axKHOpenAPI1.SetInputValue("체결구분", "1");
            axKHOpenAPI1.SetInputValue("매매구분", "2");
            axKHOpenAPI1.CommRqData("실시간미체결요청", "opt10075", 0, "5700");
        }
        public void onEventConnect(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnEventConnectEvent e)
        {
        }
        DataTable getStockListFromDB()
        {
            string sql = @"select * from(
                            select rank(일자) desc as rnk, * from metainfo.기업정보
                          ) where rnk = 1";
            return DB.readFromDB(sql);
        }

    }

}

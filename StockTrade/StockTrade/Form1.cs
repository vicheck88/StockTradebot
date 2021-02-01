using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using static System.Windows.Forms.Timer;
using AxKHOpenAPILib;
using System.Threading;
using NpgsqlTypes;
using Npgsql;
using System.IO;
using Newtonsoft.Json.Linq;
using System.Runtime.Remoting.Lifetime;

namespace StockTrade
{
    public partial class Form1 : Form
    {
        public Dictionary<string,stockInfo> stocksToBuy;
        public List<stockBalance> stockBalanceList;
        public List<outstanding> outstandingList;
        public List<stockInfo> stockList;
        public List<AutoTradingRule> autoTradingRuleList;
        public List<AutoTradingRule> registeredRuleList;
        public RscriptManager Rmanager;
        int autoRuleID = 0;
        string currentServerCondition;
        public static string ACCOUNT_NUMBER = "";
        DBManager DB;
        GetListFromR Rprogram;
        string updateTime;
        string buyOrderType;
        string sellOrderType;
        System.Windows.Forms.Timer t;
        string userID;
        string userName;
        JObject curAutoTradingRule;
        string curTradingRulePath;
        bool autoFlag = false;
        bool sellAllFlag = false;
        bool isPriceUpdated = false;
        DataTable RcorpLists;

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
            selectRFileButton.Click += ButtonClicked;
            balanceDataGridView.SelectionChanged += dataGridViewSelectionChanged;
            limitPriceNumericUpDown.ValueChanged += setBuyingPerStock;
            limitNumberNumericUpDown.ValueChanged += setBuyingPerStock;
            axKHOpenAPI1.OnReceiveTrData += onRecieveTrData;
            axKHOpenAPI1.OnReceiveChejanData += onReceiveChejanData;
            axKHOpenAPI1.CommConnect();
            axKHOpenAPI1.OnEventConnect += onEventConnect;
            Rprogram = new GetListFromR();
            Rmanager = new RscriptManager(DB);
            stocksToBuy = new Dictionary<string, stockInfo>();
            stockBalanceList = new List<stockBalance>();
            readCurTradeRule();
            readDefaultAccountSetting();
        }
        void readDefaultAccountSetting()
        {
            var defaultAccountPath= Path.Combine(System.AppDomain.CurrentDomain.BaseDirectory, "accountSetting.json");
            if (File.Exists(defaultAccountPath))
            {
                var json = JObject.Parse(File.ReadAllText(defaultAccountPath));
                ACCOUNT_NUMBER = json["account"].ToString();
                passwordTextBox.Text = json["password"].ToString();
                accountComboBox.Text = ACCOUNT_NUMBER;
            }
        }
        private void readCurTradeRule() //curTradingRulePath의 데이터를 registeredRuleList에 입력
        {
            registeredRuleList = new List<AutoTradingRule>();
            curTradingRulePath = Path.Combine(System.AppDomain.CurrentDomain.BaseDirectory, "ruleSetting.json");
            if (File.Exists(curTradingRulePath))
            {
                curAutoTradingRule = JObject.Parse(File.ReadAllText(curTradingRulePath));
                foreach(var s in curAutoTradingRule)
                {
                    registeredRuleList.Add(new AutoTradingRule( int.Parse(s.Key), s.Value["Rname"].ToString(), int.Parse(s.Value["limitBuyingStockPrice"].ToString()),
                    int.Parse(s.Value["limitBuyingStockNumber"].ToString()), int.Parse(s.Value["limitBuyingPerStock"].ToString()), s.Value["autoBuyingOrderType"].ToString(),
                    s.Value["autoSellingOrderType"].ToString(), s.Value["updateTime"].ToString(), "정지"));
                }
                updateAutoTradingRule();
            }
        }
        void writeCurTradeRule() //registeredRuleList데이터를 curTradingRulPath에 저장
        {
            curAutoTradingRule = new JObject();
            foreach (var s in registeredRuleList)
            {
                var str = string.Format("{{Rname:\"{0}\",limitBuyingStockPrice:\"{1}\",limitBuyingStockNumber:\"{2}\"," +
                    "limitBuyingPerStock:\"{3}\",autoBuyingOrderType:\"{4}\",autoSellingOrderType:\"{5}\",updateTime:\"{6}\"}}",
                    s.분석R파일, s.매입제한금액, s.제한종목개수, s.종목당매수금액, s.매수거래구분, s.매도거래구분, s.업데이트시간);
                var newRuleJson = JObject.Parse(str);
                curAutoTradingRule.Add(registeredRuleList.IndexOf(s).ToString(), newRuleJson);
            }
            if (File.Exists(curTradingRulePath)) File.Delete(curTradingRulePath);
            File.WriteAllText(curTradingRulePath, curAutoTradingRule.ToString());
            updateAutoTradingRule();
        }
        public void updateAutoTradingRule() //registeredRuleList - autoRuleDataGridView 동기화
        {
            autoRuleDataGridView.Rows.Clear();
            int i = 0;
            foreach(var l in registeredRuleList)
            {
                autoRuleDataGridView.Rows.Add(new string[] {
                i++.ToString(),l.분석R파일,l.매입제한금액.ToString(),l.제한종목개수.ToString(),l.종목당매수금액.ToString(),l.매수거래구분,l.매도거래구분,
                l.업데이트시간, l.상태});
            }
            ((DataGridViewComboBoxColumn)autoRuleDataGridView.Columns[8]).Items.Clear();
            ((DataGridViewComboBoxColumn)autoRuleDataGridView.Columns[8]).Items.AddRange(new string[] { "시작", "정지" });
            ((DataGridViewComboBoxColumn)autoRuleDataGridView.Columns[8]).ReadOnly = false;
            autoRuleDataGridView.Refresh();
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
                    limitBuyingPerStockTextBox.Text = limitBuyingPerStock.ToString();
                }
            }
            else if (sender.Equals(limitNumberNumericUpDown))
            {
                long limitPrice = long.Parse(limitPriceNumericUpDown.Value.ToString());
                long limitNumber = long.Parse(limitNumberNumericUpDown.Value.ToString());
                if (limitPrice > 0 && limitNumber > 0)
                {
                    long limitBuyingPerStock = limitPrice / limitNumber;
                    limitBuyingPerStockTextBox.Text = limitBuyingPerStock.ToString();
                }
            }
        }

        private void dataGridViewSelectionChanged(object sender, EventArgs e)
        {
            if (sender.Equals(balanceDataGridView))
            {
                if (balanceDataGridView.SelectedCells.Count == 0) return;
                int rowIndex = balanceDataGridView.SelectedCells[0].RowIndex;
                string[] currentPriceArray = balanceDataGridView["현재가", rowIndex].Value.ToString().Split(',');
                string stockCode = balanceDataGridView["종목코드", rowIndex].Value.ToString().Replace("A", "");
                string stockNumber = balanceDataGridView["수량", rowIndex].Value.ToString();
                string currentPrice = "";
                for (int i = 0; i < currentPriceArray.Length; i++)
                {
                    currentPrice = currentPrice + currentPriceArray[i];
                }
                stockCodeLabel.Text = stockCode;
                long price;
                long number;
                if(long.TryParse(currentPrice,out price)) orderPriceNumericUpDown.Value = price;
                if(long.TryParse(stockNumber,out number)) orderNumberNumericUpDown.Value = number;
            }
            else if (sender.Equals(outstandingDataGridView))
            {
                if (outstandingDataGridView.SelectedCells.Count == 0) return;
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
                if(outstandingPrice!="") orderPriceNumericUpDown.Value = long.Parse(outstandingPrice);
                orderNumberNumericUpDown.Value = long.Parse(outstandingStockNumber);
                }
        }

        private void onReceiveChejanData(object sender, _DKHOpenAPIEvents_OnReceiveChejanDataEvent e)
        {
            if (e.sGubun == "0")//주문 접수 , 체결시
            {
                /*주문체결
                9201 계좌번호
                9203 주문번호
                9205 관리자사번
                9001 종목코드, 업종코드
                912 주문업무분류(JJ: 주식주문, FJ: 선물옵션, JG: 주식잔고, FG: 선물옵션잔고)
                913 주문상태(10:원주문, 11:정정주문, 12:취소주문, 20:주문확인, 21:정정확인, 22:취소확인, 90 - 92:주문거부)
                302 종목명
                900 주문수량
                901 주문가격
                902 미체결수량
                903 체결누계금액
                904 원주문번호
                905 주문구분(+현금내수, -현금매도…)
                906 매매구분(보통, 시장가…)
                907 매도수구분(1:매도, 2:매수)
                908 주문 / 체결시간(HHMMSSMS)
                909 체결번호
                910 체결가
                911 체결량
                10 현재가, 체결가, 실시간종가
                27(최우선)매도호가
                28(최우선)매수호가
                914 단위체결가
                915 단위체결량
                938 당일매매 수수료
                939 당일매매세금
                */
                DateTime date = DateTime.Now;
                string orderNumber = axKHOpenAPI1.GetChejanData(9203);
                string orderStatus = axKHOpenAPI1.GetChejanData(913);
                string orderStockName = axKHOpenAPI1.GetChejanData(302);
                string orderStockCode = axKHOpenAPI1.GetChejanData(9001);
                int orderStockNumber = int.Parse(axKHOpenAPI1.GetChejanData(900));
                int orderPrice = int.Parse(axKHOpenAPI1.GetChejanData(901));
                string orderType = axKHOpenAPI1.GetChejanData(905);

                orderRecordListBox.Items.Add("날짜 : " + date + " | " + "주문번호 : " + orderNumber + " | " + "주문상태 : " + orderStatus);
                orderRecordListBox.Items.Add("종목코드 : "+ orderStockCode + " | "+"종목명 : " + orderStockName + " | " + "주문수량 : " + orderStockNumber);
                orderRecordListBox.Items.Add("주문가격 : " + String.Format("{0:#,###}", orderPrice));
                orderRecordListBox.Items.Add("주문구분 : " + orderType);
                orderRecordListBox.Items.Add("----------------------------------------------------");

                string SQL = string.Format(@"INSERT INTO {0}.주문내역 
                              (날짜,주문자,주문번호,주문상태,종목코드,종목명,주문량,주문가격,주문구분) values 
                              (@date,@user,@orderNumber,@orderStatus,@orderStockCode,@orderStockName,@orderStockNumber,@orderPrice,@orderType)",
                              currentServerCondition=="1"?"test":"real");
                Dictionary<string, object[]> orderInfo = new Dictionary<string, object[]>();
                orderInfo.Add("date", new object[] { NpgsqlDbType.Text, date.ToString("yyyy-MM-dd HH:mm:ss") });
                orderInfo.Add("user", new object[] { NpgsqlDbType.Text, userID });
                orderInfo.Add("orderNumber", new object[] { NpgsqlDbType.Text, orderNumber });
                orderInfo.Add("orderStatus", new object[] { NpgsqlDbType.Text, orderStatus });
                orderInfo.Add("orderStockCode", new object[] { NpgsqlDbType.Text, orderStockCode.Trim(new char[] { 'A', ' ' }) });
                orderInfo.Add("orderStockName", new object[] { NpgsqlDbType.Text, orderStockName });
                orderInfo.Add("orderStockNumber", new object[] { NpgsqlDbType.Integer, orderStockNumber });
                orderInfo.Add("orderPrice", new object[] { NpgsqlDbType.Integer, orderPrice });
                orderInfo.Add("orderType", new object[] { NpgsqlDbType.Text, orderType });
                DB.writeToDB(SQL, orderInfo);
            }
            else if (e.sGubun == "1")//국내주식 잔고전달
            {
                string stockName = axKHOpenAPI1.GetChejanData(302);
                long currentPrice = long.Parse(axKHOpenAPI1.GetChejanData(10).Replace("-", ""));

                string profitRate = axKHOpenAPI1.GetChejanData(8019);

                int totalBuyingPrice, profitMoney;
                int.TryParse(axKHOpenAPI1.GetChejanData(932), out totalBuyingPrice);
                int.TryParse(axKHOpenAPI1.GetChejanData(950), out profitMoney);

                todayProfitLabel.Text = String.Format("{0:#,###}", profitMoney);
                todayProfitRateLabel.Text = profitRate;
            }
        }

        private void onRecieveTrData(object sender, _DKHOpenAPIEvents_OnReceiveTrDataEvent e)
        {
            switch (e.sRQName)
            {
                case "계좌평가잔고내역요청":
                    string stockCode, stockName;
                    int stockPrice, totalBuyingAmount, totalEstimatedAmount;
                    int.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "총매입금액"), out totalBuyingAmount);
                    int.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "총평가금액"), out totalEstimatedAmount);
                    totalBuyLabel.Text = String.Format("{0:#,###}", totalBuyingAmount);
                    totalEstimateLabel.Text = String.Format("{0:#,###}", totalEstimatedAmount);

                    int count = axKHOpenAPI1.GetRepeatCnt(e.sTrCode, e.sRQName);
                    
                    for (int i = 0; i < count; i++)
                    {
                        int buyingMoney, currentPrice, estimatedProfit, closedPrice, number, estimatedAllPrice;
                        double estimatedProfitRate;
                        stockCode = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종목번호").Trim(new char[] { 'A', ' ' });
                        stockName = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종목명").Trim();
                        int.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "보유수량"),out number);
                        int.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "매입금액"), out buyingMoney);
                        int.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "현재가"), out currentPrice);
                        int.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "평가금액"), out estimatedAllPrice);
                        int.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "평가손익"), out estimatedProfit);
                        double.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "수익률(%)"), out estimatedProfitRate);
                        int.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "전일종가"), out closedPrice);

                        stockBalanceList.Add(new stockBalance(stockCode, stockName, number, String.Format("{0:#,###}", buyingMoney),
                            String.Format("{0:#,###}", currentPrice), String.Format("{0:#,###}", estimatedProfit), String.Format("{0:f2}", estimatedProfitRate/100),
                            String.Format("{0:#,###}", closedPrice), String.Format("{0:#,###}", estimatedAllPrice)));
                    }
                    if (e.sPrevNext == "2") getContinuousBalanceInfo("계좌평가잔고내역요청");
                    else
                    {
                        balanceDataGridView.DataSource = null;
                        balanceDataGridView.DataSource = stockBalanceList;
                        if (autoFlag)
                        {
                            autoFlag = false;
                            updateBalance();
                            buyAutoStocks();
                        }
                        else if (!autoFlag) seeTodayStockDeal();
                        else if (sellAllFlag)
                        {
                            sellAllFlag = false;
                            foreach (var s in stockBalanceList)
                            {
                                stockCode = s.종목코드;
                                int boughtCount = s.수량;
                                int currentPrice = int.Parse(s.현재가);
                                axKHOpenAPI1.SendOrder("전체청산주문", "9999", ACCOUNT_NUMBER, 2, stockCode, boughtCount, currentPrice, "03", "");
                            }
                        }
                    }
                    break;
                case "계좌평가현황요청":
                    long deposit;
                    long.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "예수금"), out deposit);
                    long todayProfit;
                    long.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "당일투자손익"), out todayProfit);
                    double todayProfitRate;
                    double.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "당일손익율"), out todayProfitRate);
                    count = axKHOpenAPI1.GetRepeatCnt(e.sTrCode, e.sRQName);
                    depositLabel.Text = String.Format("{0:#,###}", deposit);
                    todayProfitLabel.Text = String.Format("{0:#,###}", todayProfit);
                    todayProfitRateLabel.Text = String.Format("{0:#.##}", todayProfitRate);
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
                    outstandingDataGridView.DataSource = null;
                    outstandingDataGridView.DataSource = outstandingList;
                    break;
                case "종목정보요청":
                    string currentStockPrice = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "현재가");
                    stockNameLabel.Text = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "종목명").Trim();
                    orderPriceNumericUpDown.Minimum = 0;
                    orderPriceNumericUpDown.Maximum = 10000000;
                    orderPriceNumericUpDown.Value = long.Parse(currentStockPrice.Replace("-", ""));
                    break;
                case "종목일자가격데이터요청":
                    string code = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "종목코드").Trim(' ');
                    int openPrice;
                    if (int.TryParse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "시가"), out openPrice))
                    {
                        var balance = stockBalanceList.Where(x => x.종목코드 == code).ToArray()[0];
                        balance.당일시가 = String.Format("{0:#,###}", openPrice);
                    }
                    break;
                case "조건검색종목":
                    count = axKHOpenAPI1.GetRepeatCnt(e.sTrCode, e.sRQName);//조건식으로 검색되는 종목의 개수
                    var buyType = buyOrderType.Split(':')[0].Trim();
                    var buyTypeName = buyOrderType.Split(':')[1].Trim();
                    var sellType = sellOrderType.Split(':')[0].Trim();
                    var sellTypeName = sellOrderType.Split(':')[1].Trim();

                    for (int i = 0; i < count; i++)
                    {
                        stockCode = axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종목코드").Trim();
                        if (stocksToBuy[stockCode].curStatus == 0) continue;

                        int remPrice = stocksToBuy[stockCode].remainingPrice;
                        if (stocksToBuy[stockCode].curPrice > 0) stockPrice = stocksToBuy[stockCode].curPrice;
                        else
                        {
                            stockPrice = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "현재가").Replace("-", ""));
                            if (remPrice > 0)
                            {
                                if (buyTypeName == "종가") stockPrice = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종가").Replace("-", ""));
                                else if (buyTypeName == "시가") stockPrice = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "시가").Replace("-", ""));
                            }
                            else
                            {
                                if (sellTypeName == "종가") stockPrice = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "종가").Replace("-", ""));
                                else if (sellTypeName == "시가") stockPrice = int.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, i, "시가").Replace("-", ""));
                            }
                            stocksToBuy[stockCode].curPrice = stockPrice;
                        }

                        if (Math.Abs(remPrice) > stockPrice)
                        {
                            int orderNumber = (int)(Math.Abs(remPrice) / stockPrice);
                            if (remPrice > 0 && buyType != "00") stockPrice = 0;
                            else if (remPrice < 0 && sellType != "00") stockPrice = 0;
                            int res = -1;
                            if(remPrice > 0) res = axKHOpenAPI1.SendOrder("자동거래매수주문", "5149", ACCOUNT_NUMBER, 1, stockCode, orderNumber, stockPrice, buyType, "");
                            else res = axKHOpenAPI1.SendOrder("자동거래매도주문", "5189", ACCOUNT_NUMBER, 2, stockCode, orderNumber, stockPrice, sellType, "");
                            stocksToBuy[stockCode].curStatus = res;
                        }
                        else stocksToBuy[stockCode].curStatus = 0;
                        orderListBox2.Items.Add("날짜 : " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " | " + "종목코드 : " + stockCode + " | " + 
                                                    "종목명 : " + stocksToBuy[stockCode].stockName + " | 주문가격 : " + stocksToBuy[stockCode].remainingPrice
                                                    + " | 주문결과 : " + stocksToBuy[stockCode].curStatus);
                        orderListBox2.Items.Add("----------------------------------------------------");
                        Thread.Sleep(250);
                    }
                    if(t!=null) t.Start();
                    break;
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
            else if (sender.Equals(selectRFileButton)) selectRFile();
        }
        private void selectRFile()
        {
            var selectionWindow = new RFileSelection(Rmanager);
            if (selectionWindow.ShowDialog() != DialogResult.OK) return;
            RFileName.Text = selectionWindow.selectedRscript;
        }
        void initStocksToBuy()
        {
            setRulesForTrading();
            if (autoTradingRuleList.Count == 0) return;
            stocksToBuy = new Dictionary<string, stockInfo>();
            if(RcorpLists!=null) RcorpLists.Clear();
            foreach (var rule in autoTradingRuleList)
            {
                DataTable RcorpList = Rprogram.getCorpTable(rule.분석R파일, rule.제한종목개수);
                if (RcorpLists == null) RcorpLists = RcorpList;
                else RcorpLists = RcorpLists.AsEnumerable().Union(RcorpList.AsEnumerable()).CopyToDataTable();

                foreach (DataRow corp in RcorpList.Rows)
                {
                    string code = corp["종목코드"].ToString();
                    string name = corp["종목명"].ToString();
                    int price = rule.종목당매수금액;

                    rule.autoTradingPurchaseStockList.Add(new AutoTradingPurchaseStock(code, price, 0));
                    if (stocksToBuy.Keys.Contains(code)) stocksToBuy[code].remainingPrice += price;
                    else stocksToBuy.Add(code, new stockInfo(code, name, price, true));
                }
                buyOrderType = rule.매수거래구분;
                sellOrderType = rule.매도거래구분;
                updateTime = rule.업데이트시간;
            }
            stockListDataGridView.DataSource = null;
            stockListDataGridView.DataSource = RcorpLists;
            foreach(DataGridViewColumn col in stockListDataGridView.Columns)
                if (col.Index != 0) col.ReadOnly = true;
        }
        void startAutoTrading()
        {
            if (ACCOUNT_NUMBER == "")
            {
                MessageBox.Show("계좌를 먼저 설정하세요.");
                return;
            }
            if (t != null) t.Stop();
            if(RcorpLists!=null) RcorpLists=null;
            stocksToBuy = new Dictionary<string, stockInfo>();
            
            initStocksToBuy();
            if (autoTradingRuleList.Count == 0)
            {
                MessageBox.Show("매매조건을 먼저 설정하세요.");
                return;
            }
            t = new System.Windows.Forms.Timer();
            t.Tick += work;
            t.Interval = 30000;
            t.Start();
            MessageBox.Show(String.Format("자동거래시작\n매수방법: {0}\n매도방법: {1}\n업데이트시간: {2}",
                buyOrderType, sellOrderType, updateTime));
            orderListBox2.Items.Add("자동거래 시작");
            orderListBox2.Items.Add("---------------------------------");
        }
        void setRulesForTrading()
        {
            autoTradingRuleList = new List<AutoTradingRule>();
            foreach (DataGridViewRow row in autoRuleDataGridView.Rows)
            {
                if (row.Cells["거래규칙_상태"].Value.ToString() != "시작") continue;
                var newRule = new AutoTradingRule(int.Parse(row.Cells[0].Value.ToString()),
                    row.Cells[1].Value.ToString(), int.Parse(row.Cells[2].Value.ToString()),
                    int.Parse(row.Cells[3].Value.ToString()), int.Parse(row.Cells[4].Value.ToString()),
                    row.Cells[5].Value.ToString(), row.Cells[6].Value.ToString(),
                    row.Cells[7].Value.ToString(), row.Cells[8].Value.ToString());
                autoTradingRuleList.Add(newRule);
                if (newRule.종목당매수금액 == 0) newRule.종목당매수금액 = newRule.매입제한금액 / newRule.제한종목개수;
            }
        }
        void seeTodayStockDeal()
        {
            if (stocksToBuy == null  || stocksToBuy.Count == 0) return;
            if (stocksToBuy.Values.Where(x => x.curStatus == 0).Count() == 0)
            {
                initStocksToBuy();
                foreach (var s in stockBalanceList)
                {
                    s.종목코드 = s.종목코드.Replace("A", "").Trim();

                    if (stocksToBuy.Keys.Contains(s.종목코드))
                    {
                        var st = stocksToBuy[s.종목코드];
                        st.remainingPrice -= int.Parse(s.총평가금액.Replace(",", ""));
                    }
                    else stocksToBuy.Add(s.종목코드, new stockInfo(s.종목코드, s.종목명, -int.Parse(s.총평가금액.Replace(",", "")), true));
                }
            }
            foreach(var s in stocksToBuy)
            {

                orderListBox2.Items.Add(string.Format("종목코드:{0}, 종목명:{1}, 매입금액:{2}", s.Value.stockCode, s.Value.stockName, s.Value.remainingPrice));
                orderListBox2.Items.Add("--------------------------------------------------");
            }
        }
        void buyAutoStocks()
        {
            if (buyOrderType == null || sellOrderType == null) return;
            if (!isPriceUpdated)
            {
                seeTodayStockDeal();
                isPriceUpdated = true;
            }
            var includedStockList = stocksToBuy.Where(x => x.Value.isIncluded);
            var stockCodeList = String.Join(";",
                includedStockList.OrderBy(i => i.Value.remainingPrice).Select(x => "A" + x.Key));
            axKHOpenAPI1.CommKwRqData(stockCodeList, 0, includedStockList.Count(), 0, "조건검색종목", "5100");
        }



        void updateBalance()
        {
            DB.deleteBalanceInfo(userID, DateTime.Now.ToString("yyyy-MM"),
                currentServerCondition == "1" ? "test" : "real");
            string SQL = string.Format(@"INSERT INTO {0}.잔고 (날짜, 주문자, 종목코드, 종목명, 매수금, 수량, 현재가, 평가손익, 수익률) VALUES ",
                currentServerCondition == "1" ? "test" : "real");
            for (int i = 0; i < stockBalanceList.Count; i++)
                SQL += string.Format(@"(@DATE{0},@USER{0},@STOCKCODE{0},@STOCKNAME{0},@BUYPRICE{0},@NUM{0},@CURPRICE{0},@PROFIT{0},@PROFITRATE{0}), ", i);
            SQL = SQL.TrimEnd(new char[] { ',',' ' });
            var balanceList = new Dictionary<string, object[]>();
            string date = DateTime.Now.ToString("yyyy-MM");
            for (int i = 0; i < stockBalanceList.Count; i++)
            {
                balanceList.Add(string.Format("DATE{0}", i), new object[] { NpgsqlDbType.Text, date });
                balanceList.Add(string.Format("USER{0}", i), new object[] { NpgsqlDbType.Text, userID });
                balanceList.Add(string.Format("STOCKCODE{0}", i), new object[] { NpgsqlDbType.Text, stockBalanceList[i].종목코드.Trim(new char[] {'A',' '}) });
                balanceList.Add(string.Format("STOCKNAME{0}", i), new object[] { NpgsqlDbType.Text, stockBalanceList[i].종목명.Trim(' ') });
                balanceList.Add(string.Format("BUYPRICE{0}", i), new object[] { NpgsqlDbType.Integer, stockBalanceList[i].매수금.Replace(",","") });
                balanceList.Add(string.Format("NUM{0}", i), new object[] { NpgsqlDbType.Integer, stockBalanceList[i].수량 });
                balanceList.Add(string.Format("CURPRICE{0}", i), new object[] { NpgsqlDbType.Integer, stockBalanceList[i].현재가.Replace(",","") });
                balanceList.Add(string.Format("PROFIT{0}", i), new object[] { NpgsqlDbType.Integer, stockBalanceList[i].평가손익.Replace(",","") });
                balanceList.Add(string.Format("PROFITRATE{0}", i), new object[] { NpgsqlDbType.Double, stockBalanceList[i].수익률 });
            }
            DB.writeToDB(SQL, balanceList);
        }
        private void work(object sender, EventArgs e)
        {
            //buyAutoStocks();
            string endTime = "17:00";
            string curTime = DateTime.Now.ToString("HH:mm");
            //curTime = "10:00";

            if (curTime.CompareTo(endTime) > 0)
            {
                if (isPriceUpdated) isPriceUpdated = false;
                return;
            }
            if (curTime.CompareTo(updateTime) < 0) return;
            var diff = DateTime.Parse(curTime) - DateTime.Parse(updateTime);

            //orderListBox2.Items.Add(string.Format("current Time: {0}, timespan: {1}, minutes: {2}", 
            //    curTime, diff.ToString(), diff.Minutes));
            //orderListBox2.Items.Add("-----------------------------------");

            if (diff.Minutes % 60 != 0) return;

            //orderListBox2.Items.Add(string.Format("Trade start"));
            //orderListBox2.Items.Add("-----------------------------------");

            autoFlag = true;
            if(t!=null) t.Stop();
            getBalanceInfo();
        }

        void stopAutoTrading()
        {
            foreach (DataGridViewRow row in autoRuleDataGridView.Rows)
                row.Cells["거래규칙_상태"].Value = "정지";
            if(t!=null) t.Stop();
        }
        void sellAllStocks()
        {
            sellAllFlag = true;
            stopAutoTrading();
            getBalanceInfo();
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
            if (RFileName.Text == "" || limitPriceNumericUpDown.Value == 0 || limitNumberNumericUpDown.Value == 0 ||
                limitBuyingPerStockTextBox.Text == "" || autoBuyOrderComboBox.Text == "" || autoSellOrderComboBox.Text == "") return;
            string RName = RFileName.Text;//조건식 선택
            int limitBuyingStockPrice = int.Parse(limitPriceNumericUpDown.Value.ToString());//매입제한 금액
            int limitBuyingStockNumber = int.Parse(limitNumberNumericUpDown.Value.ToString());//매입 제한 종목개수
            int limitBuyingPerStock = int.Parse(limitBuyingPerStockTextBox.Text.ToString());//종목당 매수금액
            string autoBuyingOrderType = autoBuyOrderComboBox.Text;//매수 거래구분
            string autoSellingOrderType = autoSellOrderComboBox.Text;//매도 거래구분
            string updateTime = updateTimeTextBox.Text;
            string status = "정지";

            if (RName.Length > 0 && limitBuyingStockPrice > 0 && limitBuyingStockNumber > 0 &&
                autoBuyingOrderType.Length > 0 && autoSellingOrderType.Length > 0)
            {
                autoRuleID = registeredRuleList.Count;
                registeredRuleList.Add(new AutoTradingRule(
                   autoRuleID,RName,limitBuyingStockPrice,limitBuyingStockNumber,limitBuyingPerStock,autoBuyingOrderType,autoSellingOrderType,updateTime,status ));
                updateAutoTradingRule();
            }
            else if (RName.Length == 0 || limitBuyingStockPrice == 0 || limitBuyingStockNumber == 0 ||
                 autoBuyingOrderType.Length == 0 || autoSellingOrderType.Length == 0)
            {
                MessageBox.Show("거래규칙 값을 모두 입력하세요");
            }
            writeCurTradeRule();
            MessageBox.Show("설정완료");
        }

        void sellStocks()
        {
            if (accountComboBox.Text == "" || stockCodeLabel.Text == "" || orderComboBox.Text == "" ||
                orderPriceNumericUpDown.Value == 0 || orderNumberNumericUpDown.Value == 0) return;
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
            if (stockCodeLabel.Text == "" || ACCOUNT_NUMBER == "" || orderComboBox.Text == ""
                || orderPriceNumericUpDown.Value == 0 || orderNumberNumericUpDown.Value == 0) return;
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
            if (stockTextBox.Text == "") return;
            string stockCode = stockTextBox.Text;
            stockCodeLabel.Text = stockCode;
            axKHOpenAPI1.SetInputValue("종목코드", stockCode);
            axKHOpenAPI1.CommRqData("종목정보요청", "opt10001", 0, "5000");
        }
        void getContinuousBalanceInfo(string name)
        {
            string accountNumber = accountComboBox.Text;
            string password = passwordTextBox.Text;
            axKHOpenAPI1.SetInputValue("계좌번호", accountNumber);
            axKHOpenAPI1.SetInputValue("비밀번호", password);
            switch (name)
            {
                case "계좌평가잔고내역요청":
                    axKHOpenAPI1.SetInputValue("비밀번호입력매체구분", "00");
                    axKHOpenAPI1.SetInputValue("조회구분", "1");
                    axKHOpenAPI1.CommRqData("계좌평가잔고내역요청", "opw00018", 2, "8100"); break;
                case "계좌평가현황요청":
                    axKHOpenAPI1.SetInputValue("상장폐지조회구분", "0");
                    axKHOpenAPI1.SetInputValue("비밀번호입력매체구분", "00");
                    axKHOpenAPI1.CommRqData("계좌평가현황요청", "opw00004", 2, "4000"); break;
                case "실시간미체결요청":
                    axKHOpenAPI1.SetInputValue("체결구분", "1");
                    axKHOpenAPI1.SetInputValue("매매구분", "2");
                    axKHOpenAPI1.CommRqData("실시간미체결요청", "opt10075", 2, "5700"); break;
            }
        }
        void getTodayPriceInfo(string code,string date)
        {
            axKHOpenAPI1.SetInputValue("종목코드", code);
            axKHOpenAPI1.SetInputValue("기준일자", date);
            axKHOpenAPI1.SetInputValue("수정주가구분", "0");
            axKHOpenAPI1.CommRqData("종목일자가격데이터요청", "opt10081", 0, "9000");
        }
        void getBalanceInfo()
        {
            if (accountComboBox.Text.Length == 0 || passwordTextBox.Text.Length == 0) return;
            string accountNumber = accountComboBox.Text;
            string password = passwordTextBox.Text;
            stockBalanceList = new List<stockBalance>();
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
            if (e.nErrCode != 0)
            {
                MessageBox.Show("로그인 실패");
                return;
            }
            //"ACCOUNT_CNT" : 보유계좌 수를 반환합니다.
            //"ACCLIST" 또는 "ACCNO" : 구분자 ';'로 연결된 보유계좌 목록을 반환합니다.
            //"USER_ID" : 사용자 ID를 반환합니다.
            //"USER_NAME" : 사용자 이름을 반환합니다.
            //"KEY_BSECGB" : 키보드 보안 해지여부를 반환합니다.(0 : 정상, 1 : 해지)
            //"FIREW_SECGB" : 방화벽 설정여부를 반환합니다.(0 : 미설정, 1 : 설정, 2 : 해지)
            //"GetServerGubun" : 접속서버 구분을 반환합니다.(1 : 모의투자, 나머지: 실서버)
            accountComboBox.Items.AddRange(axKHOpenAPI1.GetLoginInfo("ACCLIST").Split(';'));
            userID = axKHOpenAPI1.GetLoginInfo("USER_ID");
            userName = axKHOpenAPI1.GetLoginInfo("USER_NAME");
            currentServerCondition = axKHOpenAPI1.GetLoginInfo("GetServerGubun");
        }

        private void accountComboBox_SelectedValueChanged(object sender, EventArgs e)
        {
            var c = sender as ComboBox;
            if (c.SelectedItem == null) return;
            ACCOUNT_NUMBER = c.SelectedItem.ToString();
        }

        private void autoRuleDataGridView_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {
            var senderGrid = (DataGridView)sender;
            if (senderGrid.Columns[e.ColumnIndex] is DataGridViewButtonColumn &&
                e.RowIndex >= 0)
            {
                var button = senderGrid.Columns[e.ColumnIndex] as DataGridViewButtonColumn;
                if (button.HeaderText == "삭제")
                {
                    if (MessageBox.Show("삭제하시겠습니까?", "Question", MessageBoxButtons.YesNo)
                        != DialogResult.Yes) return;
                    registeredRuleList.RemoveAt(e.RowIndex);
                    writeCurTradeRule();
                }
                else if (button.HeaderText == "수정")
                {
                    if (MessageBox.Show("수정하시겠습니까?", "Question", MessageBoxButtons.YesNo)
                        != DialogResult.Yes) return;
                    var gridRow = autoRuleDataGridView.Rows[e.RowIndex];
                    var rule = registeredRuleList[e.RowIndex];
                    rule.번호 = e.RowIndex;
                    rule.분석R파일 = gridRow.Cells[1].Value.ToString();
                    rule.매입제한금액 = int.Parse(gridRow.Cells[2].Value.ToString());
                    rule.제한종목개수 = int.Parse(gridRow.Cells[3].Value.ToString());
                    rule.종목당매수금액 = int.Parse(gridRow.Cells[4].Value.ToString());
                    rule.매수거래구분 = gridRow.Cells[5].Value.ToString();
                    rule.매도거래구분 = gridRow.Cells[6].Value.ToString();
                    rule.업데이트시간 = gridRow.Cells[7].Value.ToString();
                    writeCurTradeRule();
                }
            }
        }

        private void stockListDataGridView_CellContentClick(object sender, DataGridViewCellEventArgs e)
        {
            var view = sender as DataGridView;
            if (e.RowIndex < 0) return;
            if (!(view.Columns[e.ColumnIndex] is DataGridViewCheckBoxColumn)) return;
            var code = view.Rows[e.RowIndex].Cells[2].Value.ToString();
            stocksToBuy[code].isIncluded ^= true;
            view.Rows[e.RowIndex].Cells[0].Value = stocksToBuy[code].isIncluded;
        }
    }
}

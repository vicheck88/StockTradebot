using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace StockTrade
{
    public class stockInfo
    {
        public string stockCode;
        public string stockName;
        public int remainingPrice;
        public stockInfo(string stockCode, string stockName, int remainingPrice)
        {
            this.stockCode = stockCode;
            this.stockName = stockName;
            this.remainingPrice = remainingPrice;
        }
    }
    public class outstanding
    {
        public string 주문번호 { get; set; }
        public string 종목코드 { get; set; }
        public string 종목명 { get; set; }
        public int 주문수량 { get; set; }
        public string 주문가격 { get; set; }
        public int 미체결수량 { get; set; }
        public string 주문구분 { get; set; }
        public string 현재가 { get; set; }
        public string 시간 { get; set; }

        public outstanding()
        {

        }
        public outstanding(string 주문번호, string 종목코드, string 종목명, int 주문수량, string 주문가격, string 현재가, int 미체결수량, string 주문구분, string 시간)
        {
            this.주문번호 = 주문번호;
            this.종목코드 = 종목코드;
            this.종목명 = 종목명;
            this.주문수량 = 주문수량;
            this.주문가격 = 주문가격;
            this.미체결수량 = 미체결수량;
            this.주문구분 = 주문구분;
            this.현재가 = 현재가;
            this.시간 = 시간;

        }
    }
    public class stockBalance
    {
        public string 종목코드 { get; set; }
        public string 종목명 { get; set; }
        public int 수량 { get; set; }
        public string 매수금 { get; set; }
        public string 현재가 { get; set; }
        public int 평가손익 { get; set; }
        public string 수익률 { get; set; }
        public string 전일종가 { get; set; }

        public stockBalance() { }

        public stockBalance(string 종목번호, string 종목명, int 수량, string 매수금, string 현재가, int 평가손익, string 수익률, string 전일종가)
        {
            this.종목코드 = 종목번호;
            this.종목명 = 종목명;
            this.수량 = 수량;
            this.매수금 = 매수금;
            this.현재가 = 현재가;
            this.평가손익 = 평가손익;
            this.수익률 = 수익률;
            this.전일종가 = 전일종가;
        }
    }
    public class AutoTradingRule
    {
        public int 번호;
        public string 분석R파일;
        public string 키움조건식;
        public int 매입제한금액;
        public int 제한종목개수;
        public int 종목당매수금액;
        public string 매수거래구분;
        public string 매도거래구분;
        public double 이익률;
        public double 손절률;
        public string 업데이트시간;
        public string 상태;

        public List<AutoTradingPurchaseStock> autoTradingPurchaseStockList;

        public AutoTradingRule(int autoTradingRuleID, string Rfile, int limitBuyingStockPrice,
            int limitBuyingStockNumber, int limitBuyingPerStock, string autoBuyingOrderType,
            string autoSellingOrderType, string updateTime, string status)
        {
            this.번호 = autoTradingRuleID;
            this.분석R파일 = Rfile;
            this.매입제한금액 = limitBuyingStockPrice;
            this.제한종목개수 = limitBuyingStockNumber;
            this.종목당매수금액 = limitBuyingPerStock;
            this.매수거래구분 = autoBuyingOrderType;
            this.매도거래구분 = autoSellingOrderType;
            this.업데이트시간 = updateTime;
            this.상태 = status;
            this.autoTradingPurchaseStockList = new List<AutoTradingPurchaseStock>();
        }
    }
    public class AutoTradingPurchaseStock
    {
        public string stockCode;
        public int boughtPrice;
        public int boughtCount;
        public int currentPrice;

        public AutoTradingPurchaseStock(string stockCode, int boughtPrice, int currentPrice)
        {
            this.stockCode = stockCode;
            this.boughtPrice = boughtPrice;
            this.currentPrice = currentPrice;
        }
    }

}

using AxKHOpenAPILib;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace AutoTrade
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
            axKHOpenAPI1.OnEventConnect += onEventConnect;
            axKHOpenAPI1.OnReceiveTrData += onReceiverData;
            axKHOpenAPI1.CommConnect();
        }
        private void onEventConnect(object sender, _DKHOpenAPIEvents_OnEventConnectEvent e)
        {
            if (e.nErrCode == 0)
            {
                //id정보(id)
                idLabel.Text = axKHOpenAPI1.GetLoginInfo("USER_ID");
                //유저이름정보
                nameLabel.Text = axKHOpenAPI1.GetLoginInfo("USER_NAME");
                //접속서버(모의, 실제)구분
                serverLabel.Text = axKHOpenAPI1.GetLoginInfo("GetServerGubun") == "1" ? "모의" : "실전";
                //계좌목록
                List<string> account = axKHOpenAPI1.GetLoginInfo("ACCLIST").Split(';').ToList();
                account.ForEach(x => accountComboBox.Items.Add(x));
            }
        }

        private void accountComboBox_SelectedIndexChanged(object sender, EventArgs e)
        {
            if(accountComboBox.Text.Length>0 && passwordTextBox.Text.Length > 0)
            {
                axKHOpenAPI1.SetInputValue("계좌번호", accountComboBox.Text);
                axKHOpenAPI1.SetInputValue("비밀번호", passwordTextBox.Text);
                axKHOpenAPI1.SetInputValue("비밀번호입력매체구분", "00");
                axKHOpenAPI1.SetInputValue("조회구분", "1");
                axKHOpenAPI1.CommRqData("계좌평가잔고내역요청", "opw00018", 0, "B100");
            }
        }
        private void onReceiverData(object sender, _DKHOpenAPIEvents_OnReceiveTrDataEvent e)
        {
            if (e.sRQName == "계좌평가잔고내역요청")
            {
                long totalPurchase = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "총매입금액"));
                long totalEstimate = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "총평가금액"));
                long totalProfitLoss = long.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "총평가손익금액"));
                double totalProfitRate = double.Parse(axKHOpenAPI1.GetCommData(e.sTrCode, e.sRQName, 0, "총수익률(%)"));

                totalProfitRateLabel.Text = String.Format("{0:#,###}", totalPurchase);
                totalEstimateLabel.Text = String.Format("{0:#,###}", totalEstimate);
                totalProfitLabel.Text = String.Format("{0:#,###}", totalProfitLoss);
                totalProfitRateLabel.Text = String.Format("{0:f2}", totalProfitRate);
            }
        }
    }
}

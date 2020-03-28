/************************************************************
  샘플버전 : 1.0.0.0 ( 2015.01.23 )
  샘플제작 : (주)에스비씨엔 / sbcn.co.kr/ ZooATS.com
  샘플환경 : Visual Studio 2013 / C# 5.0
  샘플문의 : support@zooats.com / john@sbcn.co.kr
  전    화 : 02-719-5500 / 070-7777-6555
************************************************************/

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using KiwoomCode;


namespace KOASampleCS
{

    public partial class Form1 : Form
    {
  
        public struct ConditionList
        {
            public string strConditionName;
            public int nIndex;
        }

        private int _scrNum = 5000;
        private string _strRealConScrNum = "0000";
        private string _strRealConName = "0000";
        private int _nIndex = 0;

        private bool _bRealTrade = false;

        // 화면번호 생산
        private string GetScrNum()
        {
            if (_scrNum < 9999)
                _scrNum++;
            else
                _scrNum = 5000;

            return _scrNum.ToString();
        }

        // 실시간 연결 종료
        private void DisconnectAllRealData()
        {
            for( int i = _scrNum; i > 5000; i-- )
            {
                axKHOpenAPI.DisconnectRealData(i.ToString());
            }

            _scrNum = 5000;
        }

        public Form1()
        {
            InitializeComponent();
        }

        // 로그를 출력합니다.
        public void Logger(Log type, string format, params Object[] args)
        {
            string message = String.Format(format, args);

            switch (type)
            {
                case Log.조회:
                    lst조회.Items.Add(message);
                    lst조회.SelectedIndex = lst조회.Items.Count - 1;
                    break;
                case Log.에러:
                    lst에러.Items.Add(message);
                    lst에러.SelectedIndex = lst에러.Items.Count - 1;
                    break;
                case Log.일반:
                    lst일반.Items.Add(message);
                    lst일반.SelectedIndex = lst일반.Items.Count - 1;
                    break;
                case Log.실시간:
                    lst실시간.Items.Add(message);
                    lst실시간.SelectedIndex = lst실시간.Items.Count - 1;
                    break;
                default:
                    break;
            }
        }

        // 로그인 창을 엽니다.
        private void 로그인ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (axKHOpenAPI.CommConnect() == 0)
            {
                Logger(Log.일반, "로그인창 열기 성공");
            }
            else
            {
                Logger(Log.에러, "로그인창 열기 실패");
            }
        }

        // 샘플 프로그램을 종료 합니다.
        private void 종료ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Application.Exit();
        }

        // 로그아웃
        private void 로그아웃ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            DisconnectAllRealData();
            axKHOpenAPI.CommTerminate();
            Logger(Log.일반, "로그아웃");
        }

        // 접속상태확인
        private void 접속상태ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (axKHOpenAPI.GetConnectState() == 0)
            {
                Logger(Log.일반, "Open API 연결 : 미연결");
            }
            else
            {
                Logger(Log.일반, "Open API 연결 : 연결중");
            }
        }

        private void axKHOpenAPI_OnReceiveTrData(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveTrDataEvent e)
        {
       
            if (e.sRQName == "주식주문")
            {
                string s원주문번호 = axKHOpenAPI.GetCommData(e.sTrCode, "", 0, "").Trim();

                long n원주문번호 = 0;
                bool canConvert = long.TryParse(s원주문번호, out n원주문번호);

                if (canConvert == true)
                    txt원주문번호.Text = s원주문번호;
                else
                    Logger(Log.에러, "잘못된 원주문번호 입니다");

            }
            // OPT1001 : 주식기본정보
            else if (e.sRQName == "주식기본정보")
            {
                Logger(Log.조회, "{0} | 현재가:{1:N0} | 등락율:{2} | 거래량:{3:N0} ",
                       axKHOpenAPI.GetCommData(e.sTrCode, e.sRQName, 0, "종목명").Trim(),
                       Int32.Parse(axKHOpenAPI.GetCommData(e.sTrCode, "", 0, "현재가").Trim()),
                       axKHOpenAPI.GetCommData(e.sTrCode, "", 0, "등락율").Trim(),
                       Int32.Parse(axKHOpenAPI.GetCommData(e.sTrCode, "", 0, "거래량").Trim()));
            }
            // OPT10081 : 주식일봉차트조회
            else if (e.sRQName == "주식일봉차트조회")
            {
                int nCnt = axKHOpenAPI.GetRepeatCnt(e.sTrCode, e.sRQName);

                for (int i = 0; i < nCnt; i++)
                {
                    Logger(Log.조회, "{0} | 현재가:{1:N0} | 거래량:{2:N0} | 시가:{3:N0} | 고가:{4:N0} | 저가:{5:N0} ",
                        axKHOpenAPI.GetCommData(e.sTrCode, "", i, "일자").Trim(),
                        Int32.Parse(axKHOpenAPI.GetCommData(e.sTrCode, "", i, "현재가").Trim()),
                        Int32.Parse(axKHOpenAPI.GetCommData(e.sTrCode, "", i, "거래량").Trim()),
                        Int32.Parse(axKHOpenAPI.GetCommData(e.sTrCode, "", i, "시가").Trim()),
                        Int32.Parse(axKHOpenAPI.GetCommData(e.sTrCode, "", i, "고가").Trim()),
                        Int32.Parse(axKHOpenAPI.GetCommData(e.sTrCode, "", i, "저가").Trim()));
                }
            }

        }

        private void axKHOpenAPI_OnEventConnect(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnEventConnectEvent e)
        {
            if (Error.IsError(e.nErrCode))
            {
                Logger(Log.일반, "[로그인 처리결과] " + Error.GetErrorMessage());
            }
            else
            {
                Logger(Log.에러, "[로그인 처리결과] " + Error.GetErrorMessage());
            }
        }

        private void axKHOpenAPI_OnReceiveChejanData(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveChejanDataEvent e)
        {
            if (e.sGubun == "0")
            {
                Logger(Log.실시간, "구분 : 주문체결통보");
                Logger(Log.실시간, "주문/체결시간 : " + axKHOpenAPI.GetChejanData(908));
                Logger(Log.실시간, "종목명 : " + axKHOpenAPI.GetChejanData(302));
                Logger(Log.실시간, "주문수량 : " + axKHOpenAPI.GetChejanData(900));
                Logger(Log.실시간, "주문가격 : " + axKHOpenAPI.GetChejanData(901));
                Logger(Log.실시간, "체결수량 : " + axKHOpenAPI.GetChejanData(911));
                Logger(Log.실시간, "체결가격 : " + axKHOpenAPI.GetChejanData(910));
                Logger(Log.실시간, "=======================================");
            }
            else if (e.sGubun == "1")
            {
                Logger(Log.실시간, "구분 : 잔고통보");
            }
            else if (e.sGubun == "3")
            {
                Logger(Log.실시간, "구분 : 특이신호");
            }

        }

        private void axKHOpenAPI_OnReceiveMsg(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveMsgEvent e)
        {
            Logger(Log.조회, "===================================================");
            Logger(Log.조회, "화면번호:{0} | RQName:{1} | TRCode:{2} | 메세지:{3}", e.sScrNo, e.sRQName, e.sTrCode, e.sMsg);
        }

        private void axKHOpenAPI_OnReceiveRealData(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveRealDataEvent e)
        {
            Logger(Log.실시간, "종목코드 : {0} | RealType : {1} | RealData : {2}",
                e.sRealKey, e.sRealType, e.sRealData);

            if( e.sRealType == "주식시세" )
            {
                Logger(Log.실시간, "종목코드 : {0} | 현재가 : {1:C} | 등락율 : {2} | 누적거래량 : {3:N0} ",
                        e.sRealKey,
                        Int32.Parse(axKHOpenAPI.GetCommRealData(e.sRealType, 10).Trim()),
                        axKHOpenAPI.GetCommRealData(e.sRealType, 12).Trim(),
                        Int32.Parse(axKHOpenAPI.GetCommRealData(e.sRealType, 13).Trim()));
            }
            
        }

        private void 계좌조회ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            lbl아이디.Text = axKHOpenAPI.GetLoginInfo("USER_ID");
            lbl이름.Text = axKHOpenAPI.GetLoginInfo("USER_NAME");

            string[] arr계좌 = axKHOpenAPI.GetLoginInfo("ACCNO").Split(';');

            cbo계좌.Items.AddRange(arr계좌);
            cbo계좌.SelectedIndex = 0;
        }

        private void 현재가ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            axKHOpenAPI.SetInputValue("종목코드", txt종목코드.Text.Trim());

            int nRet = axKHOpenAPI.CommRqData("주식기본정보", "OPT10001", 0, GetScrNum());
            _scrNum++;

            if (Error.IsError(nRet))
            {
                Logger(Log.일반, "[OPT10001] : " + Error.GetErrorMessage());
            }
            else
            {
                Logger(Log.에러, "[OPT10001] : " + Error.GetErrorMessage());
            }
        }

        private void 일봉데이터ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            axKHOpenAPI.SetInputValue("종목코드", txt종목코드.Text.Trim());
            axKHOpenAPI.SetInputValue("기준일자", txt조회날짜.Text.Trim());
            axKHOpenAPI.SetInputValue("수정주가구분", "1");


            int nRet = axKHOpenAPI.CommRqData("주식일봉차트조회", "OPT10081", 0, GetScrNum());
            _scrNum++;

            if (Error.IsError(nRet))
            {
                Logger(Log.일반, "[OPT10081] : " + Error.GetErrorMessage());
            }
            else
            {
                Logger(Log.에러, "[OPT10081] : " + Error.GetErrorMessage());
            }
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            // =================================================
            // 거래구분목록 지정
            for (int i = 0; i < 12; i++)
                cbo거래구분.Items.Add(KOACode.hogaGb[i].name);
            
            cbo거래구분.SelectedIndex = 0;


            // =================================================
            // 주문유형
            for(int i = 0; i < 5; i++)
                cbo매매구분.Items.Add(KOACode.orderType[i].name);

            cbo매매구분.SelectedIndex = 0;
        }

        private void txt주문종목코드_KeyPress(object sender, KeyPressEventArgs e)
        {
            if (!(char.IsDigit(e.KeyChar) || e.KeyChar == Convert.ToChar(Keys.Back)))
            {
                e.Handled = true;
            }
        }

        private void txt주문수량_KeyPress(object sender, KeyPressEventArgs e)
        {
            if (!(char.IsDigit(e.KeyChar) || e.KeyChar == Convert.ToChar(Keys.Back)))
            {
                e.Handled = true;
            }
        }

        private void txt주문가격_KeyPress(object sender, KeyPressEventArgs e)
        {
            if (!(char.IsDigit(e.KeyChar) || e.KeyChar == Convert.ToChar(Keys.Back)))
            {
                e.Handled = true;
            }
        }

        private void txt원주문번호_KeyPress(object sender, KeyPressEventArgs e)
        {
            if (!(char.IsDigit(e.KeyChar) || e.KeyChar == Convert.ToChar(Keys.Back)))
            {
                e.Handled = true;
            }
        }

        private void txt종목코드_KeyPress(object sender, KeyPressEventArgs e)
        {
            if (!(char.IsDigit(e.KeyChar) || e.KeyChar == Convert.ToChar(Keys.Back)))
            {
                e.Handled = true;
            }
        }

        private void txt조회날짜_KeyPress(object sender, KeyPressEventArgs e)
        {
            if (!(char.IsDigit(e.KeyChar) || e.KeyChar == Convert.ToChar(Keys.Back)))
            {
                e.Handled = true;
            }
        }

        private void btn주문_Click(object sender, EventArgs e)
        {
            // =================================================
            // 계좌번호 입력 여부 확인
            if( cbo계좌.Text.Length != 10 )
            {
                Logger(Log.에러, "계좌번호 10자리를 입력해 주세요");

                return;
            }

            // =================================================
            // 종목코드 입력 여부 확인
            if( txt주문종목코드.TextLength != 6 )
            {
                Logger(Log.에러, "종목코드 6자리를 입력해 주세요");

                return;
            }

            // =================================================
            // 주문수량 입력 여부 확인
            int n주문수량;

            if(txt주문수량.TextLength > 0)
            {
                n주문수량 = Int32.Parse(txt주문수량.Text.Trim());
            }
            else
            {
                Logger(Log.에러, "주문수량을 입력하지 않았습니다");
                
                return;
            }

            if( n주문수량 < 1 )
            {
                Logger(Log.에러, "주문수량이 1보다 작습니다");
                
                return;
            }

            // =================================================
            // 거래구분 취득
            // 0:지정가, 3:시장가, 5:조건부지정가, 6:최유리지정가, 7:최우선지정가,
            // 10:지정가IOC, 13:시장가IOC, 16:최유리IOC, 20:지정가FOK, 23:시장가FOK,
            // 26:최유리FOK, 61:장개시전시간외, 62:시간외단일가매매, 81:시간외종가
        
            string s거래구분;
            s거래구분 = KOACode.hogaGb[cbo거래구분.SelectedIndex].code;

            // =================================================
            // 주문가격 입력 여부

            int n주문가격 = 0;

            if( txt주문가격.TextLength > 0 )
            {
                n주문가격 = Int32.Parse(txt주문가격.Text.Trim());
            }

            if (s거래구분 == "3" || s거래구분 == "13" || s거래구분 == "23" && n주문가격 < 1)
            {
                Logger(Log.에러, "주문가격이 1보다 작습니다");
            }

            // =================================================
            // 매매구분 취득
            // (1:신규매수, 2:신규매도 3:매수취소, 
            // 4:매도취소, 5:매수정정, 6:매도정정)

            int n매매구분;
            n매매구분 = KOACode.orderType[cbo매매구분.SelectedIndex].code;

            // =================================================
            // 원주문번호 입력 여부

            if( n매매구분 > 2 && txt원주문번호.TextLength < 1 )
            {
                Logger(Log.에러, "원주문번호를 입력해주세요");
            }


            // =================================================
            // 주식주문
            int lRet;

            lRet = axKHOpenAPI.SendOrder("주식주문", GetScrNum(), cbo계좌.Text.Trim(), 
                                        n매매구분, txt주문종목코드.Text.Trim(), n주문수량, 
                                        n주문가격, s거래구분, txt원주문번호.Text.Trim());

            if( lRet == 0 )
            {
                Logger(Log.일반, "주문이 전송 되었습니다");
            }
            else
            {
                Logger(Log.에러, "주문이 전송 실패 하였습니다. [에러] : " + lRet);
            }
        }

        private void 주문ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            btn주문_Click(sender, e);
        }

        private void 조건식로컬저장ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            int lRet;

            lRet = axKHOpenAPI.GetConditionLoad();

            if (lRet == 1)
            {
                Logger(Log.일반, "조건식 저장이 성공 되었습니다");
            }
            else
            {
                Logger(Log.에러, "조건식 저장이 실패 하였습니다");
            }
        }

        private void axKHOpenAPI_OnReceiveConditionVer(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveConditionVerEvent e)
        {
            if( e.lRet == 1 )
            {
                Logger(Log.일반, "[이벤트] 조건식 저장 성공");
            }
            else
            {
                Logger(Log.에러, "[이벤트] 조건식 저장 실패 : " + e.sMsg);
            }

        }

        private void 조건명리스트호출ToolStripMenuItem_Click(object sender, EventArgs e)
        {
            string strConList;

            strConList = axKHOpenAPI.GetConditionNameList().Trim();

            Logger(Log.조회, strConList);

            // 분리된 문자 배열 저장
            string[] spConList = strConList.Split(';');

            // ComboBox 출력
            for(int i = 0; i < spConList.Length; i++)
            {
                if(spConList[i].Trim().Length >= 2)
                {
                    cbo조건식.Items.Add(spConList[i]);
                    /*
                    string[] spCon = spConList[i].Split('^');
                    int nIndex = Int32.Parse(spCon[0]);
                    string strConditionName = spCon[1];
                    cbo조건식.Items.Add(strConditionName);
                    */
                }
            }

            cbo조건식.SelectedIndex = 0;
        }

        private void btn_조건일반조회_Click(object sender, EventArgs e)
        {
            string[] spCon = cbo조건식.Text.Split('^');
            int nCondNumber = Int32.Parse(spCon[0]);    // 조건번호
            string spCondName = spCon[1];               // 조건식 이름
            int lRet = axKHOpenAPI.SendCondition(GetScrNum(), spCondName, nCondNumber, 0);
            
            if (lRet == 1)
            {
                Logger(Log.일반, "조건식 일반 조회 실행이 성공 되었습니다");
            }
            else
            {
                Logger(Log.에러, "조건식 일반 조회 실행이 실패 하였습니다");
            }
        }

        private void btn조건실시간조회_Click(object sender, EventArgs e)
        {
           string[] spCon = cbo조건식.Text.Split('^');
            int nCondNumber = Int32.Parse(spCon[0]);    // 조건번호
            string spCondName = spCon[1];               // 조건식 이름
            string strScrNum = GetScrNum();
            int lRet = axKHOpenAPI.SendCondition(strScrNum, spCondName, nCondNumber, 1);

            if (lRet == 1)
            {
                _strRealConScrNum = strScrNum;
                _strRealConName = cbo조건식.Text;
                _nIndex = cbo조건식.SelectedIndex;

                Logger(Log.일반, "조건식 실시간 조회 실행이 성공 되었습니다");
            }
            else
            {
                Logger(Log.에러, "조건식 실시간 조회 실행이 실패 하였습니다");
            }
        }

        private void axKHOpenAPI_OnReceiveRealCondition(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveRealConditionEvent e)
        {
            Logger(Log.실시간, "========= 조건조회 실시간 편입/이탈 ==========");
            Logger(Log.실시간, "[종목코드] : " + e.sTrCode);
            Logger(Log.실시간, "[실시간타입] : " + e.strType);
            Logger(Log.실시간, "[조건명] : " + e.strConditionName);
            Logger(Log.실시간, "[조건명 인덱스] : " + e.strConditionIndex);

            // 자동주문 로직
            if (_bRealTrade && e.strType == "I")
            {
                // 해당 종목 1주 시장가 주문
                // =================================================

                // 계좌번호 입력 여부 확인
                if (cbo계좌.Text.Length != 10)
                {
                    Logger(Log.에러, "계좌번호 10자리를 입력해 주세요");

                    return;
                }

                // =================================================
                // 주식주문
                int lRet;

                lRet = axKHOpenAPI.SendOrder("주식주문", 
                                            GetScrNum(), 
                                            cbo계좌.Text.Trim(),
                                            1,      // 매매구분
                                            e.sTrCode.Trim(),   // 종목코드
                                            1,      // 주문수량
                                            1,      // 주문가격 
                                            "03",    // 거래구분 (시장가)
                                            "0");    // 원주문 번호

                if (lRet == 0)
                {
                    Logger(Log.일반, "주문이 전송 되었습니다");
                }
                else
                {
                    Logger(Log.에러, "주문이 전송 실패 하였습니다. [에러] : " + lRet);
                }
            }
        }

        private void axKHOpenAPI_OnReceiveTrCondition(object sender, AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveTrConditionEvent e)
        {
            Logger(Log.조회, "[화면번호] : " + e.sScrNo);
            Logger(Log.조회, "[종목리스트] : " + e.strCodeList);
            Logger(Log.조회, "[조건명] : " + e.strConditionName);
            Logger(Log.조회, "[조건명 인덱스 ] : " + e.nIndex.ToString());
            Logger(Log.조회, "[연속조회] : " + e.nNext.ToString());
        }

        private void btn_조건실시간중지_Click(object sender, EventArgs e)
        {
            if( _strRealConScrNum != "0000" &&
                _strRealConName != "0000" )
            {
                axKHOpenAPI.SendConditionStop(_strRealConScrNum, _strRealConName, _nIndex);

                Logger(Log.실시간, "========= 실시간 조건 조회 중단 ==========");
                Logger(Log.실시간, "[화면번호] : " + _strRealConScrNum + " [조건명] : " + _strRealConName);
            }
        }

        private void btn실시간등록_Click(object sender, EventArgs e)
        {
            long lRet;

            lRet = axKHOpenAPI.SetRealReg(  GetScrNum(),              // 화면번호
                                            txt실시간종목코드.Text,    // 종콕코드 리스트
                                            "9001;10",  // FID번호
                                            "0");       // 0 : 마지막에 등록한 종목만 실시간

            if (lRet == 0)
            {
                Logger(Log.일반, "실시간 등록이 실행되었습니다");
            }
            else
            {
                Logger(Log.에러, "실시간 등록이 실패하였습니다");
            }
        }

        private void btn실시간해제_Click(object sender, EventArgs e)
        {
            axKHOpenAPI.SetRealRemove(  "ALL",     // 화면번호
                                        "ALL");    // 실시간 해제할 종목코드

            Logger(Log.실시간, "======= 실시간 해제 실행 ========");
        }

        private void btn자동주문_Click(object sender, EventArgs e)
        {
            if (_bRealTrade)
            {
                btn자동주문.Text = "자동주문 시작";
                _bRealTrade = false;
                Logger(Log.일반, "======= 자동 주문 중단 ========");
            }
            else
            {
                btn자동주문.Text = "자동주문 중단";
                _bRealTrade = true;
                Logger(Log.일반, "======= 자동 주문 실행 ========");
            }
        }
    }
}

namespace KOASampleCS
{
    partial class Form1
    {
        /// <summary>
        /// 필수 디자이너 변수입니다.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// 사용 중인 모든 리소스를 정리합니다.
        /// </summary>
        /// <param name="disposing">관리되는 리소스를 삭제해야 하면 true이고, 그렇지 않으면 false입니다.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form 디자이너에서 생성한 코드

        /// <summary>
        /// 디자이너 지원에 필요한 메서드입니다.
        /// 이 메서드의 내용을 코드 편집기로 수정하지 마십시오.
        /// </summary>
        private void InitializeComponent()
        {
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Form1));
            this.menuStrip = new System.Windows.Forms.MenuStrip();
            this.기본기능ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.로그인ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.로그아웃ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.접속상태ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.계좌조회ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.종료ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.조회기능ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.현재가ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.일봉데이터ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.주문기능ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.주문ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.조건검색ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.조건식로컬저장ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.조건명리스트호출ToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.lst실시간 = new System.Windows.Forms.ListBox();
            this.lst일반 = new System.Windows.Forms.ListBox();
            this.lst조회 = new System.Windows.Forms.ListBox();
            this.lst에러 = new System.Windows.Forms.ListBox();
            this.lbl일반 = new System.Windows.Forms.Label();
            this.lbl에러 = new System.Windows.Forms.Label();
            this.lbl실시간 = new System.Windows.Forms.Label();
            this.lbl조회 = new System.Windows.Forms.Label();
            this.grp로그 = new System.Windows.Forms.GroupBox();
            this.axKHOpenAPI = new AxKHOpenAPILib.AxKHOpenAPI();
            this.Label1 = new System.Windows.Forms.Label();
            this.label2 = new System.Windows.Forms.Label();
            this.lbl이름 = new System.Windows.Forms.Label();
            this.lbl아이디 = new System.Windows.Forms.Label();
            this.cbo계좌 = new System.Windows.Forms.ComboBox();
            this.label3 = new System.Windows.Forms.Label();
            this.label4 = new System.Windows.Forms.Label();
            this.txt종목코드 = new System.Windows.Forms.TextBox();
            this.label5 = new System.Windows.Forms.Label();
            this.txt조회날짜 = new System.Windows.Forms.TextBox();
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.btn주문 = new System.Windows.Forms.Button();
            this.cbo매매구분 = new System.Windows.Forms.ComboBox();
            this.cbo거래구분 = new System.Windows.Forms.ComboBox();
            this.txt원주문번호 = new System.Windows.Forms.TextBox();
            this.txt주문가격 = new System.Windows.Forms.TextBox();
            this.txt주문수량 = new System.Windows.Forms.TextBox();
            this.txt주문종목코드 = new System.Windows.Forms.TextBox();
            this.label11 = new System.Windows.Forms.Label();
            this.label10 = new System.Windows.Forms.Label();
            this.label9 = new System.Windows.Forms.Label();
            this.label8 = new System.Windows.Forms.Label();
            this.label7 = new System.Windows.Forms.Label();
            this.label6 = new System.Windows.Forms.Label();
            this.cbo조건식 = new System.Windows.Forms.ComboBox();
            this.groupBox2 = new System.Windows.Forms.GroupBox();
            this.btn_조건실시간중지 = new System.Windows.Forms.Button();
            this.btn조건실시간조회 = new System.Windows.Forms.Button();
            this.label12 = new System.Windows.Forms.Label();
            this.btn_조건일반조회 = new System.Windows.Forms.Button();
            this.group실시간등록해제 = new System.Windows.Forms.GroupBox();
            this.btn실시간해제 = new System.Windows.Forms.Button();
            this.btn실시간등록 = new System.Windows.Forms.Button();
            this.label13 = new System.Windows.Forms.Label();
            this.txt실시간종목코드 = new System.Windows.Forms.TextBox();
            this.btn자동주문 = new System.Windows.Forms.Button();
            this.menuStrip.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.axKHOpenAPI)).BeginInit();
            this.groupBox1.SuspendLayout();
            this.groupBox2.SuspendLayout();
            this.group실시간등록해제.SuspendLayout();
            this.SuspendLayout();
            // 
            // menuStrip
            // 
            this.menuStrip.GripMargin = new System.Windows.Forms.Padding(2, 2, 0, 2);
            this.menuStrip.ImageScalingSize = new System.Drawing.Size(24, 24);
            this.menuStrip.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.기본기능ToolStripMenuItem,
            this.조회기능ToolStripMenuItem,
            this.주문기능ToolStripMenuItem,
            this.조건검색ToolStripMenuItem});
            this.menuStrip.Location = new System.Drawing.Point(0, 0);
            this.menuStrip.Name = "menuStrip";
            this.menuStrip.Size = new System.Drawing.Size(2064, 35);
            this.menuStrip.TabIndex = 0;
            this.menuStrip.Text = "menuStrip";
            // 
            // 기본기능ToolStripMenuItem
            // 
            this.기본기능ToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.로그인ToolStripMenuItem,
            this.로그아웃ToolStripMenuItem,
            this.접속상태ToolStripMenuItem,
            this.계좌조회ToolStripMenuItem,
            this.종료ToolStripMenuItem});
            this.기본기능ToolStripMenuItem.Name = "기본기능ToolStripMenuItem";
            this.기본기능ToolStripMenuItem.Size = new System.Drawing.Size(100, 29);
            this.기본기능ToolStripMenuItem.Text = "기본기능";
            // 
            // 로그인ToolStripMenuItem
            // 
            this.로그인ToolStripMenuItem.Name = "로그인ToolStripMenuItem";
            this.로그인ToolStripMenuItem.Size = new System.Drawing.Size(270, 34);
            this.로그인ToolStripMenuItem.Text = "로그인";
            this.로그인ToolStripMenuItem.Click += new System.EventHandler(this.로그인ToolStripMenuItem_Click);
            // 
            // 로그아웃ToolStripMenuItem
            // 
            this.로그아웃ToolStripMenuItem.Name = "로그아웃ToolStripMenuItem";
            this.로그아웃ToolStripMenuItem.Size = new System.Drawing.Size(270, 34);
            this.로그아웃ToolStripMenuItem.Text = "로그아웃";
            this.로그아웃ToolStripMenuItem.Click += new System.EventHandler(this.로그아웃ToolStripMenuItem_Click);
            // 
            // 접속상태ToolStripMenuItem
            // 
            this.접속상태ToolStripMenuItem.Name = "접속상태ToolStripMenuItem";
            this.접속상태ToolStripMenuItem.Size = new System.Drawing.Size(270, 34);
            this.접속상태ToolStripMenuItem.Text = "접속상태";
            this.접속상태ToolStripMenuItem.Click += new System.EventHandler(this.접속상태ToolStripMenuItem_Click);
            // 
            // 계좌조회ToolStripMenuItem
            // 
            this.계좌조회ToolStripMenuItem.Name = "계좌조회ToolStripMenuItem";
            this.계좌조회ToolStripMenuItem.Size = new System.Drawing.Size(270, 34);
            this.계좌조회ToolStripMenuItem.Text = "계좌조회";
            this.계좌조회ToolStripMenuItem.Click += new System.EventHandler(this.계좌조회ToolStripMenuItem_Click);
            // 
            // 종료ToolStripMenuItem
            // 
            this.종료ToolStripMenuItem.Name = "종료ToolStripMenuItem";
            this.종료ToolStripMenuItem.Size = new System.Drawing.Size(270, 34);
            this.종료ToolStripMenuItem.Text = "종료";
            this.종료ToolStripMenuItem.Click += new System.EventHandler(this.종료ToolStripMenuItem_Click);
            // 
            // 조회기능ToolStripMenuItem
            // 
            this.조회기능ToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.현재가ToolStripMenuItem,
            this.일봉데이터ToolStripMenuItem});
            this.조회기능ToolStripMenuItem.Name = "조회기능ToolStripMenuItem";
            this.조회기능ToolStripMenuItem.Size = new System.Drawing.Size(100, 29);
            this.조회기능ToolStripMenuItem.Text = "조회기능";
            // 
            // 현재가ToolStripMenuItem
            // 
            this.현재가ToolStripMenuItem.Name = "현재가ToolStripMenuItem";
            this.현재가ToolStripMenuItem.Size = new System.Drawing.Size(204, 34);
            this.현재가ToolStripMenuItem.Text = "현재가";
            this.현재가ToolStripMenuItem.Click += new System.EventHandler(this.현재가ToolStripMenuItem_Click);
            // 
            // 일봉데이터ToolStripMenuItem
            // 
            this.일봉데이터ToolStripMenuItem.Name = "일봉데이터ToolStripMenuItem";
            this.일봉데이터ToolStripMenuItem.Size = new System.Drawing.Size(204, 34);
            this.일봉데이터ToolStripMenuItem.Text = "일봉데이터";
            this.일봉데이터ToolStripMenuItem.Click += new System.EventHandler(this.일봉데이터ToolStripMenuItem_Click);
            // 
            // 주문기능ToolStripMenuItem
            // 
            this.주문기능ToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.주문ToolStripMenuItem});
            this.주문기능ToolStripMenuItem.Name = "주문기능ToolStripMenuItem";
            this.주문기능ToolStripMenuItem.Size = new System.Drawing.Size(100, 29);
            this.주문기능ToolStripMenuItem.Text = "주문기능";
            // 
            // 주문ToolStripMenuItem
            // 
            this.주문ToolStripMenuItem.Name = "주문ToolStripMenuItem";
            this.주문ToolStripMenuItem.Size = new System.Drawing.Size(150, 34);
            this.주문ToolStripMenuItem.Text = "주문";
            this.주문ToolStripMenuItem.Click += new System.EventHandler(this.주문ToolStripMenuItem_Click);
            // 
            // 조건검색ToolStripMenuItem
            // 
            this.조건검색ToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.조건식로컬저장ToolStripMenuItem,
            this.조건명리스트호출ToolStripMenuItem});
            this.조건검색ToolStripMenuItem.Name = "조건검색ToolStripMenuItem";
            this.조건검색ToolStripMenuItem.Size = new System.Drawing.Size(100, 29);
            this.조건검색ToolStripMenuItem.Text = "조건검색";
            // 
            // 조건식로컬저장ToolStripMenuItem
            // 
            this.조건식로컬저장ToolStripMenuItem.Name = "조건식로컬저장ToolStripMenuItem";
            this.조건식로컬저장ToolStripMenuItem.Size = new System.Drawing.Size(270, 34);
            this.조건식로컬저장ToolStripMenuItem.Text = "조건식 로컬저장";
            this.조건식로컬저장ToolStripMenuItem.Click += new System.EventHandler(this.조건식로컬저장ToolStripMenuItem_Click);
            // 
            // 조건명리스트호출ToolStripMenuItem
            // 
            this.조건명리스트호출ToolStripMenuItem.Name = "조건명리스트호출ToolStripMenuItem";
            this.조건명리스트호출ToolStripMenuItem.Size = new System.Drawing.Size(270, 34);
            this.조건명리스트호출ToolStripMenuItem.Text = "조건명 리스트 호출";
            this.조건명리스트호출ToolStripMenuItem.Click += new System.EventHandler(this.조건명리스트호출ToolStripMenuItem_Click);
            // 
            // lst실시간
            // 
            this.lst실시간.FormattingEnabled = true;
            this.lst실시간.HorizontalScrollbar = true;
            this.lst실시간.ItemHeight = 18;
            this.lst실시간.Location = new System.Drawing.Point(1150, 128);
            this.lst실시간.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.lst실시간.Name = "lst실시간";
            this.lst실시간.Size = new System.Drawing.Size(871, 292);
            this.lst실시간.TabIndex = 2;
            // 
            // lst일반
            // 
            this.lst일반.FormattingEnabled = true;
            this.lst일반.HorizontalScrollbar = true;
            this.lst일반.ItemHeight = 18;
            this.lst일반.Location = new System.Drawing.Point(726, 128);
            this.lst일반.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.lst일반.Name = "lst일반";
            this.lst일반.Size = new System.Drawing.Size(414, 292);
            this.lst일반.TabIndex = 3;
            // 
            // lst조회
            // 
            this.lst조회.FormattingEnabled = true;
            this.lst조회.HorizontalScrollbar = true;
            this.lst조회.ItemHeight = 18;
            this.lst조회.Location = new System.Drawing.Point(1150, 468);
            this.lst조회.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.lst조회.Name = "lst조회";
            this.lst조회.Size = new System.Drawing.Size(871, 292);
            this.lst조회.TabIndex = 4;
            // 
            // lst에러
            // 
            this.lst에러.FormattingEnabled = true;
            this.lst에러.HorizontalScrollbar = true;
            this.lst에러.ItemHeight = 18;
            this.lst에러.Location = new System.Drawing.Point(726, 468);
            this.lst에러.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.lst에러.Name = "lst에러";
            this.lst에러.Size = new System.Drawing.Size(414, 292);
            this.lst에러.TabIndex = 5;
            // 
            // lbl일반
            // 
            this.lbl일반.AutoSize = true;
            this.lbl일반.Location = new System.Drawing.Point(723, 105);
            this.lbl일반.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.lbl일반.Name = "lbl일반";
            this.lbl일반.Size = new System.Drawing.Size(44, 18);
            this.lbl일반.TabIndex = 6;
            this.lbl일반.Text = "일반";
            // 
            // lbl에러
            // 
            this.lbl에러.AutoSize = true;
            this.lbl에러.Location = new System.Drawing.Point(723, 446);
            this.lbl에러.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.lbl에러.Name = "lbl에러";
            this.lbl에러.Size = new System.Drawing.Size(44, 18);
            this.lbl에러.TabIndex = 7;
            this.lbl에러.Text = "에러";
            // 
            // lbl실시간
            // 
            this.lbl실시간.AutoSize = true;
            this.lbl실시간.Location = new System.Drawing.Point(1150, 105);
            this.lbl실시간.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.lbl실시간.Name = "lbl실시간";
            this.lbl실시간.Size = new System.Drawing.Size(62, 18);
            this.lbl실시간.TabIndex = 8;
            this.lbl실시간.Text = "실시간";
            // 
            // lbl조회
            // 
            this.lbl조회.AutoSize = true;
            this.lbl조회.Location = new System.Drawing.Point(1150, 446);
            this.lbl조회.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.lbl조회.Name = "lbl조회";
            this.lbl조회.Size = new System.Drawing.Size(44, 18);
            this.lbl조회.TabIndex = 9;
            this.lbl조회.Text = "조회";
            // 
            // grp로그
            // 
            this.grp로그.Location = new System.Drawing.Point(704, 74);
            this.grp로그.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.grp로그.Name = "grp로그";
            this.grp로그.Padding = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.grp로그.Size = new System.Drawing.Size(1343, 712);
            this.grp로그.TabIndex = 10;
            this.grp로그.TabStop = false;
            this.grp로그.Text = "오픈 API 로그";
            // 
            // axKHOpenAPI
            // 
            this.axKHOpenAPI.Enabled = true;
            this.axKHOpenAPI.Location = new System.Drawing.Point(12, 506);
            this.axKHOpenAPI.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.axKHOpenAPI.Name = "axKHOpenAPI";
            this.axKHOpenAPI.OcxState = ((System.Windows.Forms.AxHost.State)(resources.GetObject("axKHOpenAPI.OcxState")));
            this.axKHOpenAPI.Size = new System.Drawing.Size(96, 29);
            this.axKHOpenAPI.TabIndex = 11;
            this.axKHOpenAPI.OnReceiveTrData += new AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveTrDataEventHandler(this.axKHOpenAPI_OnReceiveTrData);
            this.axKHOpenAPI.OnReceiveRealData += new AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveRealDataEventHandler(this.axKHOpenAPI_OnReceiveRealData);
            this.axKHOpenAPI.OnReceiveMsg += new AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveMsgEventHandler(this.axKHOpenAPI_OnReceiveMsg);
            this.axKHOpenAPI.OnReceiveChejanData += new AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveChejanDataEventHandler(this.axKHOpenAPI_OnReceiveChejanData);
            this.axKHOpenAPI.OnEventConnect += new AxKHOpenAPILib._DKHOpenAPIEvents_OnEventConnectEventHandler(this.axKHOpenAPI_OnEventConnect);
            this.axKHOpenAPI.OnReceiveRealCondition += new AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveRealConditionEventHandler(this.axKHOpenAPI_OnReceiveRealCondition);
            this.axKHOpenAPI.OnReceiveTrCondition += new AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveTrConditionEventHandler(this.axKHOpenAPI_OnReceiveTrCondition);
            this.axKHOpenAPI.OnReceiveConditionVer += new AxKHOpenAPILib._DKHOpenAPIEvents_OnReceiveConditionVerEventHandler(this.axKHOpenAPI_OnReceiveConditionVer);
            // 
            // Label1
            // 
            this.Label1.AutoSize = true;
            this.Label1.Location = new System.Drawing.Point(17, 92);
            this.Label1.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.Label1.Name = "Label1";
            this.Label1.Size = new System.Drawing.Size(62, 18);
            this.Label1.TabIndex = 12;
            this.Label1.Text = "이름 : ";
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(17, 130);
            this.label2.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(80, 18);
            this.label2.TabIndex = 13;
            this.label2.Text = "아이디 : ";
            // 
            // lbl이름
            // 
            this.lbl이름.AutoSize = true;
            this.lbl이름.Location = new System.Drawing.Point(84, 92);
            this.lbl이름.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.lbl이름.Name = "lbl이름";
            this.lbl이름.Size = new System.Drawing.Size(0, 18);
            this.lbl이름.TabIndex = 14;
            // 
            // lbl아이디
            // 
            this.lbl아이디.AutoSize = true;
            this.lbl아이디.Location = new System.Drawing.Point(101, 130);
            this.lbl아이디.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.lbl아이디.Name = "lbl아이디";
            this.lbl아이디.Size = new System.Drawing.Size(0, 18);
            this.lbl아이디.TabIndex = 15;
            // 
            // cbo계좌
            // 
            this.cbo계좌.FormattingEnabled = true;
            this.cbo계좌.Location = new System.Drawing.Point(117, 165);
            this.cbo계좌.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.cbo계좌.Name = "cbo계좌";
            this.cbo계좌.Size = new System.Drawing.Size(171, 26);
            this.cbo계좌.TabIndex = 16;
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(16, 170);
            this.label3.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(98, 18);
            this.label3.TabIndex = 17;
            this.label3.Text = "계좌번호 : ";
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(14, 210);
            this.label4.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(92, 18);
            this.label4.TabIndex = 18;
            this.label4.Text = "종목코드 :";
            // 
            // txt종목코드
            // 
            this.txt종목코드.Location = new System.Drawing.Point(117, 204);
            this.txt종목코드.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.txt종목코드.Name = "txt종목코드";
            this.txt종목코드.Size = new System.Drawing.Size(105, 28);
            this.txt종목코드.TabIndex = 19;
            this.txt종목코드.Text = "039490";
            this.txt종목코드.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.txt종목코드_KeyPress);
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(14, 256);
            this.label5.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(178, 18);
            this.label5.TabIndex = 20;
            this.label5.Text = "조회날짜 (20141226)";
            // 
            // txt조회날짜
            // 
            this.txt조회날짜.Location = new System.Drawing.Point(187, 252);
            this.txt조회날짜.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.txt조회날짜.Name = "txt조회날짜";
            this.txt조회날짜.Size = new System.Drawing.Size(101, 28);
            this.txt조회날짜.TabIndex = 21;
            this.txt조회날짜.Text = "20150126";
            this.txt조회날짜.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.txt조회날짜_KeyPress);
            // 
            // groupBox1
            // 
            this.groupBox1.Controls.Add(this.btn주문);
            this.groupBox1.Controls.Add(this.cbo매매구분);
            this.groupBox1.Controls.Add(this.cbo거래구분);
            this.groupBox1.Controls.Add(this.txt원주문번호);
            this.groupBox1.Controls.Add(this.txt주문가격);
            this.groupBox1.Controls.Add(this.txt주문수량);
            this.groupBox1.Controls.Add(this.txt주문종목코드);
            this.groupBox1.Controls.Add(this.label11);
            this.groupBox1.Controls.Add(this.label10);
            this.groupBox1.Controls.Add(this.label9);
            this.groupBox1.Controls.Add(this.label8);
            this.groupBox1.Controls.Add(this.label7);
            this.groupBox1.Controls.Add(this.label6);
            this.groupBox1.Location = new System.Drawing.Point(20, 310);
            this.groupBox1.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Padding = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.groupBox1.Size = new System.Drawing.Size(356, 369);
            this.groupBox1.TabIndex = 22;
            this.groupBox1.TabStop = false;
            this.groupBox1.Text = "주문입력";
            // 
            // btn주문
            // 
            this.btn주문.Location = new System.Drawing.Point(39, 296);
            this.btn주문.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.btn주문.Name = "btn주문";
            this.btn주문.Size = new System.Drawing.Size(283, 45);
            this.btn주문.TabIndex = 12;
            this.btn주문.Text = "주     문";
            this.btn주문.UseVisualStyleBackColor = true;
            this.btn주문.Click += new System.EventHandler(this.btn주문_Click);
            // 
            // cbo매매구분
            // 
            this.cbo매매구분.FormattingEnabled = true;
            this.cbo매매구분.Location = new System.Drawing.Point(120, 117);
            this.cbo매매구분.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.cbo매매구분.Name = "cbo매매구분";
            this.cbo매매구분.Size = new System.Drawing.Size(200, 26);
            this.cbo매매구분.TabIndex = 11;
            // 
            // cbo거래구분
            // 
            this.cbo거래구분.FormattingEnabled = true;
            this.cbo거래구분.Location = new System.Drawing.Point(120, 70);
            this.cbo거래구분.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.cbo거래구분.Name = "cbo거래구분";
            this.cbo거래구분.Size = new System.Drawing.Size(200, 26);
            this.cbo거래구분.TabIndex = 10;
            // 
            // txt원주문번호
            // 
            this.txt원주문번호.Location = new System.Drawing.Point(120, 238);
            this.txt원주문번호.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.txt원주문번호.Name = "txt원주문번호";
            this.txt원주문번호.Size = new System.Drawing.Size(200, 28);
            this.txt원주문번호.TabIndex = 9;
            this.txt원주문번호.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.txt원주문번호_KeyPress);
            // 
            // txt주문가격
            // 
            this.txt주문가격.Location = new System.Drawing.Point(120, 201);
            this.txt주문가격.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.txt주문가격.Name = "txt주문가격";
            this.txt주문가격.Size = new System.Drawing.Size(200, 28);
            this.txt주문가격.TabIndex = 8;
            this.txt주문가격.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.txt주문가격_KeyPress);
            // 
            // txt주문수량
            // 
            this.txt주문수량.Location = new System.Drawing.Point(120, 160);
            this.txt주문수량.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.txt주문수량.Name = "txt주문수량";
            this.txt주문수량.Size = new System.Drawing.Size(200, 28);
            this.txt주문수량.TabIndex = 7;
            this.txt주문수량.Text = "10";
            this.txt주문수량.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.txt주문수량_KeyPress);
            // 
            // txt주문종목코드
            // 
            this.txt주문종목코드.Location = new System.Drawing.Point(120, 30);
            this.txt주문종목코드.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.txt주문종목코드.Name = "txt주문종목코드";
            this.txt주문종목코드.Size = new System.Drawing.Size(200, 28);
            this.txt주문종목코드.TabIndex = 6;
            this.txt주문종목코드.Text = "039490";
            this.txt주문종목코드.KeyPress += new System.Windows.Forms.KeyPressEventHandler(this.txt주문종목코드_KeyPress);
            // 
            // label11
            // 
            this.label11.AutoSize = true;
            this.label11.Location = new System.Drawing.Point(13, 243);
            this.label11.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label11.Name = "label11";
            this.label11.Size = new System.Drawing.Size(98, 18);
            this.label11.TabIndex = 5;
            this.label11.Text = "원주문번호";
            // 
            // label10
            // 
            this.label10.AutoSize = true;
            this.label10.Location = new System.Drawing.Point(30, 206);
            this.label10.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label10.Name = "label10";
            this.label10.Size = new System.Drawing.Size(80, 18);
            this.label10.TabIndex = 4;
            this.label10.Text = "주문가격";
            // 
            // label9
            // 
            this.label9.AutoSize = true;
            this.label9.Location = new System.Drawing.Point(30, 165);
            this.label9.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label9.Name = "label9";
            this.label9.Size = new System.Drawing.Size(80, 18);
            this.label9.TabIndex = 3;
            this.label9.Text = "주문수량";
            // 
            // label8
            // 
            this.label8.AutoSize = true;
            this.label8.Location = new System.Drawing.Point(30, 122);
            this.label8.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label8.Name = "label8";
            this.label8.Size = new System.Drawing.Size(80, 18);
            this.label8.TabIndex = 2;
            this.label8.Text = "매매구분";
            // 
            // label7
            // 
            this.label7.AutoSize = true;
            this.label7.Location = new System.Drawing.Point(30, 80);
            this.label7.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label7.Name = "label7";
            this.label7.Size = new System.Drawing.Size(80, 18);
            this.label7.TabIndex = 1;
            this.label7.Text = "거래구분";
            // 
            // label6
            // 
            this.label6.AutoSize = true;
            this.label6.Location = new System.Drawing.Point(30, 44);
            this.label6.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(80, 18);
            this.label6.TabIndex = 0;
            this.label6.Text = "종목코드";
            // 
            // cbo조건식
            // 
            this.cbo조건식.FormattingEnabled = true;
            this.cbo조건식.Location = new System.Drawing.Point(91, 28);
            this.cbo조건식.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.cbo조건식.Name = "cbo조건식";
            this.cbo조건식.Size = new System.Drawing.Size(171, 26);
            this.cbo조건식.TabIndex = 23;
            // 
            // groupBox2
            // 
            this.groupBox2.Controls.Add(this.btn_조건실시간중지);
            this.groupBox2.Controls.Add(this.btn조건실시간조회);
            this.groupBox2.Controls.Add(this.label12);
            this.groupBox2.Controls.Add(this.btn_조건일반조회);
            this.groupBox2.Controls.Add(this.cbo조건식);
            this.groupBox2.Location = new System.Drawing.Point(393, 74);
            this.groupBox2.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.groupBox2.Name = "groupBox2";
            this.groupBox2.Padding = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.groupBox2.Size = new System.Drawing.Size(303, 201);
            this.groupBox2.TabIndex = 24;
            this.groupBox2.TabStop = false;
            this.groupBox2.Text = "조건검색";
            // 
            // btn_조건실시간중지
            // 
            this.btn_조건실시간중지.Location = new System.Drawing.Point(157, 136);
            this.btn_조건실시간중지.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.btn_조건실시간중지.Name = "btn_조건실시간중지";
            this.btn_조건실시간중지.Size = new System.Drawing.Size(107, 34);
            this.btn_조건실시간중지.TabIndex = 27;
            this.btn_조건실시간중지.Text = "실시간중지";
            this.btn_조건실시간중지.UseVisualStyleBackColor = true;
            this.btn_조건실시간중지.Click += new System.EventHandler(this.btn_조건실시간중지_Click);
            // 
            // btn조건실시간조회
            // 
            this.btn조건실시간조회.Location = new System.Drawing.Point(157, 80);
            this.btn조건실시간조회.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.btn조건실시간조회.Name = "btn조건실시간조회";
            this.btn조건실시간조회.Size = new System.Drawing.Size(107, 34);
            this.btn조건실시간조회.TabIndex = 26;
            this.btn조건실시간조회.Text = "실시간조회";
            this.btn조건실시간조회.UseVisualStyleBackColor = true;
            this.btn조건실시간조회.Click += new System.EventHandler(this.btn조건실시간조회_Click);
            // 
            // label12
            // 
            this.label12.AutoSize = true;
            this.label12.Location = new System.Drawing.Point(9, 36);
            this.label12.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label12.Name = "label12";
            this.label12.Size = new System.Drawing.Size(80, 18);
            this.label12.TabIndex = 25;
            this.label12.Text = "조건식 : ";
            // 
            // btn_조건일반조회
            // 
            this.btn_조건일반조회.Location = new System.Drawing.Point(26, 80);
            this.btn_조건일반조회.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.btn_조건일반조회.Name = "btn_조건일반조회";
            this.btn_조건일반조회.Size = new System.Drawing.Size(107, 34);
            this.btn_조건일반조회.TabIndex = 25;
            this.btn_조건일반조회.Text = "일반조회";
            this.btn_조건일반조회.UseVisualStyleBackColor = true;
            this.btn_조건일반조회.Click += new System.EventHandler(this.btn_조건일반조회_Click);
            // 
            // group실시간등록해제
            // 
            this.group실시간등록해제.Controls.Add(this.btn실시간해제);
            this.group실시간등록해제.Controls.Add(this.btn실시간등록);
            this.group실시간등록해제.Controls.Add(this.label13);
            this.group실시간등록해제.Controls.Add(this.txt실시간종목코드);
            this.group실시간등록해제.Location = new System.Drawing.Point(393, 310);
            this.group실시간등록해제.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.group실시간등록해제.Name = "group실시간등록해제";
            this.group실시간등록해제.Padding = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.group실시간등록해제.Size = new System.Drawing.Size(303, 150);
            this.group실시간등록해제.TabIndex = 25;
            this.group실시간등록해제.TabStop = false;
            this.group실시간등록해제.Text = "실시간 등록 해제";
            // 
            // btn실시간해제
            // 
            this.btn실시간해제.Location = new System.Drawing.Point(187, 105);
            this.btn실시간해제.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.btn실시간해제.Name = "btn실시간해제";
            this.btn실시간해제.Size = new System.Drawing.Size(107, 34);
            this.btn실시간해제.TabIndex = 29;
            this.btn실시간해제.Text = "실시간해제";
            this.btn실시간해제.UseVisualStyleBackColor = true;
            this.btn실시간해제.Click += new System.EventHandler(this.btn실시간해제_Click);
            // 
            // btn실시간등록
            // 
            this.btn실시간등록.Location = new System.Drawing.Point(11, 105);
            this.btn실시간등록.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.btn실시간등록.Name = "btn실시간등록";
            this.btn실시간등록.Size = new System.Drawing.Size(107, 34);
            this.btn실시간등록.TabIndex = 28;
            this.btn실시간등록.Text = "실시간등록";
            this.btn실시간등록.UseVisualStyleBackColor = true;
            this.btn실시간등록.Click += new System.EventHandler(this.btn실시간등록_Click);
            // 
            // label13
            // 
            this.label13.AutoSize = true;
            this.label13.Location = new System.Drawing.Point(9, 36);
            this.label13.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label13.Name = "label13";
            this.label13.Size = new System.Drawing.Size(98, 18);
            this.label13.TabIndex = 26;
            this.label13.Text = "종목코드 : ";
            // 
            // txt실시간종목코드
            // 
            this.txt실시간종목코드.Location = new System.Drawing.Point(11, 66);
            this.txt실시간종목코드.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.txt실시간종목코드.Name = "txt실시간종목코드";
            this.txt실시간종목코드.Size = new System.Drawing.Size(281, 28);
            this.txt실시간종목코드.TabIndex = 0;
            // 
            // btn자동주문
            // 
            this.btn자동주문.Location = new System.Drawing.Point(393, 500);
            this.btn자동주문.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.btn자동주문.Name = "btn자동주문";
            this.btn자동주문.Size = new System.Drawing.Size(294, 44);
            this.btn자동주문.TabIndex = 26;
            this.btn자동주문.Text = "자동주문 시작";
            this.btn자동주문.UseVisualStyleBackColor = true;
            this.btn자동주문.Click += new System.EventHandler(this.btn자동주문_Click);
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(10F, 18F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(2064, 804);
            this.Controls.Add(this.btn자동주문);
            this.Controls.Add(this.group실시간등록해제);
            this.Controls.Add(this.groupBox2);
            this.Controls.Add(this.groupBox1);
            this.Controls.Add(this.txt조회날짜);
            this.Controls.Add(this.label5);
            this.Controls.Add(this.txt종목코드);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.cbo계좌);
            this.Controls.Add(this.lbl아이디);
            this.Controls.Add(this.lbl이름);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.Label1);
            this.Controls.Add(this.axKHOpenAPI);
            this.Controls.Add(this.lbl조회);
            this.Controls.Add(this.lbl실시간);
            this.Controls.Add(this.lbl에러);
            this.Controls.Add(this.lbl일반);
            this.Controls.Add(this.lst에러);
            this.Controls.Add(this.lst조회);
            this.Controls.Add(this.lst일반);
            this.Controls.Add(this.lst실시간);
            this.Controls.Add(this.menuStrip);
            this.Controls.Add(this.grp로그);
            this.MainMenuStrip = this.menuStrip;
            this.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.Name = "Form1";
            this.Text = "키움 오픈 API C# 예제 ( www.sbcn.co.kr )";
            this.Load += new System.EventHandler(this.Form1_Load);
            this.menuStrip.ResumeLayout(false);
            this.menuStrip.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.axKHOpenAPI)).EndInit();
            this.groupBox1.ResumeLayout(false);
            this.groupBox1.PerformLayout();
            this.groupBox2.ResumeLayout(false);
            this.groupBox2.PerformLayout();
            this.group실시간등록해제.ResumeLayout(false);
            this.group실시간등록해제.PerformLayout();
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.MenuStrip menuStrip;
        private System.Windows.Forms.ToolStripMenuItem 기본기능ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 로그인ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 로그아웃ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 접속상태ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 계좌조회ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 종료ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 조회기능ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 현재가ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 일봉데이터ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 주문기능ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 주문ToolStripMenuItem;
        private System.Windows.Forms.ListBox lst실시간;
        private System.Windows.Forms.ListBox lst일반;
        private System.Windows.Forms.ListBox lst조회;
        private System.Windows.Forms.ListBox lst에러;
        private System.Windows.Forms.Label lbl일반;
        private System.Windows.Forms.Label lbl에러;
        private System.Windows.Forms.Label lbl실시간;
        private System.Windows.Forms.Label lbl조회;
        private System.Windows.Forms.GroupBox grp로그;
        private AxKHOpenAPILib.AxKHOpenAPI axKHOpenAPI;
        private System.Windows.Forms.Label Label1;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Label lbl이름;
        private System.Windows.Forms.Label lbl아이디;
        private System.Windows.Forms.ComboBox cbo계좌;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.TextBox txt종목코드;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.TextBox txt조회날짜;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.ComboBox cbo매매구분;
        private System.Windows.Forms.ComboBox cbo거래구분;
        private System.Windows.Forms.TextBox txt원주문번호;
        private System.Windows.Forms.TextBox txt주문가격;
        private System.Windows.Forms.TextBox txt주문수량;
        private System.Windows.Forms.TextBox txt주문종목코드;
        private System.Windows.Forms.Label label11;
        private System.Windows.Forms.Label label10;
        private System.Windows.Forms.Label label9;
        private System.Windows.Forms.Label label8;
        private System.Windows.Forms.Label label7;
        private System.Windows.Forms.Label label6;
        private System.Windows.Forms.Button btn주문;
        private System.Windows.Forms.ToolStripMenuItem 조건검색ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 조건식로컬저장ToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem 조건명리스트호출ToolStripMenuItem;
        private System.Windows.Forms.ComboBox cbo조건식;
        private System.Windows.Forms.GroupBox groupBox2;
        private System.Windows.Forms.Button btn_조건실시간중지;
        private System.Windows.Forms.Button btn조건실시간조회;
        private System.Windows.Forms.Label label12;
        private System.Windows.Forms.Button btn_조건일반조회;
        private System.Windows.Forms.GroupBox group실시간등록해제;
        private System.Windows.Forms.Label label13;
        private System.Windows.Forms.TextBox txt실시간종목코드;
        private System.Windows.Forms.Button btn실시간등록;
        private System.Windows.Forms.Button btn실시간해제;
        private System.Windows.Forms.Button btn자동주문;
    }
}


﻿namespace StockTrade
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
        /// 이 메서드의 내용을 코드 편집기로 수정하지 마세요.
        /// </summary>
        private void InitializeComponent()
        {
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Form1));
            this.axKHOpenAPI1 = new AxKHOpenAPILib.AxKHOpenAPI();
            this.tableLayoutPanel1 = new System.Windows.Forms.TableLayoutPanel();
            this.tableLayoutPanel4 = new System.Windows.Forms.TableLayoutPanel();
            this.label7 = new System.Windows.Forms.Label();
            this.stockCodeLabel = new System.Windows.Forms.Label();
            this.label9 = new System.Windows.Forms.Label();
            this.label10 = new System.Windows.Forms.Label();
            this.label11 = new System.Windows.Forms.Label();
            this.orderComboBox = new System.Windows.Forms.ComboBox();
            this.orderPriceNumericUpDown = new System.Windows.Forms.NumericUpDown();
            this.orderNumberNumericUpDown = new System.Windows.Forms.NumericUpDown();
            this.buyButton = new System.Windows.Forms.Button();
            this.sellButton = new System.Windows.Forms.Button();
            this.stockSearchButton = new System.Windows.Forms.Button();
            this.stockTextBox = new System.Windows.Forms.TextBox();
            this.tableLayoutPanel3 = new System.Windows.Forms.TableLayoutPanel();
            this.numericUpDown4 = new System.Windows.Forms.NumericUpDown();
            this.label5 = new System.Windows.Forms.Label();
            this.label6 = new System.Windows.Forms.Label();
            this.limitLossRateNumericUpDown = new System.Windows.Forms.NumericUpDown();
            this.limitProfitRateNumericUpDown = new System.Windows.Forms.NumericUpDown();
            this.setAutoTradingRuleButton = new System.Windows.Forms.Button();
            this.orderFixButton = new System.Windows.Forms.Button();
            this.balanceCheckButton = new System.Windows.Forms.Button();
            this.orderCancelButton = new System.Windows.Forms.Button();
            this.sellAllStockButton = new System.Windows.Forms.Button();
            this.tableLayoutPanel2 = new System.Windows.Forms.TableLayoutPanel();
            this.label1 = new System.Windows.Forms.Label();
            this.label3 = new System.Windows.Forms.Label();
            this.label2 = new System.Windows.Forms.Label();
            this.conditionComboBox = new System.Windows.Forms.ComboBox();
            this.limitPriceNumericUpDown = new System.Windows.Forms.NumericUpDown();
            this.limitNumberNumericUpDown = new System.Windows.Forms.NumericUpDown();
            this.startAutoTradingButton = new System.Windows.Forms.Button();
            this.stopAutoTradingButton = new System.Windows.Forms.Button();
            this.label18 = new System.Windows.Forms.Label();
            this.autoSellOrderComboBox = new System.Windows.Forms.ComboBox();
            this.label4 = new System.Windows.Forms.Label();
            this.autoBuyOrderComboBox = new System.Windows.Forms.ComboBox();
            this.label19 = new System.Windows.Forms.Label();
            this.limitBuyingPerStockLabel = new System.Windows.Forms.Label();
            this.tableLayoutPanel5 = new System.Windows.Forms.TableLayoutPanel();
            this.label12 = new System.Windows.Forms.Label();
            this.accountComboBox = new System.Windows.Forms.ComboBox();
            this.label17 = new System.Windows.Forms.Label();
            this.label16 = new System.Windows.Forms.Label();
            this.label15 = new System.Windows.Forms.Label();
            this.label14 = new System.Windows.Forms.Label();
            this.label13 = new System.Windows.Forms.Label();
            this.todayProfitRateLabel = new System.Windows.Forms.Label();
            this.todayProfitLabel = new System.Windows.Forms.Label();
            this.totalEstimateLabel = new System.Windows.Forms.Label();
            this.passwordTextBox = new System.Windows.Forms.TextBox();
            this.label8 = new System.Windows.Forms.Label();
            this.totalBuyLabel = new System.Windows.Forms.Label();
            this.depositLabel = new System.Windows.Forms.Label();
            this.tableLayoutPanel7 = new System.Windows.Forms.TableLayoutPanel();
            this.autoRuleDataGridView = new System.Windows.Forms.DataGridView();
            this.거래규칙_번호 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_R파일 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_조건식 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_매입제한_금액 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_매입제한_종목_개수 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_종목당_매수금액 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_매수_거래구분 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_매도_거래구분 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_이익률 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_손절률 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_업데이트시간 = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.거래규칙_상태 = new System.Windows.Forms.DataGridViewComboBoxColumn();
            this.tableLayoutPanel6 = new System.Windows.Forms.TableLayoutPanel();
            this.tabControl2 = new System.Windows.Forms.TabControl();
            this.tabPage3 = new System.Windows.Forms.TabPage();
            this.insertListBox = new System.Windows.Forms.ListBox();
            this.tabPage4 = new System.Windows.Forms.TabPage();
            this.deleteListBox = new System.Windows.Forms.ListBox();
            this.tabPage6 = new System.Windows.Forms.TabPage();
            this.orderRecordListBox = new System.Windows.Forms.ListBox();
            this.tabControl1 = new System.Windows.Forms.TabControl();
            this.tabPage1 = new System.Windows.Forms.TabPage();
            this.balanceDataGridView = new System.Windows.Forms.DataGridView();
            this.tabPage2 = new System.Windows.Forms.TabPage();
            this.outstandingDataGridView = new System.Windows.Forms.DataGridView();
            ((System.ComponentModel.ISupportInitialize)(this.axKHOpenAPI1)).BeginInit();
            this.tableLayoutPanel1.SuspendLayout();
            this.tableLayoutPanel4.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.orderPriceNumericUpDown)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.orderNumberNumericUpDown)).BeginInit();
            this.tableLayoutPanel3.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown4)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.limitLossRateNumericUpDown)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.limitProfitRateNumericUpDown)).BeginInit();
            this.tableLayoutPanel2.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.limitPriceNumericUpDown)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.limitNumberNumericUpDown)).BeginInit();
            this.tableLayoutPanel5.SuspendLayout();
            this.tableLayoutPanel7.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.autoRuleDataGridView)).BeginInit();
            this.tableLayoutPanel6.SuspendLayout();
            this.tabControl2.SuspendLayout();
            this.tabPage3.SuspendLayout();
            this.tabPage4.SuspendLayout();
            this.tabPage6.SuspendLayout();
            this.tabControl1.SuspendLayout();
            this.tabPage1.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.balanceDataGridView)).BeginInit();
            this.tabPage2.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.outstandingDataGridView)).BeginInit();
            this.SuspendLayout();
            // 
            // axKHOpenAPI1
            // 
            this.axKHOpenAPI1.Enabled = true;
            this.axKHOpenAPI1.Location = new System.Drawing.Point(12, 301);
            this.axKHOpenAPI1.Name = "axKHOpenAPI1";
            this.axKHOpenAPI1.OcxState = ((System.Windows.Forms.AxHost.State)(resources.GetObject("axKHOpenAPI1.OcxState")));
            this.axKHOpenAPI1.Size = new System.Drawing.Size(150, 75);
            this.axKHOpenAPI1.TabIndex = 0;
            // 
            // tableLayoutPanel1
            // 
            this.tableLayoutPanel1.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.tableLayoutPanel1.ColumnCount = 4;
            this.tableLayoutPanel1.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 25F));
            this.tableLayoutPanel1.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 25F));
            this.tableLayoutPanel1.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 25F));
            this.tableLayoutPanel1.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 25F));
            this.tableLayoutPanel1.Controls.Add(this.tableLayoutPanel4, 2, 0);
            this.tableLayoutPanel1.Controls.Add(this.tableLayoutPanel3, 1, 0);
            this.tableLayoutPanel1.Controls.Add(this.tableLayoutPanel2, 0, 0);
            this.tableLayoutPanel1.Controls.Add(this.tableLayoutPanel5, 3, 0);
            this.tableLayoutPanel1.Location = new System.Drawing.Point(3, 3);
            this.tableLayoutPanel1.Name = "tableLayoutPanel1";
            this.tableLayoutPanel1.RowCount = 1;
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 222F));
            this.tableLayoutPanel1.Size = new System.Drawing.Size(1726, 222);
            this.tableLayoutPanel1.TabIndex = 1;
            // 
            // tableLayoutPanel4
            // 
            this.tableLayoutPanel4.AutoSize = true;
            this.tableLayoutPanel4.ColumnCount = 3;
            this.tableLayoutPanel4.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel4.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel4.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 3F));
            this.tableLayoutPanel4.Controls.Add(this.label7, 0, 1);
            this.tableLayoutPanel4.Controls.Add(this.stockCodeLabel, 1, 1);
            this.tableLayoutPanel4.Controls.Add(this.label9, 0, 2);
            this.tableLayoutPanel4.Controls.Add(this.label10, 0, 3);
            this.tableLayoutPanel4.Controls.Add(this.label11, 0, 4);
            this.tableLayoutPanel4.Controls.Add(this.orderComboBox, 1, 2);
            this.tableLayoutPanel4.Controls.Add(this.orderPriceNumericUpDown, 1, 3);
            this.tableLayoutPanel4.Controls.Add(this.orderNumberNumericUpDown, 1, 4);
            this.tableLayoutPanel4.Controls.Add(this.buyButton, 0, 5);
            this.tableLayoutPanel4.Controls.Add(this.sellButton, 1, 5);
            this.tableLayoutPanel4.Controls.Add(this.stockSearchButton, 1, 0);
            this.tableLayoutPanel4.Controls.Add(this.stockTextBox, 0, 0);
            this.tableLayoutPanel4.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel4.Location = new System.Drawing.Point(866, 4);
            this.tableLayoutPanel4.Margin = new System.Windows.Forms.Padding(4);
            this.tableLayoutPanel4.Name = "tableLayoutPanel4";
            this.tableLayoutPanel4.RowCount = 7;
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 0F));
            this.tableLayoutPanel4.Size = new System.Drawing.Size(423, 214);
            this.tableLayoutPanel4.TabIndex = 2;
            // 
            // label7
            // 
            this.label7.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label7.AutoSize = true;
            this.label7.Location = new System.Drawing.Point(65, 43);
            this.label7.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label7.Name = "label7";
            this.label7.Size = new System.Drawing.Size(80, 18);
            this.label7.TabIndex = 0;
            this.label7.Text = "종목코드";
            this.label7.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // stockCodeLabel
            // 
            this.stockCodeLabel.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.stockCodeLabel.AutoSize = true;
            this.stockCodeLabel.Location = new System.Drawing.Point(293, 43);
            this.stockCodeLabel.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.stockCodeLabel.Name = "stockCodeLabel";
            this.stockCodeLabel.Size = new System.Drawing.Size(44, 18);
            this.stockCodeLabel.TabIndex = 0;
            this.stockCodeLabel.Text = "label";
            this.stockCodeLabel.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label9
            // 
            this.label9.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label9.AutoSize = true;
            this.label9.Location = new System.Drawing.Point(65, 78);
            this.label9.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label9.Name = "label9";
            this.label9.Size = new System.Drawing.Size(80, 18);
            this.label9.TabIndex = 0;
            this.label9.Text = "거래구분";
            this.label9.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label10
            // 
            this.label10.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label10.AutoSize = true;
            this.label10.Location = new System.Drawing.Point(65, 113);
            this.label10.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label10.Name = "label10";
            this.label10.Size = new System.Drawing.Size(80, 18);
            this.label10.TabIndex = 0;
            this.label10.Text = "주문가격";
            this.label10.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label11
            // 
            this.label11.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label11.AutoSize = true;
            this.label11.Location = new System.Drawing.Point(65, 148);
            this.label11.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label11.Name = "label11";
            this.label11.Size = new System.Drawing.Size(80, 18);
            this.label11.TabIndex = 0;
            this.label11.Text = "주문수량";
            this.label11.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // orderComboBox
            // 
            this.orderComboBox.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.orderComboBox.FormattingEnabled = true;
            this.orderComboBox.Items.AddRange(new object[] {
            "00:지정가",
            "03:시장가"});
            this.orderComboBox.Location = new System.Drawing.Point(214, 74);
            this.orderComboBox.Margin = new System.Windows.Forms.Padding(4);
            this.orderComboBox.Name = "orderComboBox";
            this.orderComboBox.Size = new System.Drawing.Size(202, 26);
            this.orderComboBox.TabIndex = 2;
            // 
            // orderPriceNumericUpDown
            // 
            this.orderPriceNumericUpDown.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.orderPriceNumericUpDown.Location = new System.Drawing.Point(214, 109);
            this.orderPriceNumericUpDown.Margin = new System.Windows.Forms.Padding(4);
            this.orderPriceNumericUpDown.Name = "orderPriceNumericUpDown";
            this.orderPriceNumericUpDown.Size = new System.Drawing.Size(202, 28);
            this.orderPriceNumericUpDown.TabIndex = 3;
            // 
            // orderNumberNumericUpDown
            // 
            this.orderNumberNumericUpDown.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.orderNumberNumericUpDown.Location = new System.Drawing.Point(214, 144);
            this.orderNumberNumericUpDown.Margin = new System.Windows.Forms.Padding(4);
            this.orderNumberNumericUpDown.Name = "orderNumberNumericUpDown";
            this.orderNumberNumericUpDown.Size = new System.Drawing.Size(202, 28);
            this.orderNumberNumericUpDown.TabIndex = 3;
            // 
            // buyButton
            // 
            this.buyButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.buyButton.Location = new System.Drawing.Point(4, 179);
            this.buyButton.Margin = new System.Windows.Forms.Padding(4);
            this.buyButton.Name = "buyButton";
            this.buyButton.Size = new System.Drawing.Size(202, 27);
            this.buyButton.TabIndex = 3;
            this.buyButton.Text = "매수주문";
            this.buyButton.UseVisualStyleBackColor = true;
            // 
            // sellButton
            // 
            this.sellButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.sellButton.Location = new System.Drawing.Point(214, 179);
            this.sellButton.Margin = new System.Windows.Forms.Padding(4);
            this.sellButton.Name = "sellButton";
            this.sellButton.Size = new System.Drawing.Size(202, 27);
            this.sellButton.TabIndex = 3;
            this.sellButton.Text = "매도주문";
            this.sellButton.UseVisualStyleBackColor = true;
            // 
            // stockSearchButton
            // 
            this.stockSearchButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.stockSearchButton.Location = new System.Drawing.Point(214, 4);
            this.stockSearchButton.Margin = new System.Windows.Forms.Padding(4);
            this.stockSearchButton.Name = "stockSearchButton";
            this.stockSearchButton.Size = new System.Drawing.Size(202, 27);
            this.stockSearchButton.TabIndex = 3;
            this.stockSearchButton.Text = "종목검색";
            this.stockSearchButton.UseVisualStyleBackColor = true;
            // 
            // stockTextBox
            // 
            this.stockTextBox.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.stockTextBox.Location = new System.Drawing.Point(4, 4);
            this.stockTextBox.Margin = new System.Windows.Forms.Padding(4);
            this.stockTextBox.Name = "stockTextBox";
            this.stockTextBox.Size = new System.Drawing.Size(202, 28);
            this.stockTextBox.TabIndex = 4;
            // 
            // tableLayoutPanel3
            // 
            this.tableLayoutPanel3.AutoSize = true;
            this.tableLayoutPanel3.ColumnCount = 3;
            this.tableLayoutPanel3.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel3.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel3.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 3F));
            this.tableLayoutPanel3.Controls.Add(this.numericUpDown4, 2, 0);
            this.tableLayoutPanel3.Controls.Add(this.label5, 0, 0);
            this.tableLayoutPanel3.Controls.Add(this.label6, 0, 1);
            this.tableLayoutPanel3.Controls.Add(this.limitLossRateNumericUpDown, 1, 1);
            this.tableLayoutPanel3.Controls.Add(this.limitProfitRateNumericUpDown, 1, 0);
            this.tableLayoutPanel3.Controls.Add(this.setAutoTradingRuleButton, 0, 2);
            this.tableLayoutPanel3.Controls.Add(this.orderFixButton, 0, 3);
            this.tableLayoutPanel3.Controls.Add(this.balanceCheckButton, 1, 3);
            this.tableLayoutPanel3.Controls.Add(this.orderCancelButton, 0, 4);
            this.tableLayoutPanel3.Controls.Add(this.sellAllStockButton, 1, 4);
            this.tableLayoutPanel3.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel3.Location = new System.Drawing.Point(435, 4);
            this.tableLayoutPanel3.Margin = new System.Windows.Forms.Padding(4);
            this.tableLayoutPanel3.Name = "tableLayoutPanel3";
            this.tableLayoutPanel3.RowCount = 6;
            this.tableLayoutPanel3.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 20F));
            this.tableLayoutPanel3.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 20F));
            this.tableLayoutPanel3.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 20F));
            this.tableLayoutPanel3.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 20F));
            this.tableLayoutPanel3.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 20F));
            this.tableLayoutPanel3.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 0F));
            this.tableLayoutPanel3.Size = new System.Drawing.Size(423, 214);
            this.tableLayoutPanel3.TabIndex = 1;
            // 
            // numericUpDown4
            // 
            this.numericUpDown4.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.numericUpDown4.Location = new System.Drawing.Point(424, 7);
            this.numericUpDown4.Margin = new System.Windows.Forms.Padding(4);
            this.numericUpDown4.Name = "numericUpDown4";
            this.numericUpDown4.Size = new System.Drawing.Size(1, 28);
            this.numericUpDown4.TabIndex = 4;
            // 
            // label5
            // 
            this.label5.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(74, 12);
            this.label5.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(62, 18);
            this.label5.TabIndex = 0;
            this.label5.Text = "이익률";
            this.label5.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label6
            // 
            this.label6.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label6.AutoSize = true;
            this.label6.Location = new System.Drawing.Point(74, 54);
            this.label6.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(62, 18);
            this.label6.TabIndex = 0;
            this.label6.Text = "손절률";
            this.label6.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // limitLossRateNumericUpDown
            // 
            this.limitLossRateNumericUpDown.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.limitLossRateNumericUpDown.Location = new System.Drawing.Point(214, 49);
            this.limitLossRateNumericUpDown.Margin = new System.Windows.Forms.Padding(4);
            this.limitLossRateNumericUpDown.Name = "limitLossRateNumericUpDown";
            this.limitLossRateNumericUpDown.Size = new System.Drawing.Size(202, 28);
            this.limitLossRateNumericUpDown.TabIndex = 3;
            // 
            // limitProfitRateNumericUpDown
            // 
            this.limitProfitRateNumericUpDown.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.limitProfitRateNumericUpDown.Location = new System.Drawing.Point(214, 7);
            this.limitProfitRateNumericUpDown.Margin = new System.Windows.Forms.Padding(4);
            this.limitProfitRateNumericUpDown.Name = "limitProfitRateNumericUpDown";
            this.limitProfitRateNumericUpDown.Size = new System.Drawing.Size(202, 28);
            this.limitProfitRateNumericUpDown.TabIndex = 3;
            // 
            // setAutoTradingRuleButton
            // 
            this.setAutoTradingRuleButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.tableLayoutPanel3.SetColumnSpan(this.setAutoTradingRuleButton, 2);
            this.setAutoTradingRuleButton.Location = new System.Drawing.Point(4, 88);
            this.setAutoTradingRuleButton.Margin = new System.Windows.Forms.Padding(4);
            this.setAutoTradingRuleButton.Name = "setAutoTradingRuleButton";
            this.setAutoTradingRuleButton.Size = new System.Drawing.Size(412, 34);
            this.setAutoTradingRuleButton.TabIndex = 3;
            this.setAutoTradingRuleButton.Text = "조건식 거래규칙 설정";
            this.setAutoTradingRuleButton.UseVisualStyleBackColor = true;
            // 
            // orderFixButton
            // 
            this.orderFixButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.orderFixButton.Location = new System.Drawing.Point(4, 130);
            this.orderFixButton.Margin = new System.Windows.Forms.Padding(4);
            this.orderFixButton.Name = "orderFixButton";
            this.orderFixButton.Size = new System.Drawing.Size(202, 34);
            this.orderFixButton.TabIndex = 3;
            this.orderFixButton.Text = "정정";
            this.orderFixButton.UseVisualStyleBackColor = true;
            // 
            // balanceCheckButton
            // 
            this.balanceCheckButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.balanceCheckButton.Location = new System.Drawing.Point(214, 130);
            this.balanceCheckButton.Margin = new System.Windows.Forms.Padding(4);
            this.balanceCheckButton.Name = "balanceCheckButton";
            this.balanceCheckButton.Size = new System.Drawing.Size(202, 34);
            this.balanceCheckButton.TabIndex = 3;
            this.balanceCheckButton.Text = "잔고조회";
            this.balanceCheckButton.UseVisualStyleBackColor = true;
            // 
            // orderCancelButton
            // 
            this.orderCancelButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.orderCancelButton.Location = new System.Drawing.Point(4, 172);
            this.orderCancelButton.Margin = new System.Windows.Forms.Padding(4);
            this.orderCancelButton.Name = "orderCancelButton";
            this.orderCancelButton.Size = new System.Drawing.Size(202, 34);
            this.orderCancelButton.TabIndex = 3;
            this.orderCancelButton.Text = "주문취소";
            this.orderCancelButton.UseVisualStyleBackColor = true;
            // 
            // sellAllStockButton
            // 
            this.sellAllStockButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.sellAllStockButton.Location = new System.Drawing.Point(214, 172);
            this.sellAllStockButton.Margin = new System.Windows.Forms.Padding(4);
            this.sellAllStockButton.Name = "sellAllStockButton";
            this.sellAllStockButton.Size = new System.Drawing.Size(202, 34);
            this.sellAllStockButton.TabIndex = 3;
            this.sellAllStockButton.Text = "전체 청산";
            this.sellAllStockButton.UseVisualStyleBackColor = true;
            // 
            // tableLayoutPanel2
            // 
            this.tableLayoutPanel2.AutoSize = true;
            this.tableLayoutPanel2.ColumnCount = 3;
            this.tableLayoutPanel2.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel2.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel2.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 3F));
            this.tableLayoutPanel2.Controls.Add(this.label1, 0, 0);
            this.tableLayoutPanel2.Controls.Add(this.label3, 0, 2);
            this.tableLayoutPanel2.Controls.Add(this.label2, 0, 1);
            this.tableLayoutPanel2.Controls.Add(this.conditionComboBox, 1, 0);
            this.tableLayoutPanel2.Controls.Add(this.limitPriceNumericUpDown, 1, 1);
            this.tableLayoutPanel2.Controls.Add(this.limitNumberNumericUpDown, 1, 2);
            this.tableLayoutPanel2.Controls.Add(this.startAutoTradingButton, 0, 6);
            this.tableLayoutPanel2.Controls.Add(this.stopAutoTradingButton, 1, 6);
            this.tableLayoutPanel2.Controls.Add(this.label18, 0, 5);
            this.tableLayoutPanel2.Controls.Add(this.autoSellOrderComboBox, 1, 5);
            this.tableLayoutPanel2.Controls.Add(this.label4, 0, 4);
            this.tableLayoutPanel2.Controls.Add(this.autoBuyOrderComboBox, 1, 4);
            this.tableLayoutPanel2.Controls.Add(this.label19, 0, 3);
            this.tableLayoutPanel2.Controls.Add(this.limitBuyingPerStockLabel, 1, 3);
            this.tableLayoutPanel2.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel2.Location = new System.Drawing.Point(4, 4);
            this.tableLayoutPanel2.Margin = new System.Windows.Forms.Padding(4);
            this.tableLayoutPanel2.Name = "tableLayoutPanel2";
            this.tableLayoutPanel2.RowCount = 8;
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28816F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 0F));
            this.tableLayoutPanel2.Size = new System.Drawing.Size(423, 214);
            this.tableLayoutPanel2.TabIndex = 0;
            // 
            // label1
            // 
            this.label1.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(53, 6);
            this.label1.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(104, 18);
            this.label1.TabIndex = 0;
            this.label1.Text = "조건식 선택";
            this.label1.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label3
            // 
            this.label3.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(32, 66);
            this.label3.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(146, 18);
            this.label3.TabIndex = 0;
            this.label3.Text = "매입제한 종목 수";
            this.label3.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label2
            // 
            this.label2.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(44, 36);
            this.label2.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(122, 18);
            this.label2.TabIndex = 0;
            this.label2.Text = "매입제한 금액";
            this.label2.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // conditionComboBox
            // 
            this.conditionComboBox.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.conditionComboBox.FormattingEnabled = true;
            this.conditionComboBox.Location = new System.Drawing.Point(214, 4);
            this.conditionComboBox.Margin = new System.Windows.Forms.Padding(4);
            this.conditionComboBox.Name = "conditionComboBox";
            this.conditionComboBox.Size = new System.Drawing.Size(165, 26);
            this.conditionComboBox.TabIndex = 1;
            // 
            // limitPriceNumericUpDown
            // 
            this.limitPriceNumericUpDown.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.limitPriceNumericUpDown.Location = new System.Drawing.Point(214, 34);
            this.limitPriceNumericUpDown.Margin = new System.Windows.Forms.Padding(4);
            this.limitPriceNumericUpDown.Name = "limitPriceNumericUpDown";
            this.limitPriceNumericUpDown.Size = new System.Drawing.Size(202, 28);
            this.limitPriceNumericUpDown.TabIndex = 2;
            // 
            // limitNumberNumericUpDown
            // 
            this.limitNumberNumericUpDown.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.limitNumberNumericUpDown.Location = new System.Drawing.Point(214, 64);
            this.limitNumberNumericUpDown.Margin = new System.Windows.Forms.Padding(4);
            this.limitNumberNumericUpDown.Name = "limitNumberNumericUpDown";
            this.limitNumberNumericUpDown.Size = new System.Drawing.Size(202, 28);
            this.limitNumberNumericUpDown.TabIndex = 2;
            // 
            // startAutoTradingButton
            // 
            this.startAutoTradingButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.startAutoTradingButton.Location = new System.Drawing.Point(4, 184);
            this.startAutoTradingButton.Margin = new System.Windows.Forms.Padding(4);
            this.startAutoTradingButton.Name = "startAutoTradingButton";
            this.startAutoTradingButton.Size = new System.Drawing.Size(202, 22);
            this.startAutoTradingButton.TabIndex = 3;
            this.startAutoTradingButton.Text = "자동매매 시작";
            this.startAutoTradingButton.UseVisualStyleBackColor = true;
            // 
            // stopAutoTradingButton
            // 
            this.stopAutoTradingButton.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.stopAutoTradingButton.Location = new System.Drawing.Point(214, 184);
            this.stopAutoTradingButton.Margin = new System.Windows.Forms.Padding(4);
            this.stopAutoTradingButton.Name = "stopAutoTradingButton";
            this.stopAutoTradingButton.Size = new System.Drawing.Size(202, 22);
            this.stopAutoTradingButton.TabIndex = 3;
            this.stopAutoTradingButton.Text = "자동매매 중지";
            this.stopAutoTradingButton.UseVisualStyleBackColor = true;
            // 
            // label18
            // 
            this.label18.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label18.AutoSize = true;
            this.label18.Location = new System.Drawing.Point(47, 156);
            this.label18.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label18.Name = "label18";
            this.label18.Size = new System.Drawing.Size(116, 18);
            this.label18.TabIndex = 0;
            this.label18.Text = "매도거래구분";
            this.label18.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // autoSellOrderComboBox
            // 
            this.autoSellOrderComboBox.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.autoSellOrderComboBox.FormattingEnabled = true;
            this.autoSellOrderComboBox.Location = new System.Drawing.Point(214, 154);
            this.autoSellOrderComboBox.Margin = new System.Windows.Forms.Padding(4);
            this.autoSellOrderComboBox.Name = "autoSellOrderComboBox";
            this.autoSellOrderComboBox.Size = new System.Drawing.Size(202, 26);
            this.autoSellOrderComboBox.TabIndex = 1;
            // 
            // label4
            // 
            this.label4.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(47, 126);
            this.label4.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(116, 18);
            this.label4.TabIndex = 0;
            this.label4.Text = "매수거래구분";
            this.label4.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // autoBuyOrderComboBox
            // 
            this.autoBuyOrderComboBox.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.autoBuyOrderComboBox.FormattingEnabled = true;
            this.autoBuyOrderComboBox.Location = new System.Drawing.Point(214, 124);
            this.autoBuyOrderComboBox.Margin = new System.Windows.Forms.Padding(4);
            this.autoBuyOrderComboBox.Name = "autoBuyOrderComboBox";
            this.autoBuyOrderComboBox.Size = new System.Drawing.Size(202, 26);
            this.autoBuyOrderComboBox.TabIndex = 1;
            // 
            // label19
            // 
            this.label19.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label19.AutoSize = true;
            this.label19.Location = new System.Drawing.Point(35, 96);
            this.label19.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label19.Name = "label19";
            this.label19.Size = new System.Drawing.Size(140, 18);
            this.label19.TabIndex = 0;
            this.label19.Text = "종목당 매수금액";
            this.label19.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // limitBuyingPerStockLabel
            // 
            this.limitBuyingPerStockLabel.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.limitBuyingPerStockLabel.AutoSize = true;
            this.limitBuyingPerStockLabel.Location = new System.Drawing.Point(306, 96);
            this.limitBuyingPerStockLabel.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.limitBuyingPerStockLabel.Name = "limitBuyingPerStockLabel";
            this.limitBuyingPerStockLabel.Size = new System.Drawing.Size(18, 18);
            this.limitBuyingPerStockLabel.TabIndex = 0;
            this.limitBuyingPerStockLabel.Text = "0";
            this.limitBuyingPerStockLabel.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // tableLayoutPanel5
            // 
            this.tableLayoutPanel5.AutoSize = true;
            this.tableLayoutPanel5.ColumnCount = 3;
            this.tableLayoutPanel5.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel5.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel5.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 3F));
            this.tableLayoutPanel5.Controls.Add(this.label12, 0, 0);
            this.tableLayoutPanel5.Controls.Add(this.accountComboBox, 1, 0);
            this.tableLayoutPanel5.Controls.Add(this.label17, 0, 6);
            this.tableLayoutPanel5.Controls.Add(this.label16, 0, 5);
            this.tableLayoutPanel5.Controls.Add(this.label15, 0, 4);
            this.tableLayoutPanel5.Controls.Add(this.label14, 0, 3);
            this.tableLayoutPanel5.Controls.Add(this.label13, 0, 2);
            this.tableLayoutPanel5.Controls.Add(this.todayProfitRateLabel, 1, 6);
            this.tableLayoutPanel5.Controls.Add(this.todayProfitLabel, 1, 5);
            this.tableLayoutPanel5.Controls.Add(this.totalEstimateLabel, 1, 4);
            this.tableLayoutPanel5.Controls.Add(this.passwordTextBox, 1, 1);
            this.tableLayoutPanel5.Controls.Add(this.label8, 0, 1);
            this.tableLayoutPanel5.Controls.Add(this.totalBuyLabel, 1, 3);
            this.tableLayoutPanel5.Controls.Add(this.depositLabel, 1, 2);
            this.tableLayoutPanel5.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel5.Location = new System.Drawing.Point(1297, 4);
            this.tableLayoutPanel5.Margin = new System.Windows.Forms.Padding(4);
            this.tableLayoutPanel5.Name = "tableLayoutPanel5";
            this.tableLayoutPanel5.RowCount = 8;
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28531F));
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 14.28816F));
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 0F));
            this.tableLayoutPanel5.Size = new System.Drawing.Size(425, 214);
            this.tableLayoutPanel5.TabIndex = 3;
            // 
            // label12
            // 
            this.label12.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label12.AutoSize = true;
            this.label12.Location = new System.Drawing.Point(65, 6);
            this.label12.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label12.Name = "label12";
            this.label12.Size = new System.Drawing.Size(80, 18);
            this.label12.TabIndex = 0;
            this.label12.Text = "계좌번호";
            this.label12.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // accountComboBox
            // 
            this.accountComboBox.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.accountComboBox.FormattingEnabled = true;
            this.accountComboBox.Location = new System.Drawing.Point(215, 4);
            this.accountComboBox.Margin = new System.Windows.Forms.Padding(4);
            this.accountComboBox.Name = "accountComboBox";
            this.accountComboBox.Size = new System.Drawing.Size(203, 26);
            this.accountComboBox.TabIndex = 2;
            // 
            // label17
            // 
            this.label17.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label17.AutoSize = true;
            this.label17.Location = new System.Drawing.Point(65, 186);
            this.label17.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label17.Name = "label17";
            this.label17.Size = new System.Drawing.Size(80, 18);
            this.label17.TabIndex = 0;
            this.label17.Text = "실현손익";
            this.label17.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label16
            // 
            this.label16.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label16.AutoSize = true;
            this.label16.Location = new System.Drawing.Point(47, 156);
            this.label16.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label16.Name = "label16";
            this.label16.Size = new System.Drawing.Size(116, 18);
            this.label16.TabIndex = 0;
            this.label16.Text = "당일손익금액";
            this.label16.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label15
            // 
            this.label15.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label15.AutoSize = true;
            this.label15.Location = new System.Drawing.Point(56, 126);
            this.label15.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label15.Name = "label15";
            this.label15.Size = new System.Drawing.Size(98, 18);
            this.label15.TabIndex = 0;
            this.label15.Text = "총평가금액";
            this.label15.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label14
            // 
            this.label14.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label14.AutoSize = true;
            this.label14.Location = new System.Drawing.Point(56, 96);
            this.label14.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label14.Name = "label14";
            this.label14.Size = new System.Drawing.Size(98, 18);
            this.label14.TabIndex = 0;
            this.label14.Text = "총매입금액";
            this.label14.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // label13
            // 
            this.label13.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label13.AutoSize = true;
            this.label13.Location = new System.Drawing.Point(74, 66);
            this.label13.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label13.Name = "label13";
            this.label13.Size = new System.Drawing.Size(62, 18);
            this.label13.TabIndex = 0;
            this.label13.Text = "예수금";
            this.label13.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // todayProfitRateLabel
            // 
            this.todayProfitRateLabel.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.todayProfitRateLabel.AutoSize = true;
            this.todayProfitRateLabel.Location = new System.Drawing.Point(307, 186);
            this.todayProfitRateLabel.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.todayProfitRateLabel.Name = "todayProfitRateLabel";
            this.todayProfitRateLabel.Size = new System.Drawing.Size(18, 18);
            this.todayProfitRateLabel.TabIndex = 0;
            this.todayProfitRateLabel.Text = "0";
            this.todayProfitRateLabel.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // todayProfitLabel
            // 
            this.todayProfitLabel.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.todayProfitLabel.AutoSize = true;
            this.todayProfitLabel.Location = new System.Drawing.Point(307, 156);
            this.todayProfitLabel.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.todayProfitLabel.Name = "todayProfitLabel";
            this.todayProfitLabel.Size = new System.Drawing.Size(18, 18);
            this.todayProfitLabel.TabIndex = 0;
            this.todayProfitLabel.Text = "0";
            this.todayProfitLabel.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // totalEstimateLabel
            // 
            this.totalEstimateLabel.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.totalEstimateLabel.AutoSize = true;
            this.totalEstimateLabel.Location = new System.Drawing.Point(307, 126);
            this.totalEstimateLabel.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.totalEstimateLabel.Name = "totalEstimateLabel";
            this.totalEstimateLabel.Size = new System.Drawing.Size(18, 18);
            this.totalEstimateLabel.TabIndex = 0;
            this.totalEstimateLabel.Text = "0";
            this.totalEstimateLabel.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // passwordTextBox
            // 
            this.passwordTextBox.Anchor = ((System.Windows.Forms.AnchorStyles)((System.Windows.Forms.AnchorStyles.Left | System.Windows.Forms.AnchorStyles.Right)));
            this.passwordTextBox.Location = new System.Drawing.Point(215, 34);
            this.passwordTextBox.Margin = new System.Windows.Forms.Padding(4);
            this.passwordTextBox.Name = "passwordTextBox";
            this.passwordTextBox.Size = new System.Drawing.Size(203, 28);
            this.passwordTextBox.TabIndex = 4;
            // 
            // label8
            // 
            this.label8.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label8.AutoSize = true;
            this.label8.Location = new System.Drawing.Point(65, 36);
            this.label8.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label8.Name = "label8";
            this.label8.Size = new System.Drawing.Size(80, 18);
            this.label8.TabIndex = 0;
            this.label8.Text = "비밀번호";
            this.label8.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // totalBuyLabel
            // 
            this.totalBuyLabel.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.totalBuyLabel.AutoSize = true;
            this.totalBuyLabel.Location = new System.Drawing.Point(307, 96);
            this.totalBuyLabel.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.totalBuyLabel.Name = "totalBuyLabel";
            this.totalBuyLabel.Size = new System.Drawing.Size(18, 18);
            this.totalBuyLabel.TabIndex = 0;
            this.totalBuyLabel.Text = "0";
            this.totalBuyLabel.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // depositLabel
            // 
            this.depositLabel.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.depositLabel.AutoSize = true;
            this.depositLabel.Location = new System.Drawing.Point(307, 66);
            this.depositLabel.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.depositLabel.Name = "depositLabel";
            this.depositLabel.Size = new System.Drawing.Size(18, 18);
            this.depositLabel.TabIndex = 0;
            this.depositLabel.Text = "0";
            this.depositLabel.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            // 
            // tableLayoutPanel7
            // 
            this.tableLayoutPanel7.ColumnCount = 1;
            this.tableLayoutPanel7.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel7.Controls.Add(this.autoRuleDataGridView, 0, 1);
            this.tableLayoutPanel7.Controls.Add(this.tableLayoutPanel6, 0, 2);
            this.tableLayoutPanel7.Controls.Add(this.tableLayoutPanel1, 0, 0);
            this.tableLayoutPanel7.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel7.Location = new System.Drawing.Point(0, 0);
            this.tableLayoutPanel7.Margin = new System.Windows.Forms.Padding(4);
            this.tableLayoutPanel7.Name = "tableLayoutPanel7";
            this.tableLayoutPanel7.RowCount = 4;
            this.tableLayoutPanel7.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 38.46153F));
            this.tableLayoutPanel7.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 23.07692F));
            this.tableLayoutPanel7.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 38.46154F));
            this.tableLayoutPanel7.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 0F));
            this.tableLayoutPanel7.Size = new System.Drawing.Size(1732, 593);
            this.tableLayoutPanel7.TabIndex = 3;
            // 
            // autoRuleDataGridView
            // 
            this.autoRuleDataGridView.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.autoRuleDataGridView.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.거래규칙_번호,
            this.거래규칙_R파일,
            this.거래규칙_조건식,
            this.거래규칙_매입제한_금액,
            this.거래규칙_매입제한_종목_개수,
            this.거래규칙_종목당_매수금액,
            this.거래규칙_매수_거래구분,
            this.거래규칙_매도_거래구분,
            this.거래규칙_이익률,
            this.거래규칙_손절률,
            this.거래규칙_업데이트시간,
            this.거래규칙_상태});
            this.autoRuleDataGridView.Dock = System.Windows.Forms.DockStyle.Fill;
            this.autoRuleDataGridView.Location = new System.Drawing.Point(4, 232);
            this.autoRuleDataGridView.Margin = new System.Windows.Forms.Padding(4);
            this.autoRuleDataGridView.Name = "autoRuleDataGridView";
            this.autoRuleDataGridView.RowHeadersVisible = false;
            this.autoRuleDataGridView.RowHeadersWidth = 62;
            this.autoRuleDataGridView.RowTemplate.Height = 23;
            this.autoRuleDataGridView.Size = new System.Drawing.Size(1724, 128);
            this.autoRuleDataGridView.TabIndex = 3;
            // 
            // 거래규칙_번호
            // 
            this.거래규칙_번호.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.거래규칙_번호.HeaderText = "";
            this.거래규칙_번호.MinimumWidth = 8;
            this.거래규칙_번호.Name = "거래규칙_번호";
            this.거래규칙_번호.Width = 29;
            // 
            // 거래규칙_R파일
            // 
            this.거래규칙_R파일.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.거래규칙_R파일.HeaderText = "분석R파일";
            this.거래규칙_R파일.MinimumWidth = 8;
            this.거래규칙_R파일.Name = "거래규칙_R파일";
            // 
            // 거래규칙_조건식
            // 
            this.거래규칙_조건식.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.거래규칙_조건식.HeaderText = "키움조건식";
            this.거래규칙_조건식.MinimumWidth = 8;
            this.거래규칙_조건식.Name = "거래규칙_조건식";
            // 
            // 거래규칙_매입제한_금액
            // 
            this.거래규칙_매입제한_금액.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.거래규칙_매입제한_금액.HeaderText = "매입제한금액";
            this.거래규칙_매입제한_금액.MinimumWidth = 8;
            this.거래규칙_매입제한_금액.Name = "거래규칙_매입제한_금액";
            // 
            // 거래규칙_매입제한_종목_개수
            // 
            this.거래규칙_매입제한_종목_개수.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.거래규칙_매입제한_종목_개수.HeaderText = "매입제한종목개수";
            this.거래규칙_매입제한_종목_개수.MinimumWidth = 8;
            this.거래규칙_매입제한_종목_개수.Name = "거래규칙_매입제한_종목_개수";
            // 
            // 거래규칙_종목당_매수금액
            // 
            this.거래규칙_종목당_매수금액.HeaderText = "종목당매수금액";
            this.거래규칙_종목당_매수금액.MinimumWidth = 8;
            this.거래규칙_종목당_매수금액.Name = "거래규칙_종목당_매수금액";
            this.거래규칙_종목당_매수금액.Width = 150;
            // 
            // 거래규칙_매수_거래구분
            // 
            this.거래규칙_매수_거래구분.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.거래규칙_매수_거래구분.HeaderText = "매수거래구분";
            this.거래규칙_매수_거래구분.MinimumWidth = 8;
            this.거래규칙_매수_거래구분.Name = "거래규칙_매수_거래구분";
            // 
            // 거래규칙_매도_거래구분
            // 
            this.거래규칙_매도_거래구분.HeaderText = "매도거래구분";
            this.거래규칙_매도_거래구분.MinimumWidth = 8;
            this.거래규칙_매도_거래구분.Name = "거래규칙_매도_거래구분";
            this.거래규칙_매도_거래구분.Width = 150;
            // 
            // 거래규칙_이익률
            // 
            this.거래규칙_이익률.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.거래규칙_이익률.HeaderText = "이익률";
            this.거래규칙_이익률.MinimumWidth = 8;
            this.거래규칙_이익률.Name = "거래규칙_이익률";
            // 
            // 거래규칙_손절률
            // 
            this.거래규칙_손절률.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
            this.거래규칙_손절률.HeaderText = "손절율";
            this.거래규칙_손절률.MinimumWidth = 8;
            this.거래규칙_손절률.Name = "거래규칙_손절률";
            // 
            // 거래규칙_업데이트시간
            // 
            this.거래규칙_업데이트시간.HeaderText = "업데이트시간";
            this.거래규칙_업데이트시간.MinimumWidth = 8;
            this.거래규칙_업데이트시간.Name = "거래규칙_업데이트시간";
            this.거래규칙_업데이트시간.Width = 150;
            // 
            // 거래규칙_상태
            // 
            this.거래규칙_상태.HeaderText = "상태";
            this.거래규칙_상태.Items.AddRange(new object[] {
            "시작",
            "중지"});
            this.거래규칙_상태.MinimumWidth = 8;
            this.거래규칙_상태.Name = "거래규칙_상태";
            this.거래규칙_상태.Resizable = System.Windows.Forms.DataGridViewTriState.True;
            this.거래규칙_상태.SortMode = System.Windows.Forms.DataGridViewColumnSortMode.Automatic;
            this.거래규칙_상태.Width = 150;
            // 
            // tableLayoutPanel6
            // 
            this.tableLayoutPanel6.ColumnCount = 2;
            this.tableLayoutPanel6.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel6.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel6.Controls.Add(this.tabControl2, 1, 0);
            this.tableLayoutPanel6.Controls.Add(this.tabControl1, 0, 0);
            this.tableLayoutPanel6.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel6.Location = new System.Drawing.Point(4, 368);
            this.tableLayoutPanel6.Margin = new System.Windows.Forms.Padding(4);
            this.tableLayoutPanel6.Name = "tableLayoutPanel6";
            this.tableLayoutPanel6.RowCount = 1;
            this.tableLayoutPanel6.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel6.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 202F));
            this.tableLayoutPanel6.Size = new System.Drawing.Size(1724, 220);
            this.tableLayoutPanel6.TabIndex = 2;
            // 
            // tabControl2
            // 
            this.tabControl2.Controls.Add(this.tabPage3);
            this.tabControl2.Controls.Add(this.tabPage4);
            this.tabControl2.Controls.Add(this.tabPage6);
            this.tabControl2.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tabControl2.Location = new System.Drawing.Point(866, 4);
            this.tabControl2.Margin = new System.Windows.Forms.Padding(4);
            this.tabControl2.Name = "tabControl2";
            this.tabControl2.SelectedIndex = 0;
            this.tabControl2.Size = new System.Drawing.Size(854, 212);
            this.tabControl2.TabIndex = 1;
            // 
            // tabPage3
            // 
            this.tabPage3.Controls.Add(this.insertListBox);
            this.tabPage3.Location = new System.Drawing.Point(4, 28);
            this.tabPage3.Margin = new System.Windows.Forms.Padding(4);
            this.tabPage3.Name = "tabPage3";
            this.tabPage3.Padding = new System.Windows.Forms.Padding(4);
            this.tabPage3.Size = new System.Drawing.Size(846, 180);
            this.tabPage3.TabIndex = 0;
            this.tabPage3.Text = "편입종목";
            this.tabPage3.UseVisualStyleBackColor = true;
            // 
            // insertListBox
            // 
            this.insertListBox.Dock = System.Windows.Forms.DockStyle.Fill;
            this.insertListBox.FormattingEnabled = true;
            this.insertListBox.ItemHeight = 18;
            this.insertListBox.Location = new System.Drawing.Point(4, 4);
            this.insertListBox.Name = "insertListBox";
            this.insertListBox.Size = new System.Drawing.Size(838, 172);
            this.insertListBox.TabIndex = 0;
            // 
            // tabPage4
            // 
            this.tabPage4.Controls.Add(this.deleteListBox);
            this.tabPage4.Location = new System.Drawing.Point(4, 28);
            this.tabPage4.Margin = new System.Windows.Forms.Padding(4);
            this.tabPage4.Name = "tabPage4";
            this.tabPage4.Padding = new System.Windows.Forms.Padding(4);
            this.tabPage4.Size = new System.Drawing.Size(846, 180);
            this.tabPage4.TabIndex = 1;
            this.tabPage4.Text = "이탈종목";
            this.tabPage4.UseVisualStyleBackColor = true;
            // 
            // deleteListBox
            // 
            this.deleteListBox.Dock = System.Windows.Forms.DockStyle.Fill;
            this.deleteListBox.FormattingEnabled = true;
            this.deleteListBox.ItemHeight = 18;
            this.deleteListBox.Location = new System.Drawing.Point(4, 4);
            this.deleteListBox.Name = "deleteListBox";
            this.deleteListBox.Size = new System.Drawing.Size(838, 172);
            this.deleteListBox.TabIndex = 0;
            // 
            // tabPage6
            // 
            this.tabPage6.Controls.Add(this.orderRecordListBox);
            this.tabPage6.Location = new System.Drawing.Point(4, 28);
            this.tabPage6.Margin = new System.Windows.Forms.Padding(4);
            this.tabPage6.Name = "tabPage6";
            this.tabPage6.Padding = new System.Windows.Forms.Padding(4);
            this.tabPage6.Size = new System.Drawing.Size(846, 180);
            this.tabPage6.TabIndex = 2;
            this.tabPage6.Text = "주문기록";
            this.tabPage6.UseVisualStyleBackColor = true;
            // 
            // orderRecordListBox
            // 
            this.orderRecordListBox.Dock = System.Windows.Forms.DockStyle.Fill;
            this.orderRecordListBox.FormattingEnabled = true;
            this.orderRecordListBox.ItemHeight = 18;
            this.orderRecordListBox.Location = new System.Drawing.Point(4, 4);
            this.orderRecordListBox.Margin = new System.Windows.Forms.Padding(4);
            this.orderRecordListBox.Name = "orderRecordListBox";
            this.orderRecordListBox.Size = new System.Drawing.Size(838, 172);
            this.orderRecordListBox.TabIndex = 0;
            // 
            // tabControl1
            // 
            this.tabControl1.Controls.Add(this.tabPage1);
            this.tabControl1.Controls.Add(this.tabPage2);
            this.tabControl1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tabControl1.Location = new System.Drawing.Point(4, 4);
            this.tabControl1.Margin = new System.Windows.Forms.Padding(4);
            this.tabControl1.Name = "tabControl1";
            this.tabControl1.SelectedIndex = 0;
            this.tabControl1.Size = new System.Drawing.Size(854, 212);
            this.tabControl1.TabIndex = 0;
            // 
            // tabPage1
            // 
            this.tabPage1.Controls.Add(this.balanceDataGridView);
            this.tabPage1.Location = new System.Drawing.Point(4, 28);
            this.tabPage1.Margin = new System.Windows.Forms.Padding(4);
            this.tabPage1.Name = "tabPage1";
            this.tabPage1.Padding = new System.Windows.Forms.Padding(4);
            this.tabPage1.Size = new System.Drawing.Size(846, 180);
            this.tabPage1.TabIndex = 0;
            this.tabPage1.Text = "잔고";
            this.tabPage1.UseVisualStyleBackColor = true;
            // 
            // balanceDataGridView
            // 
            this.balanceDataGridView.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.balanceDataGridView.Dock = System.Windows.Forms.DockStyle.Fill;
            this.balanceDataGridView.Location = new System.Drawing.Point(4, 4);
            this.balanceDataGridView.Margin = new System.Windows.Forms.Padding(4);
            this.balanceDataGridView.Name = "balanceDataGridView";
            this.balanceDataGridView.RowHeadersVisible = false;
            this.balanceDataGridView.RowHeadersWidth = 62;
            this.balanceDataGridView.RowTemplate.Height = 23;
            this.balanceDataGridView.SelectionMode = System.Windows.Forms.DataGridViewSelectionMode.FullRowSelect;
            this.balanceDataGridView.Size = new System.Drawing.Size(838, 172);
            this.balanceDataGridView.TabIndex = 0;
            // 
            // tabPage2
            // 
            this.tabPage2.Controls.Add(this.outstandingDataGridView);
            this.tabPage2.Location = new System.Drawing.Point(4, 28);
            this.tabPage2.Margin = new System.Windows.Forms.Padding(4);
            this.tabPage2.Name = "tabPage2";
            this.tabPage2.Padding = new System.Windows.Forms.Padding(4);
            this.tabPage2.Size = new System.Drawing.Size(846, 180);
            this.tabPage2.TabIndex = 1;
            this.tabPage2.Text = "미체결";
            this.tabPage2.UseVisualStyleBackColor = true;
            // 
            // outstandingDataGridView
            // 
            this.outstandingDataGridView.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.outstandingDataGridView.Dock = System.Windows.Forms.DockStyle.Fill;
            this.outstandingDataGridView.Location = new System.Drawing.Point(4, 4);
            this.outstandingDataGridView.Margin = new System.Windows.Forms.Padding(4);
            this.outstandingDataGridView.Name = "outstandingDataGridView";
            this.outstandingDataGridView.RowHeadersWidth = 62;
            this.outstandingDataGridView.RowTemplate.Height = 23;
            this.outstandingDataGridView.Size = new System.Drawing.Size(838, 172);
            this.outstandingDataGridView.TabIndex = 0;
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(10F, 18F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(1732, 593);
            this.Controls.Add(this.tableLayoutPanel7);
            this.Controls.Add(this.axKHOpenAPI1);
            this.Name = "Form1";
            this.Text = "Form1";
            ((System.ComponentModel.ISupportInitialize)(this.axKHOpenAPI1)).EndInit();
            this.tableLayoutPanel1.ResumeLayout(false);
            this.tableLayoutPanel1.PerformLayout();
            this.tableLayoutPanel4.ResumeLayout(false);
            this.tableLayoutPanel4.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.orderPriceNumericUpDown)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.orderNumberNumericUpDown)).EndInit();
            this.tableLayoutPanel3.ResumeLayout(false);
            this.tableLayoutPanel3.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown4)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.limitLossRateNumericUpDown)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.limitProfitRateNumericUpDown)).EndInit();
            this.tableLayoutPanel2.ResumeLayout(false);
            this.tableLayoutPanel2.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.limitPriceNumericUpDown)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.limitNumberNumericUpDown)).EndInit();
            this.tableLayoutPanel5.ResumeLayout(false);
            this.tableLayoutPanel5.PerformLayout();
            this.tableLayoutPanel7.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.autoRuleDataGridView)).EndInit();
            this.tableLayoutPanel6.ResumeLayout(false);
            this.tabControl2.ResumeLayout(false);
            this.tabPage3.ResumeLayout(false);
            this.tabPage4.ResumeLayout(false);
            this.tabPage6.ResumeLayout(false);
            this.tabControl1.ResumeLayout(false);
            this.tabPage1.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.balanceDataGridView)).EndInit();
            this.tabPage2.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.outstandingDataGridView)).EndInit();
            this.ResumeLayout(false);

        }

        #endregion

        private AxKHOpenAPILib.AxKHOpenAPI axKHOpenAPI1;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel1;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel5;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel4;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel3;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel2;
        private System.Windows.Forms.Label label7;
        private System.Windows.Forms.Label stockCodeLabel;
        private System.Windows.Forms.Label label9;
        private System.Windows.Forms.Label label10;
        private System.Windows.Forms.Label label11;
        private System.Windows.Forms.ComboBox orderComboBox;
        private System.Windows.Forms.NumericUpDown orderPriceNumericUpDown;
        private System.Windows.Forms.NumericUpDown orderNumberNumericUpDown;
        private System.Windows.Forms.Button buyButton;
        private System.Windows.Forms.Button sellButton;
        private System.Windows.Forms.Button stockSearchButton;
        private System.Windows.Forms.TextBox stockTextBox;
        private System.Windows.Forms.NumericUpDown numericUpDown4;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.Label label6;
        private System.Windows.Forms.NumericUpDown limitLossRateNumericUpDown;
        private System.Windows.Forms.NumericUpDown limitProfitRateNumericUpDown;
        private System.Windows.Forms.Button setAutoTradingRuleButton;
        private System.Windows.Forms.Button orderFixButton;
        private System.Windows.Forms.Button balanceCheckButton;
        private System.Windows.Forms.Button orderCancelButton;
        private System.Windows.Forms.Button sellAllStockButton;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.ComboBox conditionComboBox;
        private System.Windows.Forms.ComboBox autoBuyOrderComboBox;
        private System.Windows.Forms.NumericUpDown limitPriceNumericUpDown;
        private System.Windows.Forms.NumericUpDown limitNumberNumericUpDown;
        private System.Windows.Forms.Button startAutoTradingButton;
        private System.Windows.Forms.Button stopAutoTradingButton;
        private System.Windows.Forms.Label label12;
        private System.Windows.Forms.ComboBox accountComboBox;
        private System.Windows.Forms.Label label17;
        private System.Windows.Forms.Label label16;
        private System.Windows.Forms.Label label15;
        private System.Windows.Forms.Label label14;
        private System.Windows.Forms.Label label13;
        private System.Windows.Forms.Label todayProfitRateLabel;
        private System.Windows.Forms.Label todayProfitLabel;
        private System.Windows.Forms.Label totalEstimateLabel;
        private System.Windows.Forms.Label depositLabel;
        private System.Windows.Forms.TextBox passwordTextBox;
        private System.Windows.Forms.Label totalBuyLabel;
        private System.Windows.Forms.Label label8;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel7;
        private System.Windows.Forms.DataGridView autoRuleDataGridView;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel6;
        private System.Windows.Forms.TabControl tabControl2;
        private System.Windows.Forms.TabPage tabPage3;
        private System.Windows.Forms.TabPage tabPage4;
        private System.Windows.Forms.TabPage tabPage6;
        private System.Windows.Forms.ListBox orderRecordListBox;
        private System.Windows.Forms.TabControl tabControl1;
        private System.Windows.Forms.TabPage tabPage1;
        private System.Windows.Forms.DataGridView balanceDataGridView;
        private System.Windows.Forms.TabPage tabPage2;
        private System.Windows.Forms.DataGridView outstandingDataGridView;
        private System.Windows.Forms.Label label18;
        private System.Windows.Forms.ComboBox autoSellOrderComboBox;
        private System.Windows.Forms.Label label19;
        private System.Windows.Forms.Label limitBuyingPerStockLabel;
        private System.Windows.Forms.ListBox insertListBox;
        private System.Windows.Forms.ListBox deleteListBox;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_번호;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_R파일;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_조건식;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_매입제한_금액;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_매입제한_종목_개수;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_종목당_매수금액;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_매수_거래구분;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_매도_거래구분;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_이익률;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_손절률;
        private System.Windows.Forms.DataGridViewTextBoxColumn 거래규칙_업데이트시간;
        private System.Windows.Forms.DataGridViewComboBoxColumn 거래규칙_상태;
    }
}


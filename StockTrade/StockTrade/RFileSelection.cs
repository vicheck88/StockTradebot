using NpgsqlTypes;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace StockTrade
{
    public partial class RFileSelection : Form
    {
        public string selectedRscript;
        RscriptManager RManager;
        public RFileSelection(RscriptManager Rmanager)
        {
            InitializeComponent();
            RscriptList.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            RManager = Rmanager;
            RscriptList.DataSource = Rmanager.scriptList;
        }

        private void ScriptSelctButton_Click(object sender, EventArgs e)
        {
            foreach(DataGridViewRow row in RscriptList.SelectedRows)
            {
                selectedRscript = row.Cells[0].Value.ToString();
            }
            DialogResult = DialogResult.OK;
        }
        private void UpdateRscripButton_Click(object sender, EventArgs e)
        {
            if(RscriptList.SelectedRows.Count>0 && 
                RscriptList.SelectedRows[0].Cells[0].Value.ToString() == RscriptNameText.Text) updateCurrentScript();
            else insertNewScript();
        }
        public void updateCurrentScript()
        {
            string SQL = @"UPDATE metainfo.rscript SET filterdesc=@Filter, rankdesc=@Rank, script=@Script";
            Dictionary<string, object[]> param = new Dictionary<string, object[]>();
            param.Add("Filter", new object[] { NpgsqlDbType.Text, RscriptFilterText.Text });
            param.Add("Rank", new object[] { NpgsqlDbType.Text, RscriptRankText.Text });
            param.Add("Script", new object[] { NpgsqlDbType.Text, Rscript.Text });
            RManager.DB.writeToDB(SQL, param);
            RManager.syncScriptList();
            RscriptList.DataSource = null;
            RscriptList.DataSource = RManager.scriptList;
            //RscriptList.Refresh();
        }
        public void insertNewScript()
        {
            string SQL = @"INSERT INTO metainfo.rscript (name, filterdesc, rankdesc, script) values (@Name, @Filter, @Rank, @Script)";
            Dictionary<string, object[]> param = new Dictionary<string, object[]>();
            param.Add("Name", new object[] { NpgsqlDbType.Text, RscriptNameText.Text });
            param.Add("Filter", new object[] { NpgsqlDbType.Text, RscriptFilterText.Text });
            param.Add("Rank", new object[] { NpgsqlDbType.Text, RscriptRankText.Text });
            param.Add("Script", new object[] { NpgsqlDbType.Text, Rscript.Text });
            RManager.DB.writeToDB(SQL, param);
            RManager.syncScriptList();
            RscriptList.DataSource = null;
            RscriptList.DataSource = RManager.scriptList;
            RscriptList.Refresh();
        }
        private void cancelButton_Click(object sender, EventArgs e)
        {
            DialogResult = DialogResult.Cancel;
        }

        private void RscriptList_SelectionChanged(object sender, EventArgs e)
        {
            var grid = sender as DataGridView;
            foreach(DataGridViewRow row in grid.SelectedRows)
            {
                RscriptNameText.Text = row.Cells[0].Value.ToString();
                RscriptFilterText.Text = row.Cells[1].Value.ToString();
                RscriptRankText.Text = row.Cells[2].Value.ToString();
                Rscript.Text = row.Cells[3].Value.ToString();
            }
        }

        private void DeleteButton_Click(object sender, EventArgs e)
        {
            if (RscriptNameText.Text == null) return;
            RManager.DB.deleteScriptFromDB(RscriptNameText.Text);
            RManager.syncScriptList();
        }

        private void AddNewButton_Click(object sender, EventArgs e)
        {
            RManager.scriptList.Rows.Add(new object[] { });
            RscriptList.Refresh();
            RscriptList.Rows[RscriptList.Rows.Count - 1].Selected = true;
        }
    }
}

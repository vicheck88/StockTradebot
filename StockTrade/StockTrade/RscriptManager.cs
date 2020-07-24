using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace StockTrade
{
    public class RscriptManager
    {
        public DBManager DB;
        public DataTable scriptList;
        string currentPath;
        public RscriptManager(DBManager db)
        {
            DB = db;
            scriptList = readRScripList();
            currentPath = Path.Combine(System.AppDomain.CurrentDomain.BaseDirectory, "Rscript");
            syncScriptList();
        }
        public DataTable readRScripList()
        {
            string SQL = @"SELECT * FROM metainfo.rscript";
            return DB.readFromDB(SQL);
        }
        public void syncScriptList()
        {
            scriptList = readRScripList();
            if (scriptList == null) return;
            DirectoryInfo di = new DirectoryInfo(currentPath);
            if (!di.Exists) di.Create();
            foreach (var d in di.GetDirectories()) d.Delete(true);
            foreach (var f in di.GetFiles()) f.Delete();
            foreach(DataRow s in scriptList.Rows)
            {
                string fileName = s[0].ToString();
                string script = s[3].ToString();
                string fullFilePath= Path.Combine(System.AppDomain.CurrentDomain.BaseDirectory, "Rscript", fileName+".R");
                File.WriteAllText(fullFilePath, script, Encoding.GetEncoding("euc-kr"));
            }
            
        }
    }
}

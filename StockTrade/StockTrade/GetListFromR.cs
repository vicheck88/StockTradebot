using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using RDotNet;
using System.Linq;
using DynamicInterop;
using System.Data;
using System.IO;

namespace StockTrade
{
    public class GetListFromR
    {
        string ftnListPath;
        string currentPath;
        public GetListFromR()
        {
            REngine.SetEnvironmentVariables();
            currentPath = System.AppDomain.CurrentDomain.BaseDirectory + @"\Rscript";
            ftnListPath = "RQuantFunctionList.R";
        }
        public DataTable getCorpTable(string Rname)
        {
            using(REngine engine = REngine.GetInstance())
            {
                string fullRFilePath = currentPath + @"\" + Rname;
                if (!File.Exists(fullRFilePath)) return null;
                var curPath = engine.CreateCharacter(currentPath);
                engine.SetSymbol("curPath", curPath);
                engine.Evaluate("setwd(curPath)");
                engine.Evaluate(String.Format("source({0})", ftnListPath));
                engine.Evaluate(String.Format("source({0})", Rname));
                DataFrame output = engine.GetSymbol("output").AsDataFrame();
                DataTable table = new DataTable();
                foreach (var name in output.ColumnNames) table.Columns.Add(name);
                foreach (var row in output.GetRows())
                {
                    DataRow newRow = table.Rows.Add();
                    foreach (var name in output.ColumnNames) newRow[name] = row[name];
                }
                return table;
            }
        }
    }
}

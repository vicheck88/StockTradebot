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
        string currentPath;
        public GetListFromR()
        {
            REngine.SetEnvironmentVariables();
            currentPath = Path.Combine(System.AppDomain.CurrentDomain.BaseDirectory, "Rscript");
        }
        public DataTable getCorpTable(string Rname, int stocknum)
        {
            using(REngine engine = REngine.GetInstance())
            {
                string fullRFilePath = Path.Combine(currentPath, Rname + ".R");
                if (!File.Exists(fullRFilePath)) return null;
                var curPath = engine.CreateCharacter(currentPath);
                engine.SetSymbol("stocknum", engine.CreateInteger(stocknum));
                engine.SetSymbol("curPath", curPath);
                engine.Evaluate("setwd(curPath)");
                engine.Evaluate(String.Format("source(\"{0}\")", Rname + ".R"));
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

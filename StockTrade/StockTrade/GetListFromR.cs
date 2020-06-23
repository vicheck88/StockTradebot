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
using RDotNet.Internals;

namespace StockTrade
{
    public class GetListFromR
    {
        string currentPath;
        REngine engine;
        public GetListFromR()
        {
            REngine.SetEnvironmentVariables();
            currentPath = Path.Combine(System.AppDomain.CurrentDomain.BaseDirectory, "Rscript");
            engine = REngine.GetInstance();
        }
        public DataTable getCorpTable(string Rname, int stocknum)
        {
            engine.Initialize();
            string fullRFilePath = Path.Combine(currentPath, Rname + ".R");
            if (!File.Exists(fullRFilePath)) return null;
            var curPath = engine.CreateCharacter(currentPath);
            engine.SetSymbol("stocknum", engine.CreateInteger(stocknum));
            engine.SetSymbol("curPath", curPath);
            engine.Evaluate("setwd(curPath)");
            engine.Evaluate(String.Format("source(\"{0}\")", Rname + ".R"));
            DataFrame output = engine.GetSymbol("output").AsDataFrame();
            DataTable table = new DataTable();
            foreach (var name in output.ColumnNames)
            {
                Type t;
                switch (output[name].Type)
                {
                    case SymbolicExpressionType.NumericVector:
                        t = typeof(double);break;
                    case SymbolicExpressionType.IntegerVector:
                        t = typeof(Int32);break;
                    case SymbolicExpressionType.CharacterVector:
                        t = typeof(string);break;
                    case SymbolicExpressionType.LogicalVector:
                        t = typeof(bool);break;
                    case SymbolicExpressionType.RawVector:
                        t = typeof(byte);break;
                    default: t = null;break;
                }
                table.Columns.Add(name);
                if (t != null) table.Columns[name].DataType = t;
            }
                
            foreach (var row in output.GetRows())
            {
                DataRow newRow = table.Rows.Add();
                foreach (var name in output.ColumnNames) newRow[name] = row[name];
            }
            return table;
        }
    }
}

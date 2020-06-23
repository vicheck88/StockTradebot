using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Npgsql;
using NpgsqlTypes;

namespace StockTrade
{
    public class DBManager
    {
        Configuration config;
        public string orderer;
        public DBManager()
        {
            config = new Configuration();
        }
        public DataTable readFromDB(string sql)
        {
            using(var con = config.connect())
            {
                con.Open();
                NpgsqlCommand comm = new NpgsqlCommand(sql, con);
                NpgsqlDataReader reader = comm.ExecuteReader();
                DataTable table = new DataTable();
                table.Load(reader);
                return table;
            }
        }
        public void writeToDB(string sql, Dictionary<string,object[]> param)
        {
            using (var con = config.connect())
            {
                try
                {
                    con.Open();
                    NpgsqlCommand comm = new NpgsqlCommand(sql, con);
                    foreach(var d in param)
                    {
                        NpgsqlDbType t = (NpgsqlDbType)d.Value[0];
                        if (t.Equals(NpgsqlDbType.Integer))
                            comm.Parameters.AddWithValue(d.Key, t, int.Parse(d.Value[1].ToString()));
                        else if (t.Equals(NpgsqlDbType.Text))
                            comm.Parameters.AddWithValue(d.Key, t, d.Value[1].ToString());
                        else if (t.Equals(NpgsqlDbType.Double))
                            comm.Parameters.AddWithValue(d.Key, t, double.Parse(d.Value[1].ToString()));
                    }
                    comm.ExecuteNonQuery();
                }
                catch(Exception e)
                {
                    Debug.WriteLine(e.Message);
                }
            }
        }
        public void deleteScriptFromDB(string scriptName)
        {
            using(var con = config.connect())
            {
                try
                {
                    con.Open();
                    var SQL = "DELETE FROM metainfo.rscript WHERE name=@NAME";
                    NpgsqlCommand comm = new NpgsqlCommand(SQL, con);
                    comm.Parameters.AddWithValue("NAME", NpgsqlDbType.Text, scriptName);
                    comm.ExecuteNonQuery();
                }
                catch(Exception e)
                {
                    Debug.WriteLine(e.Message);
                }
            }
        }
        public void deleteBalanceInfo(string name, string date)
        {
            using (var con = config.connect())
            {
                try
                {
                    con.Open();
                    var SQL = "DELETE FROM real.잔고 WHERE 날짜=@date AND 주문자=@name";
                    NpgsqlCommand comm = new NpgsqlCommand(SQL, con);
                    comm.Parameters.AddWithValue("date", NpgsqlDbType.Text, date);
                    comm.Parameters.AddWithValue("name", NpgsqlDbType.Text, name);
                    comm.ExecuteNonQuery();
                }
                catch (Exception e)
                {
                    Debug.WriteLine(e.Message);
                }
            }
        }
        public void writeToDB(NpgsqlCommand comm)
        {
            using (var con = config.conn)
            {
                try
                {
                    con.Open();
                    comm.ExecuteNonQuery();
                }
                catch(Exception e)
                {
                    Debug.WriteLine(e.Message);
                }
            }
        }
    }
}


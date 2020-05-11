using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Npgsql;

namespace StockTrade
{
    public class DBManager
    {
        Configuration config;
        public DBManager()
        {
            config = new Configuration();
        }
        public DataTable readFromDB(string sql)
        {
            using(var con = config.conn)
            {
                con.Open();
                NpgsqlCommand comm = new NpgsqlCommand(sql, con);
                NpgsqlDataReader reader = comm.ExecuteReader();
                DataTable table = new DataTable();
                table.Load(reader);
                return table;
            }
        }
        public void writeToDB(string sql)
        {
            using (var con = config.conn)
            {
                con.Open();
                NpgsqlCommand comm = new NpgsqlCommand(sql, con);
                comm.ExecuteNonQuery();
            }
        }
    }
}

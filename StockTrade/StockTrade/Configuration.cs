using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Npgsql;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.IO;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace StockTrade
{
    public class Configuration
    {
        public NpgsqlConnection conn;
        string path;
        JObject config;
        public Configuration()
        {
            path = System.IO.Directory.GetCurrentDirectory();
            path += @"\config.json";
            config = JObject.Parse(File.ReadAllText(path));
        }
        public NpgsqlConnection connect()
        {
            var DB = config["database"];
            string host = DB["host"].ToObject<string>();
            string port = DB["port"].ToObject<string>();
            string user = DB["user"].ToObject<string>();
            string passwd = DB["passwd"].ToObject<string>();
            string database = DB["database"].ToObject<string>();
            return new NpgsqlConnection(
                String.Format("Host={0};Port={1};Username={2};Password={3};Database={4}",
                host, port, user, passwd, database));
        }
    }
}

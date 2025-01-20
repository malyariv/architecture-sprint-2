#!/bin/bash

# Подключаемся к серверу конфигурации и проводим инициализацию
docker compose exec -T configSrv mongosh --port 27013 <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27013" }
    ]
  }
);
exit();
EOF

sleep 1

# Инициализируем шард №1 с набором реплик
docker compose exec -T shard_1-1 mongosh --port 27014 <<EOF
rs.initiate(
    {
      _id : "shard1ReplSet",
      members: [
        { _id : 0, host : "shard_1-1:27014" },
        { _id : 1, host : "shard_1-2:27015" },
        { _id : 2, host : "shard_1-3:27016" }
      ]
    }
);
exit();
EOF

sleep 1

# Инициализируем шард №2 с набором реплик
docker compose exec -T shard_2-1 mongosh --port 27017 <<EOF
rs.initiate(
    {
      _id : "shard2ReplSet",
      members: [
        { _id : 3, host : "shard_2-1:27017" },
        { _id : 4, host : "shard_2-2:27018" },
        { _id : 5, host : "shard_2-3:27019" }
      ]
    }
);
exit();
EOF

sleep 1

# Инициализируем роутер и наполняем его тестовыми данными
docker compose exec -T mongos_router mongosh --port 27020 <<EOF
sh.addShard( "shard1ReplSet/shard_1-1:27014,shard_1-2:27015,shard_1-3:27016");
sh.addShard( "shard2ReplSet/shard_2-1:27017,shard_2-2:27018,shard_2-3:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
db.helloDoc.countDocuments();
exit();
EOF
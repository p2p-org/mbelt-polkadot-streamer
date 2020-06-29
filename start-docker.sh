#!/bin/bash
docker-compose up -d zookeeper broker

docker-compose exec broker kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic event
docker-compose exec broker kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic block_events

docker-compose up -d schema-registry connect control-center ksqldb-server ksqldb-cli ksql-datagen rest-proxy

echo "Starting ksql containers..."
sleep 3m # we should wait a little bit

# create streams
curl -X "POST" "http://localhost:8088/ksql" \
     -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
     -d $'{
  "ksql": " CREATE STREAM EVENT (block MAP<VARCHAR, VARCHAR>, extrinsics ARRAY<VARCHAR>) WITH (kafka_topic=\'event\', value_format=\'JSON\'); CREATE STREAM EXTRINSICS WITH (KAFKA_TOPIC=\'EXTRINSICS\', PARTITIONS=1, REPLICAS=1) AS SELECT EXTRACTJSONFIELD(EVENT.BLOCK[\'header\'], \'$.number\') BLOCK_ID, EXPLODE(EVENT.EXTRINSICS) EXTRINSIC FROM EVENT EVENT EMIT CHANGES; CREATE STREAM EXTRINSICS_PARSED WITH (KAFKA_TOPIC=\'EXTRINSICS_PARSED\', PARTITIONS=1, REPLICAS=1) AS SELECT EXTRINSICS.BLOCK_ID BLOCK_ID, EXTRACTJSONFIELD(EXTRINSICS.EXTRINSIC, \'$.signature\') SIGNATURE, EXTRACTJSONFIELD(EXTRINSICS.EXTRINSIC, \'$.signature.nonce\') NONCE, EXTRACTJSONFIELD(EXTRINSICS.EXTRINSIC, \'$.signature.tip\') TIP, EXTRACTJSONFIELD(EXTRINSICS.EXTRINSIC, \'$.method\') METHOD_JSON, EXTRACTJSONFIELD(EXTRINSICS.EXTRINSIC, \'$.method.args\') ARGS_JSON FROM EXTRINSICS EXTRINSICS EMIT CHANGES;",
  "streamsProperties": {}
}' > /dev/null

docker-compose up -d streamer enrichment
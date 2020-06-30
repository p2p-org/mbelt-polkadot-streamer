from substrateinterface import SubstrateInterface
import json
import requests
from kafka import KafkaProducer


producer = KafkaProducer(bootstrap_servers=['broker:9092'],
                         value_serializer=lambda x: x.encode('utf-8'),
                         compression_type='gzip')
topic = "block_events"

substrate = SubstrateInterface(
    url="ws://49.12.97.44:9944",
    address_type=2,
    type_registry_preset='kusama'
)

metadata_decoder = None

def get_block_events(block_hash):
    global metadata_decoder

    try:
        events = substrate.get_block_events(block_hash, metadata_decoder=metadata_decoder)
    except:
        print("get metadata_decoder")
        metadata_decoder = substrate.get_block_metadata(block_hash=block_hash, decode=True)
        events = substrate.get_block_events(block_hash, metadata_decoder=metadata_decoder)
    return json.dumps(events.serialize())

ksqlRESTURL = "http://ksqldb-server:8088/query"
data =  {
  "ksql": "select extractjsonfield(block, '$.header.hash') from EVENT EMIT CHANGES;",
  "streamsProperties": {
    "ksql.streams.auto.offset.reset": "latest"
  }
}


r = requests.post(ksqlRESTURL, stream=True, verify=False, json=data)
for line in r.iter_lines(chunk_size=100):
    try:
        dict_line = json.loads(line.decode('utf-8').strip(','))
    except:
        continue
    if "row" not in dict_line.keys():
        continue
    hash = dict_line["row"]["columns"][0]
    kafka_msg = {
        "block_hash": hash,
        "block_events": get_block_events(hash)
    }

    future = producer.send(topic=topic, value=json.dumps(kafka_msg))
    record_metadata = future.get(timeout=10)
    print('--> Events of block with hash {} has been sent to a topic: \
                        {}, partition: {}, offset: {}' \
          .format(hash, record_metadata.topic,
                  record_metadata.partition,
                  record_metadata.offset))

producer.flush()
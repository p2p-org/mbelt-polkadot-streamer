// Import
const { ApiPromise, WsProvider } = require('@polkadot/api');
const { Kafka } = require('kafkajs');
const config = require('./config.json');


const kafka = new Kafka({
    clientId: 'polkadot-streamer',
    brokers: [config.kafka_uri]
  })
  


async function main () {
    // Construct
    const wsProvider = new WsProvider(config.substrate_uri);
    const api = await ApiPromise.create({ provider: wsProvider });
    const producer = kafka.producer()
    await producer.connect()

    async function process_block(height) {
        const blockHash = await api.rpc.chain.getBlockHash(height);
        const signedBlock = await api.rpc.chain.getBlock(blockHash);
        extrinsics = []
        signedBlock.block.extrinsics.forEach((ex, index) => {
            extrinsics.push(ex.toString());
        });
        block_data = {
            'block' : {
                'header' : {
                    'number' : signedBlock.block.header.number.toNumber(),
                    'hash' : signedBlock.block.header.hash.toHex(),
                    'stateRoot' : signedBlock.block.header.stateRoot.toHex(),
                    'extrinsicsRoot' : signedBlock.block.header.extrinsicsRoot.toHex(),
                    'parentHash' : signedBlock.block.header.parentHash.toHex(),
                    'digest' : signedBlock.block.header.digest.toString()
                }
            },
            'extrinsics' : [...extrinsics]
        }
        if(height%500 === 0) {
            console.log(height);
        }
        await producer.send({
            topic: 'event',
            messages: [
            {  'value': JSON.stringify(block_data) 
            },
            ],
        })
    }
    while(true) {
        for (var i =1; i<400000; ++i) {
            await process_block(i);
        }
    }   


}

main()
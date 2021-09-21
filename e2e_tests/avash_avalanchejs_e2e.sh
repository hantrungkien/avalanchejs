#!/bin/bash

is_bootstrapped () {
    [ $# != 2 ] && echo is_bootstrapped requires two arguments: node_ip node_port && exit 1
    node_ip=$1
    node_port=$2
    curl -s -X POST --data '{"jsonrpc":"2.0", "id":1, "method":"info.isBootstrapped", "params":{"chain":"X"}}' -H 'content-type:application/json;' $node_ip:$node_port/ext/info | grep true > /dev/null
}

avalanchego_ip=127.0.0.1
avalanchego_port=9650

network_ports=$(seq 9650 2 9658)

max_bootstrapping_time=90

[ $# != 2 ] && echo usage: $0 avash_dir avalanchejs_dir && exit 1

avash_location=$1
avalanchejs_location=$2

export AVALANCHEGO_IP=$avalanchego_ip
export AVALANCHEGO_PORT=$avalanchego_port

# make absolute paths
avash_location=$(cd $avash_location; pwd)
avalanchejs_location=$(cd $avalanchejs_location; pwd)

# create avash ipc fifo
fifo_fname=$avash_location/avash.fifo
rm -f $fifo_fname
mkfifo $fifo_fname
sleep 6000 > $fifo_fname &

# start avash network
cd $avash_location
./avash < $fifo_fname &
echo runscript scripts/five_node_staking.lua >> $fifo_fname 

# wait network bootstrapping
start_time=$(date -u +%s)
elapsed=0
sleep 2
for port in $network_ports
do
    echo waiting bootstrapping for node $AVALANCHEGO_IP:$port
    is_bootstrapped $AVALANCHEGO_IP $port
    while [ $? != 0 ] && [ $elapsed -lt $max_bootstrapping_time ]
    do
        sleep 5
        end_time=$(date -u +%s)
        elapsed=$(($end_time-$start_time))
        is_bootstrapped $AVALANCHEGO_IP $port
    done
done
echo elapsed: $elapsed seconds
if [ $elapsed -gt $max_bootstrapping_time ]
then
    echo WARN: elapsed time is greater than max_bootstrapping_time $max_bootstrapping_time
fi

# execute tests
cd $avalanchejs_location
yarn test -i --roots e2e_tests

# end avash network
cd $avash_location
echo exit >> $fifo_fname 

# cleanup
rm -f $fifo_fname


#!/bin/bash

telnet_status()
{
    echo "b" | telnet -e "b" $1 $2 > /dev/null 2>&1
    if [ $? == 0 ]
    then
        return 0
    else
        return 1
    fi
}

wait_pods_update()
{
    if [ "$ETCDCTL_PEERS" ]; then
        peers=`echo $ETCDCTL_PEERS | sed -e "s/,/ /g"`

        for i in $peers
        do
            read host port <<< $(echo $i | awk 'BEGIN {FS=":"; OFS =" "} {print $1,$2}')
            telnet_status $host $port
            if [ $? == 0 ]
            then
                curl -L http://$host:$port/v2/keys/registry/pods/$KUBE_NAMESPACE?wait=true\&recursive=true
                if [ $? == 0 ]; then
                    break
                fi
            fi
        done
    fi
}

if [ "$WORKER" ]; then
    /usr/local/bin/redis-server /redis.conf
fi

while true;
do
    #sleep 10

    /auto_config_redis_cluster.py

    wait_pods_update

    sleep 10
done

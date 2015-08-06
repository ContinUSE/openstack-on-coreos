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
    /usr/sbin/sshd -D
fi

/usr/sbin/sshd -D &

MACHINE_FILE=/root/host_file
FIRST_HOSTS=/root/first_hosts

touch $MACHINE_FILE
touch $MACHINE_FILE.old

while true;
do
    /pod_ip.py $KUBE_NAMESPACE > $MACHINE_FILE
    /known_hosts.py $MACHINE_FILE > $FIRST_HOSTS
    list=`cat $FIRST_HOSTS`
    for i in $list
    do
        /auto_ssh.sh $i
    done

    wait_pods_update

    cp $MACHINE_FILE $MACHINE_FILE.old

done

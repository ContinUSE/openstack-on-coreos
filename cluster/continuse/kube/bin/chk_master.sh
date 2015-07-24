#!/bin/bash

ETCDCTL_PEERS=192.168.10.11:4001,192.168.10.12:4001,192.168.10.13:4001
ping_status()
{
    ping -q -c2 $1 > /dev/null 2>&1
    if [ $? == 0 ]
    then
        return 0     
    else
        return 1
    fi
}

correct_ip_chk()
{
    re='[0-9]+([.][0-9]+)?$'
    if ! [[ $master_ip =~ $re ]] 
    then
        return 1
    else
        return 0
    fi
}

get_master_info()
{
    master_ip=''
    if [ "$ETCDCTL_PEERS" ]; then
        peers=`echo $ETCDCTL_PEERS | sed -e "s/,/ /g"`

        for i in $peers
        do
            read host port <<< $(echo $i | awk 'BEGIN {FS=":"; OFS =" "} {print $1,$2}')
            ping_status $host
            if [ $? == 0 ]
            then
                values=`curl -L http://$host:$port/v2/keys/continuse/kube/master 2> /dev/null`
	        master_ip=`echo $values | awk -F ',' '{print $3}' | awk -F "\"" '{print $4}'`
                break
            fi
        done
    fi
}

wait_master_info()
{
    master_ip=''
    if [ "$ETCDCTL_PEERS" ]; then
        peers=`echo $ETCDCTL_PEERS | sed -e "s/,/ /g"`

        for i in $peers
        do
            read host port <<< $(echo $i | awk 'BEGIN {FS=":"; OFS =" "} {print $1,$2}')
            ping_status $host
            if [ $? == 0 ]
            then
                values=`curl -L http://$host:$port/v2/keys/continuse/kube/master?wait=true 2> /dev/null`
                if [ $? == 0 ]; then
	            master_ip=`echo $values | awk -F ',' '{print $3}' | awk -F "\"" '{print $4}'`
                    break
                fi
            fi
        done
    fi
}

exec_command()
{
    if [ $1 == 'kubelet' ];then
        /usr/bin/pkill kubelet
        /continuse/kube/bin/kubelet \
            --address=0.0.0.0 \
            --port=10250 \
            --hostname_override=$2 \
            --api_servers=$master_ip:8080 \
            --allow_privileged=true \
            --logtostderr=true \
            --cadvisor_port=4194 \
            --healthz_bind_address=0.0.0.0 \
            --healthz_port=10248 &
    fi

    if [ $1 == 'proxy' ]; then
        /usr/bin/pkill -f kube-proxy
        /continuse/kube/bin/kube-proxy \
              --master=$master_ip:8080 \
              --logtostderr=true &
    fi
}

# Usage : chk_master.sh {kubelet or proxy} $COREOS_PUBLIC_IPV4)
while true; do
    echo 'Getting master ip address from etcd....'
    get_master_info

    # check for the master ip address
    correct_ip_chk
    if [ $? == 0 ]
    then
        break
    fi

    # If do not getting correct ip address, retry after sleep time.
    sleep 10
done

while true; do
    exec_command $1 $2

    wait_master_info
done


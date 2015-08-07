#!/bin/bash

master=`/usr/bin/etcdctl get /continuse/kube/master`
echo "Master Node IP Address : $master"

kubectl --server="$master:8080" $*

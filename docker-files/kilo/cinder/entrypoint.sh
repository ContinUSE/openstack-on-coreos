#!/bin/bash

/hostsctl.sh insert
controller=`awk '/controller/ {print $1}' /tmp/hosts`
hostname=`hostname`
echo "$MYIPADDR $hostname" >> /tmp/hosts
echo "$MYIPADDR $hostname" >> /etc/hosts

# Cinder SETUP

CINDER_CONF=/etc/cinder/cinder.conf

sed -i "s/CINDER_DBPASS/$CINDER_DBPASS/g" $CINDER_CONF
sed -i "s/CINDER_PASS/$CINDER_PASS/g" $CINDER_CONF
sed -i "s/RABBIT_PASS/$RABBIT_PASS/g" $CINDER_CONF
sed -i "s/MYIPADDR/$MYIPADDR/g" $CINDER_CONF
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $CINDER_CONF
sed -i "s/controller/$controller/g" $CINDER_CONF

chown nobody:nogroup  /storage
chmod 777 /storage
#chown cinder:cinder  /storage

service rpcbind start
service nfs-kernel-server start
service tgt start
service cinder-volume start

/hostsctl.sh update

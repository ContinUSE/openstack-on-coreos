#!/bin/bash

/hostsctl.sh insert
controller=`awk '/controller/ {print $1}' /tmp/hosts`
hostname=`hostname`
echo "$MYIPADDR $hostname" >> /tmp/hosts
echo "$MYIPADDR $hostname" >> /etc/hosts

######### Edit /etc/sysctl.conf for neutron networking #########
sed -i "s/^#net.ipv4.conf.all.rp_filter.*/net.ipv4.conf.all.rp_filter=0/" /etc/sysctl.conf
sed -i "s/^#net.ipv4.conf.default.rp_filter.*/net.ipv4.conf.default.rp_filter=0/" /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

########### Edit /etc/libvirt/libvirtd.conf ##########
# sed -i "s/^#listen_tls.*/listen_tls = 0/" /etc/libvirt/libvirtd.conf
# sed -i "s/^#listen_tcp.*/listen_tcp = 1/" /etc/libvirt/libvirtd.conf
# sed -i "s/^#auth_tcp.*/auth_tcp = \"none\"/" /etc/libvirt/libvirtd.conf
# echo "LIBVIRTD_ARGS=\"-listen\"" >> /etc/default/libvirt-bin

############ NEUTRON SETUP START #############################
### /etc/neutron/neutron.conf modify
NEUTRON_CONF=/etc/neutron/neutron.conf

sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $NEUTRON_CONF
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" $NEUTRON_CONF
sed -i "s/RABBIT_PASS/$RABBIT_PASS/g" $NEUTRON_CONF

########################### DVR / L3 HA Setup #################################
# DVR Setup
if [ $HA_MODE == "DVR" ]; then
    sed -i "s/^# router_distributed.*/router_distributed = True/" $NEUTRON_CONF
fi

# L3 HA Setup
if [ $HA_MODE == "L3_HA" ]; then
    sed -i "s/^# router_distributed.*/router_distributed = False/" $NEUTRON_CONF
fi

# L3 Agent Failover
sed -i "s/^# allow_automatic_l3agent_failover.*/allow_automatic_l3agent_failover = True/" $NEUTRON_CONF
########################### DVR / L3 HA Setup #################################

## Edit the /etc/neutron/plugins/ml2/ml2_conf.ini
ML2_CONF=/etc/neutron/plugins/ml2/ml2_conf.ini

sed -i "s/TUNNEL_IP/$TUNNEL_IP/g" $ML2_CONF

########################### DVR / L3 HA Setup #################################
# DVR Setup
if [ $HA_MODE == "DVR" ]; then
    echo "enable_distributed_routing = True" >> $ML2_CONF
fi

# L3 HA Setup
if [ $HA_MODE == "L3_HA" ]; then
    echo "enable_distributed_routing = False" >> $ML2_CONF
fi
echo "arp_responder = True" >> $ML2_CONF
########################### DVR / L3 HA Setup #################################

L3_AGENT=/etc/neutron/l3_agent.ini
sed -i "s/^# external_network_bridge.*/external_network_bridge = br-ex/" $L3_AGENT

########################### DVR / L3 HA Setup #################################
# DVR Setup
if [ $HA_MODE == "DVR" ]; then
    sed -i "s/^# agent_mode.*/agent_mode = dvr/" $L3_AGENT
fi

# L3 Agent Setup
if [ $HA_MODE == "L3_HA" ]; then
    sed -i "s/^# agent_mode.*/agent_mode = legacy/" $L3_AGENT
fi
########################### DVR / L3 HA Setup #################################

METADATA_AGENT=/etc/neutron/metadata_agent.ini

sed -i "s/REGION_NAME/$REGION_NAME/g" $METADATA_AGENT
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $METADATA_AGENT
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" $METADATA_AGENT
############ NEUTRON SETUP END #############################

# Nova SETUP (Edit /etc/nova/nova.conf)
NOVA_CONF=/etc/nova/nova.conf
NOVA_COMPUTE=/etc/nova/nova-compute.conf

sed -i "s/RABBIT_PASS/$RABBIT_PASS/g" $NOVA_CONF
sed -i "s/NOVA_PASS/$NOVA_PASS/g" $NOVA_CONF
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" $NOVA_CONF
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $NOVA_CONF
sed -i "s/MYIPADDR/$MYIPADDR/g" $NOVA_CONF

sed -i "s/^novncproxy_base_url.*/novncproxy_base_url = http:\/\/$controller:6080\/vnc_auto.html/" $NOVA_CONF

# Select kvm/qemu
cpus=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ $cpus -eq 0 ]; then
    sed -i "s/virt_type.*/virt_type=qemu/" $NOVA_COMPUTE
fi

# libvirt-bin service starting
service libvirt-bin start

# remove the SQLite database file:
rm -f /var/lib/nova/nova.sqlite

# /var/lib/nova/intances owner change to nova
chown -R nova:nova /var/lib/nova/instances

# nova-compute service starting
su -s /bin/sh -c "/usr/bin/nova-compute --config-file=/etc/nova/nova.conf --config-file=/etc/nova/nova-compute.conf &" nova

# rpcbind service
service rpcbind start

######### Neutron Setup Start ################
modprobe gre
modprobe openvswitch

# Restart the OVS service
service openvswitch-switch start

ifconfig br-ex
if [ $? != 0 ]; then
    echo 'Making br-ex bridge using OVS command'
    ovs-vsctl add-br br-ex
fi

if [ "$INTERFACE_NAME" ]; then
    echo 'Add port to br-ex bridge....'
    ovs-vsctl add-port br-ex $INTERFACE_NAME
fi

# Neutron openvswitch-agent service
su -s /bin/sh -c "neutron-openvswitch-agent --config-file=/etc/neutron/neutron.conf \
    --config-file=/etc/neutron/plugins/ml2/ml2_conf.ini \
    --log-file=/var/log/neutron/openvswitch-agent.log &" neutron

su -s /bin/sh -c "neutron-metadata-agent --config-file=/etc/neutron/neutron.conf \
    --config-file=/etc/neutron/metadata_agent.ini \
    --log-file=/var/log/neutron/metadata-agent.log &" neutron

su -s /bin/sh -c "neutron-l3-agent --config-file=/etc/neutron/neutron.conf \
    --config-file=/etc/neutron/l3_agent.ini \
    --config-file=/etc/neutron/fwaas_driver.ini \
    --log-file=/var/log/neutron/l3-agent.log &" neutron

/hostsctl.sh update

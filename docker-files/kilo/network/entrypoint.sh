#!/bin/bash

/hostsctl.sh insert
controller=`awk '/controller/ {print $1}' /tmp/hosts`
hostname=`hostname`
echo "$MYIPADDR $hostname" >> /tmp/hosts
echo "$MYIPADDR $hostname" >> /etc/hosts

# Neutron SETUP

sed -i "s/^#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf
sed -i "s/^#net.ipv4.conf.all.rp_filter.*/net.ipv4.conf.all.rp_filter=0/" /etc/sysctl.conf
sed -i "s/^#net.ipv4.conf.default.rp_filter.*/net.ipv4.conf.default.rp_filter=0/" /etc/sysctl.conf

sysctl -p

NEUTRON_CONF=/etc/neutron/neutron.conf

sed -i "s/RABBIT_PASS/$RABBIT_PASS/g" $NEUTRON_CONF
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" $NEUTRON_CONF
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $NEUTRON_CONF

########################### DVR / L3 HA Setup #################################
# DVR Setup
if [ $HA_MODE == "DVR" ]; then
    sed -i "s/^# router_distributed.*/router_distributed = True/" $NEUTRON_CONF
fi

# L3 HA Setup
if [ $HA_MODE == "L3_HA" ]; then
    sed -i "s/^# router_distributed.*/router_distributed = False/" $NEUTRON_CONF
    sed -i "s/^# l3_ha = False.*/l3_ha = True/" $NEUTRON_CONF
    sed -i "s/^# max_l3_agents_per_router.*/max_l3_agents_per_router = 0/" $NEUTRON_CONF
fi

# L3 Agent Failover
sed -i "s/^# allow_automatic_l3agent_failover.*/allow_automatic_l3agent_failover = True/" $NEUTRON_CONF
########################### DVR / L3 HA Setup #################################

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
########################### DVR / L3 HA Setup #################################
# DVR Setup
if [ $HA_MODE == "DVR" ]; then
    sed -i "s/^# agent_mode.*/agent_mode = dvr_snat/" $L3_AGENT
fi

# L3 Agent Setup
if [ $HA_MODE == "L3_HA" ]; then
    sed -i "s/^# agent_mode.*/agent_mode = legacy/" $L3_AGENT
fi
########################### DVR / L3 HA Setup #################################

DHCP_AGENT=/etc/neutron/dhcp_agent.ini

METADATA_AGENT=/etc/neutron/metadata_agent.ini

sed -i "s/REGION_NAME/$REGION_NAME/g" $METADATA_AGENT
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" $METADATA_AGENT
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $METADATA_AGENT

modprobe gre
modprobe openvswitch

service openvswitch-switch start

ifconfig br-ex
if [ $? != 0 ]; then
    echo "Making br-ex bridge by OVS command"
    ovs-vsctl add-br br-ex
fi

if [ "$INTERFACE_NAME" ]; then
    echo "Add port to br-ex bridge : $INTERFACE_NAME........"
    ovs-vsctl add-port br-ex $INTERFACE_NAME
fi

su -s /bin/sh -c "neutron-metadata-agent --config-file=/etc/neutron/neutron.conf \
    --config-file=/etc/neutron/metadata_agent.ini \
    --log-file=/var/log/neutron/metadata-agent.log &" neutron

su -s /bin/sh -c "neutron-dhcp-agent --config-file=/etc/neutron/neutron.conf \
    --config-file=/etc/neutron/dhcp_agent.ini \
    --log-file=/var/log/neutron/dhcp-agent.log &" neutron

su -s /bin/sh -c "neutron-openvswitch-agent --config-file=/etc/neutron/neutron.conf \
    --config-file=/etc/neutron/plugins/ml2/ml2_conf.ini \
    --log-file=/var/log/neutron/openvswitch-agent.log &" neutron

su -s /bin/sh -c "neutron-l3-agent --config-file=/etc/neutron/neutron.conf \
    --config-file=/etc/neutron/l3_agent.ini \
    --config-file=/etc/neutron/fwaas_driver.ini \
    --log-file=/var/log/neutron/l3-agent.log &" neutron

/hostsctl.sh update

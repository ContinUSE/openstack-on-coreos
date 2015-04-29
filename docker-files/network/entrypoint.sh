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

## /etc/neutron/neutron.conf modify
NEUTRON_CONF=/etc/neutron/neutron.conf
sed -i "s/^#rpc_backend.*/rpc_backend=rabbit/" $NEUTRON_CONF
sed -i "s/^#rabbit_host=localhost.*/rabbit_host=$controller/" $NEUTRON_CONF
sed -i "s/^#rabbit_password.*/rabbit_password=$RABBIT_PASS/" $NEUTRON_CONF

sed -i "s/^# auth_strategy.*/auth_strategy = keystone/" $NEUTRON_CONF

sed -i "s/^auth_host.*/auth_uri = http:\/\/$controller:5000\/v2.0/" $NEUTRON_CONF
sed -i "s/^auth_port.*/identity_uri = http:\/\/$controller:35357/" $NEUTRON_CONF

sed -i "s/^admin_tenant_name.*/admin_tenant_name = $ADMIN_TENANT_NAME/" $NEUTRON_CONF
sed -i "s/^admin_user.*/admin_user = neutron/" $NEUTRON_CONF
sed -i "s/^admin_password.*/admin_password = $NEUTRON_PASS/" $NEUTRON_CONF

sed -i "s/^# service_plugins.*/service_plugins = router/" $NEUTRON_CONF
sed -i "s/^# allow_overlapping_ips.*/allow_overlapping_ips = True/" $NEUTRON_CONF

sed -i "s/# agent_down_time = 75.*/# agent_down_time = 75/" $NEUTRON_CONF
sed -i "s/# report_interval = 30.*/# report_interval = 5/" $NEUTRON_CONF

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

## Edit the /etc/neutron/plugins/ml2/ml2_conf.ini
ML2_CONF=/etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "s/^# type_drivers.*/type_drivers = flat,vxlan/" $ML2_CONF
sed -i "s/^# tenant_network_types.*/tenant_network_types = vxlan/" $ML2_CONF
sed -i "s/^# mechanism_drivers.*/mechanism_drivers = openvswitch,l2population/" $ML2_CONF
sed -i "s/^# vni_ranges.*/vni_ranges = 1:1000/" $ML2_CONF
sed -i "s/^# vxlan_group.*/vxlan_group = 239.1.1.1/" $ML2_CONF
sed -i "s/^# enable_security_group.*/enable_security_group = True/" $ML2_CONF
sed -i "s/^# enable_ipset.*/enable_ipset = True/" $ML2_CONF
echo "firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver" \
    >> $ML2_CONF
sed -i "s/^# flat_networks.*/flat_networks = external/" $ML2_CONF

echo "" >> $ML2_CONF
echo "[ovs]" >> $ML2_CONF
echo "local_ip = $TUNNEL_IP" >> $ML2_CONF
echo "enable_tunneling = True" >> $ML2_CONF
echo "bridge_mappings = external:br-ex" >> $ML2_CONF

echo "" >> $ML2_CONF
echo "[agent]" >> $ML2_CONF
echo "l2population = True" >> $ML2_CONF
echo "tunnel_types = vxlan" >> $ML2_CONF

########################### DVR / L3 HA Setup #################################
# DVR Setup
if [ $HA_MODE == "DVR" ]; then
    echo "enable_distributed_routing = True" >> $ML2_CONF
fi

# L3 HA Setup
if [ $HA_MODE == "L3_HA" ]; then
    echo "enable_distributed_routing = False" >> $ML2_CONF
fi
########################### DVR / L3 HA Setup #################################

echo "arp_responder = True" >> $ML2_CONF

## Edit the /etc/neutron/l3_agent.ini
L3_AGENT=/etc/neutron/l3_agent.ini
sed -i "s/^# interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver.*/interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/" $L3_AGENT
sed -i "s/^# use_namespaces.*/use_namespaces = True/" $L3_AGENT
sed -i "s/^# external_network_bridge.*/external_network_bridge = br-ex/" $L3_AGENT
sed -i "s/^# router_delete_namespaces = False.*/router_delete_namespaces = True/" $L3_AGENT

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

## Edit the /etc/neutron/dhcp_agent.ini
DHCP_AGENT=/etc/neutron/dhcp_agent.ini
sed -i "s/^# interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver.*/interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/" $DHCP_AGENT
sed -i "s/^# dhcp_driver.*/dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq/" $DHCP_AGENT
sed -i "s/^# use_namespaces.*/use_namespaces = True/" $DHCP_AGENT
sed -i "s/^# dhcp_delete_namespaces = False.*/dhcp_delete_namespaces = True/" $DHCP_AGENT

# dnsmasq
sed -i "s/^# dnsmasq_config_file.*/dnsmasq_config_file = \/etc\/neutron\/dnsmasq-neutron.conf/" $DHCP_AGENT
echo "dhcp-option-force=26,1454" > /etc/neutron/dnsmasq-neutron.conf

# Metadata Support on isolated network
#sed -i "s/^# enable_isolated_metadata.*/enable_isolated_metadata = True/" $DHCP_AGENT
#sed -i "s/^# enable_metadata_network.*/enable_metadata_network = True/" $DHCP_AGENT


## Edit the /etc/neutron/metadata_agent.ini
METADATA_AGENT=/etc/neutron/metadata_agent.ini
sed -i "s/^auth_url.*/auth_url = http:\/\/$controller:5000\/v2.0/" $METADATA_AGENT
sed -i "s/^auth_region.*/auth_region = $REGION_NAME/" $METADATA_AGENT
sed -i "s/^admin_tenant_name.*/admin_tenant_name = $ADMIN_TENANT_NAME/" $METADATA_AGENT
sed -i "s/^admin_user.*/admin_user = neutron/" $METADATA_AGENT
sed -i "s/^admin_password.*/admin_password = $NEUTRON_PASS/" $METADATA_AGENT
sed -i "s/^# nova_metadata_ip.*/nova_metadata_ip = $controller/" $METADATA_AGENT
#sed -i "s/^# nova_metadata_port.*/nova_metadata_port = 8775/" $METADATA_AGENT
sed -i "s/^# metadata_proxy_shared_secret.*/metadata_proxy_shared_secret = METADATA_SECRET/" $METADATA_AGENT

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

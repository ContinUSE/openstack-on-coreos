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
sed -i "s/^#listen_tls.*/listen_tls = 0/" /etc/libvirt/libvirtd.conf
sed -i "s/^#listen_tcp.*/listen_tcp = 1/" /etc/libvirt/libvirtd.conf
sed -i "s/^#auth_tcp.*/auth_tcp = \"none\"/" /etc/libvirt/libvirtd.conf
echo "LIBVIRTD_ARGS=\"-listen\"" >> /etc/default/libvirt-bin

############ NEUTRON SETUP START #############################
### /etc/neutron/neutron.conf modify
NEUTRON_CONF=/etc/neutron/neutron.conf
sed -i "s/^#rpc_backend.*/rpc_backend=rabbit/" $NEUTRON_CONF
sed -i "s/^#rabbit_host=localhost.*/rabbit_host=$controller/" $NEUTRON_CONF
sed -i "s/^#rabbit_password.*/rabbit_password=$RABBIT_PASS/" $NEUTRON_CONF

sed -i "s/^# auth_strategy.*/auth_strategy = keystone/" $NEUTRON_CONF

sed -i "s/^auth_host.*/auth_uri = http:\/\/$controller:5000\/v2.0/" $NEUTRON_CONF
sed -i "s/^auth_host.*/identity_uri = http:\/\/$controller:35357/" $NEUTRON_CONF

sed -i "s/^admin_tenant_name.*/admin_tenant_name = $ADMIN_TENANT_NAME/" $NEUTRON_CONF
sed -i "s/^admin_user.*/admin_user = neutron/" $NEUTRON_CONF
sed -i "s/^admin_password.*/admin_password = $NEUTRON_PASS/" $NEUTRON_CONF

sed -i "s/^# service_plugins.*/service_plugins = router/" $NEUTRON_CONF
sed -i "s/^# allow_overlapping_ips.*/allow_overlapping_ips = True/" $NEUTRON_CONF

sed -i "s/# agent_down_time = 75.*/agent_down_time = 75/" $NEUTRON_CONF
sed -i "s/# report_interval = 30.*/report_interval = 5/" $NEUTRON_CONF

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
# sed -i "s/^# allow_automatic_l3agent_failover.*/allow_automatic_l3agent_failover = True/" $NEUTRON_CONF
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
#echo "tunnel_type = gre" >> $ML2_CONF
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
#sed -i "s/^# external_network_bridge.*/external_network_bridge = br-ex/" $L3_AGENT
sed -i "s/^# router_delete_namespaces = False.*/router_delete_namespaces = True/" $L3_AGENT

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

## Edit the /etc/neutron/metadata_agent.ini
METADATA_AGENT=/etc/neutron/metadata_agent.ini
sed -i "s/^auth_url.*/auth_url = http:\/\/$controller:5000\/v2.0/" $METADATA_AGENT
sed -i "s/^auth_region.*/auth_region = $REGION_NAME/" $METADATA_AGENT
sed -i "s/^admin_tenant_name.*/admin_tenant_name = $ADMIN_TENANT_NAME/" $METADATA_AGENT
sed -i "s/^admin_user.*/admin_user = neutron/" $METADATA_AGENT
sed -i "s/^admin_password.*/admin_password = $NEUTRON_PASS/" $METADATA_AGENT
sed -i "s/^# nova_metadata_ip.*/nova_metadata_ip = $controller/" $METADATA_AGENT
sed -i "s/^# metadata_proxy_shared_secret.*/metadata_proxy_shared_secret = METADATA_SECRET/" $METADATA_AGENT

############ NEUTRON SETUP END #############################

# Nova SETUP (Edit /etc/nova/nova.conf)
NOVA_CONF=/etc/nova/nova.conf
NOVA_COMPUTE=/etc/nova/nova-compute.conf

###### Nova-network Setup Start (lagacy networking) ###############
## echo "" >> $NOVA_CONF
## echo "network_api_class = nova.network.api.API" >> $NOVA_CONF
## echo "security_group_api = nova" >> $NOVA_CONF
## echo "firewall_driver = nova.virt.libvirt.firewall.IptablesFirewallDriver" >> $NOVA_CONF
## echo "network_manager = nova.network.manager.FlatDHCPManager" >> $NOVA_CONF
## echo "network_size = 254" >> $NOVA_CONF
## echo "allow_same_net_traffic = False" >> $NOVA_CONF
## echo "multi_host = True" >> $NOVA_CONF
## echo "send_arp_for_ha = True" >> $NOVA_CONF
## echo "share_dhcp_address = True" >> $NOVA_CONF
## echo "force_dhcp_release = True" >> $NOVA_CONF
## echo "flat_network_bridge = $IF_NAME" >> $NOVA_CONF
## #echo "flat_interface = $IF_NAME" >> $NOVA_CONF
## #echo "public_interface = $IF_NAME" >> $NOVA_CONF
###### Nova-network Setup End (lagacy networking) ###############

#### Live Migration #########
echo "live_migration_flag=VIR_MIGRATE_UNDEFINE_SOURCE,VIR_MIGRATE_PEER2PEER,VIR_MIGRATE_LIVE" >> $NOVA_CONF

####### Neutron Setup Start ################
echo "" >> $NOVA_CONF
echo "network_api_class = nova.network.neutronv2.api.API" >> $NOVA_CONF
echo "security_group_api = neutron" >> $NOVA_CONF
echo "linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver" >> $NOVA_CONF
#echo "libvirt_vif_driver = nova.virt.libvirt.vif.NeutronLinuxBridgeVIFDriver" >> $NOVA_CONF
#
### vif plugging define
#echo "vif_plugging_is_fatal = False" >> $NOVA_CONF
#echo "vif_plugging_timeout = 0" >> $NOVA_CONF
echo "fixed_ip_disassociate_timeout=30" >> $NOVA_CONF
echo "enable_instance_password=False" >> $NOVA_CONF
echo "service_neutron_metadata_proxy=True" >> $NOVA_CONF
echo "neutron_metadata_proxy_shared_secret=METADATA_SECRET" >> $NOVA_CONF

echo "firewall_driver = nova.virt.firewall.NoopFirewallDriver" >> $NOVA_CONF
####### Neutron Setup End ################

echo "" >> $NOVA_CONF
echo "rpc_backend = rabbit" >> $NOVA_CONF
echo "rabbit_host = $controller" >> $NOVA_CONF
echo "rabbit_password = $RABBIT_PASS" >> $NOVA_CONF

echo "" >> $NOVA_CONF
echo "auth_strategy = keystone" >> $NOVA_CONF

echo "" >> $NOVA_CONF
echo "my_ip = $MYIPADDR" >> $NOVA_CONF

echo "" >> $NOVA_CONF
echo "vnc_enabled = True" >> $NOVA_CONF
echo "vncserver_listen = 0.0.0.0" >> $NOVA_CONF
echo "vncserver_proxyclient_address = $MYIPADDR " >> $NOVA_CONF
echo "novncproxy_base_url = http://$controller:6080/vnc_auto.html" >> $NOVA_CONF

echo "" >> $NOVA_CONF
echo "[glance]" >> $NOVA_CONF
echo "host = $controller" >> $NOVA_CONF

echo "" >> $NOVA_CONF
echo "[keystone_authtoken]" >> $NOVA_CONF
echo "auth_uri = http://$controller:5000/v2.0" >> $NOVA_CONF
echo "identity_uri = http://$controller:35357" >> $NOVA_CONF
echo "admin_tenant_name = $ADMIN_TENANT_NAME" >> $NOVA_CONF
echo "admin_user = nova" >> $NOVA_CONF
echo "admin_password = $NOVA_PASS" >> $NOVA_CONF

######### Neutron Setup Start ################
echo "" >> $NOVA_CONF
echo "[neutron]" >> $NOVA_CONF
echo "url = http://$controller:9696" >> $NOVA_CONF
echo "auth_strategy = keystone" >> $NOVA_CONF
echo "admin_auth_url = http://$controller:35357/v2.0" >> $NOVA_CONF
echo "admin_tenant_name = $ADMIN_TENANT_NAME" >> $NOVA_CONF
echo "admin_username = neutron" >> $NOVA_CONF
echo "admin_password = $NEUTRON_PASS" >> $NOVA_CONF
######### Neutron Setup End ################

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

#!/bin/bash

/hostsctl.sh insert
controller=`awk '/controller/ {print $1}' /tmp/hosts`

# hostname insert to /tmp/hosts file
hostname=`hostname`
echo "$MYIPADDR $hostname" >> /tmp/hosts

######### Edit /etc/sysctl.conf #########
sed -i "s/^#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf
######### Edit /etc/sysctl.conf #########

########### Edit /etc/libvirt/libvirtd.conf ##########
sed -i "s/^#listen_tls.*/listen_tls = 0/" /etc/libvirt/libvirtd.conf
sed -i "s/^#listen_tcp.*/listen_tcp = 1/" /etc/libvirt/libvirtd.conf
sed -i "s/^#auth_tcp.*/auth_tcp = \"none\"/" /etc/libvirt/libvirtd.conf
echo "LIBVIRTD_ARGS=\"-listen\"" >> /etc/default/libvirt-bin

# libvirt-bin service starting
service libvirt-bin start

# Nova SETUP (Edit /etc/nova/nova.conf)
NOVA_CONF=/etc/nova/nova.conf
NOVA_COMPUTE=/etc/nova/nova-compute.conf

###### Nova-network Setup Start (lagacy networking) ###############
echo "" >> $NOVA_CONF
echo "network_api_class = nova.network.api.API" >> $NOVA_CONF
echo "security_group_api = nova" >> $NOVA_CONF
echo "firewall_driver = nova.virt.libvirt.firewall.IptablesFirewallDriver" >> $NOVA_CONF
echo "network_manager = nova.network.manager.FlatDHCPManager" >> $NOVA_CONF
echo "network_size = 254" >> $NOVA_CONF
echo "allow_same_net_traffic = False" >> $NOVA_CONF
echo "multi_host = True" >> $NOVA_CONF
echo "send_arp_for_ha = True" >> $NOVA_CONF
echo "share_dhcp_address = True" >> $NOVA_CONF
echo "force_dhcp_release = True" >> $NOVA_CONF
echo "flat_network_bridge = $IF_NAME" >> $NOVA_CONF
#echo "flat_interface = $IF_NAME" >> $NOVA_CONF
#echo "public_interface = $IF_NAME" >> $NOVA_CONF
###### Nova-network Setup End (lagacy networking) ###############

#### Live Migration #########
echo "live_migration_flag=VIR_MIGRATE_UNDEFINE_SOURCE,VIR_MIGRATE_PEER2PEER,VIR_MIGRATE_LIVE" >> $NOVA_CONF

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

# Select kvm/qemu
cpus=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ $cpus -eq 0 ]; then
    sed -i "s/virt_type.*/virt_type=qemu/" $NOVA_COMPUTE
fi

# remove the SQLite database file:
rm -f /var/lib/nova/nova.sqlite

# /var/lib/nova/intances owner change to nova
chown -R nova:nova /var/lib/nova/instances

###### Nova-network Setup Start (lagacy networking) ###############
su -s /bin/sh -c "/usr/bin/nova-network --config-file=/etc/nova/nova.conf &" nova
su -s /bin/sh -c "/usr/bin/nova-api-metadata --config-file=/etc/nova/nova.conf &" nova
###### Nova-network Setup End (lagacy networking) ###############

# nova-compute service starting
su -s /bin/sh -c "/usr/bin/nova-compute --config-file=/etc/nova/nova.conf --config-file=/etc/nova/nova-compute.conf &" nova

/hostsctl.sh update

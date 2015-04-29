#!/bin/bash

# Setup for MySQL
# Remove mysql directory
if [ -d /data/mysql ]; then
    rm -rf /data/mysql
fi

echo 'Running mysql_install_db ...'
mysql_install_db 
echo 'Finished mysql_install_db'
		
tempSqlFile='/tmp/mysql-first-time.sql'
cat > "$tempSqlFile" <<-EOSQL
DELETE FROM mysql.user ;
CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
DROP DATABASE IF EXISTS test ;
EOSQL

# Create User & Database
if [ "$KEYSTONE_DBPASS" ]; then
    echo "CREATE USER 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`keystone\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`keystone\`.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';" >> "$tempSqlFile"
fi
if [ "$GLANCE_DBPASS" ]; then
    echo "CREATE USER 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`glance\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`glance\`.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';" >> "$tempSqlFile"
fi
if [ "$NOVA_DBPASS" ]; then
    echo "CREATE USER 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`nova\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`nova\`.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';" >> "$tempSqlFile"
fi
if [ "$NEUTRON_DBPASS" ]; then
    echo "CREATE USER 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`neutron\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`neutron\`.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';" >> "$tempSqlFile"
fi
if [ "$CINDER_DBPASS" ]; then
    echo "CREATE USER 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`cinder\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`cinder\`.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';" >> "$tempSqlFile"
fi

echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"
		
mysqld --init-file="$tempSqlFile" &

# Rabbitmq-server Setup
echo 'Rabbitmq-server Setup....................'
service rabbitmq-server start

# Change password for Rabbitmq Server
while true; do
    if [ "$RABBIT_PASS" ]; then
        rabbitmqctl change_password guest $RABBIT_PASS
        if [ $? == 0 ]; then break
        else echo "Waiting for RabbitMQ Server Password change....";sleep 1
        fi
    fi
done

# Keystone Setup
echo 'Keystone Setup....................'
sed -i "s#^connection.*#connection = \
       mysql://keystone:$KEYSTONE_DBPASS@controller/keystone#" \
       /etc/keystone/keystone.conf

if [ "$ADMIN_TOKEN" ]; then
    sed -i "s/^#admin_token.*/admin_token = $ADMIN_TOKEN/" \
           /etc/keystone/keystone.conf
fi

sed -i "s/^#provider.*/provider = keystone.token.providers.uuid.Provider/" \
        /etc/keystone/keystone.conf
sed -i "s/^#driver=keystone.token.*/driver=keystone.token.persistence.backends.sql.Token/" \
       /etc/keystone/keystone.conf
sed -i "s/^#driver=keystone.contrib.revoke.*/driver = keystone.contrib.revoke.backends.sql.Revoke/" \
        /etc/keystone/keystone.conf

# excution for keystone Service
su -s /bin/sh -c "keystone-manage db_sync" keystone
su -s /bin/sh -c "keystone-all &" keystone

# remove the SQLite database file:
rm -f /var/lib/keystone/keystone.db

# GLANCE SETUP
echo 'Glance Setup..................'
GLANCE_API=/etc/glance/glance-api.conf
GLANCE_REGISTRY=/etc/glance/glance-registry.conf
GLANCE_CACHE=/etc/glance/glance-cache.conf

### /etc/glance/glance-api.conf modify for MySQL & RabbitMQ
sed -i "s/# rpc_backend.*/rpc_backend = 'rabbit'/" $GLANCE_API
sed -i "s/rabbit_host.*/rabbit_host = controller/" $GLANCE_API
sed -i "s/rabbit_password.*/rabbit_password = $RABBIT_PASS/" $GLANCE_API
sed -i "s/sqlite_db.*/connection = \
     mysql:\/\/glance:$GLANCE_DBPASS@controller\/glance/" $GLANCE_API
sed -i "s/backend = sqlalchemy.*/backend = mysql/" $GLANCE_API

### /etc/glance/glance-registry.conf for MySQL & RabbitMQ
sed -i "s/sqlite_db.*/connection = \
     mysql:\/\/glance:$GLANCE_DBPASS@controller\/glance/" $GLANCE_REGISTRY
sed -i "s/backend = sqlalchemy.*/backend = mysql/" $GLANCE_REGISTRY

### /etc/glance/glance-api.conf modify for Keystone Service
sed -i "s/^identity_uri.*/identity_uri = http:\/\/controller:35357/" $GLANCE_API
sed -i "s/^admin_tenant_name.*/admin_tenant_name = $ADMIN_TENANT_NAME/" $GLANCE_API
sed -i "s/^admin_user.*/admin_user = glance/" $GLANCE_API
sed -i "s/^admin_password.*/admin_password = $GLANCE_PASS/" $GLANCE_API
sed -i "s/^#flavor.*/flavor = keystone/" $GLANCE_API
sed -i "s/^#container_formats.*/container_formats=ami,ari,aki,bare,ovf,ova,docker/" $GLANCE_API

### /etc/glance/glance-registry.conf for Keystone Service
sed -i "s/^identity_uri.*/identity_uri = http:\/\/controller:35357/" $GLANCE_REGISTRY
sed -i "s/^admin_tenant_name.*/admin_tenant_name = $ADMIN_TENANT_NAME/" $GLANCE_REGISTRY
sed -i "s/^admin_user.*/admin_user = glance/" $GLANCE_REGISTRY
sed -i "s/^admin_password.*/admin_password = $GLANCE_PASS/" $GLANCE_REGISTRY
sed -i "s/^#flavor.*/flavor = keystone/" $GLANCE_REGISTRY

### glance image directory / files owner:group change
chown -R glance:glance /var/lib/glance

# excution for glance service
su -s /bin/sh -c "glance-manage db_sync" glance
su -s /bin/sh -c "glance-registry &" glance
su -s /bin/sh -c "glance-api &" glance
rm -f /var/lib/glance/glance.sqlite

## Nova Setup
echo 'Nova Setup.......................'
NOVA_CONF=/etc/nova/nova.conf

echo "" >> $NOVA_CONF
echo "rpc_backend = rabbit" >> $NOVA_CONF
echo "rabbit_host = controller" >> $NOVA_CONF
echo "rabbit_password = $RABBIT_PASS" >> $NOVA_CONF
echo "" >> $NOVA_CONF
echo "my_ip = controller" >> $NOVA_CONF
echo "vncserver_listen = controller" >> $NOVA_CONF
echo "vncserver_proxyclient_address = controller" >> $NOVA_CONF
echo "" >> $NOVA_CONF
echo "auth_strategy = keystone" >> $NOVA_CONF
echo "" >> $NOVA_CONF

######## Neutron Setup Start ####################
echo "network_api_class = nova.network.neutronv2.api.API" >>$NOVA_CONF
echo "security_group_api = neutron" >>$NOVA_CONF
echo "linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver" >>$NOVA_CONF
#echo "libvirt_vif_driver = nova.virt.libvirt.vif.NeutronLinuxBridgeVIFDriver" >> $NOVA_CONF

echo "fixed_ip_disassociate_timeout=30" >> $NOVA_CONF
echo "enable_instance_password=False" >> $NOVA_CONF

echo "firewall_driver = nova.virt.firewall.NoopFirewallDriver" >>$NOVA_CONF
echo "" >> $NOVA_CONF
######## Neutron Setup End ####################

echo "" >> $NOVA_CONF
echo "[keystone_authtoken]" >> $NOVA_CONF
echo "auth_uri = http://controller:5000/v2.0" >> $NOVA_CONF
echo "identity_uri = http://controller:35357" >> $NOVA_CONF
echo "admin_tenant_name = $ADMIN_TENANT_NAME"  >> $NOVA_CONF
echo "admin_user = nova" >> $NOVA_CONF
echo "admin_password = $NOVA_PASS" >> $NOVA_CONF
echo "" >> $NOVA_CONF

######### Neutron Setup Start ######################
echo "[neutron]" >> $NOVA_CONF
echo "url = http://controller:9696" >> $NOVA_CONF
echo "auth_strategy = keystone" >> $NOVA_CONF
echo "admin_auth_url = http://controller:35357/v2.0" >> $NOVA_CONF
echo "admin_tenant_name = $ADMIN_TENANT_NAME" >> $NOVA_CONF
echo "admin_username = neutron" >> $NOVA_CONF
echo "admin_password = $NEUTRON_PASS" >> $NOVA_CONF
echo "service_metadata_proxy = True" >> $NOVA_CONF
echo "metadata_proxy_shared_secret = METADATA_SECRET" >> $NOVA_CONF
######### Neutron Setup End ######################

# Database Section
echo "" >> $NOVA_CONF
echo "[database]" >> $NOVA_CONF
echo "connection=mysql://nova:$NOVA_DBPASS@controller/nova" >> $NOVA_CONF

# Glance Section
echo "" >> $NOVA_CONF
echo "[glance]" >> $NOVA_CONF
echo "host = controller" >> $NOVA_CONF

# apache2 & memcached service starting for Horizone Service
if [ "$TIME_ZONE" ]; then
    sed -i "s|^TIME_ZONE.*|TIME_ZONE = \"$TIME_ZONE\"|" /etc/openstack-dashboard/local_settings.py
fi

# For related dashboard service start
service memcached start
service apache2 start

# Nova service start
su -s /bin/sh -c "nova-manage db sync" nova
rm -f /var/lib/nova/nova.sqlite

su -s /bin/sh -c "nova-api --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-cert --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-consoleauth --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-scheduler --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-conductor --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-novncproxy --config-file=$NOVA_CONF &" nova

# Creation of Tenant & User & Role
echo 'Creation of Tenant / User / Role ..............'
/keystone.sh > /dev/null 2>&1

## Neutron Setup
echo 'Neutron Setup.......................'
NEUTRON_CONF=/etc/neutron/neutron.conf
ML2_CONF=/etc/neutron/plugins/ml2/ml2_conf.ini

export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://controller:5000/v2.0/
export OS_NO_CACHE=1

### /etc/neutron/neutron.conf modify
sed -i "s/# connection = mysql.*/connection = \
        mysql:\/\/neutron:$NEUTRON_DBPASS@controller\/neutron/" $NEUTRON_CONF
sed -i "s/connection = sqlite:.*/#connection = sqlite:/" $NEUTRON_CONF
sed -i "s/#rpc_backend=rabbit.*/rpc_backend=rabbit/" $NEUTRON_CONF
sed -i "s/#rabbit_host=localhost.*/rabbit_host=controller/" $NEUTRON_CONF
sed -i "s/#rabbit_password=guest.*/rabbit_password=$RABBIT_PASS/" $NEUTRON_CONF
sed -i "s/# auth_strategy = keystone.*/auth_strategy = keystone/" $NEUTRON_CONF

sed -i "s/^auth_host.*/auth_uri = http:\/\/controller:5000\/v2.0/" $NEUTRON_CONF
sed -i "s/^auth_port.*/identity_uri = http:\/\/controller:35357/" $NEUTRON_CONF

sed -i "s/admin_tenant_name.*/admin_tenant_name = $ADMIN_TENANT_NAME/" $NEUTRON_CONF
sed -i "s/^admin_user.*/admin_user = neutron/" $NEUTRON_CONF
sed -i "s/^admin_password.*/admin_password = $NEUTRON_PASS/" $NEUTRON_CONF
sed -i "s/# service_plugins.*/service_plugins = router/" $NEUTRON_CONF
sed -i "s/# allow_overlapping_ips.*/allow_overlapping_ips = True/" $NEUTRON_CONF
sed -i "s/# notify_nova_on_port_status_changes.*/notify_nova_on_port_status_changes = True/" $NEUTRON_CONF
sed -i "s/# notify_nova_on_port_data_changes.*/notify_nova_on_port_data_changes = True/" $NEUTRON_CONF
sed -i "s/# nova_url.*/nova_url = http:\/\/controller:8774\/v2/" $NEUTRON_CONF
sed -i "s/# nova_admin_auth_url.*/nova_admin_auth_url = http:\/\/controller:35357\/v2.0/" $NEUTRON_CONF
sed -i "s/# nova_region_name.*/nova_region_name = $REGION_NAME/" $NEUTRON_CONF
sed -i "s/# nova_admin_username.*/nova_admin_username = nova/" $NEUTRON_CONF
sed -i "s/# nova_admin_password.*/nova_admin_password = $NOVA_PASS/" $NEUTRON_CONF
NOVA_SERVICE_ID=$(keystone tenant-list | awk '/ '$ADMIN_TENANT_NAME' / {print $2}')
sed -i "s/# nova_admin_tenant_id.*/nova_admin_tenant_id = $NOVA_SERVICE_ID/" $NEUTRON_CONF

# DVR Setup / L3 HA
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

### /etc/neutron/plugin/ml2/ml2_conf.ini modify
sed -i "s/# type_drivers.*/type_drivers = flat,vxlan/" $ML2_CONF
sed -i "s/# tenant_network_types.*/tenant_network_types = vxlan/" $ML2_CONF
sed -i "s/# mechanism_drivers.*/mechanism_drivers = openvswitch,l2population/" $ML2_CONF
sed -i "s/# vni_ranges.*/vni_ranges = 1:1000/" $ML2_CONF
sed -i "s/# vxlan_group.*/vxlan_group = 239.1.1.1/" $ML2_CONF
sed -i "s/# enable_security_group.*/enable_security_group = True/" $ML2_CONF
sed -i "s/# enable_ipset.*/enable_ipset = True/" $ML2_CONF
echo "firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver" >> $ML2_CONF

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno" neutron

echo 'Neutron Service Starting......'
su -s /bin/sh -c "neutron-server --config-file $NEUTRON_CONF --config-file $ML2_CONF" neutron

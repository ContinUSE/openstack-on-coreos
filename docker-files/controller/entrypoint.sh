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
echo 'Rabbitmq-server Setup...............................'
service rabbitmq-server start
#su -s /bin/sh -c "rabbitmq-server &" rabbitmq

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
echo 'Keystone Setup............................'
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

# Creation of Tenant & User & Role
echo 'Creation of Tenant / User / Role ..............'
sleep 2
/keystone.sh

# GLANCE SETUP
echo 'Glance Setup............................'
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

###### Nova-network setup (Legacy Networking) ############
echo "" >> $NOVA_CONF
echo "network_api_class = nova.network.api.API" >> $NOVA_CONF
echo "security_group_api = nova" >> $NOVA_CONF
###### Nova-network setup end (Legacy Networking) ############

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

echo "" >> $NOVA_CONF
echo "[keystone_authtoken]" >> $NOVA_CONF
echo "auth_uri = http://controller:5000/v2.0" >> $NOVA_CONF
echo "identity_uri = http://controller:35357" >> $NOVA_CONF
echo "admin_tenant_name = $ADMIN_TENANT_NAME"  >> $NOVA_CONF
echo "admin_user = nova" >> $NOVA_CONF
echo "admin_password = $NOVA_PASS" >> $NOVA_CONF

echo "" >> $NOVA_CONF
echo "[database]" >> $NOVA_CONF
echo "connection=mysql://nova:$NOVA_DBPASS@controller/nova" >> $NOVA_CONF

# apache2 & memcached service starting for Horizone Service
if [ "$TIME_ZONE" ]; then
    sed -i "s|^TIME_ZONE.*|TIME_ZONE = \"$TIME_ZONE\"|" /etc/openstack-dashboard/local_settings.py
fi
service memcached start
service apache2 start

su -s /bin/sh -c "nova-manage db sync" nova
rm -f /var/lib/nova/nova.sqlite

su -s /bin/sh -c "nova-api --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-cert --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-consoleauth --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-scheduler --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-conductor --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-novncproxy --config-file=$NOVA_CONF" nova

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

# Add User & Change password for Rabbitmq Server
while true; do
    if [ "$RABBIT_PASS" ]; then
        rabbitmqctl add_user openstack $RABBIT_PASS
        if [ $? == 0 ]; then break
        else echo "Waiting for RabbitMQ Server Password change....";sleep 1
        fi
    fi
done
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

# Keystone Setup
echo 'Keystone Setup....................'

sed -i "s/ADMIN_TOKEN/$ADMIN_TOKEN/g" /etc/keystone/keystone.conf
sed -i "s/KEYSTONE_DBPASS/$KEYSTONE_DBPASS/g" /etc/keystone/keystone.conf

# excution for keystone Service
su -s /bin/sh -c "keystone-manage db_sync" keystone

# Dashboard Service
# Timezone Setup for Horizone Service
if [ "$TIME_ZONE" ]; then
    sed -i "s|^TIME_ZONE.*|TIME_ZONE = \"$TIME_ZONE\"|" /etc/openstack-dashboard/local_settings.py
fi

# Start the Apache HTTP Server
service apache2 start
service memcached start

# Creation of Tenant & User & Role
echo 'Creation of Tenant / User / Role ..............'
/keystone.sh

# GLANCE SETUP
echo 'Glance Setup..................'
GLANCE_API=/etc/glance/glance-api.conf
GLANCE_REGISTRY=/etc/glance/glance-registry.conf

sed -i "s/GLANCE_DBPASS/$GLANCE_DBPASS/g" $GLANCE_API
sed -i "s/GLANCE_PASS/$GLANCE_PASS/g" $GLANCE_API
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $GLANCE_API

sed -i "s/GLANCE_DBPASS/$GLANCE_DBPASS/g" $GLANCE_REGISTRY
sed -i "s/GLANCE_PASS/$GLANCE_PASS/g" $GLANCE_REGISTRY
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $GLANCE_REGISTRY

### glance image directory / files owner:group change
chown -R glance:glance /var/lib/glance

# excution for glance service
su -s /bin/sh -c "glance-manage db_sync" glance
su -s /bin/sh -c "glance-registry &" glance
su -s /bin/sh -c "glance-api &" glance

## Nova Setup
echo 'Nova Setup.......................'
NOVA_CONF=/etc/nova/nova.conf

sed -i "s/NOVA_DBPASS/$NOVA_DBPASS/g" $NOVA_CONF
sed -i "s/NOVA_PASS/$NOVA_PASS/g" $NOVA_CONF
sed -i "s/RABBIT_PASS/$RABBIT_PASS/g" $NOVA_CONF
sed -i "s/MYIPADDR/$MYIPADDR/g" $NOVA_CONF
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $NOVA_CONF
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" $NOVA_CONF

# Nova service start
su -s /bin/sh -c "nova-manage db sync" nova

su -s /bin/sh -c "nova-api --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-cert --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-consoleauth --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-scheduler --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-conductor --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-novncproxy --config-file=$NOVA_CONF &" nova

## Neutron Setup
echo 'Neutron Setup.......................'
NEUTRON_CONF=/etc/neutron/neutron.conf
ML2_CONF=/etc/neutron/plugins/ml2/ml2_conf.ini

sed -i "s/NEUTRON_DBPASS/$NEUTRON_DBPASS/g" $NEUTRON_CONF
sed -i "s/RABBIT_PASS/$RABBIT_PASS/g" $NEUTRON_CONF
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" $NEUTRON_CONF
sed -i "s/NOVA_PASS/$NOVA_PASS/g" $NEUTRON_CONF
sed -i "s/REGION_NAME/$REGION_NAME/g" $NEUTRON_CONF
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $NEUTRON_CONF

############################################################################
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
############################################################################

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

echo 'Neutron Service Starting......'
su -s /bin/sh -c "neutron-server --config-file $NEUTRON_CONF --config-file $ML2_CONF" neutron

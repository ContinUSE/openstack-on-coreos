#!/bin/bash

# 
export SERVICE_TOKEN=$ADMIN_TOKEN
export SERVICE_ENDPOINT=http://controller:35357/v2.0

# Tenant / User / User-role create for admin
keystone tenant-create --name admin --description "Admin Tenant"
keystone user-create   --name admin --pass $ADMIN_PASS --email EMAIL_ADDRESS
keystone role-create   --name admin
keystone user-role-add --user admin --tenant admin --role admin

# Tenant / User create for demo
keystone tenant-create --name demo --description "Demo Tenant"
keystone user-create --name demo --tenant demo --pass $DEMO_PASS --email EMAIL_ADDRESS

# Tenant create for service
keystone tenant-create --name $ADMIN_TENANT_NAME --description "Service Tenant"

# Service create for Identity
name=`keystone service-list | awk '/ identity / {print $2}'`
if [  -z $name ]; then
    keystone service-create --name keystone --type identity --description "OpenStack Identity"
fi

# Endpoint create for keystone service
name=`keystone service-list | awk '/ identity / {print $2}'`
endpoint=`keystone endpoint-list | awk '/ '$name' / {print $2}'`
if [ -z "$endpoint" ]; then
    keystone endpoint-create \
        --region $REGION_NAME \
        --publicurl http://controller:5000/v2.0 \
        --internalurl http://controller:5000/v2.0 \
        --adminurl http://controller:35357/v2.0 \
        --service_id $name 
fi

## FOR GLANCE
keystone user-create --name glance --pass $GLANCE_PASS
keystone user-role-add --user glance --tenant $ADMIN_TENANT_NAME --role admin

name=`keystone service-list | awk '/ image / {print $2}'`
if [  -z $name ]; then
    keystone service-create --name glance --type image --description "OpenStack Image Service"
fi
name=`keystone service-list | awk '/ image / {print $2}'`
endpoint=`keystone endpoint-list | awk '/ '$name' / {print $2}'`
if [ -z "$endpoint" ]; then
    keystone endpoint-create \
        --region $REGION_NAME \
        --publicurl http://controller:9292 \
        --internalurl http://controller:9292 \
        --adminurl http://controller:9292 \
        --service_id $name 
fi

## FOR NOVA
keystone user-create --name nova --pass $NOVA_PASS
keystone user-role-add --user nova --tenant $ADMIN_TENANT_NAME --role admin

name=`keystone service-list | awk '/ compute / {print $2}'`
if [  -z $name ]; then
    keystone service-create --name nova --type compute --description "OpenStack Compute"
fi
name=`keystone service-list | awk '/ compute / {print $2}'`
endpoint=`keystone endpoint-list | awk '/ '$name' / {print $2}'`
if [ -z "$endpoint" ]; then
    keystone endpoint-create \
        --region $REGION_NAME \
        --publicurl http://controller:8774/v2/%\(tenant_id\)s \
        --internalurl http://controller:8774/v2/%\(tenant_id\)s \
        --adminurl http://controller:8774/v2/%\(tenant_id\)s \
        --service_id $name 
fi


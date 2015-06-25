#!/bin/bash

export OS_TOKEN=$ADMIN_TOKEN
export OS_URL=http://controller:35357/v2.0

# For Keystone
name=`openstack service list | awk '/ identity / {print $2}'`
if [ -z $name ]; then
   openstack service create --name keystone --description "OpenStack Identity" identity
fi

# Endpoint create for keystone service
endpoint=`openstack endpoint list | awk '/ identity / {print $2}'`
if [ -z "$endpoint" ]; then
   openstack endpoint create \
     --publicurl http://controller:5000/v2.0 \
     --internalurl http://controller:5000/v2.0 \
     --adminurl http://controller:35357/v2.0 \
     --region $REGION_NAME \
     identity
fi

# Create projects, users, and roles
openstack project create --description "Admin Project" admin > /dev/null 2>&1
openstack user create --password $ADMIN_PASS admin > /dev/null 2>&1
openstack role create admin > /dev/null 2>&1
openstack role add --project admin --user admin admin > /dev/null 2>&1

openstack project create --description "Service Project" $ADMIN_TENANT_NAME > /dev/null 2>&1
openstack project create --description "Demo Project" demo > /dev/null 2>&1
openstack user create --password $DEMO_PASS demo > /dev/null 2>&1
openstack role create user > /dev/null 2>&1
openstack role add --project demo --user demo user > /dev/null 2>&1

# Foe Heat Service
openstack role create heat_stack_owner > /dev/null 2>&1
openstack role add --project demo --user demo heat_stack_owner > /dev/null 2>&1
openstack role create heat_stack_user > /dev/null 2>&1

unset OS_TOKEN OS_URL
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://controller:35357/v3

# user / role / endpoint create for Glance Service
openstack user create --password $GLANCE_PASS glance > /dev/null 2>&1
openstack role add --project $ADMIN_TENANT_NAME --user glance admin > /dev/null 2>&1
name=`openstack service list | awk '/ image / {print $2}'`
if [ -z $name ]; then
   openstack service create --name glance --description "OpenStack Image service" image
fi

# Endpoint create for glance service
endpoint=`openstack endpoint list | awk '/ image / {print $2}'`
if [ -z "$endpoint" ]; then
   openstack endpoint create \
     --publicurl http://controller:9292 \
     --internalurl http://controller:9292 \
     --adminurl http://controller:9292 \
     --region $REGION_NAME \
     image
fi

# user / role / endpoint create for Nova Service
openstack user create --password $NOVA_PASS nova > /dev/null 2>&1
openstack role add --project $ADMIN_TENANT_NAME --user nova admin > /dev/null 2>&1
name=`openstack service list | awk '/ compute / {print $2}'`
if [ -z $name ]; then
   openstack service create --name nova --description "OpenStack Compute" compute
fi

# Endpoint create for nova service
endpoint=`openstack endpoint list | awk '/ compute / {print $2}'`
if [ -z "$endpoint" ]; then
   openstack endpoint create \
     --publicurl http://controller:8774/v2/%\(tenant_id\)s \
     --internalurl http://controller:8774/v2/%\(tenant_id\)s \
     --adminurl http://controller:8774/v2/%\(tenant_id\)s \
     --region $REGION_NAME \
     compute
fi

# user / role / endpoint create for Neutron Service
openstack user create --password $NEUTRON_PASS neutron > /dev/null 2>&1
openstack role add --project $ADMIN_TENANT_NAME --user neutron admin > /dev/null 2>&1
name=`openstack service list | awk '/ network / {print $2}'`
if [ -z $name ]; then
   openstack service create --name neutron --description "OpenStack Networking" network
fi

# Endpoint create for neutron service
endpoint=`openstack endpoint list | awk '/ network / {print $2}'`
if [ -z "$endpoint" ]; then
   openstack endpoint create \
     --publicurl http://controller:9696 \
     --adminurl http://controller:9696 \
     --internalurl http://controller:9696 \
     --region $REGION_NAME \
     network
fi

# user / role / endpoint create for Heat Service
openstack user create --password $HEAT_PASS heat > /dev/null 2>&1
openstack role add --project $ADMIN_TENANT_NAME --user heat admin > /dev/null 2>&1
name=`openstack service list | awk '/ orchestration / {print $2}'`
if [ -z $name ]; then
   openstack service create --name heat --description "Orchestration" orchestration
fi

name=`openstack service list | awk '/ cloudformation / {print $2}'`
if [ -z $name ]; then
   openstack service create --name heat-cfn --description "Orchestration" cloudformation
fi

# Endpoint create for heat service
endpoint=`openstack endpoint list | awk '/ orchestration / {print $2}'`
if [ -z "$endpoint" ]; then
   openstack endpoint create \
     --publicurl http://controller:8004/v1/%\(tenant_id\)s  \
     --internalurl http://controller:8004/v1/%\(tenant_id\)s \
     --adminurl http://controller:8004/v1/%\(tenant_id\)s  \
     --region $REGION_NAME \
     orchestration
fi

endpoint=`openstack endpoint list | awk '/ cloudformation / {print $2}'`
if [ -z "$endpoint" ]; then
   openstack endpoint create \
     --publicurl http://controller:8000/v1  \
     --internalurl http://controller:8000/v1 \
     --adminurl http://controller:8000/v1  \
     --region $REGION_NAME \
     cloudformation 
fi

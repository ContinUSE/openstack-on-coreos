# Heat Usage
Heat is the OpenStack orchestration program. This document is included hands-on explore OpenStack orchestration using Heat.

## Create Heat Domain (each user)
This procedure is only one excution each user, after MySQL Database Initial.

Source the admin credentials to gain access to admin-only CLI commands on controller
```
LOGIN TO CONTROLLER

$ export OS_TENANT_NAME=admin
$ export OS_USERNAME=admin
$ export OS_PASSWORD=adminpass
$ export OS_AUTH_URL=http://controller:5000/v2.0/
$ export OS_NO_CACHE=1

$ heat-keystone-setup-domain --stack-user-domain-name heat_user_domain \
$ --stack-domain-admin heat_domain_admin \
$ --stack-domain-admin-password $HEAT_DOMAIN_PASS
```

## Single Compute Instacne
To show how Heat works, below you can see a very simple HOT template.

#### login to controller

```
On Mac
$ vagrant ssh controller-03

On CoreOS (controller)
$ connect
$
```

#### excute admin_openrc.sh

```
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://controller:35357/v3
export OS_IMAGE_API_VERSION=2
```

#### make a template file (create file as test1.yaml)

```
heat_template_version: 2014-10-16

description: Simple template to deploy a single compute instance

resources:
  my_instance:
    type: OS::Nova::Server
    properties:
      image: cirros-0.3.3-x86_64
      flavor: m1.tiny
      key_name: myKey
      networks:
        - network: private
```

#### create instance

```
$ heat stack-create stack1 -f test1.yaml
+--------------------------------------+------------+--------------------+----------------------+
| id                                   | stack_name | stack_status       | creation_time        |
+--------------------------------------+------------+--------------------+----------------------+
| 957cc4f3-3baa-4a0d-acce-740693c017cc | stack1     | CREATE_IN_PROGRESS | 2015-06-24T06:55:14Z |
+--------------------------------------+------------+--------------------+----------------------+
```

#### show status

```
$ heat stack-show stack1
```

#### delete instacne

```
$ heat stack-delete stack1
```

## Single Compute Instance with parameters

#### make a template file (create file as test2.yaml)

```
heat_template_version: 2014-10-16

description: Simple template to deploy a single compute instance

parameters:
  image:
    type: string
    label: Image name or ID
    description: Image to be used for compute instance
    default: cirros-0.3.3-x86_64
  flavor:
    type: string
    label: Flavor
    description: Type of instance (flavor) to be used
    default: m1.tiny
  key:
    type: string
    label: Key name
    description: Name of key-pair to be used for compute instance
    default: myKey
  private_network:
    type: string
    label: Private network name or ID
    description: Network to attach instance to.
    default: private

resources:
  my_instance:
    type: OS::Nova::Server
    properties:
      image: { get_param: image }
      flavor: { get_param: flavor }
      key_name: { get_param: key }
      networks:
        - network: { get_param: private_network }

outputs:
  instance_ip:
    description: IP address of the instance
    value: { get_attr: [my_instance, first_address] }

```

#### Create Instance
```
$ heat stack-create stack2 -f test2.yaml -P key=myKey;image=cirros-0.3.3-x86_64"
```


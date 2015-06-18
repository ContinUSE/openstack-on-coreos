# OpenStack Dockerizing
OpenStack is obtaining using Docker/CoreOS the following advatages :
* Easy to Deploy
* Easy to Test
* Easy to Scale-out
* Fault Tolerance

##### Controller Image
* Image Name : continuse/openstack-controller:juno
* provide service : MySQL, RabbitMQ, Keystone, Glance, Nova, Neutron

##### Network Image
* Image Name : continuse/openstack-network:juno
* provide service : Distributed Virtual Router / L3 HA with VxLAN

##### Compute Image
* Images Name : continuse/openstack-compute:juno
* provide service : Libvirt, Nova, Netron

##### Nova-docker Image
* Images Name : continuse/openstack-nova-docker:juno
* provide service : nova-docker, Netron

**Currently, these images support Operating System is only  CoreOS, but I plan to develop for any Linux that supports Docker Service.In addition, I will update for the other service of OpenStack, such as swift, cinder etc.**

Regarding the installation, please refer to the link 
https://github.com/ContinUSE/openstack-on-coreos


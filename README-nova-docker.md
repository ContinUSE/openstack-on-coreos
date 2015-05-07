# Nova-docker driver
The Docker driver is a hypervisor driver, it is support to Openstack Nova Compute. The driver lives out-of-tree for juno, but I am trying to make docker container just like Nova Compute Container. Now I'm testing this driver, and I think that needed to orchestrating docker tool.

## nova-docker service start
Any Host Login to One of the CoreOS Cluster Nodes. And Nova-docker service starting. 
```
# vagrant ssh core-05

on coreos
$ cd /continuse/service
$ fleetctl start nova-docker@1.service
```

## Docker Image Upload to Glance
```
$ connect nova-docker

# export OS_TENANT_NAME=admin
# export OS_USERNAME=admin
# export OS_PASSWORD=adminpass
# export OS_AUTH_URL=http://controller:5000/v2.0/
# export OS_NO_CACHE=1

== cirros & redis image pulling. ==
# docker pull cirros
# docker pull redis

== image upload to Glance
# docker save cirros | glance image-create --is-public=True --container-format=docker --disk-format=raw --name redis
```
**The docker driver is getting information the only container name from Glance Image Service, so the image is registered in the Glance Image Service using the small size of cirros image as named redis. To launch instance, using the image stored in the node which running nova-dokcer driver, and DOES NOT USE Glance Image Service.MUST BE PULLING docker image on nova-docker host. If you do not PULLING THE IMAGES, fail to launch instance.**

## Launch Instance
You can make instance using Project->Instance menu on Horizon (Dashboard), and allocate a floating public IP.

## Docker Container Running Check & Test
Login to CoreOS host which does not running neutron service. Because 
```
# vagrant ssh core-02

$ sudo docker run --rm -it redis redis-cli -h 10.0.5.101

```
## Issues
I need more time to test for nova-docker driver features. The Live Migration feature is not available on Nova-docker driver, so sophisticated tool is required for normal use.



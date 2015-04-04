# OpenStack Controller
This image contains MySQL Server, Keystone, Glance, Nova, Horizon service running designed by CoreOS using the shared disk for fault tolerance features.
Please reder to https://github.com/ContinUSE/openstack-on-coreos

##The sample service file is as folows:

```
[Unit]
Description=Controller for OpenStack:JUNO
Requires=docker.service
After=docker.service

[Service]
ExecStartPre=-/usr/bin/docker kill controller
ExecStartPre=-/usr/bin/docker rm controller
ExecStartPre=/bin/bash -c ". /etc/profile.d/myenv.sh; \
/usr/bin/etcdctl set /OPENSTACK/CONTROLLER/IPADDR $MYIPADDR"
ExecStart=/bin/bash -c \
". /etc/profile.d/myenv.sh; \
/usr/bin/docker run --hostname=controller --privileged=true \
--name controller \
--env TIME_ZONE=Asia/Seoul \
--env ADMIN_TOKEN=ADMIN \
--env REGION_NAME=RegionOne \
--env MYSQL_ROOT_PASSWORD=openstack \
--env KEYSTONE_DBPASS=openstack \
--env GLANCE_DBPASS=openstack \
--env NOVA_DBPASS=openstack \
--env RABBIT_PASS=rabbitpass \
--env ADMIN_TENANT_NAME=service \
--env ADMIN_PASS=adminpass \
--env DEMO_PASS=demopass \
--env KEYSTONE_PASS=keystonepass \
--env GLANCE_PASS=glancepass \
--env NOVA_PASS=novapass \
--publish 3306:3306 \
--publish 5672:5672 \
--publish 35357:35357 \
--publish 5000:5000 \
--publish 9292:9292 \
--publish 8774:8774 \
--publish 80:80 \
--publish 6080:6080 \
-v /etc/localtime:/etc/localtime \
-v /home/core/continuse:/continuse \
-v /home/core/continuse/shared/mysql:/data \
-v /home/core/continuse/shared/glance:/var/lib/glance \
continuse/openstack-controller:juno"
ExecStop=-/usr/bin/docker stop controller

[X-Fleet]
Conflicts=compute*
Conflicts=controller*
```

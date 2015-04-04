# OpenStack Compute
This image contains Nova service running designed by CoreOS using the shared disk for fault tolerance features. Please reder to https://github.com/ContinUSE/openstack-on-coreos

The sample service file is as folows:
```
[Unit]
Description=Compute %i for OpenStack:JUNO
Requires=docker.service
After=docker.service

[Service]
ExecStartPre=-/usr/bin/docker kill compute
ExecStartPre=-/usr/bin/docker rm compute
ExecStart=/bin/bash -c "\
. /etc/profile.d/myenv.sh; \
/usr/bin/docker run --net=host --privileged=true \
--name compute \
--env ETCDCTL_PEERS=10.10.0.101:4001,10.10.0.102:4001,10.10.0.103:4001,10.10.0.104:4001 \
--env RABBIT_PASS=rabbitpass \
--env MYIPADDR=$MYIPADDR \
--env ADMIN_TENANT_NAME=service \
--env NOVA_PASS=novapass \
--env IF_NAME=docker0 \
-v /etc/localtime:/etc/localtime \
-v /home/core/continuse:/continuse \
-v /home/core/continuse/data/nova:/var/lib/nova/instances \
-v /sys/fs/cgroup:/sys/fs/cgroup \
-v /lib/modules:/lib/modules \
continuse/openstack-compute:juno"
ExecStop=-/usr/bin/docker stop compute

[X-Fleet]
Conflicts=controller*
Conflicts=compute*
```

# OpenStack on CoreOS

CoreOS provide ease of cluster managing such as fault tolerance and scaleability features.
OpenStack operation need to high availability features in real world. So I am trying to make docker container according to CoreOS for OpenStack Operation Environments.
* Controller / Compute Service Start Automation
* When a server failure using shared disk (such as NFS on gluster filesystem), minimize the loss data after restart the service. (MySQL Data, Glance Images, Nova Instances etc.)
* CoreOS etcd and fleet service provide by a rapid recovery, and easy scalability server node.

## Docker Container
* ``Controller`` has MySql server, Keystone, Glance, Nova and Horizon service.
* ``Compute`` has only using nova-network service.
* The remaining services are expected to apply in the future
* The Dockerfile information contains in docker-files directory.
* The docker container images located in hub.docker.com, the named as ``continuse/openstack-controller:juno`` and ``continuse/openstack-compute:juno``.

## CoreOS Installation
My development environment is as VirtualBox and Vagrant on Mac OSX (dual core i5 and 16G memory). Please refer to the website https://coreos.com about CoreOS installation.

The below installation procedure is an example of my development environment.

1) Install dependencies

* [VirtualBox][virtualbox] 4.3.10 or greater.
* [Vagrant][vagrant] 1.6 or greater.

2) Update discovery URL in coreos/user-date

* getting the discovery URL
```
$ curl -w "\n" 'https://discovery.etcd.io/new?size=3'
https://discovery.etcd.io/6a28e078895c5ec737174db2419bb2f3
```
* Be sure to replace ``<token>`` with your discovery URL
```
coreos:
  etcd:
    # generate a new token for each unique cluster from https://discovery.etcd.io/new
    # WARNING: replace each time you 'vagrant destroy'
    discovery: <token>
    addr: $public_ipv4:4001
    peer-addr: $public_ipv4:7001
```

3) Update your Timezone in coreos/user-data

You will need to modify the set-timezeone field in your timezone as below. The default value is ``UTC``. If your location is in Korea, to set Asia/Seoul.
```
[Service]
ExecStart=/usr/bin/timedatectl set-timezone UTC
```

4) Update basic CoreOS cluster information in coreos/config.rb

**The number of servers in the cluster (min 4 nodes for basic test)**
```
# Size of the CoreOS cluster created by Vagrant
$num_instances=4
```
**choose for CoreOS (stable, beta or alpha)**
```
# Official CoreOS channel from which updates should be downloaded
$update_channel='stable'
```
**Set Up for VirtualBox VMs**

For testing, vm_memory is over 2048, and vb_cpus is over 2.
```
#$vb_gui = false
$vb_memory = 2048
$vb_cpus = 2
```

5) Update Vagrant information in coreos/Vagrantfile

**Network Interface**
```
config.vm.network :private_network, ip: "172.16.0.#{i+100}", :netmask => "255.255.0.0"
config.vm.network :private_network, ip: "10.10.0.#{i+100}", :netmask => "255.255.0.0"
```
**NFS Mount**

For testing.....if you have unzip in $HOME/abc, you can found the directory is as follows:
* $HOME/abc/coreos/continuse
* $HOME/abc/coreos/continuse/service : contains service file for fleet service
* $HOME/abc/coreos/continuse/script : sample image file and etc.
* $HOME/abc/coreos/continuse/shared 
* $HOME/abc/coreos/continuse/shared/mysql : mysql shared data
* $HOME/abc/coreos/continuse/shared/glance : glance image shared data
* $HOME/abc/coreos/continuse/shared/nova : nova instances shared data

You can modify as below in coreos/Vagrantfile for just like shared disk.
```
config.vm.synced_folder "~abc/coreos/continuse", "/continuse", id: "core", :nfs => true, :mount_options =>  ["nolock,vers=3,udp"], :map_uid => 0, :map_gid => 0
```
6) Start the machine(s)
If you have unzip in $HOME/abc..
```
$ cd $HOME/abc/coreos
$ vagrant up
```
During procedures for ``vagrant up`` need to your admin password for NFS mount.

List the status of the running machines:
```
$ vagrant status
Current machine states:

core-01                   running (virtualbox)
core-02                   running (virtualbox)
core-03                   running (virtualbox)
core-04                   running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
$
```
Connect to one of the machines:
```
$ vagrant ssh core-01 -- -A
```

## Pulling the docker container images 
I could not use attached storage for docker. (refer to https://coreos.com/docs/cluster-management/setup/mounting-storage/#use-attached-storage-for-docker). Because my test environment does not support btrfs file system device.

For the test environment, you have to pulling the images for all nodes.
```
On Mac
$ vagrant ssh core-01 -- -A

On CoreOS
$ sudo docker pull continuse/openstack-controller:juno
$ sudo docker pull continuse/openstack-compute:juno
```
If you do not the pulling images, it takes a lot of time at the beginning of services.

## Service File Modify

First, connect to one of the machines
```
$ vagrant ssh core-01 -- -A
```

**Edit /continuse/service/controller.service**
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
-v /continuse:/continuse \
-v /continuse/shared/mysql:/data \
-v /continuse/shared/glance:/var/lib/glance \
continuse/openstack-controller:juno
ExecStop=-/usr/bin/docker stop controller

[X-Fleet]
Conflicts=compute*
Conflicts=controller*
```

You can change the values are only the values as ``TIME_ZONE`` ``ADMIN_TOKEN`` ``REGION_NAME`` ``MYSQL_ROOT_PASSWORD`` ``KEYSTONE_DBPASS`` ``GLANCE_DBPASS`` ``NOVA_DBPASS`` ``RABBIT_PASS`` ``ADMIN_TENANT_NAME`` ``ADMIN_PASS`` ``DEMO_PASS`` ``KEYSTONE_PASS`` ``GLANCE_PASS`` ``NOVA_PASS``

The rest DO NOT CHANGE...

**Edit /continuse/service/compute@.service**
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
-v /continuse:/continuse \
-v /continuse/shared/nova:/var/lib/nova/instances \
-v /sys/fs/cgroup:/sys/fs/cgroup \
-v /lib/modules:/lib/modules \
openstack-compute:juno"
ExecStop=-/usr/bin/docker stop compute

[X-Fleet]
Conflicts=controller*
Conflicts=compute*
```
``ETCDCTL_PEERS`` value is listed all nodes's IP address:4001 separated with ','.

``RABBIT_PASS``  ``ADMIN_TENANT_NAME`` ``NOVA_PASS`` value is the same as in controller.service file.

``IF_NAME`` is name of bridge, I am using the default docker bridge by docker service.

## Usage
### Service Start / Stop / Destroy

connect to one of the machines:

**controller service start**
```
On Mac
$ cd $HOME/abc/coreos
$ vagrant ssh core-01 -- -A

On CoreOS
Last login: Fri Apr  3 12:11:03 2015 from 10.0.2.2
CoreOS stable (607.0.0)
$ cd /continuse/service
$ fleetctl start controller.service
```
The unit should have been scheduled to a machine in your cluster.
You can know which machine run the service.
```
$ fleetctl list-units
UNIT                MACHINE                  ACTIVE     SUB
controler.serv     c9de9451.../10.10.0.102   active    running
```
**compute service start**
```
On Mac
$ fleetctl start compute@1.service
$ fleetctl list-units
UNIT                MACHINE                  ACTIVE     SUB
controler.serv     c9de9451.../10.10.0.102   active    running
compute@1.serv     c8df8921.../10.10.0.103   active    running

```
If your computer has more resource such as memory/cpu, you can run over two node of compute service. For instance, two node compute service starting is as :
```
$ fleetctl start compute@{1..2}.service
```
**service stop**

If you want to stop the service. The stop means that stop the service, but service information remains the cluster.
```
$ fleetctl stop controller.service
$ fleetctl stop compute@1.service
```
**service destroy**

This command effective that the service information removed from the cluster.
```
$ fleetctl destroy controller.service
$ fleetctl destroy compute@{1..2}.service
```

###Log Monitoring
You can view a log of each service in a realtime.
```
$ fleetctl journal -f controller.service
$ fleetctl journal -f compute@1.service
```
If you got an error such as ``public key.....``, the below script excute for ``ALL NODE`` on Mac.
```
$ cd $HOME/abc/coreos
$ vagrant ssh-config --host core-01 >> ~/.ssh/config
$ vagrant ssh-config --host core-01 | sed -n "s/IdentityFile//gp" | xargs ssh-add
```
###Log on to controller
You can get the IP Address through the ``fleetctl list-unins`` command for the controller host.

**logon to controller running host**

For instance : the controller service running on core-02
```
$ vagrant ssh core-02 -- -A
on CoreOS
$ sudo docker exec -i -t controller /bin/bash
```

Source the admin credentials to gain access to admin-only CLI commands on controller
```
$ export OS_TENANT_NAME=admin
$ export OS_USERNAME=admin
$ export OS_PASSWORD=adminpass
$ export OS_AUTH_URL=http://controller:5000/v2.0/
$ export OS_NO_CACHE=1
```
Glance Image Upload
```
$ cd /continuse/script
$ glance image-create \
     --name "cirros-0.3.3-x86_64" \
     --file cirros-0.3.3-x86_64-disk.img \
     --disk-format qcow2 --container-format bare \
     --is-public True \
     --progress
```

Nova network creation
```
$ nova net-create test-net 172.17.42.1/16
$ nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
$ nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 
```

###Using Dashboard
You can get the IP Address through the ``fleetctl list-unins`` command for the controller host. Access the dashboard using a web browser: http://controller-ip-addr/horizon/. For instance http://10.10.0.102/horizon/

## Fault Tolerance Test
You can get IP address for running controller service using ``fleetctl list-units`` command.

**Controller node fail test**
```
On Mac
$ cd $HOME/abc/coreos
$ vagrant halt core-02
....halted
$ vagrant ssh core-01 -- -A

On CoreOS
$ fleetctl list-units
.....(YOU CAN SHOW THE INFORMATION ABOUT controller.service RUNNING STATUS)
-----(rebooting core-02 for Next Test)

On Mac
$ vagrant up core-02
```


Confirm to access the dashboard for new controller service.

**Compute node fail test**

If you have more two node of compute service running, the one compute service node fail test.
```
On Mac
$ cd $HOME/abc/coreos
$ vagrant halt core-03
...halted..
$ vagrant ssh core-1 -- -A

On CoreOS
$ fleetctl list-units
.....(YOU CAN SHOW THE INFORMATION ABOUT comput@?.service RUNNING STATUS)
-----(rebooting core-03 for Next Test)

On Mac
$ vagrant up core-03
```
**VM recovery from failed compute node**

For instance : the controller service running on core-02
```
$ vagrant ssh core-02 -- -A
on CoreOS
$ sudo docker exec -i -t controller /bin/bash
```

Source the admin credentials to gain access to admin-only CLI commands on controller
```
$ export OS_TENANT_NAME=admin
$ export OS_USERNAME=admin
$ export OS_PASSWORD=adminpass
$ export OS_AUTH_URL=http://controller:5000/v2.0/
$ export OS_NO_CACHE=1
```
VM Migration

If one VM ran on core-03, you have to migrate to another compute node.
```
On controller
$ nova evacuate vm-demo01 core-04 –-on-shared-storage
```
Confirm to access the dashboard for migration VM.

## Future Works

To review the possiblity of other OpenStack Service on this platform.

[virtualbox]: https://www.virtualbox.org/
[vagrant]: https://www.vagrantup.com/downloads.html
[using-coreos]: http://coreos.com/docs/using-coreos/

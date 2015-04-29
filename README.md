# OpenStack on CoreOS (OpenStack Dockerizing)

CoreOS provide ease of cluster managing such as fault tolerance and scaleability features.
OpenStack operation need to high availability features in real world. So I am trying to make docker container according to CoreOS for OpenStack Operation Environments.
* Controller / Network / Compute Service Start Automation
* When a server failure using shared disk (such as NFS on gluster filesystem), minimize the data lose after restart the service. (MySQL Data, Glance Images, Nova Instances etc.)
* CoreOS etcd and fleet service provide by a rapid recovery, and easy scalability server node.

And also OpenStack is obtaining using Docker/CoreOS the following advatages :
* Easy to Deploy
* Easy to Test
* Easy to Scale-out
* Fault Tolerance

## Test Environments
#####Install dependencies

* [VirtualBox][virtualbox] 4.3.10 or greater.
* [Vagrant][vagrant] 1.6 or greater.

This is a muti-node cluster proof-of-concept that includes setting up the external connectivity to VMs using Virtualbox environment. We have to setup for Virtualbox network option is as follows:

1) Open Virtualbox

2) Navigate to the Network Preferences

3) Create a new NAT Network and name it “NatNetwork”, Edit Network CIDR "10.0.5.0/24" and Unselect “supports DHCP”

#####Usage of Network Interface:

| Device | Role  | IP Range |
|--------|--------|---------|
| eth0 |  NAT (Default Route)      | 10.0.2.XX |
| eth1 | External Network (The above special setting of NAT) | 10.0.5.XX |
| eth2 | Tunneling | 172.16.0.XX |
| eth3 | Data Management | 192.168.10.XX |

## Docker Container
##### Controller Image
* Image Name : continuse/openstack-controller:juno
* provide service : MySQL, RabbitMQ, Keystone, Glance, Nova, Neutron

##### Network Image
* Image Name : continuse/openstack-network:juno
* provide service : Distributed Virtual Router / L3 HA with VxLAN

##### Compute Image
* Images Name : continuse/openstack-compute:juno
* provide service : Libvirt, Nova, Netron

**Currently, these images support Operating System is only  CoreOS, but I plan to develop for any Linux that supports Docker Service.In addition, I will update for the other services of OpenStack, such as swift, cinder service etc.**

## CoreOS Installation
My development environment is as VirtualBox and Vagrant on Mac OSX (dual core i5 and 16G memory). Please refer to the website https://coreos.com about CoreOS installation.

The below installation procedure is an example of my development environment.

1) Update "discovery URL" in coreos/user-data file

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

2) Update your Timezone in coreos/user-data file

You will need to modify the set-timezeone field in your timezone as below. The default value is ``Asia/Seoul``. If your location is in Korea, to set UTC.
```
[Service]
ExecStart=/usr/bin/timedatectl set-timezone UTC
```

3) Update basic CoreOS cluster information in coreos/config.rb

**The number of servers in the cluster (min 5 nodes for Fault Tolerance)**
```
# Size of the CoreOS cluster created by Vagrant
$num_instances=5
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

4) Update Vagrant information in coreos/Vagrantfile

Do NOT EDIT "Vagrantfile" ecept for NFS mount path for test.

**Network Interface**
```
config.vm.network :private_network, ip: "10.0.5.#{i+10}", :adapter => 2
config.vm.network :private_network, ip: "172.16.0.#{i+10}", :netmask => "255.255.0.0", :adapter => 3
config.vm.network :private_network, ip: "192.168.10.#{i+10}", :netmask => "255.255.255.0", :adapter => 4
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
config.vm.synced_folder "~/abc/coreos/continuse", "/continuse", id: "root", :nfs => true, :mount_options =>  ["nolock,vers=3,udp"], :map_uid => 0, :map_gid => 0
```
5) Start the machine(s)
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
core-05                   running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
$
```
You can connect to one of the machines the following vagrant ssh command:
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
$ sudo docker pull continuse/openstack-network:juno
$ sudo docker pull continuse/openstack-compute:juno
```
**If you do not the pulling images, it takes a lot of time at the beginning of services.**

## Service File Modification

First, connect to one of the machines
```
$ vagrant ssh core-01 -- -A
```

Neutron Service provide Distributed Virtual Router and L3 HA options. This docker images can configured to select one. 

**If you want to configure Distributed Virtual Router, to modify ""--env HA_MODE=DVR" option in three files.** 

**If you want to configure L3 HA, to modify ""--env HA_MODE=L3_HA" option in three files.** 

* /continuse/service/controller.service
* /continuse/service/network@.service
* /continuse/service/compute@.service

If you want to change the rest variables in these service files.

**NOTE: MUST BE THE SAME for the same environment variable at the three service files.**

example) If you want to configure ``HA_MODE=DVR``, ALL service files (controller.service, network@.service, compute@.service) set to ``HA_MODE=DVR`` as the same.

## Data Initialization

YOU MUST BE DATA INITIALIZATION, AFTER THE CHAGE ``HA_MODE`` VALUE.
* Glance Image Data Remove

        $ rm -rf /continuse/shared/glance/*

* MySQL Data Remove
        $ rm -rf /continuse/shared/mysql/*

* Nova Instance Data Remove
        $ rm -rf /continuse/shared/nova/*




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
**network service start (2 node service start for HA)**
```
$ fleetctl start network@{1..2}.service
```

**compute service start**
```
$ fleetctl start compute@1.service
```

The unit should have been scheduled to a machine in your cluster.
You can know which machine run the service.
```
$ fleetctl list-units
UNIT			    MACHINE				        ACTIVE	SUB
compute@1.service	68b75b56.../192.168.10.15	active	running
controller.service	01df5f39.../192.168.10.14	active	running
network@1.service	154fea9e.../192.168.10.11	active	running
network@2.service	0d348a8e.../192.168.10.13	active	running
```

**service stop**

If you want to stop the service. The stop means that stop the service, but service information remains the cluster.
```
$ fleetctl stop controller.service
$ fleetctl stop network@2.service
$ fleetctl stop compute@1.service
```
**service destroy**

This command effective that the service information removed from the cluster.
```
$ fleetctl destroy controller.service
$ fleetctl destroy network@{1..2}.service
```

###Log Monitoring
You can view a log of each service in a realtime.
```
$ fleetctl journal -f controller.service
$ fleetctl journal -f network@2.service
$ fleetctl journal -f compute@1.service
```
If you got an error such as ``public key.....``, the below script excute for ``ALL NODE`` on Mac.
```
$ cd $HOME/abc/coreos
$ vagrant ssh-config --host core-01 >> ~/.ssh/config
$ vagrant ssh-config --host core-01 | sed -n "s/IdentityFile//gp" | xargs ssh-add
```
###Login to controller / Network / Compute Node
You can get the IP Address through the ``fleetctl list-unins`` command for the controller host.

```
$ fleetctl list-units
UNIT			    MACHINE				        ACTIVE	SUB
compute@1.service	68b75b56.../192.168.10.15	active	running  ==> core-05
controller.service	01df5f39.../192.168.10.14	active	running  ==> core-04
network@1.service	154fea9e.../192.168.10.11	active	running  ==> core-01
network@2.service	0d348a8e.../192.168.10.13	active	running  ==> core-03
```

**login to controller running host**

For instance : the controller service running on core-04
```
$ vagrant ssh core-04 -- -A
on CoreOS
$ connect controller
```
Network / Compute Node connection method
```
=== Network Node ===
login to core-01 or core-03
$ connect network

=== Compute Node ===
login to core-05 
$ connect compute
```

### Image Upload & Create Network etc. on Controller

```
Login to core-04
$ connect controller

# 
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

Nova security group add
```
$ nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
$ nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 
```

External Network and Subnet Creation
```
neutron net-create public --router:external True \
    --provider:network_type flat \
    --provider:physical_network external

neutron subnet-create --name public-subnet \
    --gateway 10.0.5.1 \
    --allocation-pool start=10.0.5.100,end=10.0.5.200 \
    --disable-dhcp public 10.0.5.0/24
```

Private Network Creation
```
neutron net-create private
neutron subnet-create --name private-subnet private \
    10.10.0.0/24 --dns-nameserver 10.0.5.1
```

Router Creation (HA_MODE=L3_HA)
```
neutron router-create router  --ha True
neutron router-interface-add router private-subnet
neutron router-gateway-set router public
```

Router Creation (HA_MODE=DVR)
```
neutron router-create router  --ha False
neutron router-interface-add router private-subnet
neutron router-gateway-set router public
```

Keypair Generation
```
nova keypair-add myKey > myKey.pem
chmod 0600 myKey.pem
```

###Using Dashboard
You can get the IP Address through the ``fleetctl list-unins`` command for the controller host. Access the dashboard using a web browser: http://controller-ip-addr/horizon/. For instance http://192.168.10.14/horizon/ (ID : admin, Password : adminpass)

In my case to change RAM size 512M to 64M in m1.tiny in flavor. And Launch Instance to select network "private".

Floating IP Create on the controller
```
controller:/continuse/script# neutron floatingip-create public
Created a new floatingip:
+---------------------+--------------------------------------+
| Field               | Value                                |
+---------------------+--------------------------------------+
| fixed_ip_address    |                                      |
| floating_ip_address | 10.0.5.101                           |
| floating_network_id | dd3e01a0-26ad-49eb-b003-0cf2770a6388 |
| id                  | ca880356-9c38-4587-b10f-ce27d2f58436 |
| port_id             |                                      |
| router_id           |                                      |
| status              | DOWN                                 |
| tenant_id           | ade4c04bb5fb4185bc3e52365ea547dc     |
+---------------------+--------------------------------------+
```

Floating IP associate
```
nova floating-ip-associate demo01 10.0.5.101
```

Connect to VM
```
controller:/continuse/script# ssh cirros@10.0.5.101 -i myKey.pem
The authenticity of host '10.0.5.101 (10.0.5.101)' can't be established.
RSA key fingerprint is 3d:cd:c1:40:f3:58:01:2f:a0:1a:13:a2:87:8d:16:ae.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.0.5.101' (RSA) to the list of known hosts.
$
$
$
$ ping openstack.org
PING openstack.org (162.242.140.107): 56 data bytes
64 bytes from 162.242.140.107: seq=0 ttl=45 time=682.501 ms
64 bytes from 162.242.140.107: seq=1 ttl=45 time=493.169 ms
64 bytes from 162.242.140.107: seq=2 ttl=45 time=314.223 ms
^C
--- openstack.org ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 314.223/496.631/682.501 ms
$
```


## Fault Tolerance Test
You can get IP address for running controller service using ``fleetctl list-units`` command.

**Controller node fail test**
```
On Mac
$ vagrant halt core-04
==> core-04: Attempting graceful shutdown of VM...
$ vagrant up core-04
Bringing machine 'core-04' up with 'virtualbox' provider...
==> core-04: Checking if box 'coreos-stable' is up to date...
==> core-04: Clearing any previously set forwarded ports...
.
.
.
.

$ vagrant ssh core-01
Last login: Wed Apr 29 14:31:02 2015 from 10.0.2.2
CoreOS stable (633.1.0)
core@core-01 ~ $ fleetctl list-units
UNIT			MACHINE				ACTIVE	SUB
compute@1.service	68b75b56.../192.168.10.15	active	running
controller.service	8f6fcefb.../192.168.10.12	active	running
network@1.service	154fea9e.../192.168.10.11	active	running
network@2.service	0d348a8e.../192.168.10.13	active	running
$
```
You will found controller.service running on core-02 from core-04. For verification, to connect dashboard "http://192/168.10.12/horizon/" and YOU CAN ANY ACTION IS NO PROBLEM.

**Network Node / Compute Node Fail Test is the same as the above controller node fail test.**
In Case Of HA_MODE=L3_HA, there is no problem in network node fail test, but HA_MODE=DVR does not support failover. Because currently "snat" namespace could not move to the another host.

## VM Migration

If you want to compute node fail test, YOU NEED TO VM MIGRATION.
If one VM ran on core-05 and your new service of compute@1.service run on core-04, you will need the following the action on controller node.
```
On controller
$ nova evacuate demo01 core-04 –-on-shared-storage
```
Confirm to access the dashboard for migration VM.



[virtualbox]: https://www.virtualbox.org/
[vagrant]: https://www.vagrantup.com/downloads.html
[using-coreos]: http://coreos.com/docs/using-coreos/

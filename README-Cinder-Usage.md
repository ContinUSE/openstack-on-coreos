# Block Storage Service
This docker image has been testing using NFS Server. I'm planning to support Gluster File System Cluster or Ceph Cluster with Cinder Service ASAP.

## cinder cluster start (Now only one node for test)
```
On Mac
$ cd cinder
$ vagrant up
......
.....
$ vagrant ssh cinder-01
On CoreOS
$ sudo docker pull continuse/openstack-cinder:kilo 
```

## cinder service start using fleetctl command
On the controller node
```
$ cd /continuse/service
$ fleetctl start cinder.service
```

## Block Storage Attaching Test Procedure

On the Controller Node
```
$ export OS_PROJECT_DOMAIN_ID=default
$ export OS_USER_DOMAIN_ID=default
$ export OS_PROJECT_NAME=admin
$ export OS_TENANT_NAME=admin
$ export OS_USERNAME=admin
$ export OS_PASSWORD=$ADMIN_PASS
$ export OS_AUTH_URL=http://controller:35357/v3
$ export OS_IMAGE_API_VERSION=2
$ export OS_VOLUME_API_VERSION=2

$ cinder service-list
+------------------+---------------+------+---------+-------+----------------------------+-----------------+
|      Binary      |      Host     | Zone |  Status | State |         Updated_at         | Disabled Reason |
+------------------+---------------+------+---------+-------+----------------------------+-----------------+
| cinder-scheduler |   controller  | nova | enabled |   up  | 2015-07-09T06:05:13.000000 |       None      |
|  cinder-volume   | cinder-01@nfs | nova | enabled |   up  | 2015-07-09T06:05:14.000000 |       None      |
+------------------+---------------+------+---------+-------+----------------------------+-----------------+

$ cinder create --display_name disk01 1
+---------------------------------------+--------------------------------------+
|                Property               |                Value                 |
+---------------------------------------+--------------------------------------+
|              attachments              |                  []                  |
|           availability_zone           |                 nova                 |
|                bootable               |                false                 |
|          consistencygroup_id          |                 None                 |
|               created_at              |      2015-07-09T06:06:53.000000      |
|              description              |                 None                 |
|               encrypted               |                False                 |
|                   id                  | 47629300-da8d-4633-9680-9090b5e2c450 |
|                metadata               |                  {}                  |
|              multiattach              |                False                 |
|                  name                 |                disk01                |
|         os-vol-host-attr:host         |                 None                 |
|     os-vol-mig-status-attr:migstat    |                 None                 |
|     os-vol-mig-status-attr:name_id    |                 None                 |
|      os-vol-tenant-attr:tenant_id     |   30037a509d4c425a9012d6af386bd0eb   |
|   os-volume-replication:driver_data   |                 None                 |
| os-volume-replication:extended_status |                 None                 |
|           replication_status          |               disabled               |
|                  size                 |                  1                   |
|              snapshot_id              |                 None                 |
|              source_volid             |                 None                 |
|                 status                |               creating               |
|                user_id                |   b3d4f6bf75a74aba8baa6bcfe68a183e   |
|              volume_type              |                 None                 |
+---------------------------------------+--------------------------------------+

$ nova list
+--------------------------------------+--------+--------+------------+-------------+-------------------------------+
| ID                                   | Name   | Status | Task State | Power State | Networks                      |
+--------------------------------------+--------+--------+------------+-------------+-------------------------------+
| d0e3ee9b-220d-47ae-8616-e7ccd55ec885 | demo01 | ACTIVE | -          | Running     | private=10.10.0.3, 10.0.5.101 |
+--------------------------------------+--------+--------+------------+-------------+-------------------------------+

$ cinder list
+--------------------------------------+-----------+--------+------+-------------+----------+--------------------------------------+
|                  ID                  |   Status  |  Name  | Size | Volume Type | Bootable |             Attached to              |
+--------------------------------------+-----------+--------+------+-------------+----------+--------------------------------------+
| 47629300-da8d-4633-9680-9090b5e2c450 | available | disk01 |  1   |     None    |  false   |                                      |
| a95632b5-15cf-4ff1-b568-dda0f52190d3 |   in-use  | disk01 |  1   |     None    |  false   | d0e3ee9b-220d-47ae-8616-e7ccd55ec885 |
+--------------------------------------+-----------+--------+------+-------------+----------+--------------------------------------+

root@controller:/continuse/script# nova volume-attach demo01 47629300-da8d-4633-9680-9090b5e2c450 auto
+----------+--------------------------------------+
| Property | Value                                |
+----------+--------------------------------------+
| device   | /dev/vdc                             |
| id       | 47629300-da8d-4633-9680-9090b5e2c450 |
| serverId | d0e3ee9b-220d-47ae-8616-e7ccd55ec885 |
| volumeId | 47629300-da8d-4633-9680-9090b5e2c450 |
+----------+--------------------------------------+

$ ssh cirros@10.0.5.101 -i myKey.pem
$ sudo fdisk /dev/vdc
Device contains neither a valid DOS partition table, nor Sun, SGI or OSF disklabel
Building a new DOS disklabel with disk identifier 0x1c3dc9fa.
Changes will remain in memory only, until you decide to write them.
After that, of course, the previous content won't be recoverable.

Warning: invalid flag 0x0000 of partition table 4 will be corrected by w(rite)

Command (m for help): n
Partition type:
   p   primary (0 primary, 0 extended, 4 free)
   e   extended
Select (default p): p
Partition number (1-4, default 1): 1
First sector (2048-2097151, default 2048):
Using default value 2048
Last sector, +sectors or +size{K,M,G} (2048-2097151, default 2097151):
Using default value 2097151

Command (m for help): w
The partition table has been altered!

Calling ioctl() to re-read partition table.
Syncing disks.
```

## Issues
The cinder node reboot when fleetctl service restart. If not....could not NFS mount.


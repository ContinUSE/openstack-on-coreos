How to choose openstack version as the follows. You have to edit service files for container name.

+---------+-----------------------------------------+-----------------------+
|Version  |		Container Name		    |	service file name   |
+---------+-----------------------------------------+-----------------------+
|JUNO     |	continuse/openstack-controller:juno |	controller.service  |
|         |	continuse/openstack-network:juno    |	network.service     |
|         |	continuse/openstack-compute:juno    |	compute.service     |
|         |	continuse/openstack-nova-docker:juno|	nova-docker.service }
+---------+-----------------------------------------+-----------------------+
|KILO     |	continuse/openstack-controller:kilo |	controller.service  |
|         |	continuse/openstack-network:kilo    |	network.service     |
|         |	continuse/openstack-compute:kilo    |	compute.service     |
|         |	continuse/openstack-nova-docker:kilo|	nova-docker.service |
+---------+-----------------------------------------+-----------------------+

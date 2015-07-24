# Kuberbetes Cluster 
Currently Kubernetes does not support master services for HA in multi-node cluster. This is to support master services run to another node using fleetctl & etcd service when a master node failed.

### Kubernetes Cluster Setup
This Cluster has two nodes as kube-01, kube-02
```
On Mac
$ cd cluster/kube
$ vagrant up
..............
..............
..............
..............
$ vagrant ssh kube-01

On CoreOS (kube-01)
$ cd /continuse/kube/bin
$ openssl genrsa -out kube-serviceaccount.key 2048
..............
..............
..............
..............
$ wget https://github.com/ContinUSE/openstack-on-coreos/releases/download/kube/kube_1.0.1.tgz
$ tar tvfz kube_1.0.1.tgz
```

### Kubernetes Service Start
```
On CoreOS
$ cd /continuse/kube/service
$ fleetctl start kube-apiserver.service
$ fleetctl start kube-controller-manager.service
$ fleetctl start kube-scheduler.service
$ fleetctl start kube-kubelet.service
$ fleetctl start kube-proxy.service
```

### Usage

If you want to test something exsamples, start with [Kubernetes examples]
(https://github.com/GoogleCloudPlatform/kubernetes/blob/master/examples/).


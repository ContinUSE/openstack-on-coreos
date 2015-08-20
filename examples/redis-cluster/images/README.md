# Redis Cluster
This example provides the ability to automatically process such as initial redis cluster configuration, node expansion and node failover operation on Kubernetes environment.

## Reliable, Scalable Redis Cluster on Kubernetes
The followings are multi-node Redis Cluster Usage. This example that I tried to apply on a trial basis.

### Redis Cluster Manager Pods
Create redis cluster manager as follows:
```
$ kubectl create -f redis-cluster-manager.yaml
replicationcontrollers/redis-cluster-manager
```

Log view for status check
```
$ kubectl get pods
NAME                          READY     STATUS    RESTARTS   AGE
redis-cluster-manager-8eo9n   1/1       Running   0          1m
$ kubectl logs -f redis-cluster-manager-8eo9n
Getting information for redis cluster...........
.........
........
........
The redis cluster need at least 6 nodes.
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
```

### Replicated redis cluster workers
Create redis cluster worker as follows:
```
$ kubectl create -f redis-cluster-worker.yaml
replicationcontrollers/redis-cluster-worker
```
You can view status check for redis-cluster-manager above "kubectl logs...." command.

### Service creation for redis-cluster-worker pods
```
$ kubectl create -f redis-cluster-worker-service.yaml
You have exposed your service on an external port on all nodes in your
cluster.  If you want to expose this service to the external internet, you may
need to set up firewall rules for the service port(s) (tcp:32100) to serve traffic.

See http://releases.k8s.io/HEAD/docs/services-firewalls.md for more details.
services/redis-cluster-worker
```
And redis-cli command Usage:
The host IP address is one of node of kube, and port is 32100. (This port number defined in redis-cluster-worker-service.yaml)
```
$ sudo docker run --rm -it redis redis-cli -c -h 192.168.10.71 -p 32100
192.168.10.71:32100> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:6
cluster_my_epoch:3
cluster_stats_messages_sent:2121
cluster_stats_messages_received:2121
192.168.10.71:32100>
```

### Node Add (1 master / 1 slave)
```
$ kubectl scale rc redis-cluster-worker --replicas=8
scaled
```
See log view for ALL procedure such as node add and data reshard.

# Node Failure Test
kube-02 fail test
```
vagrant halt kube-02
```
It takes about five minutes for the automatic recovery. Checking the log view of redis-cluster-manager.

### Issue
The system is still unstable after recovery of failure.

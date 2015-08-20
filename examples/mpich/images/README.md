# MPICH Multinode Cluster
Describe how to make docker image and config Kubernetes cluster for MPI cluster. It is easy to node add/remove using ReplicationController function of Kubernetes.
This is show you a basic MPICH cluster configuration and MPI hello world application on Kubernetes cluster using MPICH3 (specifically 3.1.4).

## Reliable, Scalable MPICH cluster on Kubernetes
The followings are multi-node MPICH cluster configuration on Kubernetes. It deploys a master with replicated workers.

### Master Pods
Create this master as follows:
```
kubectl create -f mpich-master.yaml
```

### Replicated mpich servers
Create this worker as follows:
```
kubectl create -f mpich-controller.yaml
```

### Scale our replicated pods
we will add more replicas for worker:
```
kubectl scale rc mpich-worker --replicas=3
```

### mpich master service
Create the service by running: Using NodePort as 32000 tcp port
```
kubectl create -f mpich-service.yaml
```

### Connect to master & Basic test
```
$ ssh root@192.168.10.71 -p 32000 (Any one of kube cluster nodes)
root@192.168.10.71's password: (root apsswrod as 'root')
Last login: Thu Aug  6 04:11:46 2015 from mpich-master
root@mpich-master:~# mpirun -f host_file -n 3 hostname
mpich-master
mpich-worker-1p1ko
mpich-worker-r4j6z
root@mpich-master:~#
```

### Conclusion
Now We have a reliable, scalable MPICH cluster installation. By scaling the replication controller for mpich worker instances, we can increase or decrease the number of mpich-worker instances and auto update for host file on master. If you want to test for sample MPI program, visit to http://mpitutorial.com/tutorials/mpi-hello-world/. (MPICH package installed /tmp/mpich)


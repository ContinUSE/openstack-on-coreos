# Kubernetes User Interface 
Kubernetes has a web-based user interface that displays the current cluster state graphically.
By default, the Kubernetes UI is deployed as a cluster addon. To access it, visit https://<kubernetes-master>/ui.

```
kubectl create -f kube-system.yaml
kubectl create -f kube-ui-rc.yaml --namespace=kube-system
kubectl create -f kube-ui-svc.yaml --namespace=kube-system
```

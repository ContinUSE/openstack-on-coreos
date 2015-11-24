kubectl create -f kube-system.yaml
kubectl create -f kube-ui-rc.yaml --namespace=kube-system
kubectl create -f kube-ui-svc.yaml --namespace=kube-system

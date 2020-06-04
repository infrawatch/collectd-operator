# collectd-operator

Basic install collectd operator for k8s

## Environment

Test environment is currently using minikube v1.11.0 with the registry and OLM
addons.

```
minikube start --cpus=4 --memory=49152 --driver=kvm2
eval $(minikube podman-env)
source <(kubectl completion bash)
source <(minikube completion bash)
```

## Load the Operator

We're not currently making full use of the Operator Lifecycle Manager, so we'll
be importing things manually.

```
kubectl create namespace collectd
kubectl config set-context --current --namespace=collectd
kubectl apply -f deploy/service_account.yaml -f deploy/role.yaml -f deploy/role_binding.yaml
kubectl apply -f deploy/olm-catalog/collectd-operator/0.0.1/collectd.infra.watch_collectds_crd.yaml -f deploy/olm-catalog/collectd-operator/0.0.1/collectd-operator.v0.0.1.clusterserviceversion.yaml
```

Then we can check that everything is working.

```
kubectl get all,csv
NAME                                     READY   STATUS    RESTARTS   AGE
pod/collectd-operator-65749b54b4-ngwn4   2/2     Running   0          7m50s

NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/collectd-operator-metrics   ClusterIP   10.103.102.203   <none>        8686/TCP,8383/TCP   7m44s

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/collectd-operator   1/1     1            1           7m50s

NAME                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/collectd-operator-65749b54b4   1         1         1       7m50s

NAME                                                                  DISPLAY             VERSION   REPLACES                   PHASE
clusterserviceversion.operators.coreos.com/collectd-operator.v0.0.1   Collectd Operator   0.0.1     collectd-operator.v0.0.0   Succeeded
```

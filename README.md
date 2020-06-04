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

## Development

You can test that everything passes the Operator SDK scorecard. Currently we're
leveraging `operator-sdk` v0.15.2. You must run this when the collectd operator
is not already running. If the CRD is loaded, the scorecard will fail.

```
kubectl create namespace collectd
kubectl config set-context --current --namespace=collectd
operator-sdk scorecard
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

# Other Components

Load additional components to setup a transport mechanism.

## Cert-Manager Operator

TODO: this may not be necessary (need different version of cert-manager to work
with QDR Operator).

```
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.yaml
```

Then create a local signing authority.

```
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1alpha2
kind: Issuer
metadata:
  name: 'collectd-selfsigned'
  namespace: 'collectd'
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: 'collectd-ca'
  namespace: 'collectd'
spec:
  secretName: 'collectd-ca'
  commonName: 'collectd-ca'
  isCA: true
  issuerRef:
    name: 'collectd-selfsigned'
---
apiVersion: cert-manager.io/v1alpha2
kind: Issuer
metadata:
  name: 'collectd-ca'
  namespace: 'collectd'
spec:
  ca:
    secretName: 'collectd-ca'
EOF
```

## QDR Operator

```
git clone https://github.com/interconnectedcloud/qdr-operator.git
cd qdr-operator
kubectl apply -f deploy/service_account.yaml \
    -f deploy/role.yaml \
    -f deploy/role_binding.yaml \
    -f deploy/cluster_role.yaml \
    -f deploy/cluster_role_binding.yaml \
    -f deploy/olm-catalog/qdr-operator/0.4.0/qdr-operator.v0.4.0.clusterserviceversion.yaml \
    -f deploy/crds/interconnectedcloud_v1alpha1_interconnect_crd.yaml
```

Then create an instance of QDR.

```
kubectl apply -f - <<EOF
apiVersion: interconnectedcloud.github.io/v1alpha1
kind: Interconnect
metadata:
  name: 'qdr-interconnect'
  namespace: 'collectd'
spec:
  deploymentPlan:
    size: 1
    role: interior
    livenessPort: 8888
    placement: AntiAffinity
  addresses:
    - distribution: closest
      prefix: closest
    - distribution: multicast
      prefix: multicast
    - distribution: closest
      prefix: unicast
    - distribution: closest
      prefix: exclusive
    - distribution: multicast
      prefix: broadcast
    - distribution: multicast
      prefix: collectd
    - distribution: multicast
      prefix: ceilometer
  listeners:
    - port: 5672
    - expose: true
      http: true
      port: 8672
EOF
```

## Smart Gateway Operator

Instantiate the Smart Gateway Operator.

```
git clone https://github.com/infrawatch/smart-gateway-operator
cd smart-gateway-operator
kubectl apply -f deploy/role_binding.yaml -f deploy/role.yaml -f deploy/service_account.yaml -f deploy/olm-catalog/smart-gateway-operator/1.0.1/smartgateway.infra.watch_smartgateways_crd.yaml
kubectl apply -f deploy/olm-catalog/smart-gateway-operator/1.0.1/smart-gateway-operator.v1.0.1.clusterserviceversion.yaml
```

Create a Smart Gateway instance.

```
kubectl apply -f - <<EOF
apiVersion: smartgateway.infra.watch/v2alpha1
kind: SmartGateway
metadata:
  name: 'collectd-metrics-telemetry'
  namespace: 'collectd'
spec:
  amqpUrl: 'qdr-interconnect:5672/telemetry'
  debug: false
  serviceType: 'metrics'
  size: 1
  prefetch: 15000
  useTimestamp: true
EOF
```

## Prometheus Operator

```

```

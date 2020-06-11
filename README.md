# collectd-operator

Basic install collectd operator for k8s

## Environment

Test environment is currently using minikube v1.11.0 with the registry and OLM
addons.

```
minikube start --cpus=4 --memory=49152 --driver=kvm2
for i in default-storageclass ingress olm registry storage-provisioner; do minikube addons enable $i; done
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

First, create the OperatorGroup:

```
kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: collectd-og
  namespace: collectd
spec:
  targetNamespaces:
  -  collectd
EOF
```

Then create the ServiceAccount, ClusterRole, ClusterRoleBinding and
ClusterServiceVersion:

```
kubectl create namespace collectd
kubectl config set-context --current --namespace=collectd
kubectl apply -f deploy/service_account.yaml -f deploy/role.yaml -f deploy/role_binding.yaml -f deploy/olm-catalog/collectd-operator/0.0.2/collectd.infra.watch_collectds_crd.yaml 
sed -e "s#placeholder#collectd#g" deploy/olm-catalog/collectd-operator/0.0.2/collectd-operator.v0.0.2.clusterserviceversion.yaml | kubectl apply -f -
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
clusterserviceversion.operators.coreos.com/collectd-operator.v0.0.2   Collectd Operator   0.0.2     collectd-operator.v0.0.1   Succeeded
```

# Other Components

Load additional components to setup a transport mechanism.

## QDR Operator

Load the ServiceAccount, Role, RoleBinding, ClusterRole, ClusterRoleBinding and
CustomResourceDefinition:

```
git clone https://github.com/interconnectedcloud/qdr-operator.git
cd qdr-operator
kubectl apply -f deploy/service_account.yaml \
    -f deploy/role.yaml \
    -f deploy/role_binding.yaml \
    -f deploy/cluster_role.yaml \
    -f deploy/cluster_role_binding.yaml \
    -f deploy/crds/interconnectedcloud_v1alpha1_interconnect_crd.yaml
```

Then load the ClusterServiceVersion:

| **NOTE** You may need to apply a small patch prior to running the next command. See https://github.com/interconnectedcloud/qdr-operator/pull/75 |
|-------------------------------------------------------------------------------------------------------------------------------------------------|

```
sed -e "s#placeholder#collectd#g" deploy/olm-catalog/qdr-operator/0.4.0/qdr-operator.v0.4.0.clusterserviceversion.yaml | kubectl apply -f -
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
kubectl apply -f deploy/role_binding.yaml -f deploy/role.yaml -f deploy/service_account.yaml -f deploy/olm-catalog/smart-gateway-operator/1.0.2/smartgateway.infra.watch_smartgateways_crd.yaml
sed -e "s#placeholder#collectd#g" deploy/olm-catalog/smart-gateway-operator/1.0.2/smart-gateway-operator.v1.0.2.clusterserviceversion.yaml | kubectl apply -f -
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
  amqpUrl: 'qdr-interconnect:5672/collectd/openshift-telemetry'
  debug: false
  serviceType: 'metrics'
  size: 1
  prefetch: 15000
  useTimestamp: true
EOF
```

## Prometheus Operator

Subscribe to Prometheus Operator from the OperatorHubIO catalog source:

```
kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: prometheus
  namespace: collectd
spec:
  channel: beta
  installPlanApproval: Automatic
  name: prometheus
  source: operatorhubio-catalog
  sourceNamespace: olm
  startingCSV: prometheusoperator.0.37.0
EOF
```

Create a Prometheus instance:

```
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  labels:
    prometheus: 'prometheus'
  name: prometheus
  namespace: collectd
spec:
  replicas: 1
  ruleSelector: {}
  securityContext: {}
  serviceAccountName: prometheus-k8s
  serviceMonitorSelector:
    matchLabels:
      app: smart-gateway
  alerting:
    alertmanagers:
    - name: alertmanager-operated
      namespace: collectd
      port: web
EOF
```

Create a ServiceMonitor to result in Prometheus being configured to scrape our
new Smart Gateway:

```
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app: smart-gateway
  name: 'collectd'
  namespace: 'collectd'
spec:
  endpoints:
    - metricRelabelings:
        - action: labeldrop
          regex: pod
          sourceLabels: []
        - action: labeldrop
          regex: namespace
          sourceLabels: []
        - action: labeldrop
          regex: instance
          sourceLabels: []
        - action: labeldrop
          regex: job
          sourceLabels: []
      port: prom-http
  selector:
    matchLabels:
      app: smart-gateway
EOF
```

Create an Alertmanager instance:

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: 'alertmanager-collectd'
  namespace: 'collectd'
type: Opaque
stringData:
  alertmanager.yaml: |-
    global:
      resolve_timeout: 5m
    route:
      group_by: ['job']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'null'
    receivers:
    - name: 'null'
---
apiVersion: monitoring.coreos.com/v1
kind: Alertmanager
metadata:
  labels:
    alertmanager: 'alertmanager'
  name: 'collectd'
  namespace: 'collectd'
spec:
  replicas: 1
  serviceAccountName: prometheus-k8s
EOF
```

## Create Collectd DaemonSet

```
kubectl apply -f - <<EOF
apiVersion: collectd.infra.watch/v1alpha1
kind: Collectd
metadata:
  name: 'collectd'
  namespace: 'collectd'
spec:
  collectdHost: qdr-interconnect
EOF
```

# Accessing Prometheus UI

Accessing the Prometheus UI via minikube is done by exposing the
`prometheus-operated` service.

```
kubectl expose -n collectd service prometheus-operated --port=80 --target-port=9090 --name=prometheus-web --type=LoadBalancer
minikube service prometheus-web -n collectd
```

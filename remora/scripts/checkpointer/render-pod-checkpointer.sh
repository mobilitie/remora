#!/usr/bin/env bash

set -eu
export LC_ALL=C

KUBE_TEMPLATE=${LOCAL_MANIFESTS_DIR}/pod-checkpointer.yaml

CA=$(cat ${LOCAL_ASSETS_DIR}/certs/kubernetes/ca.crt | base64)
SA_KEY=$(cat ${LOCAL_ASSETS_DIR}/certs/kubernetes/sa.pub | base64)

cat << EOF > $KUBE_TEMPLATE
---
# FIXME(yuanying): Fix to apply correct ClusterRole
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: remora:pod-checkpointer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: pod-checkpointer
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-checkpointer
  namespace: kube-system
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: pod-checkpointer
  namespace: kube-system
  labels:
    tier: control-plane
    k8s-app: pod-checkpointer
data:
  kubeconfig: |
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        server: https://${KUBE_PUBLIC_SERVICE_IP}:${KUBE_PORT}
      name: default
    contexts:
    - context:
        cluster: default
        namespace: default
        user: default
      name: default
    current-context: default
    users:
    - name: default
      user:
        tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
---
apiVersion: "extensions/v1beta1"
kind: DaemonSet
metadata:
  name: pod-checkpointer
  namespace: kube-system
  labels:
    tier: control-plane
    k8s-app: pod-checkpointer
spec:
  template:
    metadata:
      labels:
        tier: control-plane
        k8s-app: pod-checkpointer
      annotations:
        checkpointer.alpha.coreos.com/checkpoint: "true"
    spec:
      containers:
      - name: pod-checkpointer
        image: quay.io/coreos/pod-checkpointer:0cd390e0bc1dcdcc714b20eda3435c3d00669d0e
        command:
        - /checkpoint
        - --v=4
        - --lock-file=/var/run/lock/pod-checkpointer.lock
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        imagePullPolicy: Always
        volumeMounts:
        - mountPath: /etc/kubernetes
          name: etc-kubernetes
        - mountPath: /var/run
          name: var-run
        - mountPath: /etc/kubernetes/kubeconfig
          name: kubeconfig
          subPath: kubeconfig
      hostNetwork: true
      nodeSelector:
        node-role.kubernetes.io/master: ""
      restartPolicy: Always
      serviceAccountName: pod-checkpointer
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      volumes:
      - name: etc-kubernetes
        hostPath:
          path: /etc/kubernetes
      - name: kubeconfig
        configMap:
          name: pod-checkpointer
      - name: var-run
        hostPath:
          path: /var/run
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate


EOF

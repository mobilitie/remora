#!/usr/bin/env bash

set -eu
export LC_ALL=C

KUBE_FLANNEL_TEMPLATE=${LOCAL_MANIFESTS_DIR}/kube-cni-flannel.yaml
mkdir -p $(dirname $KUBE_FLANNEL_TEMPLATE)
cat << EOF > $KUBE_FLANNEL_TEMPLATE
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
  labels:
    tier: node
    k8s-app: flannel
rules:
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes/status
    verbs:
      - patch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
  labels:
    tier: node
    k8s-app: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-system
  labels:
    tier: node
    k8s-app: flannel
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-system
  labels:
    tier: node
    k8s-app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "${KUBE_CLUSTER_CIDR}",
      "Backend": {
        "Type": "${FLANNEL_BACKEND_TYPE}"
      }
    }
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cni-sh
  namespace: kube-system
  labels:
    tier: node
    k8s-app: flannel
data:
  install-cni-bin.sh: |
    #!/bin/sh

    set -e -x;

    if [ -w "/host/opt/cni/bin/" ]; then
        cp /opt/cni/bin/* /host/opt/cni/bin/;
        echo "Wrote CNI binaries to /host/opt/cni/bin/";
    fi;
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds
  namespace: kube-system
  labels:
    tier: node
    k8s-app: flannel
spec:
  selector:
    matchLabels:
      tier: node
      k8s-app: flannel
  template:
    metadata:
      labels:
        tier: node
        k8s-app: flannel
    spec:
      hostNetwork: true
      nodeSelector:
        beta.kubernetes.io/arch: amd64
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni-bin
        image: ${FLANNEL_CNI_IMAGE_REPO}:${FLANNEL_CNI_VERSION}
        command: ['sh', '/bin/install-cni-bin.sh']
        volumeMounts:
        - name: host-cni-bin
          mountPath: /host/opt/cni/bin/
        - name: kube-flannel-cni-sh
          mountPath: /bin/install-cni-bin.sh
          subPath: install-cni-bin.sh
      - name: install-cni-conf
        image: ${FLANNEL_IMAGE_REPO}:${FLANNEL_VERSION}
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: ${FLANNEL_IMAGE_REPO}:${FLANNEL_VERSION}
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        - --iface
        - \$(POD_IP)
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: true
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        volumeMounts:
        - name: run
          mountPath: /run
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg
        - name: kube-flannel-cni-sh
          configMap:
            name: kube-flannel-cni-sh
        - name: host-cni-bin
          hostPath:
            path: /opt/cni/bin
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
EOF

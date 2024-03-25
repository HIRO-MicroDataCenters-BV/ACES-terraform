#!/usr/bin/env bash

set -e
set -u
# set -x

USER_NAME=$1
GROUP_NAME=$1

TMP_DIR=$(mktemp -d)

openssl genrsa -out $USER_NAME.key 4096

cat > $TMP_DIR/csr_$USER_NAME.cnf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
CN = $USER_NAME
O = $GROUP_NAME

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
EOF

openssl req -config $TMP_DIR/csr_$USER_NAME.cnf -new -key $USER_NAME.key -nodes -out $TMP_DIR/$USER_NAME.csr
BASE64_CSR=$(cat $TMP_DIR/$USER_NAME.csr | base64 | tr -d '\n')


cat > $TMP_DIR/csr_$USER_NAME.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USER_NAME}-csr
spec:
  signerName: kubernetes.io/kube-apiserver-client
  groups:
  - system:authenticated
  request: ${BASE64_CSR}
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

kubectl delete csr ${USER_NAME}-csr 2> /dev/null || true
kubectl apply -f $TMP_DIR/csr_$USER_NAME.yaml
kubectl get csr ${USER_NAME}-csr
kubectl certificate approve ${USER_NAME}-csr

kubectl create namespace $GROUP_NAME

cat > $TMP_DIR/rbac.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: $USER_NAME
  namespace: $GROUP_NAME
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $GROUP_NAME-role-binding
  namespace: $GROUP_NAME
subjects:
- kind: User
  name: $USER_NAME
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: $GROUP_NAME
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f $TMP_DIR/rbac.yaml

# User identifier
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath={.current-context} | cut -d@ -f 2)
# Client certificate
CLIENT_CERTIFICATE_DATA=$(kubectl get csr ${USER_NAME}-csr -o jsonpath='{.status.certificate}')
# Cluster Certificate Authority
CLUSTER_CA=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$CLUSTER_NAME'") | .cluster."certificate-authority-data"')
# API Server endpoint
CLUSTER_ENDPOINT=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$CLUSTER_NAME'") | .cluster."server"')
KUBCONFIG_FILE=$USER_NAME-$CLUSTER_NAME-kubeconfig.yaml

cat > $KUBCONFIG_FILE <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_ENDPOINT}
  name: ${CLUSTER_NAME}
users:
- name: ${USER_NAME}-${CLUSTER_NAME}
  user:
    client-certificate-data: ${CLIENT_CERTIFICATE_DATA}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${USER_NAME}-$CLUSTER_NAME
  name: ${USER_NAME}@${CLUSTER_NAME}
current-context: ${USER_NAME}@${CLUSTER_NAME}
EOF

kubectl config set-credentials $USER_NAME --kubeconfig $KUBCONFIG_FILE --client-key $USER_NAME.key --embed-certs=true
kubectl config set-context --kubeconfig $KUBCONFIG_FILE --current --namespace=$GROUP_NAME

echo ======================================
echo The Generated User configuration file:
echo ""
echo   $USER_NAME-$CLUSTER_NAME-kubeconfig.yaml
echo ""


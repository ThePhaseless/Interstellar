#!/usr/bin/env bash
# Usage: ./scripts/generate-bitwarden-tls.sh

set -euo pipefail

NAMESPACE="external-secrets"
SECRET_NAME="bitwarden-tls-certs"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

DNS_NAMES=(
    "bitwarden-sdk-server.${NAMESPACE}.svc.cluster.local"
    "bitwarden-sdk-server.${NAMESPACE}.svc"
    "bitwarden-sdk-server.${NAMESPACE}"
    "bitwarden-sdk-server"
    "localhost"
)

echo "Generating certificates..."

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${TMPDIR}/ca.key" \
    -out "${TMPDIR}/ca.crt" \
    -days 3650 \
    -subj "/O=external-secrets.io/CN=bitwarden-sdk-server-ca" \
    2>/dev/null

SAN=""
for i in "${!DNS_NAMES[@]}"; do
    SAN="${SAN}DNS.$((i + 1)) = ${DNS_NAMES[$i]}\n"
done
SAN="${SAN}IP.1 = 127.0.0.1"

cat >"${TMPDIR}/server.cnf" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
O = external-secrets.io
CN = bitwarden-sdk-server

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
$(echo -e "$SAN")
EOF

openssl req -newkey rsa:2048 -nodes \
    -keyout "${TMPDIR}/tls.key" \
    -out "${TMPDIR}/tls.csr" \
    -config "${TMPDIR}/server.cnf" \
    2>/dev/null

openssl x509 -req \
    -in "${TMPDIR}/tls.csr" \
    -CA "${TMPDIR}/ca.crt" \
    -CAkey "${TMPDIR}/ca.key" \
    -CAcreateserial \
    -out "${TMPDIR}/tls.crt" \
    -days 3650 \
    -extensions v3_req \
    -extfile "${TMPDIR}/server.cnf" \
    2>/dev/null

echo "Certificates generated."

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 ||
    kubectl create namespace "${NAMESPACE}"

kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
    --from-file=tls.crt="${TMPDIR}/tls.crt" \
    --from-file=tls.key="${TMPDIR}/tls.key" \
    --from-file=ca.crt="${TMPDIR}/ca.crt" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Updated secret '${SECRET_NAME}' in namespace '${NAMESPACE}'."
echo "CA certificate:"
base64 -w0 <"${TMPDIR}/ca.crt"
echo ""

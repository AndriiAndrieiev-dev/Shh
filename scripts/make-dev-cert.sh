#!/usr/bin/env bash
#
# make-dev-cert.sh — create the stable self-signed "Shh Dev" code-signing
# certificate used by dev-run.sh.
#
# Why: ad-hoc signatures change on every build, so macOS forgets the
# Accessibility / Input Monitoring grants each rebuild. Signing with a stable
# certificate keeps the code's designated requirement constant → grant once.
#
# The cert is untrusted (self-signed) — that's fine for *signing*; codesign
# only needs the private key. Gatekeeper would still warn on a fresh download,
# but for local development that doesn't matter.
#
# Run this once per machine. It's idempotent-ish: re-running creates another
# cert with the same name (harmless, but you can delete dupes in Keychain).

set -euo pipefail

NAME="Shh Dev"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/cert.conf" <<'EOF'
[ req ]
distinguished_name = req_dn
x509_extensions = v3_code_sign
prompt = no
[ req_dn ]
CN = Shh Dev
[ v3_code_sign ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

echo "==> Generating self-signed code-signing cert"
openssl req -x509 -newkey rsa:2048 \
  -keyout "${TMP}/key.pem" -out "${TMP}/cert.pem" \
  -days 3650 -nodes -config "${TMP}/cert.conf" 2>/dev/null

echo "==> Bundling p12 (legacy format for macOS security import)"
openssl pkcs12 -export -legacy \
  -inkey "${TMP}/key.pem" -in "${TMP}/cert.pem" \
  -out "${TMP}/shh.p12" -name "${NAME}" -passout pass:shhdev

echo "==> Importing into login keychain"
security import "${TMP}/shh.p12" \
  -k "${HOME}/Library/Keychains/login.keychain-db" \
  -P "shhdev" -T /usr/bin/codesign -A

echo "==> Verifying codesign can see it"
security find-identity -p codesigning | grep "${NAME}" || {
  echo "Cert imported but not listed — check Keychain Access." >&2
  exit 1
}

echo "Done. '${NAME}' is ready for scripts/dev-run.sh."

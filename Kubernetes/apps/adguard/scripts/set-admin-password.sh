#!/bin/sh
# Writing the config directly is the only IaC-owned path: AdGuard has no
# password-change API outside the first-run wizard, and the Terraform provider
# only consumes the credential.
set -eu

CONF=/opt/adguardhome/conf/AdGuardHome.yaml
PASS_FILE=/secrets/adguard/password

# Fresh volume — let AdGuard's own wizard write the file first.
[ -f "$CONF" ] || exit 0

# -C 10 overrides htpasswd's default cost of 5.
ADMIN_HASH=$(htpasswd -nbB -C 10 admin "$(cat "$PASS_FILE")" | cut -d: -f2)

if grep -q '^users:' "$CONF" && grep -q '^  - name: admin$' "$CONF"; then
    # match()-anchored so the 4-space indent survives; sub() would strip it and
    # corrupt the YAML.
    awk -v h="$ADMIN_HASH" '
      /^  - name: admin$/ { a = 1 }
      a && /^[[:space:]]*password:/ {
        match($0, /^[[:space:]]*password:[[:space:]]*/)
        $0 = substr($0, 1, RLENGTH) h
        a = 0
      }
      { print }
    ' "$CONF" >"$CONF.tmp" && mv "$CONF.tmp" "$CONF"
else
    # Renamed admin user: leave auth alone rather than risk a lockout.
    grep -q '^users:' "$CONF" ||
        printf 'users:\n  - name: admin\n    password: %s\n' "$ADMIN_HASH" >>"$CONF"
fi

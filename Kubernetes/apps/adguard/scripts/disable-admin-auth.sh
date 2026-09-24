#!/bin/sh
# AdGuard skips its login when the config has no users. dns.nerine.dev is
# already behind Authentik forward-auth, whose Remote-User header AdGuard cannot
# consume, and AdGuard has no API for removing users outside the first-run
# wizard. Who can reach it is decided by the allow-traefik NetworkPolicy in
# apps/networkpolicies/home.yaml.
set -eu

CONF=/opt/adguardhome/conf/AdGuardHome.yaml

# Fresh volume — AdGuard's wizard writes the file and creates a user; the next
# restart strips it.
[ -f "$CONF" ] || exit 0

grep -q '^users:' "$CONF" || exit 0

# Anchored on indentation rather than `- name:`/`password:` so fields AdGuard
# adds to a user entry are dropped too.
awk '
  /^users:/ { skip = 1; next }
  skip && /^[[:space:]]/ { next }
  { skip = 0; print }
' "$CONF" >"$CONF.tmp" && mv "$CONF.tmp" "$CONF"

#!/bin/sh
# AdGuard skips its login entirely when the config carries no users, which is
# what we want: dns.nerine.dev is already gated by Authentik forward-auth, and
# AdGuard cannot consume the Remote-User header that forward-auth injects, so a
# second credential would be a password nobody can single-sign-on into.
#
# Editing the config is the only IaC-owned path — AdGuard exposes no API for
# removing users outside the first-run wizard.
#
# Reaching AdGuard at all is then a network question, answered by the
# allow-traefik NetworkPolicy in apps/networkpolicies/home.yaml.
set -eu

CONF=/opt/adguardhome/conf/AdGuardHome.yaml

# Fresh volume — AdGuard's wizard writes the file and creates a user; the next
# restart strips it.
[ -f "$CONF" ] || exit 0

grep -q '^users:' "$CONF" || exit 0

# Drops `users:` plus every indented entry under it, stopping at the next
# top-level key. Anchoring on indentation rather than on `- name:`/`password:`
# keeps this correct if AdGuard adds fields to a user entry.
awk '
  /^users:/ { skip = 1; next }
  skip && /^[[:space:]]/ { next }
  { skip = 0; print }
' "$CONF" >"$CONF.tmp" && mv "$CONF.tmp" "$CONF"

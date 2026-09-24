#!/bin/sh
set -eu
CONFIG_DIR="/config/qBittorrent"
CONFIG_FILE="${CONFIG_DIR}/qBittorrent.conf"
mkdir -p "${CONFIG_DIR}"
if [ ! -f "${CONFIG_FILE}" ]; then
  cat > "${CONFIG_FILE}" <<'EOF'
[Preferences]
WebUI\RootFolder=/vuetorrent
EOF
  chmod 600 "${CONFIG_FILE}"
fi
# The 0.0.0.0/0 subnet whitelist skips qBittorrent's own login: Traefik
# forward-auth guards the UI, and NetworkPolicy admits only Traefik, sonarr,
# radarr and decluttarr to port 8080.
# CSRFProtection must stay on: the Authentik cookie is scoped to nerine.dev, so
# a page on any sibling subdomain could otherwise forge setPreferences, and
# autorun_program turns that into command execution in this pod.
# HostHeaderValidation must stay off: it made qBittorrent answer 401 to every
# caller, even hosts listed in ServerDomains, breaking the *arr download client.
# Spaces around "=" must match: configparser below rewrites with " = ".
for KEY in CSRFProtection HostHeaderValidation ServerDomains LocalHostAuth AuthSubnetWhitelistEnabled AuthSubnetWhitelist; do
  sed -i "/^WebUI\\\\${KEY}[[:space:]]*=/d" "${CONFIG_FILE}"
done
sed -i '/^\[Preferences\]/a WebUI\\LocalHostAuth=false\nWebUI\\HostHeaderValidation=false\nWebUI\\CSRFProtection=true\nWebUI\\AuthSubnetWhitelistEnabled=true\nWebUI\\AuthSubnetWhitelist=0.0.0.0\/0' "${CONFIG_FILE}"
if ! grep -q '^\[BitTorrent\]' "${CONFIG_FILE}"; then
  printf '\n[BitTorrent]\nSession\\DefaultSavePath=/downloads\n' >> "${CONFIG_FILE}"
elif ! grep -q 'DefaultSavePath' "${CONFIG_FILE}"; then
  sed -i '/^\[BitTorrent\]/a Session\\DefaultSavePath=/downloads' "${CONFIG_FILE}"
else
  sed -i 's|Session\\DefaultSavePath=.*|Session\\DefaultSavePath=/downloads|' "${CONFIG_FILE}"
fi

# Queueing must be enabled for MaxActive* limits to take effect.
python3 - <<'PY'
import configparser, os
f = '/config/qBittorrent/qBittorrent.conf'
cp = configparser.ConfigParser()
cp.optionxform = str
cp.read(f)
if not cp.has_section('BitTorrent'):
    cp.add_section('BitTorrent')
updates = {
    'Session\\QueueingSystemEnabled': 'true',
    'Session\\GlobalMaxRatio': '2',
    'Session\\GlobalMaxSeedingMinutes': '10080',
    'Session\\ShareLimitAction': 'Stop',
    # 0 means zero active torrents, not unlimited (-1).
    'Session\\MaxActiveTorrents': '-1',
    'Session\\MaxActiveDownloads': '50',
    'Session\\MaxActiveUploads': '-1',
    # KiB/s. Torrents below these rates are exempt from MaxActiveDownloads,
    # so a high value bypasses the limit and lets dozens of interleaved
    # writers turn the RAIDZ1 overflow branch's writes random. Set low rather
    # than disabling the exemption so stalled torrents cannot hold a slot.
    'Session\\IgnoreSlowTorrentsForQueueing': 'true',
    'Session\\SlowTorrentsDownloadRate': '50',
    'Session\\SlowTorrentsUploadRate': '50',
    # KiB/s (the WebAPI reports bytes/s): 1 Gbit/s down, 300 Mbit/s up.
    'Session\\AlternativeGlobalDLSpeedLimit': '122070',
    'Session\\AlternativeGlobalUPSpeedLimit': '36621',
    # Shutdown must fit the pod's grace period: a process blocked on the
    # hard-mounted NFS share cannot be killed, so an overrun strands the pod
    # in Terminating holding its RWO volume. TempPathEnabled,
    # ResumeDataStorageType and ShutdownTimeout bound every wait in
    # SessionImpl::~SessionImpl. A queued storage move makes saveResumeData()
    # loop forever (its 30s abort is gated on m_moveStorageQueue being empty),
    # and without a download path there are no moves; NVMe-versus-HDD
    # placement is mergerfs's job anyway.
    'Session\\TempPathEnabled': 'false',
    # The .!qB rename on completion changes the inode mergerfs derives from the
    # path; the NFS client marks it stale, and enough of those wedge the node.
    'Session\\AddExtensionToIncompleteFiles': 'false',
    # Legacy writes one .fastresume file per torrent; SQLite is a
    # single transaction, so the 30s resume-data budget is never
    # the thing that runs out.
    'Session\\ResumeDataStorageType': 'SQLite',
    # Bounds the final libtorrent session abort, which defaults to
    # -1 (wait indefinitely).
    'Session\\ShutdownTimeout': '15',
    # max_queued_disk_bytes: its 1 MiB default overflows with dozens of
    # torrents writing at once, and libtorrent then throttles every peer.
    'Session\\DiskQueueSize': '67108864',
    # NFS writes are latency-bound (1 -> 32 writers measured 102 -> 512 MB/s),
    # so more threads keep more in flight and let the queue above drain.
    'Session\\AsyncIOThreadsCount': '32',
}
changed = False
for k, v in updates.items():
    if cp.get('BitTorrent', k, fallback=None) != v:
        cp.set('BitTorrent', k, v)
        changed = True
if changed:
    with open(f, 'w') as fh:
        cp.write(fh)
PY

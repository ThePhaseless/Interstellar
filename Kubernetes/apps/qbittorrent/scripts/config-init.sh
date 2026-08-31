#!/bin/sh
set -eu
CONFIG_DIR="/config/qBittorrent"
CONFIG_FILE="${CONFIG_DIR}/qBittorrent.conf"
mkdir -p "${CONFIG_DIR}"
if [ ! -f "${CONFIG_FILE}" ]; then
  cat > "${CONFIG_FILE}" <<'EOF'
[Preferences]
WebUI\Port=8080
WebUI\AuthSubnetWhitelistEnabled=true
WebUI\AuthSubnetWhitelist=0.0.0.0/0
WebUI\CSRFProtection=true
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
WebUI\RootFolder=/vuetorrent
EOF
  chmod 600 "${CONFIG_FILE}"
fi
# Credential auth is delegated to Traefik forward-auth; the subnet
# whitelist skips qBittorrent's own login, and who can reach port 8080
# is constrained by NetworkPolicy (Traefik + the three *arr pods).
#
# CSRFProtection is ON and is the control that matters here: the
# Authentik cookie is scoped to nerine.dev, so without it a page on any
# sibling subdomain could forge a setPreferences call, and
# autorun_program turns that into command execution in this pod.
# Verified: a POST carrying a foreign Origin or Referer gets 401, while
# header-less API calls from the *arr apps still succeed.
#
# HostHeaderValidation must stay OFF. Turning it on made qBittorrent
# answer 401 to every caller regardless of Host -- including hostnames
# explicitly listed in ServerDomains -- which broke the *arr download
# client and crashlooped decluttarr on /api/v2/auth/login.
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

# Reduce idle disk reads on the Storage pool by limiting active
# seeding/checking torrents and stopping them after import.
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
    # MaxActiveTorrents=0 means zero active torrents, not unlimited
    # (-1); a stale 0 in the config queued every download forever.
    'Session\\MaxActiveTorrents': '-1',
    'Session\\MaxActiveDownloads': '20',
    'Session\\MaxActiveUploads': '-1',
    # Thresholds are KiB/s; 977 KiB/s = 1 MB/s. Torrents slower
    # than this for SlowTorrentsInactivityTimer stop consuming an
    # active slot.
    'Session\\IgnoreSlowTorrentsForQueueing': 'true',
    'Session\\SlowTorrentsDownloadRate': '977',
    'Session\\SlowTorrentsUploadRate': '977',
    # Config file stores speed limits in KiB/s while the WebAPI
    # reports bytes/s. 1 Gbit/s down and 300 Mbit/s up.
    'Session\\AlternativeGlobalDLSpeedLimit': '122070',
    'Session\\AlternativeGlobalUPSpeedLimit': '36621',
    # Shutdown must fit the pod's grace period: a process blocked
    # on the hard-mounted NFS share cannot be killed, so an overrun
    # strands the pod in Terminating holding its RWO volume. These
    # three bound every wait in SessionImpl::~SessionImpl.
    #
    # A queued storage move makes saveResumeData() loop forever:
    # its 30s abort is gated on m_moveStorageQueue being empty.
    # Without a download path there are no move jobs at all.
    'Session\\TempPathEnabled': 'false',
    # Legacy writes one .fastresume file per torrent; SQLite is a
    # single transaction, so the 30s resume-data budget is never
    # the thing that runs out.
    'Session\\ResumeDataStorageType': 'SQLite',
    # Bounds the final libtorrent session abort, which defaults to
    # -1 (wait indefinitely).
    'Session\\ShutdownTimeout': '15',
    # max_queued_disk_bytes. Its 1 MiB default is exceeded almost
    # immediately with dozens of torrents writing at once, and
    # libtorrent then throttles peers -- the "write disk cache
    # overload" warning, and download rates that sawtooth.
    'Session\\DiskQueueSize': '67108864',
    # Writes to the NFS share are latency-bound, not bandwidth-
    # bound: measured aggregate throughput rose 102 -> 512 MB/s
    # going from 1 to 32 concurrent writers. More threads keep
    # more writes in flight so the queue above actually drains.
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

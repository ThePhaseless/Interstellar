# Technologie: przechowywanie danych, kopie zapasowe, sekrety i obserwowalność

Plik opisuje warstwę danych homelaba: gdzie leżą dane, jak są kopiowane, skąd biorą się sekrety i jak autor widzi stan systemu. Każda technologia ma rolę, datę wprowadzenia, poprzednika, alternatywy oraz ograniczenia, które wyszły w praktyce. Stan obecny odczytano z brancha `main` (tip `9b1d576`, 2026-11-25). Nazwy okresów E1-E5 są wspólne dla całej bazy wiedzy.

Oznaczenia dowodów: [commit `hash`, data], [plik `ścieżka`], [PR #N], [wniosek], [źródło: URL, dostęp 2026-11-27], [nieznane].

## Mapa warstwy danych (stan na 2026-11)

| Warstwa | Technologia | Co trzyma | Gdzie fizycznie |
| --- | --- | --- | --- |
| Pule dyskowe hosta | ZFS na Proxmoxie (`carbon`) | wszystko | pula `Storage` (HDD, RAIDZ1 z 5 dysków), `rpool` (system Proxmoxa i dyski VM), `ssdstage` (NVMe na pobierane torrenty) |
| Udziały plikowe dla klastra | NFS v4.2 z hosta + statyczne PV | media, pobrane pliki, pliki osobiste, zdjęcia Immich | `/Storage/Media`, `/Storage/Photos`, `/SSDStorage`, `/srv/downloads` |
| Pula pobierania | mergerfs (NVMe najpierw, HDD jako przelew) | torrenty w trakcie i seedowane | `/ssdstage/dl` + `/Storage/dl` + `/Storage/Media/Downloads` |
| Wolumeny aplikacji | Longhorn CSI | konfiguracje aplikacji, bazy, dane observability | dysk `scsi1` każdej VM Talos, zvol na `local-zfs` (`rpool`) |
| Kopia poza domem | BorgBackup → Hetzner Storage Box (BX11) | konfiguracje, zrzuty Postgresa, zdjęcia, pliki osobiste | Hetzner, repozytorium `backups/interstellar` |
| Sekrety | Bitwarden Secrets Manager + External Secrets Operator | hasła, klucze, tokeny | chmura Bitwarden, synchronizowane do `Secret` w klastrze |
| Obserwowalność | Grafana, Loki, Mimir, Alloy, Promtail, node-exporter, kube-state-metrics, talos-kmsg-shipper | metryki, logi, alerty | wolumeny Longhorn w namespace `observability` |
| Restart po zmianie konfiguracji | Stakater Reloader | - | Deployment w namespace `reloader` |

Źródła tabeli: [plik `Ansible/setup-proxmox.yaml`], [plik `Ansible/vars/proxmox.yaml`], [plik `Kubernetes/apps/common/media-pv.yaml`], [plik `Kubernetes/bootstrap/longhorn/kustomization.yaml`], [plik `Terraform/proxmox.tf`], [plik `Terraform/hetzner.tf`], [plik `Kubernetes/bootstrap/observability/kustomization.yaml`]. Układ RAIDZ1 z 5 dysków pochodzi z wpisu Key Gotchas o kontrolerze ASMedia [plik `CLAUDE.md`]; sama pula nie jest tworzona przez repo (zob. pytania).

## 1. ZFS na hoście Proxmox

### Rola

ZFS daje redundancję dysków, sumy kontrolne, snapshoty i zbiory danych (datasety) z osobnymi ustawieniami. Pule: `Storage` (HDD, biblioteka mediów, zdjęcia, pobrane pliki), `rpool` (root Proxmoxa: `root=ZFS=rpool/ROOT/pve-1`; na nim datastore `local-zfs` z dyskami VM), `ssdstage` (NVMe do pobierania) [plik `Ansible/setup-proxmox.yaml`], [plik `Terraform/variables.tf`].

### Od kiedy

W E1 skrypt instalacyjny budował programowy RAID10 na `mdadm` [commit `d998e1b`, 2024-01-20]. 2024-03-26 zastąpił go skrypt `setup_raidz10.sh`, który robi `zpool create ... mirror d0 d1 mirror d2 d3`, czyli ZFS-owy odpowiednik RAID10 na 4 dyskach, montowany w `/public/Storage` [commit `d68bcf6`, 2024-03-26]. Kiedy pula zmieniła się w obecny RAIDZ1 z 5 dysków i kiedy serwer przeszedł na Proxmoxa: [nieznane]. Repo nie tworzy puli, tylko ją konfiguruje.

### Co zastąpił i dlaczego

mdadm + ext4 (stary skrypt robił `mkfs.ext4 /dev/md0` i wpis w `/etc/fstab`) [plik `DMZ/setup_raid10.sh` @ `d68bcf6^`]. Commit nie podaje powodu („Update RAID10 setup script to use ZFS”). [wniosek] Skrypt ZFS ma 36 linii zamiast 154, bo ZFS sam łączy RAID, system plików i montowanie, ale to obserwacja, nie deklarowany motyw. Pytanie do autora.

### Strojenie w repo (Ansible)

| Ustawienie | Wartość | Po co | Dowód |
| --- | --- | --- | --- |
| `atime` na `Storage` | `off` | odczyt nie zapisuje metadanych, więc dyski mogą zasnąć | [plik `Ansible/setup-proxmox.yaml`], gotcha w [plik `CLAUDE.md`] |
| `zfs_txg_timeout` | 30 s (domyślnie 5) | rzadsze commity grup transakcji, dyski mogą zasnąć | [commit `5615611`, 2026-06-18] (gotcha) |
| `hd-idle -i 600 -c ata` | usypianie HDD po 10 min | `-c scsi` nigdy nie usypia dysków SATA, które zostawały w `IDLE_A/B` | [commit `55389fa`, 2026-06-14] (wprowadzenie, jeszcze z `-c scsi`), [commit `0eb5f62`, 2026-06-18] (zmiana na `-c ata`), [commit `5615611`, 2026-06-18], [plik `Ansible/setup-proxmox.yaml`] |
| `zfs_arc_max` | 4 GiB | limit pamięci ARC na hoście, który dzieli RAM z VM | [commit `aeca5da`, 2026-07-20] |
| `zfs_vdev_async_write_max_active=32`, `..._min_dirty_percent=10` | - | kolejka zapisów rośnie, zanim ZFS zacznie dławić piszącego (NFS) | [commit `61c109d`, 2026-08-31] |
| `zfs_dirty_data_max` | 256 MiB | txg na `rpool` synchronizuje się w ułamku sekundy, więc etcd nie traci lidera | [commit `34899c2`, 2026-09-21], [commit `d795946`, 2026-09-21], [commit `cca052c`, 2026-09-22] |
| `compression=zle` na datasetach pobierania | - | `off` wyłącza też wykrywanie bloków zerowych; `zle` je zostawia | [commit `064f440`, 2026-09-02] |
| `sync=disabled`, `recordsize=1M` na `ssdstage/dl`, `Storage/dl` | - | szybkie zapisy na danych, które da się pobrać ponownie | [commit `0bdd584`, 2026-09-01], [plik `docs/ssd-download-pool.md`] |
| `quota=2T` na `Storage/dl` | - | pobieranie nie zapełni puli do poziomu, przy którym ZFS zwalnia | [plik `Ansible/vars/proxmox.yaml`] |
| ZED + smartd → Discord | - | alerty dyskowe hosta (Postfix na hoście wyłączony) | [commit `dc32b4e`, 2026-10-26] |

### Ograniczenia napotkane w repo

Studia przypadków z Key Gotchas [plik `CLAUDE.md`]:
- `atime=on` (domyślne) nie pozwala dyskom HDD zasnąć; każdy odczyt zapisuje do wszystkich vdevów.
- `zfs_txg_timeout=5` (domyślne) też trzyma dyski w ruchu.
- `hd-idle -c scsi` na dyskach SATA nie usypiał ich wcale; pierwsza konfiguracja miała właśnie tę opcję, więc talerze kręciły się bez przerwy. Poprawne jest `-c ata` dla SATA i `-c scsi` dla SAS. Smartd pomaga sprawdzić, czy dyski spały: `STANDBY` w logu oznacza sen, a komunikat „spins up disk” nie oznacza wybudzenia [commit `957d2a2`, 2026-11-19].
- Parametry modułu ZFS są globalne. Strojenie pod usypianie HDD (`txg_timeout=30`, duży `dirty_data_max`) objęło też pulę NVMe z etcd. Sync trwał 6-25 s, etcd zgłaszał `apply request took too long`, przegrywał wybory lidera, a za nim padały wszystkie kontrolery z leader election [commit `34899c2`, 2026-09-21]. Naprawa: `zfs_dirty_data_max=256MiB` (sync ok. 0,4 s) [commit `cca052c`, 2026-09-22].
- Zmiana `/etc/modprobe.d/zfs.conf` wymaga `update-initramfs -u`, bo moduł ładuje się z initramfs ze starymi opcjami.
- `compression=off` wyłącza wykrywanie bloków zerowych. Kopiowanie mergerfs przez `sendfile()` nie zna dziur, więc rzadki torrent (0,9 GiB danych) zajął 79 GiB i zapełnił limit 2 TiB [commit `064f440`, 2026-09-02].
- Utknięte (wedged) klienty NFSv4 w VM Talos po kilkusekundowych przestojach hypervisora; skutek tego samego strojenia txg [commit `034599f`, 2026-09-21].

### Alternatywy

| Opcja | Licencja | Ograniczenia istotne tutaj | Źródło |
| --- | --- | --- | --- |
| OpenZFS (wybrane) | CDDL; niezgodna z GPLv2 jądra, więc ZFS nie może wejść do binarnego jądra Linuksa i jest dystrybuowany jako osobny moduł | ARC zajmuje RAM hosta, strojenie modułu jest globalne (zob. wyżej) | [źródło: https://openzfs.github.io/openzfs-docs/License.html, dostęp 2026-11-27], [źródło: https://github.com/openzfs/zfs/blob/master/LICENSE, dostęp 2026-11-27] |
| btrfs | [wniosek] część jądra Linuksa (GPL), licencji nie weryfikowano osobno | profil RAID5/6 ma status „unstable” i „should not be used in production” (brak dziennika zapisu, write hole) | [źródło: https://btrfs.readthedocs.io/en/latest/Status.html, dostęp 2026-11-27], [źródło: https://btrfs.readthedocs.io/en/latest/btrfs-man5.html, dostęp 2026-11-27] |
| mdadm + ext4 (używane w E1) | GPL-2.0 | md nie sumuje kontrolnie danych; brudna, zdegradowana macierz RAID5/6 może mieć niewykrywalną korupcję | [źródło: https://raw.githubusercontent.com/md-raid-utilities/mdadm/main/COPYING, dostęp 2026-11-27], [źródło: https://docs.kernel.org/admin-guide/md.html, dostęp 2026-11-27] |
| Unraid | komercyjna, wieczysta: Starter 49 USD (6 urządzeń), Unleashed 109 USD, Lifetime 249 USD | [wniosek] osobny system operacyjny hosta, więc wykluczałby Proxmoxa na tej samej maszynie | [źródło: https://account.unraid.net/buy, dostęp 2026-11-27] |
| SnapRAID (+ mergerfs) | GPL-3.0 | parzystość tylko na żądanie („similar to a backup”), odtworzenie do stanu ostatniego `sync`; „primarily suited for data that rarely changes” | [źródło: https://www.snapraid.it/compare, dostęp 2026-11-27], [źródło: https://www.snapraid.it/manual, dostęp 2026-11-27] |

### Kiedy wybrać coś innego

[wniosek] Przy jednym hoście z dyskami różnej wielkości, które mają być dokładane pojedynczo, lepiej pasuje Unraid albo SnapRAID + mergerfs (parzystość nie wymaga równych dysków, a każdy dysk z osobna da się odczytać). Gdy ważniejsza jest zgodność z jądrem niż funkcje, mdadm + ext4/XFS. Gdy pamięć RAM hosta jest bardzo mała, ARC trzeba mocno ograniczać (tu 4 GiB), więc przewaga ZFS maleje.

## 2. NFS v4.2 z hosta i statyczne PV

### Rola

Host Proxmox eksportuje przez `nfs-kernel-server` katalogi `/Storage`, `/SSDStorage`, `/ssdstage` i `/srv/downloads` (union mergerfs, z wymuszonym `fsid=72`) tylko dla trzech węzłów Talos i localhosta [plik `Ansible/vars/proxmox.yaml`]. W klastrze są statyczne PV/PVC: `media-pvc` (8 Ti), `downloads-pvc`, `personal-pvc` (`/SSDStorage`), `downloads-ssd-pvc`, `downloads-pool-pvc`, `immich-upload` (`/Storage/Photos`), z opcjami `nfsvers=4.2,noatime` [plik `Kubernetes/apps/common/media-pv.yaml`]. Adres serwera podstawia root `kustomization.yaml` [plik `CLAUDE.md`].

### Od kiedy i co zastąpił

- E1-E2 (docker-compose): kontenery montowały ścieżki hosta bezpośrednio (`STORAGE_PATH`, `/public/Storage`) [commit `5171ff5`, 2024-01-19], [commit `d68bcf6`, 2024-03-26].
- E3 (k3s, 2025-08 → 2026-01): aplikacje mediów montowały `hostPath: /Storage` albo `/Storage/Media`, a konfiguracje trzymały w PVC bez `storageClassName` [plik `Kubernetes/media/*/deployment.yaml` @ `ba45059`, 2026-01-14]. k3s działał na kontenerach Proxmoxa wykrywanych przez Tailscale, w grupach `server` i `agent` [plik `Ansible/k3s.yaml` @ `ba45059`]. [wniosek] PVC bez klasy trafiały do domyślnej klasy k3s, czyli local-path-provisionera (`local-path`, dane w `/var/lib/rancher/k3s/storage`, wolumin trwale wiąże pod z węzłem) [źródło: https://raw.githubusercontent.com/k3s-io/docs/main/docs/add-ons/storage.md, dostęp 2026-11-27]. Skąd węzły k3s miały `/Storage` dla hostPath (np. bind mount do kontenera) i ile ich było: [nieznane].
- E4: po przejściu na trzy VM Talos hostPath przestał wystarczać. 2026-02-16 dodano dynamiczny `nfs-csi` [commit `6cba788`, 2026-02-16], a 4 dni później zastąpiono go 5 statycznymi parami PV/PVC [commit `a338df4`, 2026-02-20]. Commit opisuje co, nie dlaczego. [wniosek] Dynamiczny provisioner tworzył katalogi z UUID (commit wspomina „Fix Jellyfin media mount (movies/tv/downloads instead of UUID dirs)”), a biblioteka mediów musi mieć stałe, czytelne ścieżki.

### Ograniczenia napotkane w repo

- Opcja `hard` jest domyślna w kliencie NFS, więc po przestoju VM wszystkie operacje na montowaniu wiszą bez końca; `talosctl processes` tego nie pokazuje [plik `CLAUDE.md`], [commit `034599f`, 2026-09-21].
- Jeden zablokowany transport do serwera blokuje wszystkie montowania z tego serwera na danym węźle [plik `Kubernetes/AGENTS.md`], [commit `36e6157`, 2026-09-01].
- Serwer NFS musi wstać przed VM i zatrzymać się po nich (override `Before=pve-guests.service`) [plik `CLAUDE.md`].
- Udział FUSE (mergerfs) wymaga stałego `fsid`, inaczej klienci dostają `ESTALE` po każdym ponownym połączeniu [plik `Ansible/vars/proxmox.yaml`].

### Alternatywy

[wniosek] Dla jednego hosta z pulą ZFS zamiennikami są: SMB (słabsze uprawnienia POSIX dla kontenerów), `democratic-csi` (dynamiczne datasety ZFS przez NFS/iSCSI, zob. tabelę Longhorn) albo przeniesienie dysków do VM i Longhorn/Ceph (traci się ZFS i usypianie HDD). Statyczne PV są najprostsze, gdy udziałów jest kilka i rzadko się zmieniają.

## 3. mergerfs i pula pobierania SSD

### Rola

qBittorrent pobiera i seeduje z unii mergerfs: najpierw NVMe (`/ssdstage/dl`), przy braku miejsca HDD (`/Storage/dl`), a stara gałąź `/Storage/Media/Downloads` ma tryb `NC` (bez tworzenia nowych plików), więc z czasem się opróżnia. Opcje: `category.create=ff`, `minfreespace=25G` (dla NVMe 75G), `moveonenospc=true`, `inodecalc=path-hash`, `noforget` [plik `Ansible/vars/proxmox.yaml`], [plik `docs/ssd-download-pool.md`].

### Od kiedy

2026-09-01 [commit `0bdd584`, 2026-09-01]; wcześniej (2026-08-31) przez krótki czas niepełne pliki trafiały na NVMe bez unii [commit `b4744b4`, 2026-08-31].

### Co zastąpił i dlaczego

Pobieranie wprost na HDD. Dokument podaje zmierzony efekt: `write_cache_overload` 44% → 0%, `queued_io_jobs` 6018 → 0, 106 torrentów wznowionych bez ponownego sprawdzania [plik `docs/ssd-download-pool.md`]. Ten sam dokument mówi, że Radarr/Sonarr kopiują pliki zamiast tworzyć hardlinki, i nazywa to świadomie przyjętym kosztem.

### Ograniczenia napotkane w repo

- mergerfs nigdy nie przenosi pliku z powrotem na szybszą gałąź; nie ma rebalancera, `moveonenospc` przenosi tylko w dół [plik `CLAUDE.md`].
- Zmiana nazwy przez mergerfs zmienia `st_ino` (`path-hash`), co psuje klientów NFS z otwartym plikiem (`fileid changed`). Stąd wyłączenie dopisywania `.!qB` w qBittorrent [commit `bfeb1c6`, 2026-09-01], [commit `3804899`, 2026-09-02].
- Usunięcie pliku otwartego przez NFS zostawia osierocone `.nfs*` pełnej wielkości (95 GB znalezione). Wyzwala to „Mark as failed” w Sonarr/Radarr na seedowanym torrencie [commit `957d2a2`, 2026-11-19].
- Relokacja przez `sendfile()` zapisuje dziury jako zera (zob. ZFS `zle`).
- Narzut FUSE+NFS ok. 20% (139 vs 168 MB/s) przy obciążeniu do ok. 60 MB/s [plik `docs/ssd-download-pool.md`].

### Alternatywy

mergerfs ma licencję ISC i nie dzieli danych na paski ani fragmenty („does not stripe or shard data”); przenoszenie między gałęziami robi użytkownik sam [źródło: https://github.com/trapexit/mergerfs/blob/master/LICENSE, dostęp 2026-11-27], [źródło: https://trapexit.github.io/mergerfs/latest/faq/usage_and_functionality/, dostęp 2026-11-27]. [wniosek] Zamiennikami są: osobny dataset na NVMe z ręcznym przenoszeniem (qBittorrent „incomplete → complete”, czyli wersja z [commit `b4744b4`, 2026-08-31]), L2ARC/special vdev ZFS (przyspiesza odczyt i metadane, nie zapis danych) albo zwykłe pobieranie na HDD. Unia wygrała, bo jedna ścieżka NFS obsługuje oba poziomy i nie trzeba było przenosić 2,4 TiB istniejących torrentów [plik `docs/ssd-download-pool.md`].

## 4. Longhorn (wolumeny aplikacji)

### Rola

Rozproszony blokowy storage w klastrze. Klasy: `longhorn` (domyślna z charta, 3 repliki), `longhorn-rwx` (2 repliki, NFS share-manager), `longhorn-cache` (1 replika, `dataLocality: best-effort`). Dane w `/var/mnt/longhorn` na osobnym dysku `scsi1` każdej VM [plik `Kubernetes/bootstrap/longhorn/storageclass.yaml`], [plik `Terraform/talos.tf`]. Chart 1.13.0 [plik `Kubernetes/bootstrap/longhorn/kustomization.yaml`].

Uwaga o liczbie replik: `defaultSettings.defaultReplicaCount: 2` dotyczy wolumenów tworzonych bez parametru klasy. Klasa `longhorn` bierze `persistence.defaultClassReplicaCount`, którego repo nie nadpisuje, a w charcie 1.13.0 wynosi on 3. To zgadza się z komentarzem „Every volume has 3 replicas on 3 nodes” w kustomizacji [plik `Kubernetes/bootstrap/longhorn/kustomization.yaml`], [źródło: https://raw.githubusercontent.com/longhorn/longhorn/v1.13.0/chart/values.yaml, dostęp 2026-11-27].

### Od kiedy

2026-02-01, w jednym commicie „migrate” razem z ESO i observability [commit `6757719`, 2026-02-01] (gałąź migracyjna; na `main` od 2026-02-26, `327eff3`). Commit nie ma opisu.

### Co zastąpił i dlaczego

[wniosek] W E3 (k3s) konfiguracje trzymał local-path-provisioner (PVC bez klasy, zob. sekcja 2), a taki wolumin nie opuszcza węzła. Przejście na trzy VM Talos wymagało storage'u, który przeżyje przeniesienie poda na inny węzeł. Motyw wyboru Longhorna zamiast Rook-Ceph czy OpenEBS nie jest zapisany w repo; pytanie do autora.

### Ważne zastrzeżenie architektoniczne

Wszystkie trzy VM Talos stoją na jednym hoście `carbon` (`proxmox_node = "carbon"`), a ich dyski `scsi1` są zvolami na tym samym `local-zfs` [plik `Terraform/variables.tf`], [plik `Terraform/proxmox.tf`]. [wniosek] Repliki Longhorna chronią więc przed awarią lub restartem pojedynczej VM, a nie przed awarią dysku czy hosta. Przed tym chroni dopiero redundancja `rpool` (jej układ: [nieznane]) i kopia Borg poza domem. Dane są też zapisywane wielokrotnie: 3 repliki × zapis ZFS na tych samych nośnikach.

### Historia zmian i incydenty

| Data | Co | Dowód |
| --- | --- | --- |
| 2026-02-26 | przypięcie charta do 1.7.2, potem 1.8.2 i 1.11.0, usunięcie joba uninstall i hooków | [commit `657cc68`], [commit `2a4c717`], [commit `2aa6c62`], [commit `bcf28ca`] |
| 2026-03-06 | 17 zawieszonych VolumeSnapshot (ok. 36 GiB) usuniętych, presja dysku | [commit `142f214`, 2026-03-06] |
| 2026-03-10 | PVC Loki zmniejszony do 1 Gi, żeby zmieścić się w wolnym miejscu Longhorna | [commit `5ecd2fe`, 2026-03-10] |
| 2026-05-23 | procedura awaryjna dla `emergency_ro` | [commit `91c55e5`, 2026-05-23] |
| 2026-06-03 | dane observability RWO → RWX, żeby jeden job backupu mógł je zamontować | [commit `1ff0808`, 2026-06-03] |
| 2026-08-19 | z powrotem RWX → RWO: share-manager NFS powodował 12-minutowe zawieszenie zamykania węzła | [commit `fb226ed`, 2026-08-19] |
| 2026-09-21/22 | burza odbudów replik, timeouty `engine-replica-timeout`; przyczyną okazał się konflikt IP talos-3, a dławienie odbudów cofnięto | [commit `7c1a8e3`], [commit `9903e08`, 2026-09-22], [commit `0b25106`, 2026-09-22] |
| 2026-09-24 | cache modeli Immich ML z Longhorna na lokalny PV węzła GPU | [commit `e690d6b`, 2026-09-24] |
| 2026-10-02 | aktualizacje Talos węzeł po węźle, każda czeka na zdrowe wolumeny Longhorna | [commit `feb2ee9`, 2026-10-02] |

### Ograniczenia napotkane w repo

Źródła: [plik `CLAUDE.md`], [plik `Kubernetes/AGENTS.md`].

- `emergency_ro`: aplikacje zgłaszają `Read-only file system`; trzeba odłączyć wolumen, skopiować dane z surowego urządzenia i uruchomić `e2fsck` [commit `91c55e5`, 2026-05-23].
- `nodeAffinity` PV jest niezmienne. Przeniesienie obciążenia na nowy węzeł wymaga dodania repliki, odłączenia, usunięcia PV z `Retain` i `pvCreate` [commit `d96741f`, 2026-06-14].
- RecurringJob: etykieta `recurring-job-group.longhorn.io/default` wraca przez webhook, choć grupa jest pusta. Wcześniejsza diagnoza, że ręczne snapshoty znikają po sekundach [commit `1ff0808`, 2026-06-03], została sprostowana pomiarem (snapshot przetrwał 30 min) [commit `2924c95`, 2026-09-22]. Nadaje się do pracy jako przykład poprawionej diagnozy.
- Usunięcie klucza z `defaultSettings` nie resetuje żywego `Setting`, więc repo i klaster mogą się rozjechać [commit `d10f74a`, 2026-09-22].
- Livelock odbudowy replik przy 8-sekundowym `engine-replica-timeout`; według gotchy trzeba wtedy wstrzymać odbudowy, dokładanie zasobów nie pomaga [plik `Kubernetes/AGENTS.md`]. Zastrzeżenie: obserwacje z 2026-09-21 okazały się skutkiem konfliktu IP talos-3 [commit `0b25106`, 2026-09-22], a timeout wrócił do 8 s [commit `b11c5b1`, 2026-09-22]. To opis mechanizmu, nie problem, który dziś występuje.
- RWX przez share-manager NFS wydłuża zamykanie węzła (ok. 12 min na montowanie bez drenażu) [commit `fb226ed`, 2026-08-19], [plik `CLAUDE.md`, sekcja Workflow].
- Niezgodność `revisionCounterDisabled` między repliką a wolumenem daje pętlę błędów [plik `Kubernetes/AGENTS.md`].

### Alternatywy

| Opcja | Licencja, status | Wymagania i ograniczenia | Źródło |
| --- | --- | --- | --- |
| Longhorn (wybrane) | Apache-2.0, v1.13.0 z 2026-09-29 | zalecane minimum: 3 węzły po 4 vCPU i 4 GiB RAM, SSD/NVMe, sieć 10 Gbps; zalecana domyślna liczba replik: 2; silnik V1 potrzebuje open-iscsi, RWX klienta NFSv4 (na Talosie dodatkowa konfiguracja); oficjalnie wspiera dyski ext4 i xfs | [źródło: https://api.github.com/repos/longhorn/longhorn/releases/latest, dostęp 2026-11-27], [źródło: https://longhorn.io/docs/latest/best-practices/, dostęp 2026-11-27], [źródło: https://longhorn.io/docs/latest/deploy/install/, dostęp 2026-11-27], [źródło: https://github.com/longhorn/longhorn/issues/5106, dostęp 2026-11-27] |
| Rook-Ceph | Apache-2.0, v1.21.3 z 2026-11-24 | wymaga surowych urządzeń lub partycji bez systemu plików i modułu `rbd` | [źródło: https://rook.io/docs/rook/latest-release/Getting-Started/Prerequisites/prerequisites/, dostęp 2026-11-27] |
| OpenEBS (Local PV ZFS/LVM/Hostpath, Mayastor) | Apache-2.0, v4.6.2, CNCF Sandbox | Local PV działa na jednym węźle; Mayastor wymaga 3 węzłów, 2 rdzeni na io-engine, 2 GiB hugepages, `nvme-tcp`, jądra ≥ 5.13 | [źródło: https://github.com/openebs/openebs, dostęp 2026-11-27], [źródło: https://openebs.io/docs/quickstart-guide/prerequisites, dostęp 2026-11-27] |
| local-path-provisioner (E3, k3s) | Apache-2.0, v0.0.37 | ignoruje limit pojemności, wolumin dostępny tylko na węźle, na którym powstał | [źródło: https://github.com/rancher/local-path-provisioner, dostęp 2026-11-27], [źródło: https://raw.githubusercontent.com/k3s-io/docs/main/docs/add-ons/storage.md, dostęp 2026-11-27] |
| democratic-csi | MIT, ostatnie wydania oznaczone jako prerelease (v1.1.0 z 2026-10-01) | dynamiczne datasety ZFS przez NFS/iSCSI (TrueNAS, ZoL, lokalny ZFS); część sterowników eksperymentalna | [źródło: https://github.com/democratic-csi/democratic-csi, dostęp 2026-11-27] |

Dokumentacja Longhorna ostrzega, że przy miękkiej anty-afinicji „one node down event may bring down more than one replicas of a volume” [źródło: https://longhorn.io/docs/latest/best-practices/, dostęp 2026-11-27]. Fizycznych domen awarii (kilka VM na jednym hoście) dokumentacja nie omawia [nieznane].

### Kiedy wybrać coś innego

[wniosek] Przy jednym fizycznym hoście replikacja między VM nie daje odporności sprzętowej, więc prostsze byłyby `local-path` albo `democratic-csi` (datasety ZFS hosta przez NFS/iSCSI), a ochronę dałyby snapshoty ZFS i Borg. Longhorn zaczyna się opłacać przy kilku fizycznych maszynach. Ceph (Rook) przy co najmniej trzech hostach z dedykowanymi dyskami i szybką siecią.

## 5. MinIO (epizod 2026-06-03)

Dodany jako lokalny cel S3 dla backupów Longhorna („replaces the broken media-backup and observability-backup CronJobs, which could not mount RWO Longhorn PVCs from different nodes”) [commit `145f097`, 2026-06-03] i wycofany tego samego dnia. Powód zapisany w commicie: Borg zostaje, bo deduplikacja na poziomie bloków i kompresja zstd dają mniejsze kopie niż natywne backupy Longhorna, które zapisują pełne dane wolumenu [commit `59a11a8`, 2026-06-03]. Problem montowania RWO rozwiązano później inaczej: jeden job na wolumen, przypięty do węzła aplikacji [commit `59022fc`, 2026-06-04], [commit `fb226ed`, 2026-08-19].

Stan projektu dziś: MinIO (AGPL-3.0) ma repozytorium zarchiwizowane z dopiskiem „THIS REPOSITORY IS NO LONGER MAINTAINED” (archiwizacja 2026-04-25), ostatnie wydanie z 2025-10-16, a wersja społecznościowa jest dostępna tylko jako kod źródłowy [źródło: https://github.com/minio/minio, dostęp 2026-11-27], [źródło: https://api.github.com/repos/minio/minio/releases/latest, dostęp 2026-11-27]. Usunięcie funkcji administracyjnych z konsoli w 2025 potwierdza tylko prasa branżowa [źródło: https://blocksandfiles.com/2025/06/19/minio-removes-management-features-from-basic-community-edition-object-storage-code/, dostęp 2026-11-27]. [wniosek] Rezygnacja z 2026-06-03 okazała się korzystna także z tego powodu, choć autor podał inny motyw.

## 6. BorgBackup do Hetzner Storage Box

### Rola

Jedyna kopia poza domem. Wszystkie joby piszą do jednego repozytorium Borg (`repokey`, kompresja zstd) przez SSH na port 23 Storage Boxa [plik `Kubernetes/apps/borgbackup/scripts/borg-backup.sh`], [plik `Terraform/hetzner.tf`].

### Od kiedy

- E1: Duplicati w docker-compose [commit `8f3e37d`, 2024-01-15], przeniesiony do stosu Immich [commit `8d6dcf4`, 2024-02-10], znika przy restrukturyzacji DMZ [commit `06b7e79`, 2024-02-26]. Co zastąpiło Duplicati między 2024-02 a 2026-02: [nieznane] (pytanie).
- E4: Storage Box BX11 w Terraformie z kluczem SSH ED25519 i hasłem generowanymi przez Terraform i zapisanymi w Bitwarden [commit `2b33dec`, 2026-02-24]; pierwszy CronJob `borgbackup` (Immich) [commit `16fdd8f`, 2026-02-24].
- Rozbudowa: media/home/observability [commit `441eb36`, 2026-05-23], wspólny skrypt i archiwa per aplikacja, repo przemianowane `backups/immich` → `backups/interstellar` [commit `a3e6c50`, 2026-06-04], orkiestrator sterowany etykietami PVC [commit `59022fc`, 2026-06-04], Traefik i CrowdSec [commit `771beb5`, 2026-09-21].

### Dlaczego Borg

Jedyny zapisany motyw to deduplikacja i kompresja w porównaniu z backupem Longhorna [commit `59a11a8`, 2026-06-03]. Dlaczego Borg, a nie restic/Kopia/Velero, i dlaczego Hetzner: [nieznane], pytanie do autora. [wniosek] Storage Box obsługuje Borga natywnie przez SSH, więc nie trzeba utrzymywać serwera kopii.

### Ograniczenia napotkane w repo

- Jedno repo dla wszystkich jobów, a Borg 1.4 czeka na blokadę domyślnie 1 s. Nachodzące na siebie joby padały. Pierwsza poprawka użyła nieistniejącej zmiennej `BORG_LOCK_WAIT` [commit `aa8466b`, 2026-09-21]; działa dopiero `--lock-wait 3600` [commit `db85464`, 2026-11-09]. To drugi przykład poprawionej poprawki.
- Zabity pod zostawia blokadę w repo, trzeba `borg break-lock` [commit `171f04b`, 2026-08-09].
- `--exclude-from` (styl `fm:`) nie umie ponownie dołączać ścieżek, a `*` przechodzi tam przez `/`; reguły `+` muszą trafić do `--patterns-from` [commit `2ca87ba`, 2026-08-09], [commit `0412179`, 2026-08-09].
- Kod wyjścia 1 (ostrzeżenie: plik zmienił się w trakcie, np. WAL Lokiego) oznaczał job jako nieudany, więc skrypt traktuje 1 jako sukces [commit `782e2fa`, 2026-08-31].
- `concurrencyPolicy: Forbid` bez limitu czasu: zawieszony `apk add` blokował kolejne kopie przez 13 h i nic nie alarmowało. Dodano `activeDeadlineSeconds` [commit `7780f83`, 2026-09-22] i alert „Backup Not Succeeding” (ponad 36 h od ostatniego sukcesu) [commit `c37bf8b`, 2026-09-22], [plik `Kubernetes/bootstrap/observability/config/grafana-alerting.yaml`].
- Reloader nie może restartować CronJobów z backupem, bo przerwałby trwającą kopię i zostawił blokadę [commit `700a268`, 2026-11-12].
- Skrypt przy każdym uruchomieniu instaluje `borgbackup` przez `apk` (obraz `alpine`), więc kopia zależy od dostępności mirrorów Alpine [plik `Kubernetes/apps/borgbackup/scripts/borg-backup.sh`]. Właśnie `apk add` zawiesił się na sieci 2026-09-22 [commit `7780f83`, 2026-09-22].

### Alternatywy

| Opcja | Licencja, status | Ograniczenia | Źródło |
| --- | --- | --- | --- |
| BorgBackup (wybrane) | BSD-3-Clause; stabilna seria 1.4 (1.4.5), Borg 2.0 „currently in testing, do not use it in production” | Storage Box obsługuje Borga przez SSH na porcie 23 [źródło: https://docs.hetzner.com/storage/storage-box/access/access-ssh-rsync-borg/, dostęp 2026-11-27]; blokada repo przy wielu klientach (zob. wyżej, dowody z repo) | [źródło: https://github.com/borgbackup/borg/blob/master/LICENSE, dostęp 2026-11-27], [źródło: https://www.borgbackup.org/releases/, dostęp 2026-11-27] |
| restic | BSD-2-Clause, v0.20.0 z 2026-11-19 | backendy: local, SFTP, REST, S3, B2, Azure, GCS, rclone; utrata hasła oznacza nieodwracalną utratę danych | [źródło: https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html, dostęp 2026-11-27] |
| Kopia | Apache-2.0, v0.23.1 z 2026-06-16 | brak kontroli dostępu przy współdzielonym repo, nie odtworzy uszkodzonego pliku danych, rclone eksperymentalny | [źródło: https://kopia.io/docs/features/, dostęp 2026-11-27] |
| Velero | Apache-2.0, v1.19.0 z 2026-11-23 | kopiuje obiekty Kubernetes i wolumeny (snapshoty CSI albo File System Backup na Kopii); FSB nie daje kopii z jednego punktu w czasie, nie obsługuje hostPath, wymaga uprawnień root | [źródło: https://velero.io/docs/main/, dostęp 2026-11-27], [źródło: https://velero.io/docs/main/file-system-backup/, dostęp 2026-11-27] |
| Duplicati (używane w E1) | MIT (poza katalogiem `proprietary/`), aktywny, v2.4.1.1 z 2026-11-25 | [nieznane] | [źródło: https://github.com/duplicati/duplicati/blob/master/LICENSE, dostęp 2026-11-27], [źródło: https://api.github.com/repos/duplicati/duplicati/releases, dostęp 2026-11-27] |

[wniosek] Velero rozwiązywałby inny problem niż obecne joby: odtwarza obiekty Kubernetes, a tu manifesty są w Git i odtwarza je ArgoCD. Kopie potrzebne są tylko dla danych.

### Kiedy wybrać coś innego

[wniosek] restic albo Kopia, gdy celem ma być S3/B2 zamiast serwera SSH, albo gdy wiele klientów ma pisać równolegle (Borg serializuje je blokadą). Velero, gdy klaster nie jest w całości w GitOps.

### Alternatywy celu kopii

| Cel | Cena (stan 2026-11-27) | Uwagi | Źródło |
| --- | --- | --- | --- |
| Hetzner Storage Box BX11 (wybrane) | 3,20 EUR/mies. netto za 1 TB, 10 snapshotów; BX21 (5 TB) 10,90 EUR | protokoły: SFTP, SCP, SMB, BorgBackup, restic, rclone, rsync, WebDAV; SSH na porcie 23 bez pełnej powłoki | [źródło: https://www.hetzner.com/storage/storage-box/, dostęp 2026-11-27], [źródło: https://docs.hetzner.com/storage/storage-box/access/access-ssh-rsync-borg/, dostęp 2026-11-27] |
| Backblaze B2 | 6,95 USD/TB/mies.; pobieranie darmowe do 3× średniej przechowywanej ilości | brak minimalnego okresu przechowywania; [wniosek] wymaga narzędzia z obsługą S3/B2, np. restic | [źródło: https://www.backblaze.com/cloud-storage/pricing, dostęp 2026-11-27] |
| AWS S3 Standard (us-east-1) | 0,023 USD/GB/mies. (ok. 23 USD/TB) | | [źródło: https://b0.p.awsstatic.com/pricing/2.0/meteredUnitMaps/s3/USD/current/s3.json, dostęp 2026-11-27] |
| S3 Glacier Deep Archive | 0,00099 USD/GB/mies. (ok. 1 USD/TB) | minimum 180 dni przechowywania; [wniosek] nie nadaje się do codziennej deduplikowanej kopii | [źródło: https://aws.amazon.com/s3/storage-classes/glacier/, dostęp 2026-11-27], [źródło: https://aws.amazon.com/s3/pricing/, dostęp 2026-11-27] |

## 7. Strategia kopii (3-2-1?)

### Co jest kopiowane, kiedy i jak

Wszystkie joby: Borg, `--compression zstd`, retencja `--keep-daily 7 --keep-weekly 4 --keep-monthly 6` per prefiks archiwum, potem `borg compact` [plik `Kubernetes/apps/borgbackup/scripts/borg-backup.sh`] (skrypt identyczny we wszystkich 6 kopiach, sprawdzone sumą md5).

| Godz. (UTC [wniosek]: CronJoby nie ustawiają `timeZone`) | CronJob (namespace) | Prefiks archiwum | Źródło | Spójność | Dowód |
| --- | --- | --- | --- | --- | --- |
| 03:00 | `borgbackup` (utilities) | `utilities-` | `immich-upload` (`/Storage/Photos`, bez miniatur i transkodów), `personal-pvc` (`/SSDStorage`, bez `.hist` i `public/` poza `public/safe`), `pg_dump -Fc` Immich i Authentik | zrzuty logiczne Postgresa; pliki na żywo | [plik `Kubernetes/apps/borgbackup/cronjob.yaml`] |
| 03:30 / 03:35 / 03:40 | `mimir-backup`, `grafana-backup`, `loki-backup` (observability) | `observability-mimir-`, `-grafana-`, `-loki-` | PVC `mimir-data`, `grafana-data`, `loki-data` | odczyt na żywo, crash-consistent | [plik `Kubernetes/bootstrap/observability/backup-cronjob.yaml`], [commit `fb226ed`, 2026-08-19] |
| 03:45 | `traefik-backup` (traefik) | `traefik-` | PVC `traefik` | na żywo | [plik `Kubernetes/bootstrap/traefik/backup-cronjob.yaml`] |
| 03:50 | `crowdsec-backup` (crowdsec) | `crowdsec-` | `crowdsec-config-pvc`, `crowdsec-db-pvc` | na żywo | [plik `Kubernetes/bootstrap/crowdsec/backup-cronjob.yaml`] |
| 04:00 | `media-backup` (media) | nazwa PVC bez `-config` | każdy PVC z etykietą `backup.interstellar/enabled=true`: bazarr, jellyfin, prowlarr, qbittorrent, radarr, seerr, sonarr; wykluczenia z adnotacji (cache, logi, MediaCover, Backups) | na żywo, job przypięty do węzła poda | [plik `Kubernetes/apps/media-backup/scripts/media-backup-orchestrator.sh`], [plik `Kubernetes/apps/*/pvc.yaml`] |
| 04:30 | `home-backup` (home) | `home-` | PVC `adguard-data` (bez `querylog.json*`) | AdGuard skalowany do 0 na czas kopii, więc spójna | [plik `Kubernetes/apps/home-backup/scripts/home-backup.sh`], [commit `c664dd4`, 2026-06-19] |

Wszystkie siedem CronJobów pasuje do wyrażenia `.*backup.*` w alercie „Backup Not Succeeding”, więc każdy jest monitorowany [plik `Kubernetes/bootstrap/observability/config/grafana-alerting.yaml`].

Snapshoty po stronie Hetznera: co tydzień (niedziela, godz. 6, strefa wg API Hetznera), maks. 10, czyli okno ok. 10 tygodni. Uzasadnienie w commicie: snapshoty mają przetrwać zniszczenie repo przez przejętego klienta, bo pod backupu ma klucz SSH z prawem zapisu, a snapshotów tym kluczem usunąć się nie da. Cel 6 miesięcy wymagałby BX31 [commit `b6b0e81`, 2026-08-20]. Storage Box ma `delete_protection` i `prevent_destroy` [plik `Terraform/hetzner.tf`].

### Czego nie ma w kopii

| Dane | Gdzie | Status | Dowód / komentarz |
| --- | --- | --- | --- |
| Biblioteka mediów (filmy, seriale) | `/Storage/Media` (8 Ti PV) | brak kopii | żaden job tego nie montuje; [wniosek] dane da się pobrać ponownie, decyzja do potwierdzenia |
| Pobierane torrenty | `/ssdstage/dl`, `/Storage/dl` | brak kopii | z założenia „re-downloadable” [plik `docs/ssd-download-pool.md`] |
| Pagewire | `pagewire-data`, `pagewire-blobs` (namespace `printing`) | brak kopii | brak etykiety, a orkiestrator przegląda tylko namespace `media` [plik `Kubernetes/apps/pagewire/pvc.yaml`]; aplikacja z 2026-11-25. Od 2026-11-27 skany leżą poza Longhornem, na NFS w `/Storage/Media/Scans` (PVC `pagewire-scans`, 100 Gi), czyli w bibliotece mediów, która też nie ma kopii [commit `e7ae5da`, 2026-11-27] |
| clips-sftp | `clips-sftp-state` (utilities) | brak kopii | nie jest w `BORG_BACKUP_TARGETS` [plik `Kubernetes/apps/clips-sftp/pvc.yaml`] |
| CrowdSec web UI | `crowdsec-web-ui-data` | brak kopii | [plik `Kubernetes/bootstrap/crowdsec/web-ui/pvc.yaml`] |
| Cache Immich ML | `immich-ml-local-cache` | brak kopii | cache, odtwarzalny |
| VM Home Assistant | Proxmox | brak w repo | repo nie zawiera vzdump ani Proxmox Backup Server; [nieznane], czy HA robi własne kopie |
| Konfiguracja hosta Proxmox | `carbon` | częściowo jako kod | Ansible odtwarza NFS, ZFS-tuning, zasilanie [plik `Ansible/setup-proxmox.yaml`]; samej puli ani instalacji Proxmoxa repo nie tworzy |
| Snapshoty ZFS na hoście | - | brak w repo | żadnego `zfs snapshot`, sanoid ani zrepl w repo |
| PVC renderowane przez Helm (Authentik, ArgoCD i inne charty) | - | nie sprawdzono | wyliczenie objęło tylko PVC zapisane wprost w manifestach; Postgres Authentika jest kopiowany przez `pg_dump`, CrowdSec i Traefik mają własne joby |
| Backupy Longhorna | - | brak | brak `RecurringJob` i backup targetu [commit `2924c95`, 2026-09-22], [commit `59a11a8`, 2026-06-03] |

Poza Borgiem, ale odtwarzalne z innego miejsca:
- stan Terraform w OCI Object Storage z włączonym wersjonowaniem [plik `Terraform/oracle.tf`], [plik `Terraform/backend.tf`];
- sekrety w Bitwarden SM (chmura);
- manifesty i konfiguracja w Git (GitHub).

### Ocena względem 3-2-1

[wniosek] Reguła 3-2-1: trzy kopie, na dwóch rodzajach nośników, w tym jedna poza siedzibą.

| Kryterium | Stan | Komentarz |
| --- | --- | --- |
| Liczba kopii | 2 | produkcyjna (ZFS/Longhorn w domu) i repo Borg u Hetznera. Snapshoty Hetznera to wersje tego samego repo w tym samym centrum danych, więc nie liczą się jako trzecia kopia. Repliki Longhorna leżą na tych samych dyskach `rpool`, więc też się nie liczą |
| Rodzaje nośników | 2 | dom i Hetzner |
| Kopia poza domem | jest | Hetzner |
| Wynik | raczej „2-2-1” | przed przejęciem klienta chronią snapshoty, których klucz poda nie usunie (okno 10 tygodni) |
| Retencja | 7 dziennych, 4 tygodniowe, 6 miesięcznych w Borgu | plus 10 tygodniowych snapshotów Hetznera |

Spójność kopii. Bazy Postgres (Immich, Authentik) są zrzucane logicznie, a AdGuard zatrzymywany. Pozostałe wolumeny (Mimir, Loki, Grafana, Traefik, CrowdSec, aplikacje *arr z bazami SQLite) są kopiowane na żywo, czyli crash-consistent [commit `fb226ed`, 2026-08-19]. [wniosek] Bazy SQLite aplikacji *arr mogą po odtworzeniu wymagać naprawy. Aplikacje mają własne katalogi `Backups`, ale adnotacje `excludes` wyłączają je z kopii. AdGuard ma jedną replikę [plik `Kubernetes/apps/adguard/deployment.yaml`], więc [wniosek] na czas `home-backup` (od 04:30) DNS w LAN przestaje odpowiadać, o ile klienci nie mają zapasowego resolvera.

Zależność cykliczna przy odtwarzaniu. Hasło repo i klucz SSH istnieją w Bitwarden i w stanie Terraform (generują je `random_password` i `tls_private_key`) [plik `Terraform/hetzner.tf`]. Procedura odtwarzania pobiera je przez `bws secret get` [plik `SETUP.md`]. [wniosek] Bez dostępu do Bitwarden i do stanu Terraform w OCI archiwów nie da się odszyfrować. Czy autor ma kopię offline: pytanie.

Test odtwarzania. `SETUP.md` opisuje odtwarzanie aplikacji i baz [plik `SETUP.md`], a gotcha wspomina testowe archiwa `verifytest-*` [commit `171f04b`, 2026-08-09]. Repo nie zawiera zapisu pełnego testu odtwarzania z datą i zmierzonym czasem (RTO). [wniosek] Taki test to materiał na rozdział „Odtwarzanie po awarii”.

## 8. Sekrety: Bitwarden Secrets Manager + External Secrets Operator

### Rola

Wszystkie sekrety klastra i CI pochodzą z Bitwarden SM. Dwa projekty:
- `interstellar`: sekrety wpisywane ręcznie (Cloudflare, Google OAuth, Tailscale OAuth), w Terraformie jako zasoby z `ignore_changes = [value]` i `postcondition`, która wymaga niepustej wartości;
- `interstellar-generated`: sekrety tworzone przez Terraform (`random_password`, `tls_private_key` → `bitwarden-secrets_secret`).

[plik `Terraform/bitwarden.tf`], [plik `Terraform/secrets.tf`]

W klastrze ESO (chart 2.15.0, 2 repliki) z `bitwarden-sdk-server` czyta je przez dwa `ClusterSecretStore`: `bitwarden-store` i `bitwarden-store-generated` [plik `Kubernetes/bootstrap/external-secrets/kustomization.yaml`]. CI (GitHub Actions) pobiera sekrety przez `bitwarden/sm-action` [commit `c75ff53`, 2026-04-29]; lokalnie `scripts/setup-env.sh` [plik `CLAUDE.md`].

### Od kiedy

ESO + sdk-server [commit `6757719`, 2026-02-01] (na `main` od 2026-02-26); token dostępu ESO tworzy Terraform przez provider Kubernetes, co rozwiązuje problem „jajka i kury” (ESO potrzebuje sekretu, żeby czytać sekrety) [commit `c7e08a1`, 2026-02-18]; `secrets.tf` z generowaniem haseł [commit `d3f5333`, 2026-02-19]; podział na dwa store'y [commit `0f79e5f`, 2026-02-25]; przeniesienie wszystkich ręcznych sekretów i sekretów GitHub App do Bitwarden [commit `8019d5b`, 2026-02-26], [commit `228af66`, 2026-02-26]; organizacja Bitwarden założona od nowa [commit `24834b9`, 2026-07-19].

### Co zastąpił

- E1: pliki `.env` obok compose. Wzorce `.env.example` miały puste wartości [commit `6038726`, 2024-01-15]. Przy restrukturyzacji DMZ na kilka godzin trafiły jednak do repo wypełnione pliki `envs/.env.*`; usunięto je tego samego dnia i dopisano do `.gitignore` [commit `d68685f`, 2024-02-26].
- E2: `.env` przemianowany na `.env.example` [commit `c67b548`, 2024-07-14], później `.env.authentik.example` i `.env.decluttarr.example` [commit `c8dccdd`, 2025-02-12].
- E3: `.secrets.exmaple` (sic) dla narzędzia `act` i Terraform (`TF_VAR_*`, `PM_PASS`, `TS_OAUTH_SECRET`) [commit `dc9916f`, 2025-08-02], katalog `Keys/` [commit `1bb126d`, 2025-07-26], sekrety GitHub Actions, a w k3s ręcznie stosowane manifesty `kind: Secret` z placeholderami [plik `Kubernetes/infrastructure/traefik/secret.yaml` @ `ba45059`].
- Sprzątanie śladów: usunięcie z repo danych uwierzytelniających zapisanych w `docs/superpowers` i hasła AdGuard zapisanego literałem [commit `c3bd45f`, 2026-08-13].

### Dlaczego

Motyw wyboru Bitwarden SM zamiast SOPS/Sealed Secrets/Vault nie jest zapisany; pytanie do autora. Historia repo daje dwa przypadki wycieku sekretów do Git: pliki env z 2024-02-26 oraz dane uwierzytelniające i hasło AdGuard usunięte 2026-08-13 (zob. wyżej). [wniosek] Rachunek z repo: jedno źródło dla Terraformu, CI i klastra, generowanie haseł jako kod, brak zaszyfrowanych blobów w publicznym repo i brak własnego serwera sekretów do utrzymania. Dlaczego organizację założono od nowa (2026-07-19): [nieznane].

### Ograniczenia napotkane w repo

- `bitwarden-sdk-server` wymaga certyfikatów TLS przed instalacją (`scripts/generate-bitwarden-tls.sh`) [plik `Kubernetes/bootstrap/external-secrets/kustomization.yaml`].
- Burze odświeżeń Bitwarden SDK o pełnej godzinie potrafiły zabić przez OOM Flannel na węźle GPU; obejście: rozrzucić `refreshInterval` [plik `CLAUDE.md`]. Źródła się tu różnią: raport z dochodzenia podaje jako przyczynę restartów węzła GPU stare dane członka etcd, a restarty Flannela nazywa skutkiem ubocznym rebootów [plik `.opencode/tmp/GPU-Crash-Investigation.md` w `d033e3c`]; zob. `historia/04-przebudowa-gitops.md`.
- Reapply CRD przez Helm przekraczał limit adnotacji, więc `installCRDs: false` [commit `3c5ef40`, 2026-02-26].
- ExternalSecret wskazujący klucz, którego nie ma jeszcze w Bitwarden, kończy się `SecretSyncedError`; dla byparr-proxy trzeba go było usunąć [commit `dea8f50`, 2026-04-14].
- Zależność od chmury Bitwarden przy starcie od zera (zob. zależność cykliczna w sekcji 7).

### Alternatywy

| Opcja | Licencja, status | Ograniczenia | Źródło |
| --- | --- | --- | --- |
| Bitwarden SM + ESO (wybrane) | ESO: Apache-2.0, v2.15.0; Bitwarden SDK: własna licencja (nie OSI); plan Free: 2 użytkowników, 3 projekty, 3 konta maszynowe, sekrety bez limitu | dostawca Bitwarden w ESO wymaga `bitwarden-sdk-server` działającego po HTTPS; zależność od chmury | [źródło: https://bitwarden.com/products/secrets-manager/, dostęp 2026-11-27], [źródło: https://github.com/bitwarden/sdk-sm/blob/main/LICENSE, dostęp 2026-11-27], [źródło: https://external-secrets.io/latest/provider/bitwarden-secrets-manager/, dostęp 2026-11-27] |
| SOPS | MPL-2.0, v3.13.3, CNCF Sandbox od 2023-05-17 | [wniosek] zaszyfrowane pliki w Git; klucz deszyfrujący trzeba przechowywać i odtwarzać osobno | [źródło: https://api.github.com/repos/getsops/sops/releases/latest, dostęp 2026-11-27], [źródło: https://www.cncf.io/projects/sops/, dostęp 2026-11-27] |
| Sealed Secrets | Apache-2.0, v0.41.2 | klucz prywatny tylko w klastrze, więc kopię trzeba robić samemu; odnowienie klucza nie szyfruje istniejących sekretów | [źródło: https://github.com/bitnami-labs/sealed-secrets, dostęp 2026-11-27] |
| HashiCorp Vault | BSL 1.1 od wersji 1.15.0 (zmiana ogłoszona 2023-08-10) | [wniosek] własny serwer do utrzymania | [źródło: https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license, dostęp 2026-11-27], [źródło: https://github.com/hashicorp/vault/blob/main/LICENSE, dostęp 2026-11-27] |
| OpenBao | MPL-2.0, v2.7.3, fork Vaulta pod OpenSSF (Linux Foundation) | [wniosek] jak Vault: własny serwer | [źródło: https://openbao.org/, dostęp 2026-11-27] |
| 1Password Operator + Connect | operator MIT; Business 8,99 USD/użytkownika/mies. | wymaga samodzielnie hostowanego serwera Connect | [źródło: https://github.com/1Password/onepassword-operator, dostęp 2026-11-27], [źródło: https://1password.com/pricing/business, dostęp 2026-11-27] |

[wniosek] Repo używa dwóch projektów Bitwarden (`interstellar`, `interstellar-generated`), więc mieści się w limicie 3 projektów planu Free. Ile kont maszynowych jest w użyciu (CI, ESO, lokalny `bws`): [nieznane].

### Kiedy wybrać coś innego

[wniosek] SOPS (age) albo Sealed Secrets, gdy nie chce się zależności od zewnętrznej usługi i wystarcza szyfrowanie w Git. Vault/OpenBao przy dynamicznych poświadczeniach i wielu zespołach. 1Password, gdy menedżer haseł tej firmy już jest w użyciu.

## 9. Obserwowalność

### Rola i skład

Serwera Prometheus w repo nie ma: metryki zbiera Alloy, a przechowuje Mimir. Skład namespace `observability`:

| Element | Rola | Dowód |
| --- | --- | --- |
| Grafana | dashboardy (cluster, Traefik, media, logi, geo, IP, CrowdSec, Longhorn), alerty z kontaktami Discord i e-mail, logowanie przez Authentik OIDC | [plik `Kubernetes/bootstrap/observability/kustomization.yaml`], [commit `f5c2493`, 2026-02-20] |
| Mimir | magazyn metryk, `filesystem`, `replication_factor: 1`, retencja 14 dni | [plik `Kubernetes/bootstrap/observability/config/mimir.yaml`] |
| Alloy | scrape kubelet/cAdvisor/podów/Longhorna i `remote_write` do Mimira; allowlista metryk tylko pod dashboardy i alerty | [plik `Kubernetes/bootstrap/observability/config/alloy.alloy`], [commit `8ec8693`, 2026-02-28] |
| Loki | logi, `filesystem`, retencja 168 h, dla logów `info` i `debug` 48 h | [plik `Kubernetes/bootstrap/observability/config/loki.yaml`] |
| Promtail | zbieranie logów podów, wzbogacanie GeoIP dla logów Traefika | [commit `4491ce8`, 2026-02-19], [commit `517cafd`, 2026-11-07] |
| node-exporter, kube-state-metrics | metryki węzłów i obiektów | [commit `d7f1515`, 2026-07-16], [commit `4491ce8`, 2026-02-19] |
| talos-kmsg-shipper | DaemonSet `cat /dev/kmsg` → Loki (Talos nie ma SSH, więc log jądra trzeba wysłać z klastra) | [commit `70fb7b4`, 2026-06-21] |
| smartd + ZED na hoście | alerty dyskowe prosto na Discord | [commit `dc32b4e`, 2026-10-26] |

Alerty (Grafana-managed): CPU, pamięć, restarty i crashloopy, Pod Not Ready, PVC prawie pełny, Node Not Ready i flapping, wygasające certyfikaty, Backup Not Succeeding, 6 reguł Longhorna, 5xx i p95 Traefika, błędy I/O w podach, korupcja etcd [plik `Kubernetes/bootstrap/observability/config/grafana-alerting.yaml`].

### Od kiedy i co zastąpiło

Cały stos przyszedł w [commit `6757719`, 2026-02-01]. Przed E4 w plikach YAML repo nie ma Prometheusa, Grafany, Uptime Kuma, Netdata ani Scrutiny; w compose był Portainer od [commit `34a5add`, 2024-02-08] do [commit `c8dccdd`, 2025-02-12]. [wniosek] Wcześniej monitoringu jako kodu nie było; jak autor wtedy obserwował serwer: pytanie.

### Dlaczego Mimir zamiast Prometheusa

Nie zapisano; pytanie. [wniosek] Alloy jako agent z `remote_write` i Mimir jako magazyn to układ, w którym metryki i logi idą przez narzędzia jednego dostawcy (Grafana Labs).

### Ograniczenia napotkane w repo

- Szablony powiadomień Grafany używają forka alertmanagera bez części funkcji (`humanizeDuration` itd.); brakująca funkcja wywraca Grafanę przy starcie [commit `b3eb223`, 2026-07-23].
- Plik provisioningu alertów musi być poprawnym YAML-em, a `summary` z `printf` trzeba cytować [commit `f09c21e`, 2026-07-16].
- Loki 3.7 odrzuca wszystkie zapisy, gdy WAL przekroczy 90% wolumenu [commit `62cdbd0`, 2026-08-08]; PVC powiększony 1 → 10 Gi [commit `2874089`, 2026-08-08]. 97% wolumenu logów robił `kube-network-policies` na `--v=2` [plik `Kubernetes/AGENTS.md`].
- Alloy nie obserwuje swojego pliku konfiguracyjnego, więc zmiana działa dopiero po restarcie DaemonSetu [commit `d10f74a`, 2026-09-22].
- Metryka potrzebna alertowi backupu była odcinana przez allowlistę Alloya [commit `c37bf8b`, 2026-09-22].
- Odczyty sysfs GPU przez eksportery wybudzają kartę i kosztują 7-8 W, więc eksporterów GPU się nie dodaje [plik `CLAUDE.md`].
- Mimir zabijał się sam i alarmował przy NoData [commit `6046838`, 2026-09-21].
- Monitoring działa w klastrze, który monitoruje. [wniosek] Przy awarii całego klastra (albo AdGuarda/DNS) alerty z Grafany nie wyjdą; niezależne są tylko smartd/ZED na hoście.

### Alternatywy

| Opcja | Licencja, status | Ograniczenia | Źródło |
| --- | --- | --- | --- |
| Grafana | AGPL-3.0 (od 2021-04-20, wcześniej Apache-2.0), v13.3.2 | | [źródło: https://grafana.com/licensing/, dostęp 2026-11-27] |
| Loki | AGPL-3.0, v3.7.10 | indeksuje tylko etykiety, szybkie zapytania wymagają małej liczby etykiet o niskiej kardynalności | [źródło: https://grafana.com/docs/loki/latest/get-started/overview/, dostęp 2026-11-27] |
| Mimir (wybrany zamiast Prometheusa) | AGPL-3.0, v3.2.6 z 2026-11-18 | tryb monolityczny „isn't recommended for large-scale deployments”; backend `filesystem` jest domyślny, ale nie ma go na liście backendów obiektowych | [źródło: https://grafana.com/docs/mimir/latest/configure/configuration-parameters/, dostęp 2026-11-27], [źródło: https://grafana.com/docs/mimir/latest/references/architecture/deployment-modes/, dostęp 2026-11-27], [źródło: https://grafana.com/docs/mimir/latest/configure/configure-object-storage-backend/, dostęp 2026-11-27] |
| Alloy | Apache-2.0, v1.22.0 | | [źródło: https://api.github.com/repos/grafana/alloy/releases/latest, dostęp 2026-11-27] |
| Promtail | „end of life (EOL) as of March 2, 2026”; trzeba migrować do Alloy | w repo nadal używany, więc to dług techniczny | [źródło: https://grafana.com/docs/loki/latest/send-data/promtail/, dostęp 2026-11-27] |
| Prometheus | Apache-2.0, v3.16.0 | lokalna pamięć „is not clustered or replicated” | [źródło: https://prometheus.io/docs/prometheus/latest/storage/, dostęp 2026-11-27] |
| VictoriaMetrics | Apache-2.0, v1.157.0 | downsampling, wiele retencji i vmbackupmanager tylko w Enterprise (kontrakt) | [źródło: https://docs.victoriametrics.com/victoriametrics/enterprise/, dostęp 2026-11-27] |
| Netdata | agent GPL-3.0-or-later; UI zamknięte („Closed-source but free to use”, NCUL1) | | [źródło: https://github.com/netdata/netdata, dostęp 2026-11-27] |
| Uptime Kuma | MIT, 2.5.12 | katalog danych na NFS „NOT supported” | [źródło: https://github.com/louislam/uptime-kuma, dostęp 2026-11-27] |

[wniosek] Promtail po EOL to konkretne zadanie na przyszłość: Alloy już działa w klastrze, więc migracja zbierania logów sprowadza się do zmiany konfiguracji.

### Kiedy wybrać coś innego

[wniosek] Uptime Kuma (albo zewnętrzny pinger) jako uzupełnienie, gdy trzeba wiedzieć o awarii całego klastra. VictoriaMetrics, gdy potrzebny jest jeden prosty serwer metryk na Apache-2.0 bez rozdziału na agenta i magazyn. Netdata, gdy potrzeba gotowych dashboardów hosta bez konfiguracji.

## 10. Stakater Reloader

### Rola

Restartuje Deploymenty, StatefulSety i DaemonSety po zmianie danych w ConfigMap lub Secret, który montują. Dzięki temu rotacja sekretu w Bitwarden (ESO → `Secret`) albo edycja configMapGeneratora dociera do poda [plik `Kubernetes/bootstrap/reloader/kustomization.yaml`].

### Od kiedy

[commit `6757719`, 2026-02-01], najpierw na adnotacjach per aplikacja. Pierwszy raz Reloader pojawia się jednak wcześniej, w `Kubernetes/infrastructure` na gałęzi migracyjnej [commit `d0ae5b1`, 2026-01-27]; zob. `historia/03-iac-i-pierwszy-kubernetes.md`. Od [commit `700a268`, 2026-11-12] `autoReloadAll: true` z wyjątkami: Joby i CronJoby (przerwałyby backup), namespace `kube-system` i `tailscale` (pętla restartów), qBittorrent i Jellyfin z opt-outem (przerwanie pobierania albo odtwarzania). Powód zapisany w commicie: zmiany konfiguracji aplikacji bez adnotacji nie docierały do działającego poda.

### Ograniczenia

Nawet zmiana samego komentarza w pliku configMapGeneratora zmienia hash i restartuje aplikacje (np. edycja `apps/common/scripts/*.sh` restartuje sonarr, radarr, prowlarr) [plik `Kubernetes/AGENTS.md`].

### Alternatywy

Reloader ma licencję Apache-2.0 (v1.4.25 z 2026-11-20, równolegle bety v2; repo używa charta 2.2.20) i obsługuje Deployment, StatefulSet, DaemonSet, DeploymentConfig i Argo Rollout [źródło: https://github.com/stakater/Reloader, dostęp 2026-11-27], [źródło: https://api.github.com/repos/stakater/Reloader/releases, dostęp 2026-11-27]. [wniosek] Zamienniki: hash treści w nazwie ConfigMapy (`configMapGenerator` bez `disableNameSuffixHash` robi to samo dla ConfigMap, ale nie dla Secretów z ESO) albo aplikacje, które same przeładowują pliki.

## Pytania do autora

1. Kiedy i dlaczego pula `Storage` zmieniła się z dwóch mirrorów na 4 dyskach (skrypt z 2024-03-26) w RAIDZ1 z 5 dysków? Czy dane przenoszono, czy pulę zbudowano od nowa?
2. Dlaczego w 2024-03 zastąpiłeś mdadm RAID10 ZFS-em?
3. Jaki układ ma `rpool` (mirror czy pojedynczy dysk)? To decyduje, czy Longhorn i etcd przeżyją awarię dysku systemowego.
4. Czego używałeś do kopii zapasowych między wycofaniem Duplicati (2024-02) a Borgiem (2026-02)? Czy w tym czasie była jakakolwiek kopia poza domem?
5. Dlaczego Borg + Hetzner Storage Box, a nie restic/Kopia do B2 lub S3? Czy liczyła się cena, natywna obsługa Borga przez Storage Box czy coś innego?
6. Czy brak kopii biblioteki mediów (`/Storage/Media`) to świadoma decyzja („da się pobrać ponownie”)?
7. Czy Pagewire (`pagewire-data`, `pagewire-blobs`) i `clips-sftp-state` mają celowo zostać bez kopii?
8. Czy VM Home Assistant ma jakąkolwiek kopię (vzdump, kopia z HA, nic)?
9. Czy masz offline'ową kopię hasła repo Borg i klucza SSH poza Bitwarden i stanem Terraform? Bez nich archiwa są nie do odczytania.
10. Czy wykonałeś pełny test odtworzenia z Borga (np. archiwa `verifytest-*` z 2026-08)? Jeśli tak: kiedy, co odtwarzałeś i ile to trwało?
11. Dlaczego Longhorn, a nie Rook-Ceph, OpenEBS albo `democratic-csi` na ZFS hosta, skoro wszystkie węzły są VM na jednym hoście?
12. Dlaczego Bitwarden Secrets Manager, a nie SOPS lub Sealed Secrets w Git? Czy wpływ miało to, że używasz już Bitwardena jako menedżera haseł?
13. Dlaczego 2026-07-19 założyłeś organizację Bitwarden od nowa?
14. Dlaczego Mimir + Alloy zamiast zwykłego Prometheusa? Jak monitorowałeś serwer przed 2026-02?
15. Czy dopuszczasz, że alerty nie wyjdą przy awarii całego klastra, czy planujesz zewnętrzny monitoring dostępności?
16. Czy nocne zatrzymanie AdGuarda na czas `home-backup` (od 04:30) powoduje przerwę w DNS w LAN, czy klienci mają zapasowy resolver?
17. Czy przypadki sekretów zapisanych w repo (2024-02-26 i 2026-08-13) wpłynęły na wybór Bitwarden SM + External Secrets zamiast trzymania sekretów w plikach?
18. Czy migracja z Promtaila (EOL 2026-03-02) do Alloya jest zaplanowana?

## Do której części pracy

- Technologie: sekcje 1-4, 6, 8-10 z tabelami alternatyw.
- Projekt: mapa warstwy danych, podział NFS (duże pliki) / Longhorn (konfiguracje i bazy), dwa projekty Bitwarden, układ jobów backupu.
- Implementacja: strojenie ZFS, mergerfs, orkiestrator `media-backup`, ESO i bootstrap tokena, Reloader.
- Odtwarzanie po awarii: sekcja 7 (3-2-1, braki w kopii, zależność cykliczna, brak zapisanego testu), procedura z `SETUP.md`, incydenty Longhorna.
- Analiza kosztów: Hetzner BX11 vs BX31 (snapshoty), ceny B2/S3 z tabeli celów kopii, wpływ ZFS i hd-idle na pobór prądu.
- Podsumowanie: poprawione diagnozy (RecurringJob, `BORG_LOCK_WAIT`, konflikt IP zamiast awarii Longhorna) jako lekcje.

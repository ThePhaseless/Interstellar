# Odtwarzanie po awarii i analiza kosztów

Stan repozytorium: branch `main`, 2026-11-27. Znaczniki dowodów: [commit], [plik], [PR], [wniosek], [źródło: URL], [nieznane]. Pliki usunięte z `main` są cytowane przez commit, w którym jeszcze istniały.

## Część A. Sprzęt

### A.1. Host fizyczny `carbon` (Proxmox VE)

| Element | Wartość | Dowód |
|---|---|---|
| Płyta główna | MSI MS-7C37 | [commit `bc91666`, 2025-12-17] (wynik fastfetch w planie migracji; gałąź migracyjna, na `main` od 2026-02-26, `327eff3`); kontroler RGB MSI MYSTIC LIGHT `1462:7c37` [plik `Ansible/setup-proxmox.yaml`] |
| CPU | AMD Ryzen 9 3950X, 16 rdzeni / 32 wątki, TDP 105 W | [commit `bc91666`, 2025-12-17]; [commit `4367315`, 2026-06-18, `docs/superpowers/specs/2026-06-14-proxmox-power-optimization-design.md`]; `amd_iommu=on` w cmdline jądra [plik `Ansible/setup-proxmox.yaml`]; sterownik `amd-pstate-epp` [commit `4367315`, spec `2026-06-18-proxmox-host-power-design.md`] |
| RAM | 64 GB DDR4 (system widzi 62,71 GiB) | [commit `bc91666`]; [commit `4367315`] |
| GPU | Intel Arc B580 (`8086:e20b`, Battlemage), przekazany do VM talos-1 przez mapowanie PCI Proxmoxa `gpu` | [plik `Terraform/variables.tf`]; [plik `CLAUDE.md`, Key Gotchas]. Wcześniej w tym serwerze była karta NVIDIA (urządzenia `/dev/nvidia*` przekazywane do kontenerów) [commit `8d78c86`, 2025-07-27]. B580 pojawia się w repo po raz pierwszy 2025-12-17, na gałęzi migracyjnej [commit `bc91666`] |
| Dyski HDD | 5 × 3 TB, 7200 obr./min, pula ZFS `Storage` w RAIDZ1, ok. 10,77 TiB użytkowej pojemności, `compression=zstd` | [commit `4367315`]; [commit `bc91666`] |
| NVMe (system) | 2 × 1 TB NVMe w lustrze ZFS (`rpool`): system Proxmoxa, magazyn `local-zfs` z dyskami VM (w tym etcd i dyski danych Longhorna), katalog `/SSDStorage` | [commit `4367315`]; `root=ZFS=rpool/ROOT/pve-1` [plik `Ansible/setup-proxmox.yaml`]; [plik `Terraform/variables.tf`] (`vm_os_datastore_id = "local-zfs"`); [commit `a3383c1`, 2026-09-21] |
| NVMe (pobieranie) | osobny dysk 238 GiB, pula `ssdstage` (bufor qBittorrenta, gałąź mergerfs) | [commit `0258e6e`, 2026-09-02]; dodany ok. 2026-08-31; [wniosek] to najpewniej ten NVMe, którego instalacja przenumerowała grupy IOMMU [commit `c939f49`, 2026-08-31] |
| Kontrolery SATA | ASMedia ASM1062 (`26:00.0`) obsługuje sda i sdb; FCH `2c:00.0` obsługuje sdc, sdd, sde; FCH `2b:00.0` jest pusty | [plik `CLAUDE.md`, Key Gotchas] |
| Sieć | 2 karty Realtek: 1 GbE RTL8168 (`nic0`, nieużywana, sterownik odpięty dla oszczędzania energii) i 2,5 GbE (używana); Wi-Fi/BT Intel AC 3168 odpięte | [commit `4367315`]; [plik `Ansible/setup-proxmox.yaml`] |
| Wentylatory | układ `nct6797`, ręczne PWM 30 i 60 | [plik `Ansible/vars/proxmox.yaml`] |
| Zigbee | konwerter CH340 `1a86:7523` przekazany do VM Home Assistanta (mapowanie USB `Zigbee`) | [plik `CLAUDE.md`, Key Gotchas] |
| System | Proxmox VE 9.2.3 (stan na 2026-06-14) | [commit `4367315`] |
| Zasilacz, obudowa, UPS | brak w repo. 2026-06-18 usługi `nut`/`apcupsd` były nieaktywne | [nieznane]; [commit `4367315`] |

Dwie sprzeczności w dokumentacji trzeba wyjaśnić przed pisaniem:
- `README.md` podaje Intel Core i5-12600K, 32 GB DDR4, „1TB NVMe” i węzły po 8 vCPU / 16 GB [plik `README.md`]. Tabela pochodzi z przepisania README 2025-03-13 [commit `84ea802`, 2025-03-13] i nie zgadza się z żadnym nowszym źródłem. [wniosek] README jest nieaktualne albo opisuje wcześniejszą maszynę. Patrz pytanie 1.
- W grudniu 2025 system hosta stał na ext4 (`/ (root): 93.93 GiB ext4`) [commit `bc91666`]. Najpóźniej 2026-02-16 Terraform używa już magazynu `local-zfs` [commit `7a30c5b`, 2026-02-16] (gałąź migracyjna; na `main` od 2026-02-26, `327eff3`), a cmdline wskazuje root na ZFS. [wniosek] Proxmox został w tym okresie przeinstalowany na lustro ZFS. To była pełna odbudowa hosta, dobry przykład do rozdziału o odtwarzaniu. Patrz pytanie 2.

### A.2. Maszyny wirtualne

Talos (wszystkie trzy są jednocześnie control plane i workerami). Źródło: [plik `Terraform/variables.tf`], [plik `Terraform/proxmox.tf`].

| VM | VMID / IP | vCPU | RAM | Dyski (`local-zfs`) | Urządzenia |
|---|---|---|---|---|---|
| talos-1 | 110 / 192.168.1.110 | 4 (domyślne) | 16 GiB | OS 64 GB + dane Longhorn 120 GB | GPU Arc B580 (hostpci, mapowanie `gpu`) |
| talos-2 | 111 / 192.168.1.111 | 6 | 12 GiB | 64 + 120 GB | drukarka USB `04e8:342e` (Ansible, nie Terraform) |
| talos-3 | 112 / 192.168.1.112 | 6 | 12 GiB | 64 + 120 GB | brak |
| **Razem** | | 16 | 40 GiB | 552 GB | |

- Typ maszyny q35, OVMF, CPU `host`, dyski `raw` z `discard=on` i `cache=writethrough` [plik `Terraform/proxmox.tf`].
- VIP API Kubernetesa 192.168.1.100 [plik `Terraform/variables.tf`]. Traefik na adresie MetalLB 192.168.1.11 [plik `CLAUDE.md`].
- Historia rozmiarów: w planie z 2025-12 każdy węzeł miał 8 vCPU / 16 GiB [commit `bc91666`]. talos-2 i talos-3 przeszły z 4 vCPU / 8 GiB na 6 vCPU / 12 GiB po zagłodzeniu CPU i awariach sond [commit `c664dd4`, 2026-06-19].
- VM Home Assistanta: VMID 102, 192.168.1.186 [commit `4367315`, spec `2026-06-18-proxmox-host-power-design.md`]; [plik `CLAUDE.md`]. Nie ma jej w Terraformie ani w Ansible. Jedyne odwołania to tag Tailscale `tag:homeassistant` [plik `Terraform/tailscale.tf`] i komentarz o mapowaniu Zigbee [plik `Ansible/setup-proxmox.yaml`]. [wniosek] Jest utrzymywana ręcznie.
- Bilans RAM hosta: 40 GiB dla Talosa, ARC ZFS ograniczony do 4 GiB [plik `Ansible/setup-proxmox.yaml`], do tego VM HA o nieznanym rozmiarze, przy 64 GB fizycznie. [wniosek] Zostaje kilkanaście GiB na Proxmoxa, HA i zapas.

### A.3. Urządzenia w sieci domowej

| Urządzenie | Rola | Zarządzanie | Dowód |
|---|---|---|---|
| Router Mercusys, 192.168.1.1 | NAT do Orange; przekierowanie 80/443 na 192.168.1.11; pula DHCP 192.168.1.180-253; restart co poniedziałek o 03:00 | ręcznie przez panel WWW, poza repo | [plik `CLAUDE.md`, Key Gotchas] |
| Drukarka Samsung SCX-4300 (USB `04e8:342e`) | Pagewire na talos-2 | Ansible (`qm set ... usb0: host=`) | [plik `Ansible/vars/proxmox.yaml`]; [plik `CLAUDE.md`] |
| Wtyczki Zigbee Tuya `TS011F` (3 szt.), żarówka `TS0505B` | automatyka; jedna wtyczka mierzy pobór serwera (`sensor.serwer_current_consumption`) | Home Assistant | [plik `CLAUDE.md`]; [commit `4367315`] |

### A.4. Zasoby poza domem

| Zasób | Parametry | Dowód |
|---|---|---|
| Oracle Cloud, VM `compute` | `VM.Standard.A1.Flex` (ARM), 4 OCPU, 24 GB RAM, dysk 150 GB, Ubuntu 24.04; osobiste (nieotagowane) urządzenie Tailscale | [plik `Terraform/oracle.tf`]; [plik `CLAUDE.md`] |
| Oracle, wcześniej | do 2026-08-20 dwie VM: `proxy` (1 OCPU / 6 GB / 50 GB, HAProxy jako publiczne wejście) i `compute` (3 OCPU / 18 GB / 150 GB) | [commit `7158f21`, 2026-08-20, PR #567] |
| Oracle, budżet | `oci_budget_budget.free_tier_guard`: kwota 1 miesięcznie, alert przy przekroczeniu; komentarz „Steady state is 0” | [plik `Terraform/oracle.tf`] |
| Oracle, Object Storage | bucket `tf-state` z wersjonowaniem: stan Terraformu głównego i `Terraform/apps` | [plik `Terraform/oracle.tf`]; [plik `Terraform/backend.tf`]; [plik `Terraform/apps/backend.tf`] |
| Oracle, Email Delivery | domena, DKIM, nadawca `noreply@`, poświadczenie SMTP dla Postfiksa | [plik `Terraform/email.tf`] |
| Hetzner Storage Box | `bx11` (1 TB), lokalizacja `fsn1`, SSH, migawki ZFS co tydzień (niedziela 06:00, maks. 10), `delete_protection` i `prevent_destroy`; repozytorium borg `backups/interstellar` | [plik `Terraform/hetzner.tf`]; [plik `Terraform/variables.tf`]; utworzony [commit `2b33dec`, 2026-02-24]; migawki tygodniowe od [commit `b6b0e81`, 2026-08-20] |
| SaaS bez infrastruktury własnej | Cloudflare (strefa DNS), Tailscale (tailnet, ACL, OAuth), Bitwarden Secrets Manager (dwa projekty: ręczny i generowany), GitHub (repo, Actions, GitHub App), Google OAuth (logowanie do Authentika), webhook Discorda (alerty), Let's Encrypt (certyfikaty Traefika) | [plik `SETUP.md`]; [plik `Terraform/bitwarden.tf`]; [plik `Kubernetes/bootstrap/traefik/ingress.yaml`] (`certResolver: letsencrypt`) |

## Część B. Odtwarzanie po awarii

### B.1. Założenie projektowe i jego granica

Cała platforma działa na jednym hoście fizycznym. Trzy węzły Talosa, etcd i wszystkie repliki Longhorna leżą na tym samym lustrze NVMe `rpool` [commit `a3383c1`, 2026-09-21]: „etcd's WAL and the Longhorn data disks are both zvols on the rpool NVMe mirror”. Domyślną klasę `longhorn` tworzy chart i ma ona najpewniej 3 repliki [wniosek]; komentarz w wartościach charta w repo mówi „Every volume has 3 replicas on 3 nodes” [plik `Kubernetes/bootstrap/longhorn/kustomization.yaml`]. 2 repliki mają tylko `longhorn-rwx` i ustawienie `defaultReplicaCount` [plik `Kubernetes/bootstrap/longhorn/storageclass.yaml`]. Zmiana „3 na 2” z [commit `06093ff`, 2026-02-28] objęła też klasę `longhorn` w `storageclass.yaml`, ale ten plik nie był wtedy w żadnej kustomizacji (wypadł z niej w [commit `9b810a8`, 2026-02-25]), a definicję klasy `longhorn` usunięto z niego później [commit `81609a2`, 2026-08-19]; zob. `technologie/04-dane-kopie-sekrety-monitoring.md`.

[wniosek] Repliki (3 w klasie `longhorn`, 2 w `longhorn-rwx`) chronią przed utratą jednej VM, ale po niej każdy wolumen, który miał tam replikę, ma do końca odbudowy o jedną kopię mniej, a wolumen `longhorn-rwx` tylko jedną. Przed utratą hosta albo jego dysków chronią tylko dwie rzeczy: odtworzenie konfiguracji z gita i dane z kopii borg na Hetznerze. Ten podział warto przyjąć jako oś rozdziału.

### B.2. Co odtwarza się z gita

| Warstwa | Gdzie w repo | Jak | Automatycznie? | Uwagi |
|---|---|---|---|---|
| Instalacja Proxmoxa, pule ZFS (`rpool`, `Storage`, `ssdstage`), mapowania PCI `gpu` i USB `Zigbee`, token API Proxmoxa | brak | ręcznie | nie | Mapowanie PCI celowo nie jest w Terraformie, bo numer grupy IOMMU zmienia się ze sprzętem [plik `Terraform/AGENTS.md`, Key Gotchas] |
| Konfiguracja hosta: NFS, mergerfs, datasety pobierania, tuning ZFS, oszczędzanie energii, smartd/ZED → Discord, logger konsoli szeregowej, drukarka | `Ansible/setup-proxmox.yaml`, `Ansible/vars/proxmox.yaml` | `ansible-playbook`; CI `ansible.yaml` przy pushu na `main` | tak, po instalacji PVE i dostępie przez Tailscale | Playbook tworzy datasety (`zfs create -p`), ale nie pule [plik `Ansible/setup-proxmox.yaml`]. Kolejności „NFS przed VM” (`Before=pve-guests.service`) nie ma w playbooku [wniosek z `git grep`], choć opisuje ją `CLAUDE.md` |
| VM Talosa, obrazy ISO z Image Factory, konfiguracja maszyn, bootstrap etcd, kubeconfig | `Terraform/proxmox.tf`, `talos.tf`, `modules/talos-node/` | `terraform apply` | tak | warunki w B.4 |
| Tailscale: ACL, klucze, DNS tailnetu, wyłączenie wygasania kluczy urządzeń infrastruktury | `Terraform/tailscale.tf`, `Tailscale/policy.hujson` | Terraform | tak | brak |
| Cloudflare: apex, wildcard, CAA, SPF, DKIM | `Terraform/cloudflare.tf`, `email.tf` | Terraform | tak | Treść rekordów A aktualizuje `cloudflare-ddns` (`ignore_changes = [content]`) [plik `CLAUDE.md`] |
| Sekrety generowane (hasła, klucze SSH borg i Oracle, passphrase borg, tokeny CrowdSec) | `Terraform/secrets.tf`, `hetzner.tf`, `oracle.tf` | `random_password` / `tls_private_key` → Bitwarden | tak | Wartości żyją w stanie (OCI) i w Bitwardenie, więc ponowny `apply` ich nie zmienia [wniosek] |
| Sekrety ręczne (17 pozycji: OCI, Proxmox, Tailscale OAuth, Cloudflare, Hetzner, GitHub App, Google OAuth, Discord itd.) | tabela w `SETUP.md` | ręcznie w Bitwardenie | nie, ale są w SaaS i przetrwają utratę domu | [plik `SETUP.md`] |
| Oracle: VCN, VM, bucket stanu, e-mail, budżet | `Terraform/oracle.tf`, `email.tf` | Terraform | tak, poza zapisaniem `compute` do Tailscale (logowanie w przeglądarce) | [plik `CLAUDE.md`, gotcha o urządzeniu osobistym] |
| Hetzner Storage Box | `Terraform/hetzner.tf` | Terraform | tak; `prevent_destroy` chroni przed skasowaniem | brak |
| Zmienne i sekrety GitHub Actions | `Terraform/github.tf` | Terraform | tak | brak |
| Fundament klastra (MetalLB, Longhorn, ESO, Traefik, CrowdSec, Tailscale Operator, obserwowalność, Authentik, CoreDNS, ArgoCD) | `Kubernetes/bootstrap/` | `scripts/apply-kubernetes.sh` ręcznie, fazami, potem ArgoCD | półautomatycznie | `SETUP.md`, kroki E-H |
| Aplikacje | `Kubernetes/apps/` przez `argocd/app-of-apps` (`targetRevision: main`, `automated`, `prune`, `selfHeal`) | ArgoCD | tak | [plik `Kubernetes/bootstrap/argocd/app-of-apps.yaml`] |
| Konfiguracja aplikacji (Authentik: 75 zasobów, *arr, Jellyfin, AdGuard, CrowdSec) | `Terraform/apps/` | Terraform + `scripts/port-forward-apps.sh` | tak | Stan w buckecie OCI (`interstellar/servarr.tfstate`) [plik `Terraform/apps/backend.tf`], więc przeżywa utratę klastra. `Terraform/AGENTS.md` nadal twierdzi, że stan apps jest w sekrecie Kubernetesa, co jest nieaktualne |
| Dane aplikacji (PVC Longhorna, bazy) | kopie borg na Hetznerze | `borg extract` + `kubectl cp` / `pg_restore` | nie | B.5 |
| Biblioteka multimediów (`/Storage/Media`) | brak kopii | ponowne pobranie przez *arr | nie | B.5 |
| VM Home Assistanta | brak | ręcznie | nie | pytanie 7 |
| Router | brak | ręcznie | nie | pytanie 8 |

### B.3. Korzenie zaufania (bez nich nic się nie odtworzy)

1. `BWS_ACCESS_TOKEN`, token konta maszynowego Bitwardena. `scripts/setup-env.sh` pobiera nim wszystkie pozostałe poświadczenia [plik `SETUP.md`]. Musi być przechowywany poza infrastrukturą (pytanie 9).
2. Konto Bitwarden Secrets Manager z oboma projektami.
3. Bucket `tf-state` w OCI i poświadczenia OCI (zapisane w Bitwardenie jako `oci-config`, `oci-private-key`). Bez stanu Terraform nie wie, co już istnieje, i plan stałby się planem budowy od zera.
4. Passphrase borg i klucz SSH do Storage Boxa, oba w Bitwardenie [plik `Terraform/hetzner.tf`]. Notatka przy passphrase mówi wprost: „Store safely — required for restore”. Borg działa w trybie `repokey` (klucz w repozytorium), więc do odczytu wystarcza passphrase [wniosek z notatki w `hetzner.tf`].
5. Repozytorium GitHub i dostęp administratora do Tailscale, Cloudflare i Hetznera.

### B.4. Kolejność i zależności przy odbudowie hosta

Kolejność wynika z `SETUP.md` i z pułapek opisanych w repo. `SETUP.md` opisuje start od zera („local backend first”). Przy odtwarzaniu stan w OCI już istnieje, więc krok A sprowadza się do `terraform init` z backendem OCI, a krok C (migracja stanu) odpada [wniosek].

| # | Krok | Zależność / pułapka | Dowód |
|---|---|---|---|
| 0 | Stacja robocza: `mise install`, `mise run install`, `.env` z `BWS_ACCESS_TOKEN`, `source scripts/setup-env.sh` | B.3 | [plik `SETUP.md`] |
| 1 | Router: przekierowania 80/443, pula DHCP poza adresami statycznymi (dziś .180-.253) | Pula obejmująca .112 doprowadziła do konfliktu ARP z talos-3 | [plik `CLAUDE.md`, gotcha DHCP] |
| 2 | Instalacja Proxmoxa na ZFS, import lub utworzenie pul, token API → Bitwarden (`proxmox-*`) | Ręcznie; nowy token wymaga aktualizacji sekretów ręcznych | [plik `SETUP.md`] |
| 3 | Mapowanie PCI `gpu` z aktualnym numerem grupy IOMMU, mapowanie USB `Zigbee` | Inaczej `qm start` talos-1 kończy się błędem `iommugroup does not match` | [plik `Terraform/AGENTS.md`] |
| 4 | Tailscale na `carbon`. Przed zapisaniem zwolnić nazwę skryptem `scripts/tailscale-release-hostname.sh` | Inaczej host dostaje nazwę `carbon-1`. Kasowanie po ponownym logowaniu może usunąć nowe urządzenie | [plik `CLAUDE.md`]; [commit `34d7f55`, 2026-08-20] |
| 5 | `ansible-playbook setup-proxmox.yaml` (NFS, mergerfs, tuning ZFS + `update-initramfs`), a ręcznie override systemd `nfs-server.service.d` z `Before=pve-guests.service` | NFS musi wstać przed VM, a playbook tej kolejności nie ustawia. Parametry ZFS wymagają przebudowy initramfs | [plik `CLAUDE.md`, dwie gotchas] |
| 6 | `terraform apply` z `-var talos_upgrade_gates=false` | Bramki Longhorna wymagają działającego API | [plik `Terraform/variables.tf`]; [commit `feb2ee9`, 2026-10-02] |
| 6a | Jeśli `talos_version` wyprzedza ISO o ponad ~2 wersje minor: `-replace` obu `proxmox_download_file` | Próg `MinimumHostUpgradeVersion` | [plik `Terraform/AGENTS.md`]; [commit `80990c3`, 2026-09-24] |
| 6b | DNS stacji roboczej bez AdGuarda (np. `tailscale up --accept-dns=false` albo publiczny resolver) | DNS tailnetu wskazuje na AdGuarda w klastrze. Gdy klastra nie ma, Terraform nie rozwiąże ani backendu OCI, ani `carbon` | [plik `CLAUDE.md`, gotcha kubelet]; [plik `Terraform/tailscale.tf`] |
| 7 | `scripts/generate-bitwarden-tls.sh` | Certyfikaty dla bitwarden-sdk-server w ESO | [plik `SETUP.md`, krok D] |
| 8 | Bootstrap Kubernetesa w 4 fazach (MetalLB i ESO aplikowane dwa razy: najpierw CRD, potem zasoby) | 17 wywołań `apply-kubernetes.sh` i 2 `kubectl wait` | [plik `SETUP.md`, krok E] |
| 9 | `apply-kubernetes.sh apps`, `Terraform/apps` z port-forwardem, na końcu ArgoCD | brak | [plik `SETUP.md`, kroki F-H] |
| 10 | Przywrócenie danych z borg (B.5) | Kolejność względem kroku 9 dla Authentika nie jest opisana; pytanie 10 | [plik `SETUP.md`, „Restore from Backups”] |
| 11 | Walidacja: `kubectl get nodes`, `talosctl health`, `clustersecretstore`, `argocd applications` | brak | [plik `SETUP.md`, krok 3] |

Ryzyka w trakcie odbudowy:
- Auto-apply w CI: każdy push na `main` w `Terraform/**` uruchamia `terraform apply -auto-approve`, jeśli plan wykryje zmiany [plik `.github/workflows/terraform.yaml`]. Podobnie działa `Terraform/apps/**` i Ansible [pliki `terraform-apps.yaml`, `ansible.yaml`]. Commit w trakcie odbudowy może więc uruchomić równoległe apply na częściowo odtworzonej infrastrukturze. [wniosek] Na czas testu wstrzymać workflowy albo nie pushować. Workflow `terraform-destroy.yaml` (`workflow_dispatch`) istnieje i jest niebezpieczny przy pomyłce.
- Zmiana konfiguracji kubeleta może położyć wszystkie węzły naraz. 2026-08-19 pasma `shutdownGracePeriodByPodPriority` bez wyzerowanych skalarów zatrzymały kubeleta na trzech węzłach jednocześnie, bo `-parallelism=1` nie serializował skutków zmiany [commit `40f9ca2`, 2026-08-19]; [commit `59abe12`, 2026-08-19]. Obecna wersja wpisu mówi to samo o łańcuchu modułów per węzeł (wprowadzonym później) i zaleca `-target` na jeden węzeł [plik `CLAUDE.md`].
- Restart VM bez drenażu wisi ok. 12 minut na każdym montowaniu RWX Longhorna [plik `CLAUDE.md`, Workflow].
- Dołożenie dysku NVMe przenumerowało grupy IOMMU i zablokowało start talos-1 [commit `c939f49`, 2026-08-31].
- Ignorowane zmiany w `cdrom` zostawiały VM z odwołaniem do nieistniejącego pliku, co wychodziło dopiero przy restarcie [plik `Terraform/AGENTS.md`]; [commit `c939f49`].
- Masowa odbudowa replik może wpaść w pętlę: timeouty, błędy IO, zamontowanie read-only. Pętlę przerywa wstrzymanie odbudów (`concurrent-replica-rebuild-per-node-limit=0`) [plik `Kubernetes/AGENTS.md`]; [commit `f75a932`, 2026-09-22].
- Odtwarzanie przez usuwanie i ponowne tworzenie zasobów zarządzanych przez ArgoCD już raz zakończyło się utratą danych [plik `CLAUDE.md`, „Critical incident history”, wpis z [commit `4f47a7b`, 2026-03-07]]. Data i przebieg tego incydentu nie są opisane (pytanie 11).

### B.5. Kopie zapasowe: zakres, harmonogram, retencja (wejście do RPO)

Wszystkie zadania piszą do jednego repozytorium borg na Hetznerze. Kompresja zstd, retencja `--keep-daily 7 --keep-weekly 4 --keep-monthly 6`, po każdym przebiegu `borg compact` [pliki `*/scripts/borg-backup.sh`]. CronJoby nie ustawiają `timeZone` [wniosek z `git grep`], więc godziny liczy strefa kube-controller-managera (pytanie 12).

| CronJob | Pora | Zakres | Dowód |
|---|---|---|---|
| `borgbackup` (utilities) | 03:00 | zdjęcia Immicha (bez miniatur, transkodów i kopii), `personal-pvc` (wzorce), dumpy `pg_dump` Immicha i Authentika | [plik `Kubernetes/apps/borgbackup/cronjob.yaml`] |
| `mimir-backup`, `grafana-backup`, `loki-backup` | 03:30, 03:35, 03:40 | PVC obserwowalności | [plik `Kubernetes/bootstrap/observability/backup-cronjob.yaml`] |
| `traefik-backup` | 03:45 | PVC Traefika (w tym `acme.json` z certyfikatami) | [plik `Kubernetes/bootstrap/traefik/backup-cronjob.yaml`]; [plik `Kubernetes/bootstrap/traefik/kustomization.yaml`] |
| `crowdsec-backup` | 03:50 | PVC CrowdSec | [plik `Kubernetes/bootstrap/crowdsec/backup-cronjob.yaml`] |
| `media-backup` | 04:00 | PVC z etykietą `backup.interstellar/enabled=true`: bazarr, jellyfin, prowlarr, qbittorrent, radarr, seerr, sonarr | [plik `Kubernetes/apps/media-backup/cronjob.yaml`]; [plik `Kubernetes/AGENTS.md`] |
| `home-backup` | 04:30 | dane AdGuarda (orkiestrator wyłącza AdGuarda na czas kopii) | [plik `Kubernetes/apps/home-backup/cronjob.yaml`]; [commit `c664dd4`] |
| Migawki Storage Boxa | niedziela 06:00, maks. 10 | ochrona repozytorium przed klientem, który je wyczyści | [plik `Terraform/hetzner.tf`] |

[wniosek] Dla danych objętych kopią RPO wynosi do ~24 h (kopia raz na dobę), a przy sprawnym hoście lokalnie zero, bo ZFS i Longhorn żyją dalej.

Czego nie ma w kopii off-site (stan `main`; lista PVC z `git grep -lE 'kind: PersistentVolumeClaim|volumeClaimTemplates' main -- Kubernetes`, zestawiona z zakresem CronJobów; PVC tworzone przez charty Helm, np. Longhorn czy Authentik, nie zostały sprawdzone):

| Dane | Skutek utraty | Dowód |
|---|---|---|
| Biblioteka multimediów `/Storage/Media` i pobrane pliki | do ponownego pobrania przez *arr (RPO = cała biblioteka, RTO = czas pobierania); BX11 ma 1 TB, a pula ok. 10,77 TiB | [plik `SETUP.md`] (tabela archiwów); [plik `Terraform/variables.tf`] |
| PVC bez kopii: `clips-sftp-state` (1 Gi), `pagewire-data` (2 Gi), `pagewire-blobs` (1 Gi), `crowdsec-web-ui-data` (1 Gi), `immich-ml-local-cache` (12 Gi, cache) | utrata stanu Pagewire i clips-sftp; cache odtworzy się sam. Skany Pagewire od 2026-11-27 są na NFS w `/Storage/Media/Scans` (PVC `pagewire-scans`), więc nie giną z Longhornem, ale kopii też nie mają, jak cała `/Storage/Media` [commit `e7ae5da`, 2026-11-27] | [pliki `Kubernetes/apps/*/pvc.yaml`, `Kubernetes/bootstrap/crowdsec/web-ui/pvc.yaml`; `crowdsec-backup` montuje tylko `crowdsec-config-pvc` i `crowdsec-db-pvc`] |
| VM Home Assistanta | konfiguracja automatyki i parowanie Zigbee [wniosek] | brak w repo; pytanie 7 |
| `/etc/pve` (mapowania PCI/USB, definicja VM HA, token API) | ręczna rekonfiguracja | brak w repo |
| etcd | nieistotne przy odtwarzaniu z gita, bo stan klastra opisuje repo; zasoby utworzone ręcznie poza gitem przepadną | brak `talosctl etcd snapshot` w repo [wniosek] |
| Router | ręczna konfiguracja | brak w repo |

Repo nie zawiera śladu odtworzenia danych z borg na próbę. Udokumentowano tylko testowe archiwa `verifytest-*` przy tworzeniu kopii i `borg break-lock` [commit `171f04b`, 2026-08-09]. Procedura w `SETUP.md` zawiera nieścisłość: `kubectl -n media cp ... sonarr-0:/config` wskazuje pod `sonarr-0`, a Sonarr jest Deploymentem, i kopiuje do skalowanego do zera poda [plik `SETUP.md`]. [wniosek] Repo nie zawiera dowodu, że procedurę wykonano od początku do końca. Sprawdzi to test z B.8.

### B.6. Rzeczywiste awarie i odbudowy z historii

| Data | Zdarzenie | Jak odtworzono | Dowód |
|---|---|---|---|
| 2025-12 → 2026-02 | [wniosek] przeinstalowanie Proxmoxa z ext4 na lustro ZFS i migracja z k3s w LXC na Talos w VM | nowy klaster z Terraformu; szczegóły nieznane | [commit `bc91666`, 2025-12-17]; [commit `7a30c5b`, 2026-02-16]; pytanie 2 |
| 2026-02-27 | DiskPressure Longhorna, zdegradowane i uszkodzone wolumeny, pełny PVC Mimira | 3 → 2 repliki (`defaultReplicaCount`; klasa `longhorn` bez zmian, zob. B.1), overprovisioning 150 → 200%, powiększenie PVC | [commit `06093ff`, 2026-02-28, `docs/checkpoints/2026-02-27-longhorn-storage-checkpoint.md`] |
| przed 2026-03-07 | utrata danych po odtworzeniu app-of-apps ArgoCD | nieznane; reguła „nigdy nie odtwarzaj zasobów ArgoCD” | [commit `4f47a7b`, 2026-03-07]; pytanie 11 |
| 2026-06 (wpis z 2026-06-19) | węzeł z binarką o rozmiarze 0 bajtów (uszkodzone migawki containerd) | zatrzymanie VM, skasowanie i odtworzenie ZVOL dysku systemowego, boot z ISO GPU, `apply-config --insecure` | [commit `f33592a`, 2026-06-19]; [plik `CLAUDE.md`] |
| 2026-06-23 | „recovery”: usunięcie wiecznego dryfu w Terraform (Tailscale, Authentik, Jellyfin), przeniesienie stanu apps do OCI | commit naprawczy | [commit `eefc9d7`, 2026-06-23] |
| 2026-08-19 | dodanie pasm `shutdownGracePeriodByPodPriority` → kubelet w pętli restartów na wszystkich trzech węzłach, a z klastrem padł AdGuard (DNS) | poprawka konfiguracji i `terraform apply -refresh=false -target=talos_machine_configuration_apply.controlplane` z obejściem niedostępnego providera Proxmoxa (wersja wpisu z tamtego dnia; dzisiejszy wpis podaje komendę dla modułów per węzeł) | [commit `59abe12`, 2026-08-19]; [commit `40f9ca2`, 2026-08-19]; [plik `CLAUDE.md`] |
| 2026-08-18 | wygasły klucz węzła Tailscale na `carbon` odciął NFS i exit node | `tailscale_device_key.infra` wyłącza wygasanie | [commit `4fe6631`, 2026-08-18] |
| ok. 2026-08-31 | klaster nie wstał po restarcie: nieaktualne ISO w `cdrom` i przesunięta grupa IOMMU po dołożeniu NVMe | ręczna poprawka mapowania, usunięcie `cdrom` z `ignore_changes` | [commit `c939f49`, 2026-08-31] |
| 2026-09-21/22 | flapowanie talos-3, burze odbudów Longhorna, zawieszony klient NFS. Przyczyna: dekoder TV z tym samym IP z DHCP po cotygodniowym restarcie routera | zawężenie puli DHCP; wygaszenie klienta NFSv4 po stronie serwera zamiast resetu; pauza odbudów | [commit `9903e08`, 2026-09-22]; [commit `1b7ad54`, 2026-09-21]; [commit `f75a932`, 2026-09-22] |
| wielokrotnie, daty nieznane | talos-1 (węzeł GPU) odtwarzany „częściej” przy eksperymentach ze sprzętem i GPU; jego tożsamość Tailscale nie przeżywa reinstalacji | z Terraformu; CI wybiera talos-2 jako węzeł API | [plik `Terraform/AGENTS.md`, Key Gotchas]; pytanie 13 |
| 2026-10-02 | apply bez łańcucha zrestartował talos-1 podczas odbudowy replik na talos-3; dwa wolumeny uszkodzone | łańcuch modułów per węzeł z bramką „Longhorn zdrowy” | [commit `feb2ee9`, 2026-10-02] |

Żaden z tych wpisów nie podaje czasu trwania przestoju. Znaczniki czasu commitów go nie mierzą (pytanie 13).

### B.7. Istniejące runbooki

| Dokument | Co obejmuje | Czego brakuje |
|---|---|---|
| `SETUP.md` | budowa od zera (sekrety, Terraform, Ansible, bootstrap k8s w fazach, ArgoCD), walidacja, odtwarzanie z borg (lista, pojedyncza aplikacja, bazy, rodziny archiwów) | wariant „stan w OCI istnieje”, `talos_upgrade_gates=false`, DNS bez AdGuarda, host Proxmoxa, router, HA, kolejność odtwarzania danych względem `Terraform/apps`, pomiar czasu |
| `Kubernetes/AGENTS.md`, „Emergency Recovery” | wolumen Longhorna w `emergency_ro`: 7 kroków, alternatywnie migawka | tylko ten jeden scenariusz |
| `CLAUDE.md` / `AGENTS.md`, Key Gotchas | rozproszone procedury: odtworzenie ZVOL, kubelet, NFS, Tailscale `-1`, Longhorn PV `nodeAffinity` | jeden spójny scenariusz DR |

[wniosek] W repo nie ma runbooka DR ani zmierzonej odbudowy. Test z B.8 da pierwsze takie dane.

### B.8. Propozycja testu odtworzenia

Scenariusze, od najtańszego:

| # | Scenariusz | Co niszczymy | Co sprawdza | Ryzyko dla danych |
|---|---|---|---|---|
| S1 | utrata jednego węzła | VM talos-3 + ZVOL-e (najpierw `kubectl drain`, `tailscale-release-hostname.sh`) | Terraform odtwarza VM, Talos dołącza do etcd, Longhorn odbudowuje repliki | średnie: wolumeny z repliką na talos-3 zostają z jedną kopią do końca odbudowy (dokładnie ten stan opisuje [commit `feb2ee9`, 2026-10-02]); wolumeny `longhorn-cache` z 1 repliką na tym węźle przepadają i blokują drain [plik `Terraform/AGENTS.md`]; przed zniszczeniem trzeba usunąć członka etcd (etcd leży w `EPHEMERAL`, a nie na osobnej partycji [plik `CLAUDE.md`]) |
| S2 | utrata klastra przy zdrowym hoście | wszystkie 3 VM i ich ZVOL-e; pule `Storage`/`ssdstage` zostają | pełny bootstrap k8s, ArgoCD, `Terraform/apps`, odtworzenie PVC z borg | wysokie, jeśli kopie są niekompletne; najpierw ręczna kopia `borg create` i weryfikacja `borg list` |
| S3 | utrata hosta (dyski systemowe) | nowa instalacja Proxmoxa na zapasowym dysku lub sprzęcie; `Storage` zaimportowana | S2 plus kroki ręczne hosta (B.4, kroki 1-5) | bardzo wysokie na jedynym serwerze; [wniosek] wykonalne tylko na zapasowych dyskach NVMe albo jako próba „na sucho” |
| S4 | katastrofa (dom) | wszystko lokalne | tylko na papierze: lista kroków + czas pobrania danych z Hetznera | brak |

[wniosek] Rekomendacja: S1 i S2 wykonać naprawdę, S3 opisać i ewentualnie przetestować na zapasowych dyskach, S4 przeprowadzić jako ćwiczenie analityczne. S2 najlepiej odpowiada tematowi pracy (IaC + GitOps).

Mierzone wielkości:

| Wielkość | Definicja | Jak mierzyć |
|---|---|---|
| RTO całkowite | od zniszczenia do zaliczenia walidacji (B.4, krok 11) i działania usług kontrolnych (np. Jellyfin, Immich, Authentik przez `https://*.nerine.dev`) | `date -Is` w logu operatora; `script -T` lub `asciinema` całej sesji |
| Czas faz | Terraform (VM + Talos), bootstrap k8s, ArgoCD do `Synced/Healthy`, `Terraform/apps`, odtworzenie danych | znaczniki przed i po każdym kroku; `time terraform apply`; `kubectl wait`; `argocd app wait` |
| RPO | wiek najnowszego archiwum borg w chwili awarii, per rodzina archiwów | `borg list --last 1 --format '{time}'` |
| Kompletność danych | czy usługi mają stan sprzed awarii | wybrane próbki: liczba zdjęć w Immichu, użytkownicy w Authentiku, seriale w Sonarrze; porównanie przed i po |
| Liczba kroków ręcznych | polecenia i decyzje operatora poza `terraform apply` / ArgoCD | licznik w logu; podział na „polecenie z runbooka” i „improwizacja” |
| Liczba interwencji naprawczych | błędy, które wymagały diagnozy | każdy wpis z przyczyną (to materiał na wnioski) |
| Ilość pobranych danych / przepustowość | GB z Hetznera, MB/s | `borg extract --progress`, liczniki interfejsu |

Otwarty punkt dla S2 [nieznane]: czy przy zachowanym stanie i usuniętych VM `terraform apply` sam ponownie wykona bootstrap etcd (`talos_cluster` w `Terraform/talos.tf`), czy zasoby `talos_machine` trzeba odtworzyć przez `-replace`. Sprawdzić `terraform plan` przed testem.

Warunki wstępne:
- świeża ręczna kopia (`borg create` wszystkich rodzin) i `borg check` przed testem;
- `BWS_ACCESS_TOKEN` i dostęp do OCI sprawdzone z innej maszyny;
- wstrzymane workflowy `terraform*.yaml` i `ansible.yaml` albo zakaz pushowania na czas testu;
- stacja robocza z DNS niezależnym od AdGuarda;
- spisane wartości kontrolne do porównania;
- `talos_upgrade_gates=false` i decyzja, czy odświeżać ISO;
- dla S1: zwolniona nazwa w Tailscale przed ponownym zapisaniem węzła.

Ryzyka testu: utrata danych z PVC bez kopii (Pagewire, clips-sftp); ograniczenia Let's Encrypt przy wielokrotnym wydawaniu certyfikatów, jeśli `acme.json` nie zostanie odtworzony przed startem Traefika [wniosek]; zmiana tożsamości węzłów w Tailscale (`-1`); przypadkowy apply z CI; przestój usług dla innych użytkowników (grupy `vips`, `photos` w Authentiku [commit `12b2249`, 2026-08-19]).

## Część C. Koszty

### C.1. Pomiary poboru mocy zapisane w repo

Metoda: czujnik wtyczki Zigbee w Home Assistancie `sensor.serwer_current_consumption`, odczyt przez REST API HA [commit `4367315`, spec `2026-06-18-proxmox-host-power-design.md`]. Wtyczki to Tuya `TS011F` [plik `CLAUDE.md`]. Repo nie zawiera porównania ich wskazań z niezależnym watomierzem (pytanie 15).

| Okno | Średnia | Minimum (próg spoczynku) | Dowód |
|---|---|---|---|
| przed fazą 1 (2026-06-10 do 06-14) | 147,4 W | 100,4 W | [commit `4367315`] |
| po fazie 1 (2026-06-15 do 06-18) | 130,2 W | 83,3 W | [commit `4367315`] |
| cel fazy 2 (plan, nie pomiar) | 110-115 W | 55-60 W | [commit `4367315`] |

Faza 1 (2026-06-14): ASPM, TLP, powertop, EPP `balance_power`, SATA `min_power`, Wi-Fi, wyłączenie Postfiksa, hd-idle, usunięcie eksportera GPU [commit `4367315`]; [commit `aee76cc`]; [commit `d96741f`]; [commit `55389fa`].

Zmiany po ostatnim zapisanym pomiarze, bez pomiaru zbiorczego w repo:
- `atime=off` [commit `b175bfb`, 2026-06-18];
- `zfs_txg_timeout=30` [commit `2027bad`, 2026-06-18];
- odpięcie USB RGB (opis zakłada ~2 W) [commit `63048da`];
- odpięcie `nic0` (~1-2 W) [commit `0d9e2ac`];
- firmware DMC dla GPU (~8 W) [commit `08b837f`, 2026-06-18];
- D3cold GPU [commit `d0c61f2`, 2026-06-21];
- `halt_poll_ns=0` [commit `c664dd4`];
- wyłączenie CPU boost i limit ARC [commit `aeca5da`, 2026-07-20];
- poprawka autosuspendu `sda` [commit `73d06cc`, 2026-10-26];
- pula NVMe na pobieranie, żeby HDD mogły zasypiać [commit `0bdd584`, 2026-09-01].

Liczby cząstkowe pochodzą z różnych metod i nie składają się w jeden szereg:
- RAPL pakietu CPU ~38-42 W (rdzenie ~1,8 W, uncore ~40 W) [commit `4367315`];
- 5 HDD „~28 W” to szacunek, nie pomiar [commit `4367315`];
- GPU „~20 W” → „~25 W idle” w opisie [commit `cd9ea11`, 2026-06-14], „~9 W” [commit `aee76cc`], „z ~22 W do ~11,6 W” [commit `d0c61f2`].

[wniosek] Do pracy potrzebny jest świeży pomiar z okresu co najmniej 30 dni (pytanie 14).

### C.2. Usługi zewnętrzne widoczne w repo

Ceny odczytano 2026-11-27. Plan konta autora jest w większości nieznany (pytania 17-19). Kolumna „Wynika z repo” opisuje tylko zużycie widoczne w kodzie.

| Usługa | Wynika z repo | Cena lub limit planu (web) | Źródło |
|---|---|---|---|
| Hetzner Storage Box BX11 (1 TB) | jedna skrzynka `bx11` | 3,20 EUR/mies. netto (z 23% VAT ok. 3,94 EUR, przeliczenie własne); w cenie migawki, borg przez SSH, brak limitu ruchu | [źródło: https://www.hetzner.com/storage/storage-box/bx11, dostęp 2026-11-27] |
| Oracle Cloud, VM A1 | 4 OCPU / 24 GB, 150 GB dysku; commit z 2026-08-20 nazywa to „the whole allowance” [commit `7158f21`] | Always Free: 1500 OCPU-godz. i 9000 GB-godz. miesięcznie, czyli 2 OCPU i 12 GB; 200 GB block+boot łącznie; instancja bezczynna przez 7 dni (p95 CPU, sieć i pamięć < 20%) może zostać odebrana | [źródło: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm, dostęp 2026-11-27] |
| Oracle Object Storage | bucket `tf-state` (dwa pliki stanu) | 20 GB i 50 tys. żądań/mies. w Always Free | jw. |
| Oracle Email Delivery | nadawca `noreply@`, Postfix | 3000 wiadomości/mies. | jw. (wartość z raportu pomocniczego; przy ponownym odczycie strony nie sprawdzana) |
| Domena `nerine.dev` | strefa w Cloudflare; rejestrator nieznany | Cloudflare Registrar: 12,20 USD/rok przy odnowieniu (dane z agregatora, Cloudflare nie publikuje kwoty na stronie produktu) | [źródło: https://costgoat.com/compare/domains/dev, dostęp 2026-11-27] |
| Cloudflare DNS | strefa, rekordy A/CAA/TXT/CNAME, `proxied = false` | autorytatywny DNS dostępny we wszystkich planach, także darmowym | [źródło: https://developers.cloudflare.com/dns/, dostęp 2026-11-27] |
| Bitwarden Secrets Manager | 2 projekty (ręczny, generowany); co najmniej 1 konto maszynowe (`BWS_ACCESS_TOKEN`, token dla ESO „może być równy”) [plik `SETUP.md`] | Free: do 2 użytkowników, 3 projekty, 3 konta maszynowe; Teams 6 USD/użytkownik/mies. | [źródło: https://bitwarden.com/help/secrets-manager-plans/, dostęp 2026-11-27]; [źródło: https://www.bitwarden.com/pricing/business/, dostęp 2026-11-27] |
| Tailscale | tailnet z urządzeniami otagowanymi (`tag:proxmox`, `tag:node`, `tag:homeassistant`, `tag:files`, CI) | Personal (darmowy): do 6 użytkowników, 50 zasobów otagowanych/mies., tylko użytek niekomercyjny; exit node i MagicDNS potwierdzone ze średnią pewnością | [źródło: https://tailscale.com/pricing, dostęp 2026-11-27] |
| GitHub Actions | repo publiczne, standardowe runnery | darmowe bez limitu minut dla repozytoriów publicznych | [źródło: https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions, dostęp 2026-11-27] |
| Google OAuth, webhook Discorda, Let's Encrypt | logowanie do Authentika, alerty, certyfikaty | bez opłat [wniosek] | brak |

[wniosek] Zużycie zasobów mieści się w darmowych planach Bitwardena (2 z 3 projektów), GitHuba i najpewniej Tailscale. Stałym kosztem z repo jest tylko Storage Box (ok. 38,40 EUR netto rocznie) i domena.

Rozbieżność Oracle. Według aktualnej dokumentacji Always Free obejmuje 2 OCPU i 12 GB A1, a VM `compute` ma 4 OCPU i 24 GB. Limit obowiązuje od 2026-06-15 [źródło: https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm, dostęp 2026-11-27]. Commit `7158f21` z 2026-08-20, który ustawił 4 OCPU / 24 GB jako „the whole allowance”, powstał więc już po zmianie. [wniosek] Albo konto jest w trybie Pay As You Go i od tego czasu płaci za nadwyżkę (2 OCPU i 12 GB), albo konto ma inne warunki niż opisane w dokumentacji. Budżet `free-tier-guard` z progiem 1 powinien to wykazać (pytanie 19). Do analizy kosztów trzeba to rozstrzygnąć fakturą z konsoli OCI.

### C.3. Cena energii elektrycznej (Polska, G11, 2026)

Ceny energii sprzedawców z urzędu obowiązują od 2026-01-01 do 2026-12-31 (taryfy zatwierdzone 2025-12-17). Mrożenie ceny na 500 zł/MWh netto skończyło się 2025-12-31 i w 2026 nie obowiązuje [źródło: https://www.money.pl/gospodarka/stawki-za-prad-w-2026-r-jest-decyzja-prezesa-ure-7233452426144736a.html, dostęp 2026-11-27]. Średnia cena dla gospodarstw domowych według URE to 0,49516 zł/kWh netto [źródło: https://www.ure.gov.pl/pl/urzad/informacje-ogolne/aktualnosci/13002,Prezes-Urzedu-Regulacji-Energetyki-zatwierdzil-taryfy-na-sprzedaz-i-dystrybucje-.html, dostęp 2026-11-27].

| Sprzedawca | Energia G11, zł/kWh netto | Źródło |
|---|---|---|
| PGE Obrót („Komfortowa”) | 0,4982 | [źródło: https://bip.ure.gov.pl/download/3/20342/PGEObrot.pdf, dostęp 2026-11-27] |
| Tauron Sprzedaż | 0,4970 | [źródło: https://bip.ure.gov.pl/download/3/20340/TauronSprzedaz.pdf, dostęp 2026-11-27] |
| Energa Obrót | 0,4968 | [źródło: https://bip.ure.gov.pl/download/3/20346/ENERGAOBROT.pdf, dostęp 2026-11-27] |

Ceny PGE i Tauronu sprawdzono bezpośrednio w tekście PDF-ów URE. Cena Enei (ok. 0,498) pochodzi tylko ze źródeł wtórnych. Zmiana taryfy Tauronu z 2026-11-17 nie została przeczytana w całości, więc nie wiadomo, czy zmienia cenę G11.

Cena za kWh ze wszystkimi opłatami zmiennymi: (energia + akcyza 0,0050 + zmienna sieciowa + jakościowa 0,0332 + OZE 0,0073 + kogeneracyjna 0,0030) × 1,23. Stawki jakościowej, OZE, kogeneracyjnej i akcyzy podaje [źródło: https://www.ure.gov.pl/pl/urzad/informacje-ogolne/aktualnosci/13002,Prezes-Urzedu-Regulacji-Energetyki-zatwierdzil-taryfy-na-sprzedaz-i-dystrybucje-.html, dostęp 2026-11-27] oraz [źródło: https://energycompass.pl/taryfy/pge/g11, dostęp 2026-11-27]. Stawki dystrybucji pochodzą z agregatora, nie z taryf OSD [źródło: https://selectra.pl/cena-pradu/skladniki-ceny, dostęp 2026-11-27]; dla PGE potwierdza je [źródło: https://energycompass.pl/taryfy/pge/g11, dostęp 2026-11-27].

| Wariant (sprzedawca + OSD) | Zmienna sieciowa, zł/kWh netto | Razem netto | Razem brutto |
|---|---|---|---|
| PGE Obrót + PGE Dystrybucja | 0,3469 | 0,8936 | 1,0991 |
| Tauron + Tauron Dystrybucja | 0,2464 | 0,7919 | 0,9740 |
| Energa Obrót + Energa-Operator | 0,3485 | 0,8938 | 1,0994 |
| Stoen (wartość z agregatora) | 0,2342 | brak | 0,9627 |

Do pracy: przedział ok. 0,96-1,10 zł/kWh brutto zależnie od OSD. W przykładach z C.5 użyto obu krańców i wartości pośredniej 1,05 zł/kWh. Najlepiej podać stawkę z faktury autora (pytanie 20).

Opłaty stałe (netto/mies.): opłata mocowa 4,29 / 10,31 / 17,18 / 24,05 zł dla rocznego zużycia < 0,5 / 0,5-1,2 / 1,2-2,8 / > 2,8 MWh, stała sieciowa 5,50-11,46 zł, abonament (PGE 4,50 zł) [źródło: https://energycompass.pl/taryfy/pge/g11, dostęp 2026-11-27]; [źródło: https://selectra.pl/cena-pradu/skladniki-ceny, dostęp 2026-11-27]. [wniosek] Serwer zużywa ok. 1,1 MWh rocznie, więc sam może przesunąć gospodarstwo do wyższego progu opłaty mocowej. Tę różnicę warto doliczyć do kosztu krańcowego.

### C.4. Metoda porównania

Koszt roczny środowiska domowego:

- Energia: `K_e = P_śr × 8760 h / 1000 × c_kWh` [zł/rok], gdzie `P_śr` to średnia moc z gniazdka w W z okresu ≥ 30 dni, a `c_kWh` to cena za kWh ze wszystkimi opłatami zmiennymi. Opłaty stałe (abonament, opłata stała sieciowa) płaci się niezależnie od serwera. [wniosek] W koszcie krańcowym serwera należy je pominąć i napisać to wprost. Wyjątkiem jest opłata mocowa, jeśli serwer przesuwa gospodarstwo do wyższego progu (C.3).
- Amortyzacja sprzętu: `K_a = Σ (cena_i − wartość_rezydualna_i) / okres_i`, liniowo. Okres przyjąć jawnie (np. 5 lat dla dysków i GPU). Sprzęt kupiony przed projektem (np. do komputera osobistego) można liczyć po wartości rynkowej używanego albo pominąć, z uzasadnieniem.
- Usługi zewnętrzne: `K_u = Σ abonament_j × 12` (Hetzner, domena, opcjonalnie Oracle, jeśli przekroczy Always Free).
- Porównanie: `K_dom = K_e + K_a + K_u` wobec `K_chmura = Σ` abonamentów zastąpionych usług, po cenach z dnia porównania, w tej samej walucie i z VAT.
- Wrażliwość: wynik dla co najmniej trzech wartości `P_śr` (np. 83 W, 110 W, 130 W) i dwóch cen energii; próg opłacalności w miesiącach: `cena_sprzętu / (K_chmura/12 − (K_e + K_u)/12)`.
- Koszty pominięte, nazwane wprost: czas pracy autora, ryzyko utraty danych, wartość edukacyjna.

### C.5. Przykład liczbowy (tylko ilustracja metody)

Liczby poniżej ilustrują wzór z C.4. Moc pochodzi z czerwca 2026 albo z planów, cena energii z C.3. Nie są to wyniki do pracy.

| Średnia moc | Źródło mocy | Energia/rok | Koszt przy 0,974 zł/kWh | przy 1,05 zł/kWh | przy 1,099 zł/kWh |
|---|---|---|---|---|---|
| 147,4 W | pomiar przed fazą 1 | 1291,2 kWh | 1258 zł | 1356 zł | 1420 zł |
| 130,2 W | pomiar po fazie 1 | 1140,6 kWh | 1111 zł | 1198 zł | 1254 zł |
| 110 W | dolna granica celu fazy 2 (plan) | 963,6 kWh | 939 zł | 1012 zł | 1059 zł |
| 83,3 W | minimum po fazie 1 (dolna granica, serwer nigdy nie pracuje tak cały rok) | 729,7 kWh | 711 zł | 766 zł | 802 zł |

[wniosek] Faza 1 obniżyła średnią o 17,2 W, czyli o ok. 150,7 kWh rocznie, co przy 1,05 zł/kWh daje ok. 158 zł rocznie.

Usługi zewnętrzne z repo (C.2): Storage Box 38,40 EUR netto rocznie plus domena (ok. 12,20 USD rocznie, jeśli rejestratorem jest Cloudflare). Oracle 0 zł tylko wtedy, gdy rozbieżność z C.2 okaże się nieistotna.

Ceny referencyjne zastąpionych kategorii usług (do rozdziału, jeśli autor potwierdzi, że z nich korzystał; pytanie 16):

| Kategoria | Odpowiednik w homelabie | Cena (PLN/mies., brutto) | Źródło |
|---|---|---|---|
| zdjęcia/dysk w chmurze | Immich, Copyparty | Google One 2 TB (Google AI Plus): 9,99 EUR (oficjalny cennik pokazuje EUR); w artykule 46,99 zł | [źródło: https://one.google.com/about/plans?hl=pl&gl=PL, dostęp 2026-11-27] |
| zdjęcia/dysk w chmurze | jw. | iCloud+ 2 TB: 49,99 zł | [źródło: https://support.apple.com/pl-pl/108047, dostęp 2026-11-27] |
| streaming | Jellyfin + *arr | Netflix 37 / 55 / 75 zł (od maja 2026; artykuł, oficjalna strona pokazuje EUR) | [źródło: https://antyweb.pl/ile-kosztuje-netflix-w-2026-roku, dostęp 2026-11-27] |
| streaming | jw. | Disney+ z reklamami 24,99 zł, Standard 34,99 zł, Premium 59,99 zł | [źródło: https://www.disneyplus.com/pl-pl, dostęp 2026-11-27] |
| streaming | jw. | HBO Max 29,99 / 39,99 / 49,99 zł (ceny regularne, bez promocji Black Friday) | [źródło: https://www.hbomax.com/pl/pl, dostęp 2026-11-27] |
| filtr DNS | AdGuard Home | NextDNS Pro 1,99 EUR/mies. | [źródło: https://nextdns.io/pricing, dostęp 2026-11-27] |
| VPN | exit node Tailscale na `carbon` [plik `Ansible/setup-proxmox.yaml`] | Mullvad 5 EUR/mies. | [źródło: https://mullvad.net/en/pricing, dostęp 2026-11-27] |
| zdalny dostęp do HA | Tailscale + Traefik | Home Assistant Cloud (Nabu Casa) 7,50 EUR/mies. bez VAT | [źródło: https://www.nabucasa.com/pricing/, dostęp 2026-11-27] |

Ceny katalogowe sprzętu (tylko jako punkt odniesienia, gdy brakuje faktur): Ryzen 9 3950X 749 USD przy premierze w 2019 [źródło: https://www.tomshardware.com/news/amd-ryzen-9-3950x-zen-2,39615.html, dostęp 2026-11-27]; Arc B580 249 USD (cena doradcza Intela, premiera 2024-12) [źródło: https://www.intel.com/content/www/us/en/products/sku/241598/intel-arc-b580-graphics/specifications.html, dostęp 2026-11-27]. Aktualnych cen B580, HDD 3 TB 7200 obr./min i NVMe 1 TB w Polsce nie udało się potwierdzić w porównywarce.

### C.6. Jak zmierzyć brakujące dane

| Brak | Propozycja pomiaru |
|---|---|
| średnia moc po wszystkich optymalizacjach | eksport historii `sensor.serwer_current_consumption` z HA za ≥ 30 dni (statystyki długoterminowe HA albo REST `/api/history/period`); jeśli wtyczka ma licznik energii, wziąć różnicę kWh |
| wiarygodność wtyczki Tuya | 24 h równolegle z watomierzem gniazdkowym; porównać średnie |
| udział komponentów | pomiar różnicowy: HDD uśpione vs pracujące (`hdparm -C`, log smartd), GPU w D3cold vs aktywne (transkodowanie testowe); RAPL CPU (`turbostat` lub `/sys/class/powercap`) jako uzupełnienie, nie zamiennik pomiaru z gniazdka |
| co jeszcze wisi na wtyczce (router, switch, monitor?) | spis urządzeń; ewentualnie osobna wtyczka |
| koszt stanu „przed” (abonamenty) | wyciągi lub faktury z ostatnich 12 miesięcy przed repatriacją, z datami rezygnacji |
| cena sprzętu | faktury lub historia zamówień; w razie braku mediana cen z porównywarki z datą |

## Pytania do autora

1. README podaje Intel i5-12600K, 32 GB RAM, „1TB NVMe” i węzły po 8 vCPU / 16 GB. Commity z 2025-12 i 2026-06 podają Ryzen 9 3950X, 64 GB i 2 × 1 TB NVMe. Która konfiguracja jest aktualna? Czy i5 to wcześniejsza maszyna, a jeśli tak, kiedy ją wymieniono?
2. Kiedy i dlaczego Proxmox został przeinstalowany z ext4 na lustro ZFS (`rpool`)? Ile trwała odbudowa i co było odtwarzane ręcznie?
3. Jakie są dokładne modele i daty zakupu dysków: 5 HDD 3 TB, 2 NVMe 1 TB, NVMe 238 GiB dodanego ok. 2026-08-31? Jaki jest zasilacz i obudowa?
4. Ile kosztował każdy element serwera i kiedy został kupiony (CPU, płyta MSI MS-7C37, RAM, Arc B580, dyski)? Które części były kupione specjalnie na homelab, a które pochodzą z dawnego komputera?
5. Jaką kartę NVIDIA miał serwer przed Arc B580 i dlaczego ją wymieniono?
6. Czy serwer ma UPS? Jeśli tak, to jaki i czy wisi na tej samej wtyczce pomiarowej?
7. Jak jest robiona kopia VM Home Assistanta (VMID 102) i czy kiedykolwiek ją odtwarzano? Ile RAM i vCPU ma ta VM?
8. Czy konfiguracja routera Mercusys (przekierowania 80/443, pula DHCP .180-.253, restart w poniedziałki o 03:00) jest gdzieś zapisana poza `CLAUDE.md`, np. jako eksport ustawień?
9. Gdzie poza infrastrukturą przechowywany jest `BWS_ACCESS_TOKEN` i dane logowania do Bitwardena, Hetznera, OCI i Tailscale, tak żeby dało się je odzyskać po utracie domu?
10. Czy bazę Authentika odtwarza się z `pg_restore` przed czy po `terraform apply` w `Terraform/apps`? Ta kolejność decyduje, czy aplikacje Authentika będą miały te same ID.
11. Kiedy doszło do incydentu, w którym odtworzenie app-of-apps ArgoCD skasowało dane, i co dokładnie przepadło?
12. W jakiej strefie czasowej działają CronJoby kopii (UTC czy czas lokalny)?
13. Czy przy którejś awarii (przeinstalowanie hosta, odtworzenie ZVOL talos-1 w czerwcu 2026, padnięcie kubeleta 2026-08-19, zablokowany start 2026-08-31) zanotowano, ile trwał przestój i odbudowa?
14. Czy można wyeksportować z Home Assistanta historię `sensor.serwer_current_consumption` za ostatnie 30-90 dni (średnia i kWh)? Jakie urządzenia są podłączone do tej wtyczki poza serwerem?
15. Czy pomiar wtyczki Tuya był porównany z niezależnym watomierzem?
16. Jakie płatne usługi chmurowe autor miał przed repatriacją (np. Google One lub Zdjęcia Google, Netflix, Disney+, VPN, NextDNS, Dropbox) i w jakich cenach? Kiedy z nich zrezygnował?
17. U którego rejestratora jest domena `nerine.dev` i ile kosztuje rocznie?
18. Na jakich planach są Cloudflare, Tailscale i Bitwarden Secrets Manager (darmowe czy płatne)?
19. Czy konto Oracle jest w trybie Free Tier czy Pay As You Go? Od 2026-06-15 Always Free obejmuje 2 OCPU i 12 GB dla A1, a VM `compute` ma 4 OCPU i 24 GB: czy OCI nalicza za nią opłaty i czy budżet `free-tier-guard` zgłosił przekroczenie?
20. Który sprzedawca i dystrybutor energii oraz która taryfa (G11, G12, G12w) obowiązuje w lokalizacji serwera? Jaka jest cena z faktury?
21. Który zakres testu odtworzenia jest akceptowalny: S1 (jeden węzeł), S2 (cały klaster), S3 (host na zapasowym dysku)? Czy w trakcie testu dopuszczalny jest przestój dla innych użytkowników?

## Do której części pracy

- Projekt: A.1-A.4 (sprzęt i zasoby zewnętrzne), B.1 (pojedynczy host jako założenie i jego granica).
- Implementacja: A.2, B.2 (co jest kodem, a co ręcznie), B.5 (kopie zapasowe).
- Odtwarzanie po awarii: B.1-B.8 w całości; B.6 jako studia przypadków, B.8 jako metodyka testu.
- Analiza kosztów: C.1-C.6, A.4 (usługi zewnętrzne).
- Podsumowanie: wnioski z B.1 (granica odporności jednego hosta), B.7 (brak runbooka DR), C.1 (brak aktualnego pomiaru).

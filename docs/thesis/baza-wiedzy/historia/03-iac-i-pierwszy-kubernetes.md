# E3: Terraform, Ansible i pierwszy Kubernetes (2025-07-26 → 2026-01-31)

E3 obejmuje 357 commitów na `main`: 86 w lipcu 2025 (od 26.07), 160 w sierpniu, 41 we wrześniu, potem 27, 13, 17 i 13 miesięcznie **[wniosek: zliczenie `git log main --since=2025-07-26 --until=2026-02-01` bez 5 commitów z 2026-02-01]**. Około 70 z nich to aktualizacje od Renovate. Spoza bota pochodzi tylko PR #173 i #174 **[wniosek: `gh pr list`]**. Commity autora mają same tytuły, zwykle 2-4 słowa („fix k3s”, „maybe fix race condition”). Ok. 70 tytułów zawiera „fix/try/maybe/finally” **[wniosek: grep po tytułach]**, co pokazuje, jak dużo tu było prób i błędów. Motywy decyzji rzadko są zapisane, więc większość „dlaczego” trafia do pytań.

Okres ma trzy fazy:

1. **2025-07-26 → 2025-08-04**: IaC i CI. Terraform (Oracle Cloud + LXC na Proxmoxie), Ansible, uv, `act`, k3s instalowany Ansiblem. 161 commitów w 10 dni, z czego 87 dotyka `.github/` **[wniosek: zliczenie]**.
2. **2025-08-11 → 2025-09-14**: przeniesienie usług z Docker Compose do k3s, koniec compose (2025-09-01), wdrażanie manifestów z CI.
3. **2025-09-15 → 2026-01-31**: cisza na `main` (prawie tylko Renovate), a od 2025-12-17 przygotowanie przebudowy na Talos na osobnej gałęzi migracyjnej, scalonej do `main` dopiero 2026-02-26.

## 1. Stan na początku E3 (`b1a441a`, 2025-07-24)

- Usługi w plikach `compose.{auth,home,media,misc,proxy}.yaml`, scalanych przez `compose.yaml` z `include` **[plik `compose.yaml` w `b1a441a`]**:
  - `auth`: CrowdSec, Traefik, whoami, PostgreSQL, Redis, Authentik (server, worker, LDAP), Postfix;
  - `home`: Home Assistant, httpd, Homepage, Renamer, AdGuard Home, scanservjs;
  - `media`: Bazarr, Radarr, Sonarr, Prowlarr, qBittorrent, Jellyseerr, Jellyfin, Byparr, Decluttarr, Recyclarr;
  - `proxy` (na VPS): HAProxy + Watchtower **[pliki `compose.*.yaml` w `b1a441a`]**.
- Wdrożenie: GitHub Actions → Tailscale → `tailscale ssh` na serwer → `scripts/deploy.sh` (`git pull --rebase`, `docker compose up -d --pull always`, `docker system prune`) **[plik `.github/workflows/deploy.yaml` w `b1a441a`]**, **[plik `scripts/deploy.sh` w `b1a441a`]**.
- HAProxy na VPS przekazywał TCP 80/443 z PROXY protocol v2 do hosta `media` przez Tailscale (`server server1 media:443 send-proxy-v2`) **[plik `haproxy.cfg` w `b1a441a`]**. README tłumaczy to brakiem publicznego IP od ISP („bypassing the lack of the public IP from the ISP”) **[plik `README.md` w `b1a441a`]**.
- Infrastruktury (VM, VPS, DNS) nie było w repo. Konfigurowano ją ręcznie **[wniosek: brak takich plików w drzewie `b1a441a`]**.

Szczegóły tego okresu są w pliku E2 (`02-rozwoj-compose.md`).

## 2. Wejście IaC (2025-07-26 → 2025-08-04)

### 2.1 Co doszło pierwszego dnia

| Element | Co robił | Dowód |
| --- | --- | --- |
| `pyproject.toml`, `uv.lock`, `.python-version` | Środowisko Pythona zarządzane przez uv; zależności `ansible-dev-tools` i `oci-cli`, Python ≥3.13 | **[commit `7a357aa`, 2025-07-26]**, **[plik `pyproject.toml` w `ea23c77`]** |
| Devcontainer | Własny `Dockerfile` (obraz bazowy + uv), rozszerzenia Ansible, OpenTofu, „GitHub Local Actions”, feature `terraform` | **[commit `f61e660`, 2025-07-26]** |
| `Ansible/` | `site.yaml`, `main.yaml` i rola `roles/proxmox_containers` (wykrywanie kontenerów LXC przez `pct exec`, dopisywanie urządzeń NVIDIA i `/dev/net/tun` do `/etc/pve/lxc/<id>.conf`). README opisuje też rolę `tailscale`, której w commicie nie ma | **[commit `162b32c`, 2025-07-26]** |
| `Terraform/` | `oracle.tf` (VPS), `proxmox.tf` (LXC), `deployment.tf` (klucz SSH + inwentarz), `Templates/inventory-static.tpl` | **[commit `6930efc`, 2025-07-26]** |
| `Keys/` | Katalog na wygenerowany klucz wdrożeniowy `deployment_key.pem` | **[commit `1bb126d`, 2025-07-26]** |
| Stary workflow `deploy.yaml` | Wyłączony (koniec auto-wdrożeń compose) | **[commit `fc8269f`, 2025-07-26]** |

Pierwszy Terraform:

- **Oracle Cloud (OCI)**: compartment, VCN z modułu `oracle-terraform-modules/vcn/oci`, security list budowana z mapy `ports` (SSH 22, HTTPS 443, Minecraft 25565), instancja `argon` typu `VM.Standard.A1.Flex` (4 OCPU, 24 GB RAM, 200 GB). Komentarz w kodzie: „Free limits are 200 GB / 24 GB / 4 cores” **[plik `Terraform/oracle.tf` w `6930efc`]**. Do tego wersjonowany bucket `terraform-state-bucket` na stan Terraform. W pierwszej wersji backend `oci` był jeszcze zakomentowany **[plik `Terraform/backend.tf` w `6930efc`]**.
- **Proxmox** (provider `Telmate/proxmox` 3.0.2-rc03): jeden kontener LXC `nickel`, Ubuntu 24.04, **uprzywilejowany** (`unprivileged = false`), `fuse` i `nesting`, 16 GB RAM, rootfs 256 GB na `local-lvm` **[plik `Terraform/proxmox.tf` w `6930efc`]**.
- **Most Terraform → Ansible**: `tls_private_key` generuje klucz, `local_file` zapisuje inwentarz z szablonu do `Ansible/inventory-static.ini` i listę ID kontenerów do `Ansible/vars/proxmox.yaml` **[plik `Terraform/deployment.tf` w `6930efc`]**.

### 2.2 OpenTofu w pierwszej godzinie

Plik `.terraform.lock.hcl` z pierwszego commitu Terraform wygenerował `tofu init` (nagłówek „maintained automatically by "tofu init"”, providery z `registry.opentofu.org`). 13 minut później commit „migrate back to terraform” podmienił go na wersję z `terraform init` i `registry.terraform.io` **[commit `6930efc`, 2025-07-26]**, **[commit `75e604b`, 2025-07-26]**. Z „back” wynika, że pliki powstały wcześniej poza tym repo pod OpenTofu **[wniosek]**. W E3 nie ma innej ścieżki z OpenTofu: CI używało `hashicorp/setup-terraform` **[plik `.github/workflows/terraform.yaml` w `ea23c77`]**, a wpis `OpenTofu` w szkielecie osi czasu to już epizod z 2026-02-01 (commity `afad10b` „migrate to opentofu” i `06e540f` „migrate to terraform” tego samego dnia), czyli E4. Rozszerzenie `opentofu.vscode-opentofu` zostało w devcontainerze do 2025-08-31 **[commit `21f4929`, 2025-08-31]**. Powód powrotu do Terraform: **[nieznane]**.

### 2.3 Co szybko przerobiono

| Data | Zmiana | Dowód |
| --- | --- | --- |
| 2025-07-27 | Sekrety między jobami CI: inwentarz i klucz szyfrowane `gpg --symmetric` (AES256) i przekazywane jako artefakty, osobny sekret `GPG_SECRET` | **[commit `1f194cd`, 2025-07-27]**, **[commit `a0a87ba`, 2025-07-27]** |
| 2025-07-27 | Pierwszy krok do k8s: devcontainer dostaje Go, k3d, docker-in-docker, `act`, `actionlint`, kubectl/helm/minikube | **[commit `a9ff5be`, 2025-07-27]** |
| 2025-07-30 | Pojawia się `Ansible/tasks/` (współdzielone zadania, np. `update-apt.yaml`) | **[commit `8bb6719`, 2025-07-30]** |
| 2025-07-31 | GPG i artefakty zastąpione bucketem OCI `ansible`: Terraform wgrywa tam klucz i inwentarz, playbooki pobierają je `oci os object bulk-download` do `.private/`. `Keys/` usunięty | **[commit `9cc822b`, 2025-07-31]** |
| 2025-07-31 | „embrace act”: `.actrc` (obraz `catthehacker/ubuntu:act-latest`, `--privileged --device /dev/net/tun --cap-add=NET_ADMIN`, żeby Tailscale działał w lokalnym runnerze) i `.secrets.exmaple` (lista zmiennych dla `act`, literówka w nazwie została do końca) | **[commit `7b3ce98`, 2025-07-31]**, **[plik `.actrc` w `ea23c77`]** |
| 2025-08-02 | `Terraform/Templates` usunięte: inwentarz jako `yamlencode()` w obiekcie OCI zamiast szablonu `.tpl` w pliku lokalnym | **[commit `e37e5a4`, 2025-08-02]** |
| 2025-08-02 | `Ansible/roles` usunięte: playbooki płaskie (`setup-containers.yaml`, `setup-oracle.yaml`, `k3s.yaml`) + `tasks/` + `vars/`. Role zewnętrzne z Galaxy (`artis3n.tailscale`, `geerlingguy.docker`) | **[commit `718b2df`, 2025-08-02]**, **[plik `Ansible/requirements.yml` w `ea23c77`]** |
| 2025-08-03 | Inwentarz z Tailscale: `tasks/discover_tailscale.yaml` czyta `tailscale status --json` i robi z tagów urządzeń grupy Ansible (`tag:agent` → grupa `agent`) | **[commit `b7b93d0`, 2025-08-03]**, **[plik `Ansible/tasks/discover_tailscale.yaml` w `ea23c77`]** |

**[wniosek]** Każda z tych zmian usuwała plik lokalny albo własną abstrakcję i przenosiła stan współdzielony przez Terraform, Ansible i CI do chmury (bucket OCI, tagi Tailscale). Autor nie opisał tego wprost.

### 2.4 Pipeline CI na 2025-08-04

- `deploy.yaml` na pushu do `main` sprawdza `dorny/paths-filter`, co się zmieniło, i uruchamia **jeden** workflow z listy priorytetów: `terraform` → `ansible-setup` → `ansible-k3s` **[plik `.github/workflows/deploy.yaml` w `ea23c77`]**.
- `terraform.yaml`: uv, cache providerów, `terraform init` z backendem OCI, TFLint, Tailscale (`tag:ci`), `plan` i `apply` bez kroku zatwierdzenia w samym workflow (job ma `environment: server`; ewentualne reguły ochrony tego środowiska są poza repo), potem łańcuchowo `ansible-setup` **[plik `.github/workflows/terraform.yaml` w `ea23c77`]**.
- Konflikty równoległych uruchomień rozwiązywano kilka razy: `concurrency` z `cancel-in-progress`, `workflow_run`, w końcu jedna grupa `concurrency-lock` **[commit `5f45531`, 2025-07-31]**, **[commit `89d8d46`, 2025-08-03]**, **[plik `.github/workflows/maintenance.yaml` w `0a00bf3`]**. Objawu nie zapisano **[nieznane]**.

### 2.5 k3s instalowany Ansiblem

- Playbook `Ansible/k3s.yaml` importuje `k3s.orchestration.site` z kolekcji `k3s-io/k3s-ansible` (instalowanej z gita), z `--flannel-iface=tailscale0` dla serwera i agenta **[plik `Ansible/k3s.yaml` w `ea23c77`]**, **[plik `Ansible/requirements.yml` w `ea23c77`]**. Inwentarz `k3s_cluster` z podgrupami `server`/`agent` i tokenem z `random_password` generuje Terraform **[plik `Terraform/deployment.tf` w `0a00bf3`]**.
- k3s-ansible to kolekcja Ansible z grupami `server` i `agent`, a kilka hostów w `server` daje HA z wbudowanym etcd **[źródło: https://raw.githubusercontent.com/k3s-io/k3s-ansible/master/README.md, dostęp 2026-11-27]**.
- Wersję k3s najpierw przypięto (`v1.33.3+k3s1`), potem playbook pobierał najnowszą z API GitHuba **[commit `01a7a88`, 2025-08-04]**.
- Kontener LXC przygotowano pod k3s: `lxc.apparmor.profile: unconfined`, `lxc.cgroup2.devices.allow: a`, puste `lxc.cap.drop`, `/dev/kmsg` i `/dev/net/tun`, `mount --make-rshared /` w `rc.local`, wyłączony swap **[plik `Ansible/vars/containers.yaml` w `ea23c77`]**, **[plik `Ansible/setup-containers.yaml` w `ea23c77`]**. **[wniosek]** To zdejmuje z kontenera prawie całą izolację. Uruchamianie k3s w LXC prawdopodobnie wymagało tych ustępstw (kubelet korzysta z `/dev/kmsg` i współdzielonych montowań).
- Od 2025-08-31 CI nie uruchamiało już playbooka k3s automatycznie (zakomentowany job `ansible_k3s`). Klaster działał dalej **[commit `aff4c61`, 2025-08-31]**.

**Liczba węzłów jest niepewna.** W Terraform jest jeden kontener (`nickel`), workloady miały `nodeSelector: kubernetes.io/hostname: nickel` (zdjęte 2025-08-31 commitem „do not lock to nickel”) **[commit `28e9e96`, 2025-08-31]**, a kubeconfig CI brało z `root@nickel` **[plik `.github/workflows/kubernetes.yaml` w `06ecf16`]**. Z drugiej strony playbook ma osobny etap dla grupy `agent`, flannel szedł po `tailscale0` (sensowne przy węzłach w różnych sieciach), tego samego dnia przetestowano i wycofano `--flannel-backend=wireguard-native --flannel-external-ip` **[commit `af42a83`, 2025-08-16]**, **[commit `cf1ebd5`, 2025-08-16]**, a `--default-runtime=nvidia` ustawiono tylko agentom **[commit `a2a56a0`, 2025-08-16]**. Plan z grudnia mówi „K3s running on Proxmox LXC containers” (liczba mnoga) i zastrzega, że w nowej architekturze Oracle VPS ma być „HAProxy entry point only (not a K8s node)” **[plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w `bc91666`]**. Tagi Tailscale (`server`/`agent`) nadawano kluczami auth spoza repo, więc skład klastra zostaje **[nieznane]** (pytanie 1).

## 3. Pierwszy Kubernetes (2025-08-11 → 2025-09-14)

### 3.1 Przebieg

| Data | Krok | Dowód |
| --- | --- | --- |
| 2025-07-27 → 2025-08-11 | `Kubernetes` w repo był **gitlinkiem** (tryb 160000, bez `.gitmodules`), czyli osadzonym, osobnym repozytorium git, a nie katalogiem | **[commit `3c05d73`, 2025-07-27]**, **[commit `abcb648`, 2025-08-11]** |
| 2025-08-11 | „migrate compose files”: manifesty wygenerowane z plików compose przez **kompose** (nazwy typu `adguardhome-claim0-persistentvolumeclaim.yaml`, `authentik-server-deployment.yaml`). Do repo trafiła też binarka `Kubernetes/kompose` (~22 MB) | **[commit `abcb648`, 2025-08-11]** |
| 2025-08-13 | Binarka kompose usunięta | **[commit `f2082c1`, 2025-08-13]** |
| 2025-08-15 | „organize”: podział na `home/`, `infrastructure/`, `media/`, `utilities/`. **Authentik (server, worker, LDAP) i Home Assistant wypadają** z manifestów; resztki CrowdSec usunięto tego samego dnia („adjust rest of the infra”) | **[commit `328dddf`, 2025-08-15]**, **[commit `929e6b4`, 2025-08-15]**, **[commit `10a3961`, 2025-08-15]** |
| 2025-08-15 → 08-18 | `Kubernetes/Config` (pliki konfiguracyjne z dawnego `Config/`), `Templates/` (szablony konfiguracji) i `Scripts/` (skrypty *arr: wyciąganie kluczy API, konfiguracja Prowlarra) | **[commit `9200576`, 2025-08-15]**, **[commit `a248058`, 2025-08-17]**, **[commit `2d2c7f5`, 2025-08-18]** |
| 2025-08-16 → 08-25 | `proxmox`: drugi gitlink, usunięty commitem „remove proxmox terraform repo” | **[commit `a2a56a0`, 2025-08-16]**, **[commit `d5ae473`, 2025-08-25]** |
| 2025-08-25 → 08-30 | „reorganize repo”: wszystko pod `Kubernetes/Apps/`, każda aplikacja z własnym `kustomization.yaml`, `configMapGenerator` zamiast ręcznych ConfigMap. Pusty plik `Apps/media/external-secrets.yaml` | **[commit `580e44a`, 2025-08-25]** |
| 2025-08-30 | Powrót z `Apps/` do `Kubernetes/{home,infrastructure,media,utilities}`; Renovate dostaje `kubernetes.managerFilePatterns` | **[commit `38de395`, 2025-08-30]**, **[commit `8a72007`, 2025-08-30]** |
| 2025-08-31 | Ingress na Traefiku z k3s, TLS, DNS, PROXY protocol. Katalog `Kubernetes/test` (whoami) | **[commit `7ce4d94`, 2025-08-31]**, **[commit `b9c85d5`, 2025-08-31]** |
| 2025-09-01 | **„remove og compose”**: usunięte `compose.{auth,home,media,misc,test}.yaml` i `compose.yaml` (508 linii). Zostaje tylko `compose.proxy.yaml` | **[commit `28fbc9e`, 2025-09-01]** |
| 2025-09-12 | Workflow `kubernetes.yaml`: CI pobiera kubeconfig przez `scp` z `root@nickel`, `kubectl kustomize Kubernetes/ --enable-helm \| kubectl apply -f -` | **[commit `06ecf16`, 2025-09-12]**, **[commit `e73a53a`, 2025-09-12]** |
| 2025-09-14 | Wspólny `deploy.yaml` usunięty. Osobne workflow: `kubernetes`, `terraform`, `maintenance` (cron pon. 03:00: aktualizacja Proxmoxa i kontenerów), `nvidia`, `proxy` (compose na VPS przez `community.docker.docker_compose_v2`) | **[commit `943f2d3`, 2025-09-14]**, **[plik `.github/workflows/maintenance.yaml` w `0a00bf3`]**, **[plik `Ansible/proxy.yaml` w `0a00bf3`]** |

### 3.2 Klaster na koniec przeniesienia (`28fbc9e`, 2025-09-01)

| Obszar | Rozwiązanie | Dowód |
| --- | --- | --- |
| Dystrybucja | k3s z `k3s-ansible`, w uprzywilejowanym LXC `nickel` na Proxmoxie | **[plik `Ansible/k3s.yaml` w `ea23c77`]**, **[plik `Terraform/proxmox.tf` w `ea23c77`]** |
| Wdrażanie | Kustomize (+ `helmCharts`). Do 2025-09-12 w repo nie ma workflow wdrażającego manifesty, więc prawdopodobnie ręcznie **[wniosek]**; potem `kubectl apply` z CI na każdym pushu do `Kubernetes/**`. Bez GitOps i bez prune | **[plik `.github/workflows/kubernetes.yaml` w `bc91666^`]** |
| Ingress | Traefik wbudowany w k3s, konfigurowany `HelmChartConfig` w `kube-system`: `hostNetwork: true`, bez Service, porty 80/443 i 53 TCP/UDP, ACME DNS-01 przez Cloudflare z wildcardem `*.nerine.dev`, `trustedIPs` dla PROXY protocol i `forwardedHeaders` = `100.0.0.0/8` (Tailscale) | **[plik `Kubernetes/infrastructure/traefik/config.yaml` w `28fbc9e`]** |
| Routing | `IngressRoute` z `HostRegexp(`^sonarr\.(.+)`)`, czyli dowolna domena z daną subdomeną, bez middleware | **[plik `Kubernetes/media/sonarr/ingress.yaml` w `0a00bf3`]** |
| Storage | Dane przez `hostPath`: `/Storage` i `/Storage/Media` (Bazarr, Jellyfin, qBittorrent, Radarr, Sonarr); `/Storage` hosta montowany do LXC jako mountpoint, a według planu z 2025-12 to pula ZFS 10,77 TiB. Konfiguracje aplikacji na PVC bez `storageClassName` | **[plik `Terraform/proxmox.tf` w `ea23c77`]**, **[plik `Kubernetes/media/jellyfin/deployment.yaml` w `28fbc9e`]**, **[plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w `bc91666`]** |
| GPU | NVIDIA: sterownik 580.76.05 instalowany Ansiblem na hoście i w LXC (bez modułów jądra), `nvidia-container-toolkit`, `nvidia-device-plugin` v0.17.3 z Helma przez Kustomize, time-slicing `replicas: 2`, GFD | **[commit `02cbf60`, 2025-08-15]**, **[plik `Kubernetes/infrastructure/nvidia-device-plugin/values.yaml` w `28fbc9e`]**, **[commit `cd8ca1e`, 2025-08-30]** |
| Sekrety | Manifesty `Secret` z **pustymi** wartościami w repo (np. `bazarr-secrets`, `traefik-cloudflare-secret` z komentarzem „Add your Cloudflare DNS API token base64 encoded”). `secrets.yaml` Bazarra jest w `resources` jego `kustomization.yaml`, a `secret.yaml` Traefika w swoim nie, czyli Traefikowy trzeba było nałożyć ręcznie **[wniosek]**. Klucze API *arr wyciągane w klastrze przez Joby `*-api-extractor` (obraz kubectl, odczyt `config.xml` z PVC, `kubectl create secret`) | **[plik `Kubernetes/media/bazarr/secrets.yaml` w `84fe6d3`]**, **[plik `Kubernetes/infrastructure/traefik/secret.yaml` w `84fe6d3`]**, **[plik `Kubernetes/media/bazarr/kustomization.yaml` w `0a00bf3`]**, **[plik `Kubernetes/infrastructure/traefik/kustomization.yaml` w `0a00bf3`]**, **[plik `Kubernetes/media/radarr/api-extractor-job.yaml` w `0a00bf3`]** |
| Autokonfiguracja *arr | Init-containery i skrypty: wspólny `config.xml` z `AuthenticationMethod=External`, `configure-prowlarr.sh` rejestruje Radarr/Sonarr w Prowlarrze przez API, `replace-with-envs.sh` podstawia `ENV_*` w plikach konfiguracyjnych | **[plik `Kubernetes/media/common/config.xml` w `0a00bf3`]**, **[plik `Kubernetes/media/prowlarr/scripts/configure-prowlarr.sh` w `0a00bf3`]** |
| DNS | AdGuard Home w podzie z `hostNetwork`. Rewrite `nerine(.dev)` → adres Tailscale serwera dla klientów `100.0.0.0/8` i → adres LAN dla `192.168.0.0/24`; init-container kopiuje config tylko przy pierwszym starcie | **[commit `f31ed43`, 2025-09-01]** |

Fakty z dokumentacji k3s, które pomagają czytać te manifesty:

- k3s wdraża jako dodatki `coredns`, `traefik`, `local-storage` i `metrics-server` oraz wbudowany kontroler `servicelb` **[źródło: https://raw.githubusercontent.com/k3s-io/docs/main/docs/installation/packaged-components.md, dostęp 2026-11-27]**.
- `HelmChartConfig` o nazwie i przestrzeni nazw pasującej do pakietowego `HelmChart` (np. Traefika) przekazuje `valuesContent` jako dodatkowy plik wartości **[źródło: https://raw.githubusercontent.com/k3s-io/docs/main/docs/add-ons/helm.md, dostęp 2026-11-27]**.
- Domyślny Local Path Provisioner tworzy wolumeny w lokalnych ścieżkach węzła, co „permanently binding the pod to the node hosting the volume” **[źródło: https://raw.githubusercontent.com/k3s-io/docs/main/docs/add-ons/storage.md, dostęp 2026-11-27]**. **[wniosek]** PVC bez `storageClassName` trafiały więc do `local-path` na `nickel`, bez replikacji. To jedna z rzeczy, które plan migracji zastępuje Longhornem.

### 3.3 Co zostało poza Kubernetesem

- **VPS `argon` (Oracle)** z `compose.proxy.yaml`: HAProxy (TCP 80/443 → `nickel` z `send-proxy-v2`; backend przepięty z `media` na `nickel` 2025-08-31), Watchtower i od 2025-09-14 **wg-easy** (WireGuard, UDP 51820 otwarty w OCI) **[plik `haproxy.cfg` w `0a00bf3`]**, **[commit `1624795`, 2025-08-31]**, **[commit `a4f4005`, 2025-09-14]**, **[commit `aa165ae`, 2025-09-14]**. `compose.proxy.yaml` przetrwał do 2026-08-20, a `haproxy.cfg` do 2026-08-09 (szkielet osi czasu; to już E5).
- **Proxmox** i jego aktualizacje (Ansible `setup-proxmox.yaml`, `maintenance.yaml`). `setup-proxmox.yaml` m.in. dopisuje `nomodeset` do GRUB-a i włącza `ip_forward` **[plik `Ansible/setup-proxmox.yaml` w `0a00bf3`]**.
- **Home Assistant**: usunięty z manifestów 2025-08-15 **[commit `929e6b4`, 2025-08-15]**. W stanie obecnym działa jako osobna VM (CLAUDE.md, wpis o mapowaniu USB `Zigbee`); kiedy tam trafił, nie wiadomo **[nieznane]**.
- **Authentik i CrowdSec**: brak w manifestach po 2025-08-15, a `compose.auth.yaml` zniknął 2025-09-01 **[commit `328dddf`, 2025-08-15]**, **[commit `28fbc9e`, 2025-09-01]**. Do 2026-02 w repo nie ma żadnego middleware uwierzytelniania **[wniosek: brak `Middleware` w `Kubernetes/` w `0a00bf3`]**. Wrócą w E4 (Authentik w k8s od 2026-02-20 według szkieletu).

### 3.4 Publiczna ekspozycja w praktyce

- Terraform tworzy w Cloudflare tylko rekord `A @` na publiczny IP VPS (`proxied = false`), bez wildcardu **[plik `Terraform/oracle.tf` w `0a00bf3`]**.
- Port 443 w security list OCI zmieniał się 2025-08-31: wyłączony („fix public IP”), włączony („proxy https”), znowu wyłączony („disable https proxying”). Port 80 usunięto już 2025-08-30 **[commit `ae059cc`, 2025-08-30]**, **[commit `dc5dfb7`, 2025-08-31]**, **[commit `c230a67`, 2025-08-31]**, **[commit `2ef3d50`, 2025-08-31]**. Do końca E3 lista otwierała tylko SSH, Tailscale (41641/UDP) i WireGuard (51820/UDP) **[plik `Terraform/variables.tf` w `0a00bf3`]**, **[plik `Terraform/variables.tf` w `f50bd66`]**.
- **[wniosek]** Od 2025-08-31 do końca E3 usługi WWW były w praktyce dostępne tylko przez Tailscale i LAN (rewrite w AdGuardzie). To tłumaczy, dlaczego brak Authentika i `AuthenticationMethod=External` w *arr nie otwierały ich na internet. Zastrzeżenie: repo nie pokazuje domyślnej security listy VCN ani firewalla na samej instancji, a powód wyłączenia HTTPS nie jest zapisany (pytanie 4).

## 4. Okres spokojny i przygotowanie przebudowy (2025-09-15 → 2026-01-31)

### 4.1 Od września do listopada

- 2025-08-30 reguła automerge w `renovate.json` była zakomentowana, a 2025-09-12 wróciła: Renovate automatycznie scala grupę minor/patch z `ignoreTests: true`, a manifesty k8s są objęte `managerFilePatterns: Kubernetes/**/*.yaml` **[commit `8a72007`, 2025-08-30]**, **[commit `d5d64db`, 2025-09-12]**, **[plik `renovate.json` w `e005ecf`]**. Każdy taki merge od razu szedł do klastra przez workflow `kubernetes.yaml` **[wniosek]**.
- Przypadek: Renovate scalił `nvidia-device-plugin` 0.17.3 → 0.18.0 (PR #166, 2025-10-22, scalił `app/renovate`), a autor cofnął to 2025-10-31 (PR #173, „Reverts #166”) **[PR #166]**, **[PR #173]**, **[commit `a649d47`, 2025-10-31]**. Co się zepsuło: **[nieznane]** (pytanie 6).
- 2025-10-31: workflowy Claude Code (`claude.yml`, `claude-code-review.yml`) przez PR #174. Wcześniej jedyny ślad AI w historii to zakomentowany Open WebUI z 2024 **[commit `d663a49`, 2024-07-19]**, więc to pierwsze narzędzie AI działające na samym repo **[wniosek]** **[PR #174]**, **[commit `ae92196`, 2025-10-31]**.
- Pozostałe drobne zmiany z września: `Recreate`/`maxUnavailable: 1` w strategii wdrożeń, `shareProcessNamespace: true` przeciw procesom zombie w Byparr, Recyclarr jako CronJob **[commit `d152a3a`, 2025-09-12]**, **[commit `6154dee`, 2025-09-14]**, **[commit `dd3bba3`, 2025-09-12]**, **[commit `f31ed43`, 2025-09-01]**.

### 4.2 Grudzień i styczeń: plan migracji K3s → Talos

Uwaga o topologii historii: przygotowania nie szły na linii `main`. Gałąź migracyjna odchodzi od `827e399` (2025-12-15) i wraca do `main` merge'em `327eff3` („merge: incorporate migration branch into main with structural restructuring”) dopiero 2026-02-26 **[commit `bc91666`, 2025-12-17]**, **[commit `327eff3`, 2026-02-26]**, **[wniosek: `git merge-base --is-ancestor bc91666 f50bd66` zwraca 1; `git log --first-parent main`]**. Sortowanie po dacie (`git log main` bez `--first-parent`, a także szkielet osi czasu) miesza obie linie, więc daty „usunięcia” z tej gałęzi trzeba czytać jako daty commitów na gałęzi, nie na `main`.

Na gałęzi migracyjnej (w E3):

- 2025-12-17 „prepare for migration” dodaje `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` (2810 linii) i usuwa całą warstwę z E3: `Terraform/{oracle,proxmox,deployment,variables}.tf` (zostaje sam `backend.tf`), playbooki `k3s.yaml`, `setup-containers.yaml`, `setup-nvidia.yaml`, `proxy.yaml`, zadania NVIDIA i LXC, `.secrets.exmaple`, `.env.authentik.example` i workflowy `kubernetes`, `maintenance`, `nvidia`, `proxy`, `terraform` **[commit `bc91666`, 2025-12-17]**.
- Plan dopisywano jeszcze: autoaktualizacje (2025-12-17), ClamAV (2025-12-26), a 2026-01-27 („cleanup”) skrócono go do 1144 linii i dodano Reloader do `Kubernetes/infrastructure` **[commit `4265d28`, 2025-12-17]**, **[commit `9b06965`, 2025-12-26]**, **[commit `d0ae5b1`, 2026-01-27]**.
- Plik leży w `.github/prompts/` i ma rozszerzenie `.prompt.md`, więc prawdopodobnie był promptem dla asystenta AI **[wniosek]**.

Na `main` w tym samym czasie:

- 2025-12-17 „disable workflow files” usuwa z workflow `kubernetes`, `maintenance`, `nvidia`, `proxy` i `terraform` wyzwalacze `push` (a z `maintenance` także cron z poniedziałku 03:00). Zostaje tylko ręczne `workflow_dispatch` **[commit `f3f7297`, 2025-12-17]**.
- Terraform, Ansible i stare manifesty zostają na `main` bez zmian do końca E3 **[plik `Terraform/oracle.tf` w `f50bd66`]**, **[plik `Ansible/k3s.yaml` w `f50bd66`]**. 2026-02-01 (już E4) commit „remove terraform and deploy destroy” zmienia na `main` tylko workflowy: dodaje `terraform-destroy.yaml` i zamienia apply na sam plan, a pliki Terraform zostają **[commit `b8daa33`, 2026-02-01]**, **[plik `Terraform/oracle.tf` w `7fa55ed`]**. Stary Terraform i playbooki k3s znikają z `main` dopiero przy scaleniu gałęzi migracyjnej **[commit `327eff3`, 2026-02-26]**.

Co plan mówi o stanie E3 (jedyny opis „current state” w repo):

> - K3s running on Proxmox LXC containers
> - Manual configuration and deployments

**[plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w `bc91666`]**. Sekcja migracji danych dopowiada: media w `/Storage/Media` przez `hostPath`, konfiguracje „in LXC container at `/Storage` mount” **[plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w `bc91666`, sekcja 5.4]**. Plan wylicza też pliki do usunięcia „for the old K3s on LXC architecture” **[plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w `bc91666`, sekcja 11]**.

Docelowa architektura z planu to zamiar, a jej realizacja należy do E4: Talos na 3 VM (control-plane + worker), passthrough Intel Arc B580 do `talos-1`, ArgoCD, MetalLB, Longhorn (w v1 na iSCSI z zvoli ZFS), External Secrets + Bitwarden, Tailscale Operator, stos Grafana LGTM, CrowdSec, Oracle VPS tylko jako HAProxy **[plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w `bc91666`, sekcje 1-3]**. Wersja z 2026-01-27 dokłada m.in. ClamAV jako „Requirement”, Reloader, przełącznik public/private, NetworkPolicies, Immich, MCPJungle i SSO dla Jellyfina, a wycina większość gotowych bloków kodu **[plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w `d0ae5b1`]**.

### 4.3 Sprzęt: trzy niezgodne źródła

| Źródło | CPU | RAM | GPU | Dowód |
| --- | --- | --- | --- | --- |
| README (niezmieniane w E3) | Intel Core i5-12600K | 32 GB | Intel UHD 770 | **[plik `README.md` w `0a00bf3`]** |
| Ansible/k3s, 2025-08 | brak danych | LXC 24 000 MB | karta NVIDIA (sterownik 580.76.05, `/dev/nvidia0`) | **[commit `02cbf60`, 2025-08-15]**, **[plik `Terraform/proxmox.tf` w `ea23c77`]** |
| Plan migracji, 2025-12 | AMD Ryzen 9 3950X (MS-7C37) | 62,71 GiB | Intel Arc B580 | **[plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w `bc91666`]** |

Kiedy i dlaczego zmienił się sprzęt, repo nie mówi (pytanie 2).

### 4.4 Rozjazd repo z klastrem po 2025-12-17

Od wyłączenia wyzwalaczy `push` Renovate dalej scalał na `main` podbicia obrazów w manifestach, np. Bazarr 1.5.4, Jellyfin 10.11.6 i `nvidia-device-plugin` 0.18.2 **[commit `da57f8c`, 2026-01-05]**, **[commit `52b4186`, 2026-01-19]**, **[commit `dafd355`, 2026-01-23]**. Workflow `kubernetes.yaml` dało się już uruchomić tylko ręcznie, więc bez takiego uruchomienia te zmiany nie trafiały do klastra, a `main` przestawał opisywać to, co działało **[wniosek]**. Czy autor uruchamiał go ręcznie, z repo nie wynika. Stare katalogi `Kubernetes/{home,infrastructure,media,utilities,test}` usunięto na gałęzi migracyjnej 2026-02-01 **[commit `6757719`, 2026-02-01]**, a na `main` dotarło to z merge'em 2026-02-26 **[commit `327eff3`, 2026-02-26]**.

## 5. Studia przypadków

Commity podają poprawkę, prawie nigdy objawu. Poniżej opis diffu jako **[commit]**, przyczyna jako **[wniosek]**.

1. **Przekazywanie sekretów między jobami CI.** Najpierw artefakty szyfrowane GPG z hasłem w sekrecie GitHuba (na początku hasłem był klucz prywatny OCI z `TF_VAR_PRIVATE_KEY`, potem osobny `GPG_SECRET`) **[commit `1f194cd`, 2025-07-27]**. Po 4 dniach bucket OCI jako wspólny magazyn plików dla Terraform i Ansible **[commit `9cc822b`, 2025-07-31]**. **[wniosek]** To prosta wersja tego, co E4 rozwiązuje Bitwardenem i ESO: sekret ma jedno źródło, a CI tylko go czyta.
2. **Klucz wdrożeniowy, którego Terraform nie powinien podmieniać.** `oci_objectstorage_object.deployment_key` bierze treść z istniejącego obiektu, jeśli ten istnieje, a z nowego `tls_private_key` tylko przy pierwszym uruchomieniu **[commit `e37e5a4`, 2025-08-02]**. **[wniosek]** Chodziło o to, żeby odtworzenie stanu lub nowy runner CI nie zmieniał klucza zapisanego w `authorized_keys` maszyn.
3. **Wyścigi workflow.** Kilka commitów o „race condition” i `concurrency` (2025-07-31 → 2025-09-14), w końcu jedna globalna grupa `concurrency-lock` i kolejkowanie zamiast anulowania („queue instead of cancelling”) **[commit `5f45531`, 2025-07-31]**, **[commit `83cf309`, 2025-09-12]**, **[commit `e664667`, 2025-09-14]**. **[wniosek]** Terraform i Ansible pisały do tych samych zasobów (bucket, VM), więc równoległe przebiegi mogły się wzajemnie psuć.
4. **AdGuard na porcie 53 w LXC.** Najpierw DNS przez `IngressRouteTCP/UDP` Traefika (entrypointy 53), potem `hostNetwork` w podzie AdGuarda, a Ansible wyłącza `DNSStubListener` w systemd-resolved **[commit `7ce4d94`, 2025-08-31]**, **[commit `f31ed43`, 2025-09-01]**, **[commit `156200a`, 2025-08-31]**. **[wniosek]** Stub resolver systemd zajmuje port 53 na hoście, więc kolidował z serwerem DNS w sieci hosta.
5. **GPU NVIDIA w LXC.** Przez 2025-08-15 → 08-16 ok. 20 commitów: sterownik na hoście i w kontenerze (wersja przypięta, w kontenerze bez modułów jądra), przekazanie `/dev/nvidia*`, `--default-runtime=nvidia`, device plugin z time-slicingiem, test `nbody` **[commit `02cbf60`, 2025-08-15]**, **[commit `a2a56a0`, 2025-08-16]**, **[commit `af0260f`, 2025-08-16]**. **[wniosek]** Sterownik w kontenerze musi zgadzać się co do wersji z modułem jądra hosta, stąd przypięcie. Ta zależność znika dopiero przy VM z passthrough w planie Talosa.
6. **Automerge bez testów.** Opis w punkcie 4.1 (PR #166 → #173). **[wniosek]** `ignoreTests: true` w połączeniu z `kubectl apply` na pushu oznaczało, że aktualizacja minor szła na produkcję bez żadnej bramki.

## 6. Stan na koniec E3 (2026-01-31)

Stan na `main` (`f50bd66`, 2026-01-30, ostatni commit E3 na linii `main`):

- k3s w LXC `nickel` z manifestami z `Kubernetes/{home,infrastructure,media,utilities,test}` i NVIDIA device plugin (0.18.2); HAProxy i wg-easy na VPS `argon` **[plik `Kubernetes/kustomization.yaml` w `f50bd66`]**, **[plik `compose.proxy.yaml` w `f50bd66`]**.
- Terraform (OCI, LXC na Proxmoxie, Cloudflare) i Ansible (k3s, LXC, NVIDIA, Proxmox, proxy) nadal w repo, ale bez automatycznych wyzwalaczy od 2025-12-17 **[commit `f3f7297`, 2025-12-17]**.
- Renovate dalej aktualizował manifesty, których nic automatycznie nie wdrażało (punkt 4.4).

Stan gałęzi migracyjnej (`d0ae5b1`, 2026-01-27): plan Talosa w `.github/prompts/`, z Terraform tylko `backend.tf` (backend OCI, klucz `interstellar/terraform.tfstate`), z Ansible `setup-oracle.yaml`, `setup-proxmox.yaml` i `maintenance.yaml`, Reloader dopisany do manifestów **[plik `Terraform/backend.tf` w `bc91666`]**, **[commit `d0ae5b1`, 2026-01-27]**.

Co doprowadziło do przebudowy: repo podaje tylko dwa punkty „current state” planu (k3s w LXC, „manual configuration and deployments”). **[wniosek]** Z faktów E3 da się wyprowadzić listę słabości, które nowa architektura usuwa: k3s w uprzywilejowanym LXC z prawie wyłączoną izolacją, storage `local-path`/`hostPath` bez replikacji, puste sekrety w repo uzupełniane ręcznie, `kubectl apply` bez prune i bez wykrywania dryfu, sterowniki NVIDIA sprzężone z jądrem hosta. Repo nie mówi, czy to były motywy autora (pytanie 3).

## Pytania do autora

1. Ile węzłów miał klaster k3s w E3 (2025-08 → 2026-01) i które hosty miały tagi Tailscale `server` i `agent`? Czy VPS `argon` był kiedykolwiek węzłem k3s?
2. Kiedy wymieniono sprzęt serwera (README: i5-12600K, UHD 770; plan z 2025-12: Ryzen 9 3950X, 64 GB, Arc B580) i jaka karta NVIDIA była używana w sierpniu 2025?
3. Co konkretnie skłoniło do przejścia z k3s w LXC na Talos w VM (awaria, wydajność, utrzymanie, GPU, chęć GitOps)? Czy było jakieś zdarzenie z grudnia 2025?
4. Dlaczego 2025-08-31 wyłączono HTTPS na VPS („disable https proxying”) i czy w okresie 2025-09 → 2026-01 jakakolwiek usługa była dostępna z internetu bez Tailscale?
5. Czy Authentik działał gdzieś po 2025-09-01 (poza repo), skoro zniknął z compose i nie trafił do k8s?
6. Co się zepsuło po automatycznej aktualizacji `nvidia-device-plugin` do v0.18.0 (PR #166), że trzeba było ją cofnąć?
7. Skąd pochodziły pliki Terraform z 2025-07-26 (powstały pod OpenTofu w innym repo?) i dlaczego od razu wrócono do Terraform?
8. Czym były osadzone repozytoria `Kubernetes` (2025-07-27 → 2025-08-11) i `proxmox` (2025-08-16 → 2025-08-25)? Czy to przypadkowe `git add` katalogów z własnym `.git`?
9. Jak trafiały do klastra prawdziwe wartości sekretów (Cloudflare, Bazarr), skoro w repo były puste, a CI robiło `kubectl apply` na każdym pushu? Czy apply nadpisywał je pustymi?
10. Czy plan `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` był pisany z asystentem AI (Copilot/Claude) i jak bardzo realizacja w E4 się od niego różni?
11. Ile z manifestów wygenerowanych przez kompose 2025-08-11 przetrwało ręczne poprawki z sierpnia? Czy próbowano innych narzędzi?
12. Czy między 2025-12-17 a 2026-02-01 workflow `kubernetes.yaml` albo `terraform.yaml` był uruchamiany ręcznie (wyzwalacze `push` były wyłączone), i dlaczego przygotowania do Talosa szły na osobnej gałęzi scalonej dopiero 2026-02-26?

## Do której części pracy

- **Wstęp / motywacja**: przejście od ręcznego compose do IaC jako punkt wyjścia „repatriacji” i automatyzacji (§1, §2).
- **Technologie**: Terraform vs OpenTofu (§2.2), Ansible z kolekcjami Galaxy, k3s i jego pakietowe komponenty (§2.5, §3.2), kompose, `act`, Renovate (fakty o alternatywach dają pliki z `technologie/`).
- **Projekt**: wersja „przed” do porównania z architekturą E4, tabela §3.2, plan migracji jako artefakt projektowy (§4.2).
- **Implementacja**: pipeline CI (§2.4), most Terraform → Ansible przez bucket OCI (§2.3, studium 2), przeniesienie usług z compose do k8s (§3.1).
- **Odtwarzanie po awarii**: argumenty z E3 przeciw starej architekturze (k3s w uprzywilejowanym LXC, `local-path`, ręczne sekrety, dryf po 2025-12-17) jako tło testu odtworzenia (§4.4, §6).
- **Analiza kosztów**: VPS w darmowym limicie Oracle (4 OCPU / 24 GB / 200 GB), zmiany sprzętu do potwierdzenia (§4.3).

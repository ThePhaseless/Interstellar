# Oś czasu homelabu (od okresu sprzed repozytorium do 2026-11-27)

Plik zbiera w jednym miejscu daty z pięciu plików historii (`historia/`), pięciu plików technologii (`technologie/`) i pliku `odtwarzanie-i-koszty.md`. Daty sprawdzono w `git log main`. Szczegóły i uzasadnienia są w plikach źródłowych, do których prowadzą linki w tabelach.

Zasady czytania dat:

- Data commita to data autora (`git log --date=short`, w strefie czasowej autora). Liczby commitów w okresach i miesiącach policzono po dacie autora w UTC (`TZ=UTC git log main --date=short-local`) na `main` z 2026-11-27 (tip `e7ae5da`). Liczby dla pojedynczego dnia podano w strefie autora, a w nawiasie w UTC, bo różnią się o kilka commitów. W nawiasie podano liczbę commitów z historii pierwszego rodzica (`--first-parent`), czyli bez commitów, które weszły merge'em z gałęzi bocznych.
- Przebudowę z E4 przygotowano na gałęzi bocznej. Odeszła od `main` w commicie `827e399` (2025-12-15), pierwszy commit gałęzi ma datę 2025-12-17, a na `main` trafiła merge'em `327eff3` 2026-02-26 **[commit `327eff3`, 2026-02-26]**. Wszystko, co powstało na gałęzi, ma w tabelach datę commita z dopiskiem „gałąź” i znacznik „na `main` od 2026-02-26”. To, co na gałęzi powstało i zniknęło przed merge'em (nfs-csi, kube-api-lb, oauth2-proxy, drugi epizod OpenTofu), jest na `main` tylko w historii merge'a. Klaster mógł działać na nowym układzie wcześniej niż 2026-02-26; repo tego nie rozstrzyga **[nieznane]**.

## Okresy

| Okres | Daty | Streszczenie | Gdzie co działało | Model wdrażania | Commity na `main` | Plik |
| --- | --- | --- | --- | --- | --- | --- |
| Przed repo | do 2024-01-01 | Serwer domowy i VPS istniały przed pierwszym commitem. Wynika to ze skryptów instalacyjnych z nagłówkiem „January 1, 2024”, wpisu `general_old` w `.gitignore`, wcześniejszej nazwy projektu „litwave” i domeny `fireword.xyz` **[commit `386f12a`, 2024-01-01]**, **[commit `4488451`, 2024-02-11]**, **[wniosek]**. Sprzęt, system i lista usług z tego czasu: **[nieznane]**. | Maszyna domowa + VPS (najpewniej Oracle) **[wniosek]** | Ręczny **[wniosek]** | 0 **[commit `386f12a`, 2024-01-01]** | [01](historia/01-start-docker-compose.md) |
| E1 | 2024-01-01 → 2024-07-13 | Start repo: skrypty instalacyjne, docker-compose, Traefik + Authelia, odwrócenie układu host/proxy/general na DMZ/VPS/General. Od 2024-03-27 do 2024-07-13 nie ma ani jednego commita. | Dom (DMZ) z usługami w compose; VPS Oracle jako brama: tunel WireGuard VPS → DMZ od 2024-01-14 **[commit `814bff1`, 2024-01-14]** | Ręczny: skrypty `install.sh` uruchamiane na maszynach **[wniosek]** | 199 (188) **[wniosek: `git log main`]** | [01](historia/01-start-docker-compose.md) |
| E2 | 2024-07-14 → 2025-07-25 | Compose w katalogu głównym repo, CI wdraża przez Tailscale SSH, Renovate, CrowdSec, serwery gier, Authentik zamiast Authelii (2025-02), HAProxy na VPS w repo (2025-03). | Jeden host Dockera, według README z 2025-03 VM na Proxmox VE 8 **[commit `84ea802`, 2025-03-13]**; wejście z internetu przez VPS Oracle i Tailscale z PROXY protocol | Push: GitHub Actions → Tailscale SSH → `git pull && docker compose up` **[commit `9de8f42`, 2024-07-14]**; od 2025-04-23 serwer sam commituje zmiany z powrotem **[commit `a0ed77e`, 2025-04-23]** | 290 (279) **[wniosek: `git log main`]** | [02](historia/02-rozwoj-compose.md) |
| E3 | 2025-07-26 → 2026-01-31 | Terraform, Ansible i uv; k3s w kontenerze LXC; koniec compose w domu 2025-09-01; od 2025-09-15 prawie tylko Renovate; od 2025-12-17 plan Talosa na gałęzi bocznej. | Proxmox `carbon`, k3s w uprzywilejowanym LXC `nickel` z kartą NVIDIA; VPS `argon` z HAProxy (i od 2025-09-14 wg-easy) **[commit `6930efc`, 2025-07-26]**, **[commit `a4f4005`, 2025-09-14]**. Od 2025-08-31 security list OCI otwierała tylko SSH, 41641/UDP i 51820/UDP, więc WWW szło w praktyce tylko przez Tailscale i LAN **[wniosek]**, zob. [h03](historia/03-iac-i-pierwszy-kubernetes.md) | Push: CI uruchamia Terraform/Ansible, od 2025-09-12 `kubectl kustomize … \| kubectl apply` z CI **[commit `06ecf16`, 2025-09-12]** | 357 (340) **[wniosek: `git log main`]** | [03](historia/03-iac-i-pierwszy-kubernetes.md) |
| E4 | 2026-02-01 → 2026-07-31 | Przebudowa: Talos w trzech VM, ArgoCD app-of-apps, Longhorn, ESO + Bitwarden, Authentik w Kubernetesie, drugi root `Terraform/apps`; Nix flake, potem mise; strojenie RAM węzłów i oszczędzanie prądu. | Proxmox `carbon` z trzema VM Talosa (`talos-1` z Arc B580); Oracle: `oracle-proxy` (HAProxy) + `oracle-compute` **[commit `6757719`, 2026-02-01]** | Pull: ArgoCD synchronizuje `Kubernetes/` z gita (na `main` od 2026-02-26). Push: Terraform z CI, od 2026-05-23 automatyczny apply na `main` **[commit `ffea00e`, 2026-05-23]** | 812 (651) **[wniosek: `git log main`]** | [04](historia/04-przebudowa-gitops.md) |
| E5 | 2026-08-01 → 2026-11-27 | Koniec HAProxy, publiczne wystawienie Traefika na domowym IP z cloudflare-ddns, CrowdSec z agentem i AppSec, egzekwowane NetworkPolicy, pula pobierania NVMe + mergerfs, uśpienie dysków, incydenty sieci domowej, Pagewire. | Te same VM Talosa; Traefik na MetalLB `192.168.1.11` za przekierowaniem portów routera; Oracle `compute` już tylko jako urządzenie osobiste w tailnecie **[commit `7158f21`, 2026-08-20]**, **[commit `5d7f26e`, 2026-08-21]** | Jak w E4: pull (ArgoCD) dla Kubernetesa, push (CI) dla Terraformu | 517 (507) **[wniosek: `git log main`]** | [05](historia/05-publiczne-wystawienie-i-stan-obecny.md) |

Razem na `main` jest 2175 commitów, z tego 673 od `renovate[bot]` **[wniosek: `git log main --format=%an`]**.

## Kamienie milowe

„Gałąź” oznacza datę commita na gałęzi migracyjnej; ta zmiana pojawiła się na `main` dopiero 2026-02-26.

| Data | Zdarzenie | Dowód | Plik |
| --- | --- | --- | --- |
| przed 2024-01-01 | Serwer i VPS działają bez repo; projekt nazywał się „litwave”, domena `fireword.xyz` | **[commit `386f12a`, 2024-01-01]**, **[wniosek]** | [h01](historia/01-start-docker-compose.md) |
| 2024-01-01 | Pierwszy commit: katalogi `host/`, `proxy/`, `general/`; Traefik, Authelia i Watchtower na maszynie proxy (certyfikaty DNS-01 w Cloudflare); Portainer i Samba ze skryptów; RAID0 albo mergerfs | **[commit `386f12a`, 2024-01-01]** | [h01](historia/01-start-docker-compose.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2024-01-06 → 2024-01-13 | Eksperyment z DnsMasq na proxy, usunięty po tygodniu razem ze stosem proxy | **[commit `1a16b19`, 2024-01-06]**, **[commit `3dc86c2`, 2024-01-13]** | [h01](historia/01-start-docker-compose.md) |
| 2024-01-14 | Odwrócenie układu: `host/` → `DMZ/`, `proxy/` → `VPS/`; tunel WireGuard z VPS do domu; RAID10 zamiast RAID0/mergerfs | **[commit `814bff1`, 2024-01-14]** | [h01](historia/01-start-docker-compose.md) |
| 2024-01-15 | Pierwsze pliki compose usług (media, home), w tym AdGuard Home; lldap, Immich, Duplicati; 54 commity tego dnia (52 w UTC) | **[commit `ba47ea5`, 2024-01-15]**, **[commit `4689c1f`, 2024-01-15]**, **[commit `8f3e37d`, 2024-01-15]** | [h01](historia/01-start-docker-compose.md) |
| 2024-01-17 | lldap → OpenLDAP; Authelia z `two_factor` na `one_factor` | **[commit `8cf1bc9`, 2024-01-17]** | [h01](historia/01-start-docker-compose.md) |
| 2024-02-08 | Devcontainer i Dependabot (tylko ekosystem devcontainers) | **[commit `44e2ac5`, 2024-02-08]** | [t02](technologie/02-iac-gitops-ci.md) |
| 2024-02-11 | `fireword.xyz` → `nerine.dev`; powrót do lldap; Immich wyłączony | **[commit `4488451`, 2024-02-11]**, **[commit `731bdac`, 2024-02-11]** | [h01](historia/01-start-docker-compose.md) |
| 2024-02-21 | Plik konfiguracji AdGuard Home w repo (split-horizon `*.nerine.dev`); sama usługa jest w compose od 2024-01-15 | **[commit `775a8a8`, 2024-02-21]** | [h01](historia/01-start-docker-compose.md) |
| 2024-02-25 | Home Assistant w compose | **[commit `acfb3af`, 2024-02-25]** | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| 2024-02-26 | Restrukturyzacja DMZ; włączony serwer gry FTB Skies Expert (port 25565); Immich i Duplicati znikają, odtąd nie ma w repo żadnej kopii zapasowej aż do 2026-02-24. Tego samego dnia wypełnione pliki `.env` są w repo przez kilka godzin (incydent z sekretami) | **[commit `06b7e79`, 2024-02-26]**, **[commit `d68685f`, 2024-02-26]** | [h01](historia/01-start-docker-compose.md), [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| 2024-03-26 | mdadm RAID10 → ZFS (dwa mirrory w stripe); ostatni commit E1, potem prawie cztery miesiące ciszy | **[commit `d68bcf6`, 2024-03-26]** | [h01](historia/01-start-docker-compose.md), [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| 2024-07-14 | Przebudowa: usunięte `DMZ/`, `VPS/`, `General/` (z WireGuardem i skryptami Samby); compose w katalogu głównym; pierwszy workflow wdrożeniowy w GitHub Actions | **[commit `6f7927b`, 2024-07-14]**, **[commit `7198b20`, 2024-07-14]**, **[commit `9de8f42`, 2024-07-14]** | [h02](historia/02-rozwoj-compose.md) |
| 2024-07-16 | Traefik ufa PROXY protocol z tailnetu: prawdziwy adres klienta przez VPS i Tailscale. Najpóźniej teraz WireGuard ustępuje Tailscale **[wniosek]** | **[commit `d1e481a`, 2024-07-16]** | [h02](historia/02-rozwoj-compose.md) |
| 2024-07-17 | Renovate i przypięte tagi obrazów zamiast `latest` | **[commit `5b2f015`, 2024-07-17]**, **[commit `b222e39`, 2024-07-17]** | [h02](historia/02-rozwoj-compose.md), [t02](technologie/02-iac-gitops-ci.md) |
| 2024-07-18 | CrowdSec (agent + bouncer jako wtyczka Traefika) w compose | **[commit `ac3087c`, 2024-07-18]** | [h02](historia/02-rozwoj-compose.md) |
| 2024-07-25 | FlareSolverr → Byparr (obraz autora) | **[commit `6c0c661`, 2024-07-25]**, **[commit `7582a93`, 2024-07-25]** | [h02](historia/02-rozwoj-compose.md), [t05](technologie/05-aplikacje-i-repatriacja.md) |
| 2024-08-14 → 2024-12-03 | Serwer Minecraft (DawnCraft) w compose; 2024-12-03 jego `include` zakomentowany | **[commit `6461946`, 2024-08-14]**, **[commit `c0d65d8`, 2024-12-03]** | [h02](historia/02-rozwoj-compose.md) |
| 2025-02-12 | Authelia + LLDAP → Authentik; z compose znikają Portainer, Samba, domowy Watchtower i pliki serwerów gier | **[commit `c8dccdd`, 2025-02-12]** | [h02](historia/02-rozwoj-compose.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2025-03-13 | Konfiguracja VPS w repo: HAProxy (TCP z PROXY protocol v2) i Watchtower. Nowe README: i5-12600K / 32 GB, Proxmox VE 8, CGNAT | **[commit `0fa08ec`, 2025-03-13]**, **[commit `84ea802`, 2025-03-13]** | [h02](historia/02-rozwoj-compose.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2025-04-23 | Serwer commituje i pushuje „Synced latest changes”: dryf konfiguracji wraca do repo w drugą stronę | **[commit `a0ed77e`, 2025-04-23]** | [h02](historia/02-rozwoj-compose.md) |
| 2025-07-26 | Terraform, Ansible, uv. OpenTofu przez 13 minut (pierwszy epizod). Stary workflow compose wyłączony | **[commit `6930efc`, 2025-07-26]**, **[commit `75e604b`, 2025-07-26]**, **[commit `162b32c`, 2025-07-26]**, **[commit `fc8269f`, 2025-07-26]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md), [t02](technologie/02-iac-gitops-ci.md) |
| 2025-07-31 | `act` do lokalnego uruchamiania workflowów; inwentarz Ansible w buckecie OCI | **[commit `7b3ce98`, 2025-07-31]**, **[commit `9cc822b`, 2025-07-31]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md) |
| 2025-08-02 → 2025-08-04 | k3s instalowany Ansiblem w LXC `nickel`, Flannel po `tailscale0` | **[commit `5765311`, 2025-08-02]**, **[commit `ea23c77`, 2025-08-04]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md), [t01](technologie/01-platforma-i-orkiestracja.md) |
| 2025-08-11 | Pliki compose przekonwertowane na manifesty narzędziem kompose | **[commit `abcb648`, 2025-08-11]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md) |
| 2025-08-15 → 2025-08-16 | Sterownik NVIDIA w LXC i device plugin z time-slicingiem; Home Assistant wypada z manifestów | **[commit `02cbf60`, 2025-08-15]**, **[commit `1b4af72`, 2025-08-16]**, **[commit `929e6b4`, 2025-08-15]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md) |
| 2025-09-01 | Koniec compose w domu („remove og compose”); na VPS zostaje `compose.proxy.yaml` | **[commit `28fbc9e`, 2025-09-01]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md), [t01](technologie/01-platforma-i-orkiestracja.md) |
| 2025-09-12 | CI wdraża manifesty na k3s (`kubectl apply`) | **[commit `06ecf16`, 2025-09-12]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md) |
| 2025-09-14 | wg-easy na VPS; jeden `deploy.yaml` rozbity na osobne workflowy | **[commit `a4f4005`, 2025-09-14]**, **[commit `943f2d3`, 2025-09-14]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md) |
| 2025-10-31 | Revert nvidia-device-plugin 0.18.0; pierwsze workflowy Claude Code w repo | **[commit `a649d47`, 2025-10-31]**, **[commit `ae92196`, 2025-10-31]**, **[PR #174]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md) |
| 2025-12-17 (gałąź, na `main` od 2026-02-26) | „prepare for migration”: plan K3s → Talos (2810 linii) opisuje Ryzen 9 3950X i Arc B580; na gałęzi usunięty kod k3s, LXC i NVIDIA. Na `main` tego dnia wyłączone wyzwalacze starych workflowów | **[commit `bc91666`, 2025-12-17]**, **[commit `f3f7297`, 2025-12-17]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md), [h04](historia/04-przebudowa-gitops.md) |
| 2026-02-01 (main) | „remove terraform and deploy destroy” zmienia na `main` tylko workflowy: dodaje `terraform-destroy.yaml`, a `terraform.yaml` staje się `terraform-plan.yaml`. Kod Terraformu, Ansible i k3s z E3 zostaje na `main` do merge'a 2026-02-26 | **[commit `b8daa33`, 2026-02-01]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md), [h04](historia/04-przebudowa-gitops.md) |
| 2026-02-01 (gałąź, na `main` od 2026-02-26) | Commit „migrate” (262 pliki): Talos na trzech VM, ArgoCD app-of-apps, Longhorn, MetalLB, ESO + Bitwarden, CrowdSec z wyłączonym agentem, oauth2-proxy, obserwowalność. Tego dnia OpenTofu przez 6 godzin (drugi epizod) | **[commit `6757719`, 2026-02-01]**, **[commit `afad10b`, 2026-02-01]**, **[commit `06e540f`, 2026-02-01]** | [h04](historia/04-przebudowa-gitops.md), [t02](technologie/02-iac-gitops-ci.md) |
| 2026-02-16 (gałąź, na `main` od 2026-02-26) | Drugi root `Terraform/apps`; dynamiczny nfs-csi | **[commit `7a30c5b`, 2026-02-16]**, **[commit `6cba788`, 2026-02-16]** | [h04](historia/04-przebudowa-gitops.md) |
| 2026-02-18 (gałąź, na `main` od 2026-02-26) | kube-api-lb → VIP Talosa `192.168.1.100`; zasoby GPU z NVIDIA na Intel `xe` | **[commit `066701e`, 2026-02-18]**, **[commit `34c4dbc`, 2026-02-18]** | [h04](historia/04-przebudowa-gitops.md), [t05](technologie/05-aplikacje-i-repatriacja.md) |
| 2026-02-20 (gałąź, na `main` od 2026-02-26) | oauth2-proxy → Authentik w Kubernetesie; nfs-csi → statyczne PV/PVC | **[commit `e2a3a1b`, 2026-02-20]**, **[commit `a338df4`, 2026-02-20]** | [h04](historia/04-przebudowa-gitops.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2026-02-24 (gałąź, na `main` od 2026-02-26) | BorgBackup na Hetzner Storage Box (pierwsza kopia od 2024-02); Postfix przez OCI Email Delivery; nadpisanie CoreDNS; pre-commit; ArgoCD, Longhorn i Reloader na charty Helm | **[commit `16fdd8f`, 2026-02-24]**, **[commit `2b33dec`, 2026-02-24]**, **[commit `197d3cf`, 2026-02-24]**, **[commit `b4e151c`, 2026-02-24]**, **[commit `067462b`, 2026-02-24]** | [h04](historia/04-przebudowa-gitops.md), [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| 2026-02-26 (main) | Merge gałęzi migracyjnej: cały układ E4 trafia na `main` (364 pliki), a stary Terraform, Ansible i k3s z E3 znikają; 92 commity tego dnia (98 w UTC), najwięcej w historii; CI przechodzi na token GitHub App | **[commit `327eff3`, 2026-02-26]**, **[commit `9e54672`, 2026-02-26]** | [h04](historia/04-przebudowa-gitops.md), [t02](technologie/02-iac-gitops-ci.md) |
| 2026-02-27 → 2026-02-28 | Longhorn w DiskPressure, pełny PVC Mimira; `defaultReplicaCount` 3 → 2, ale domyślna klasa `longhorn` z chartu nadal ma 3 repliki | **[commit `06093ff`, 2026-02-28]** | [h04](historia/04-przebudowa-gitops.md), [ok](odtwarzanie-i-koszty.md) |
| 2026-03-01 | Nix flake + direnv jako środowisko dewelopera | **[commit `3b8be01`, 2026-03-01]** | [t02](technologie/02-iac-gitops-ci.md) |
| przed 2026-03-07 | Utrata danych po odtworzeniu app-of-apps ArgoCD; dokładna data **[nieznane]**, znany jest tylko wpis ostrzegawczy | **[commit `4f47a7b`, 2026-03-07]** | [h04](historia/04-przebudowa-gitops.md) |
| 2026-04-06 | Dependabot → Renovate (PR agenta Copilot, scalony 2026-04-07) | **[commit `bd423ac`, 2026-04-06]**, **[PR #311]** | [t02](technologie/02-iac-gitops-ci.md) |
| 2026-05-03 | Nix flake → mise; `renovate.json` → `renovate.json5` | **[commit `80cebb2`, 2026-05-03]**, **[commit `615d950`, 2026-05-03]** | [t02](technologie/02-iac-gitops-ci.md) |
| 2026-05-14 | Longhorn `emergency_ro` (przyczyna **[nieznane]**); nadpisanie CoreDNS zastąpione `hostAliases` w Jellyfinie | **[commit `43f6a34`, 2026-05-14]**, **[commit `e42d919`, 2026-05-14]** | [h04](historia/04-przebudowa-gitops.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2026-05-23 | Automatyczny `terraform apply` na `main`, gdy plan wykryje zmiany | **[commit `ffea00e`, 2026-05-23]** | [h04](historia/04-przebudowa-gitops.md) |
| 2026-06-03 | MinIO jako cel kopii Longhorna dodany i wycofany tego samego dnia; zostaje Borg | **[commit `145f097`, 2026-06-03]**, **[commit `59a11a8`, 2026-06-03]** | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| 2026-06-14 → 2026-06-18 | Faza 1 oszczędzania prądu (hd-idle, ASPM, TLP, firmware DMC przez rozszerzenie i915). Średni pobór 147,4 W → 130,2 W | **[commit `55389fa`, 2026-06-14]**, **[commit `08b837f`, 2026-06-18]**, **[commit `4367315`, 2026-06-18]** | [ok](odtwarzanie-i-koszty.md), [h04](historia/04-przebudowa-gitops.md) |
| 2026-06-19 → 2026-06-22 | Pętla restartów `talos-1`: CI apply odtworzył węzeł przez nieaktualny stan. Hipoteza o GPU za mostkiem PCIe cofnięta tego samego dnia, hipoteza o OOM Flannela zrewidowana raportem o starych danych etcd | **[commit `87e4810`, 2026-06-19]**, **[commit `70fb7b4`, 2026-06-21]** | [h04](historia/04-przebudowa-gitops.md), [ok](odtwarzanie-i-koszty.md) |
| 2026-07-24 | CrowdSec na chart Helm: od 2026-02-01 (gałąź) agent był wyłączony i nie czytał logów | **[commit `b0099ce`, 2026-07-24]** | [h04](historia/04-przebudowa-gitops.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2026-07-27 | CrowdSec AppSec (WAF); firmware Arc B580 21.1137 → 21.1182 z LVFS (wpis w tym samym commicie) | **[commit `38dcd4e`, 2026-07-27]**, **[commit `711d818`, 2026-07-27]** | [h04](historia/04-przebudowa-gitops.md) |
| 2026-08-09 | HAProxy na VPS: trzy sposoby szukania Traefika w jeden dzień; ścieżka nie działała od ok. 2026-07-26 | **[commit `0d9b743`, 2026-08-09]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md) |
| 2026-08-13 | Zamknięta luka SSO (każde konto Google wchodziło wszędzie), usunięte poświadczenia z repo, Pod Security baseline | **[commit `c3bd45f`, 2026-08-13]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2026-08-18 | Wygasły klucz Tailscale `carbon` odciął NFS i exit node; Oracle `compute` staje się urządzeniem osobistym | **[commit `4fe6631`, 2026-08-18]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [ok](odtwarzanie-i-koszty.md) |
| 2026-08-19 | NetworkPolicy zaczynają być egzekwowane (wcześniej Flannel je ignorował); pasma `shutdownGracePeriodByPodPriority` kładą kubelet na trzech węzłach; `talos-3` 8 → 12 GiB | **[commit `930e1e8`, 2026-08-19]**, **[commit `59abe12`, 2026-08-19]**, **[commit `1727f68`, 2026-08-19]**, **[PR #563]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md) |
| 2026-08-20 | VM `oracle-proxy` (1 OCPU / 6 GB) z HAProxy zniszczona na podstawie błędnej diagnozy „Orange blokuje 80/443”; `compute` powiększony z 3 OCPU / 18 GB do 4 OCPU / 24 GB; HTTP/3 włączone | **[commit `7158f21`, 2026-08-20]**, **[PR #567]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [t01](technologie/01-platforma-i-orkiestracja.md) |
| 2026-08-21 | Sprostowanie: winne było przekierowanie portów na routerze. Publiczne rekordy A z cloudflare-ddns, koniec `private-chain` i `tailscale-only`, `nerine.dev` → biblioteka aplikacji Authentika | **[commit `ca9a652`, 2026-08-21]**, **[commit `5d7f26e`, 2026-08-21]**, **[commit `cf4cbd6`, 2026-08-21]**, **[commit `3fce217`, 2026-08-21]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2026-08-31 → 2026-09-02 | Nowy dysk NVMe (238 GiB) i pula pobierania NVMe + mergerfs; restart hosta odsłania pułapki (stare ISO, przenumerowane grupy IOMMU); `compression=off` → `zle` | **[commit `b4744b4`, 2026-08-31]**, **[commit `c939f49`, 2026-08-31]**, **[commit `0bdd584`, 2026-09-01]**, **[commit `064f440`, 2026-09-02]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| 2026-09-03 | Traefik zdjęty z Tailscale (proxy L3 operatora: ok. 57 MB/s wobec 276 MB/s na MetalLB) | **[commit `905ab74`, 2026-09-03]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md) |
| 2026-09-21 | Strojenie ZFS pod uśpienie HDD spowalnia etcd na NVMe; zawieszony klient NFSv4 na `talos-3`; błędne hipotezy (porty tailscaled, limity odbudów Longhorna) | **[commit `34899c2`, 2026-09-21]**, **[commit `d795946`, 2026-09-21]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| 2026-09-22 | Przyczyna flapowania `talos-3`: kolizja IP z dekoderem TV (pula DHCP routera); router to Mercusys, nie Orange Funbox; grupa RecurringJob Longhorna okazuje się martwa | **[commit `9903e08`, 2026-09-22]**, **[commit `67466a5`, 2026-09-22]**, **[commit `ef00f2c`, 2026-09-22]**, **[commit `2924c95`, 2026-09-22]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2026-09-24 | Węzły przez `talos_machine`/`talos_cluster`; pierwsza aktualizacja tym mechanizmem: Talos v1.14.1, Kubernetes 1.37.1 | **[commit `b79a68b`, 2026-09-24]**, **[commit `a5a4ddf`, 2026-09-24]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md) |
| 2026-10-02 | Moduł `talos-node`: aktualizacje po jednym węźle z bramką zdrowia Longhorna (po restarcie, który zostawił jedną kopię danych) | **[commit `feb2ee9`, 2026-10-02]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [t01](technologie/01-platforma-i-orkiestracja.md) |
| 2026-10-05 → 2026-10-06 | CrowdSec banuje domowe IP (hairpin NAT), whitelist i panel banów; HTTP/3 wyłączone (QUIC wolniejszy przy uploadzie) | **[commit `efac355`, 2026-10-05]**, **[commit `6deeeaf`, 2026-10-06]**, **[PR #681]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| 2026-11-02 → 2026-11-04 | Po restarcie hosta: agenci CrowdSec nie mogą się ponownie zarejestrować; `fbcon` zajmuje 100% cpu0 na `talos-1` | **[PR #752]**, **[PR #760]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md) |
| 2026-11-17 | clips-sftp (SFTP przez Tailscale SSH) | **[commit `cf24c25`, 2026-11-17]** | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| 2026-11-25 | Pagewire i drukarka Samsung SCX-4300 na `talos-2` (generic-device-plugin, namespace `printing`) | **[commit `e3857f4`, 2026-11-25]** | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md), [t05](technologie/05-aplikacje-i-repatriacja.md) |

## Technologie w czasie

„Od” i „do” to daty commitów na `main`; przy zmianach z gałęzi migracyjnej podano obie daty. „dziś” w kolumnie „do” oznacza, że technologia nadal działa.

| Technologia | Od | Do | Zastąpione przez | Link |
| --- | --- | --- | --- | --- |
| Skrypty instalacyjne (`install.sh`) | 2024-01-01 **[commit `386f12a`, 2024-01-01]** | 2024-07-14 **[commit `6f7927b`, 2024-07-14]** | compose w repo + CI, potem Ansible | [h01](historia/01-start-docker-compose.md) |
| docker-compose (dom) | 2024-01-01 na proxy **[commit `386f12a`, 2024-01-01]**; usługi od 2024-01-15 **[commit `ba47ea5`, 2024-01-15]** | 2025-09-01 **[commit `28fbc9e`, 2025-09-01]** | k3s | [t01](technologie/01-platforma-i-orkiestracja.md) |
| docker-compose (VPS, `compose.proxy.yaml`) | 2025-03-13 **[commit `0fa08ec`, 2025-03-13]** | 2026-08-20 **[commit `7158f21`, 2026-08-20]** | brak (VM usunięta) | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md) |
| Portainer | 2024-01-01 skrypt **[commit `386f12a`, 2024-01-01]**; compose 2024-02-08 **[commit `34a5add`, 2024-02-08]** | 2025-02-12 **[commit `c8dccdd`, 2025-02-12]** | **[nieznane]** | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| Watchtower | dom 2024-01-01 **[commit `386f12a`, 2024-01-01]**; VPS 2025-03-13 **[commit `0fa08ec`, 2025-03-13]** | dom 2025-02-12 **[commit `c8dccdd`, 2025-02-12]**; VPS 2026-08-20 **[commit `7158f21`, 2026-08-20]** | przypięte tagi + Renovate **[wniosek]** | [h02](historia/02-rozwoj-compose.md) |
| Authelia | 2024-01-01 **[commit `386f12a`, 2024-01-01]** | 2025-02-12 **[commit `c8dccdd`, 2025-02-12]** | Authentik | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| LLDAP / OpenLDAP | lldap 2024-01-15 **[commit `4689c1f`, 2024-01-15]**; OpenLDAP 2024-01-17 **[commit `8cf1bc9`, 2024-01-17]**; znów lldap 2024-02-11 **[commit `731bdac`, 2024-02-11]** | 2025-02-12 **[commit `c8dccdd`, 2025-02-12]** | Authentik | [h01](historia/01-start-docker-compose.md) |
| Let's Encrypt przez DNS-01 w Cloudflare | 2024-01-01 **[commit `386f12a`, 2024-01-01]**; wildcard 2024-01-02 **[commit `a1042ba`, 2024-01-02]** | dziś | nie dotyczy | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| Tailscale | 2024-01-01 instalowany skryptem **[commit `386f12a`, 2024-01-01]**; SSH dla CI 2024-07-14 **[commit `5ebf412`, 2024-07-14]**; operator w k8s gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26); ACL jako kod 2026-02-26 **[commit `633f8f6`, 2026-02-26]** | dziś (Traefik zdjęty z tailnetu 2026-09-03 **[commit `905ab74`, 2026-09-03]**) | nie dotyczy | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| DnsMasq | 2024-01-06 **[commit `1a16b19`, 2024-01-06]** | 2024-01-13 **[commit `3dc86c2`, 2024-01-13]** | AdGuard Home (w compose od 2024-01-15) **[wniosek]** | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| WireGuard VPS → dom | 2024-01-14 **[commit `814bff1`, 2024-01-14]** | 2024-07-14 **[commit `6f7927b`, 2024-07-14]** | Tailscale + PROXY protocol **[wniosek]** | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| wg-easy na VPS | 2025-09-14 **[commit `a4f4005`, 2025-09-14]** | gałąź 2025-12-17 **[commit `bc91666`, 2025-12-17]**; na `main` do 2026-02-26 **[commit `327eff3`, 2026-02-26]** | Tailscale **[wniosek]** | [h03](historia/03-iac-i-pierwszy-kubernetes.md) |
| RAID0 / mergerfs (E1) | 2024-01-01 **[commit `386f12a`, 2024-01-01]** | 2024-01-14 **[commit `814bff1`, 2024-01-14]** | mdadm RAID10 | [h01](historia/01-start-docker-compose.md) |
| mdadm RAID10 + ext4 | 2024-01-14 **[commit `814bff1`, 2024-01-14]**; skrypt gotowy 2024-01-20 **[commit `d998e1b`, 2024-01-20]** | 2024-03-26 **[commit `d68bcf6`, 2024-03-26]** | ZFS | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| ZFS | 2024-03-26, dwa mirrory **[commit `d68bcf6`, 2024-03-26]**; dziś RAIDZ1 z 5 HDD, data zmiany **[nieznane]** | dziś | nie dotyczy | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| Samba | 2024-01-01 skrypt **[commit `386f12a`, 2024-01-01]**; compose 2024-07-14 **[commit `7198b20`, 2024-07-14]** | 2025-02-12 **[commit `c8dccdd`, 2025-02-12]** | copyparty (gałąź 2026-02-01, na `main` od 2026-02-26) | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| Duplicati | 2024-01-15 **[commit `8f3e37d`, 2024-01-15]** | 2024-02-26 **[commit `06b7e79`, 2024-02-26]** | nic do 2026-02; potem BorgBackup | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| Immich | 2024-01-15 **[commit `8f3e37d`, 2024-01-15]**; ponownie gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26) | pierwszy epizod do 2024-02-26 **[commit `06b7e79`, 2024-02-26]**; drugi trwa | nie dotyczy | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| AdGuard Home | compose 2024-01-15 **[commit `ba47ea5`, 2024-01-15]**; plik konfiguracji 2024-02-21 **[commit `775a8a8`, 2024-02-21]**; k3s 2025-08-11 **[commit `abcb648`, 2025-08-11]**; obecny klaster gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26) | dziś (konfiguracja w Terraformie od gałęzi 2026-02-25 **[commit `81c3675`, 2026-02-25]**) | nie dotyczy | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| Home Assistant w kontenerze | 2024-02-25 **[commit `acfb3af`, 2024-02-25]**; krótko w k3s od 2025-08-11 **[commit `abcb648`, 2025-08-11]** | 2025-08-15 **[commit `929e6b4`, 2025-08-15]** | VM na Proxmoxie (data **[nieznane]**) | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| Traefik | 2024-01-01 (najpewniej sprzed repo) **[commit `386f12a`, 2024-01-01]**, **[wniosek]**; wbudowany w k3s 2025-08-31 **[commit `7ce4d94`, 2025-08-31]**; własny Deployment gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26); chart Helm gałąź 2026-02-25 **[commit `edebb5c`, 2026-02-25]** (na `main` od 2026-02-26) | dziś | nie dotyczy | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| whoami (usługa testowa) | 2024-01-15 **[commit `370fea4`, 2024-01-15]**; w k8s gałąź 2026-02-01 **[commit `fa77451`, 2026-02-01]** (na `main` od 2026-02-26) | 2026-08-20 **[commit `7158f21`, 2026-08-20]** | brak | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| Devcontainer | 2024-02-08 **[commit `44e2ac5`, 2024-02-08]** | dziś (katalog nadal jest) | nie dotyczy (w praktyce środowisko dają Nix flake, potem mise **[wniosek]**) | [t02](technologie/02-iac-gitops-ci.md) |
| Dependabot | 2024-02-08, tylko devcontainers **[commit `44e2ac5`, 2024-02-08]** | konfiguracja 2026-04-06 **[commit `bd423ac`, 2026-04-06]**, **[PR #311]**; pojedyncze PR bezpieczeństwa do 2026-08-19 **[commit `a301ec4`, 2026-08-19]** | Renovate | [t02](technologie/02-iac-gitops-ci.md) |
| GitHub Actions | 2024-07-14 **[commit `9de8f42`, 2024-07-14]** | dziś | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| Wdrożenie compose z GitHub Actions (push) | 2024-07-14 **[commit `9de8f42`, 2024-07-14]** | 2025-07-26 **[commit `fc8269f`, 2025-07-26]** | Terraform/Ansible z CI, potem `kubectl apply` | [t02](technologie/02-iac-gitops-ci.md) |
| Renovate | 2024-07-17 **[commit `5b2f015`, 2024-07-17]** | dziś (`renovate.json5` od 2026-05-03 **[commit `615d950`, 2026-05-03]**) | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| CrowdSec (compose) | 2024-07-18 **[commit `ac3087c`, 2024-07-18]** | 2025-08-15, wypada z manifestów **[commit `328dddf`, 2025-08-15]** | brak do 2026-02 | [h03](historia/03-iac-i-pierwszy-kubernetes.md) |
| CrowdSec (Kubernetes) | gałąź 2026-02-01, bez agenta **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26); wtyczka bouncera zadeklarowana 2026-02-01, działa od 2026-02-19, gdy zniknął stary forward-auth **[commit `37f4e5e`, 2026-02-19]**; z agentem od 2026-07-24 **[commit `b0099ce`, 2026-07-24]** | dziś | nie dotyczy | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| FlareSolverr | 2024-01-15 **[commit `ba47ea5`, 2024-01-15]** | 2024-07-25 **[commit `6c0c661`, 2024-07-25]** | Byparr | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| Byparr | 2024-07-25 **[commit `6c0c661`, 2024-07-25]**; w k8s gałąź 2026-02-24 **[commit `16fdd8f`, 2026-02-24]** (na `main` od 2026-02-26) | dziś | nie dotyczy | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| Postfix z relay Gmail | 2024-07-14 **[commit `7198b20`, 2024-07-14]** | gałąź 2026-02-24 **[commit `16fdd8f`, 2026-02-24]** (na `main` od 2026-02-26) | Postfix z relay OCI Email Delivery | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| PufferPanel / serwery gier | PufferPanel 2024-01-15 (jeden dzień) **[commit `8f3e37d`, 2024-01-15]** i 2024-07-29 **[commit `7b922cd`, 2024-07-29]**; FTB Skies Expert 2024-02-26 **[commit `06b7e79`, 2024-02-26]**; DawnCraft 2024-08-14 **[commit `6461946`, 2024-08-14]** | 2025-02-12 **[commit `c8dccdd`, 2025-02-12]** | brak | [h02](historia/02-rozwoj-compose.md) |
| Authentik (compose) | 2025-02-12 **[commit `c8dccdd`, 2025-02-12]** | 2025-09-01 **[commit `28fbc9e`, 2025-09-01]** | brak uwierzytelniania na IngressRoute do 2026-02 | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| HAProxy na Oracle VPS | 2025-03-13 **[commit `0fa08ec`, 2025-03-13]** | 2026-08-20 **[commit `7158f21`, 2026-08-20]** | przekierowanie portów routera + cloudflare-ddns | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| Proxmox VE | najpóźniej 2025-03-13 według README **[commit `84ea802`, 2025-03-13]**; w kodzie od 2025-07-26 **[commit `6930efc`, 2025-07-26]** | dziś | nie dotyczy | [t01](technologie/01-platforma-i-orkiestracja.md) |
| Terraform | 2025-07-26 **[commit `6930efc`, 2025-07-26]**; kod z E3 zastąpiony nowym przy merge'u 2026-02-26 **[commit `327eff3`, 2026-02-26]** (2026-02-01 **[commit `b8daa33`, 2026-02-01]** zmienił tylko workflowy) | dziś | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| OpenTofu (dwa epizody) | 2025-07-26 15:27 **[commit `6930efc`, 2025-07-26]**; gałąź 2026-02-01 17:40 **[commit `afad10b`, 2026-02-01]** (na `main` tylko w historii merge'a 2026-02-26) | 2025-07-26 15:40 **[commit `75e604b`, 2025-07-26]**; 2026-02-01 23:36 **[commit `06e540f`, 2026-02-01]** | Terraform | [t02](technologie/02-iac-gitops-ci.md) |
| Ansible | 2025-07-26 **[commit `162b32c`, 2025-07-26]** | dziś | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| uv | 2025-07-26 **[commit `7a357aa`, 2025-07-26]** | dziś | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| act | 2025-07-31 **[commit `7b3ce98`, 2025-07-31]** | 2026-02-17 **[commit `d294d1c`, 2026-02-17]** | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| LXC `nickel` + k3s | LXC 2025-07-26 **[commit `6930efc`, 2025-07-26]**; k3s 2025-08-02 **[commit `5765311`, 2025-08-02]** | gałąź 2025-12-17 **[commit `bc91666`, 2025-12-17]**; na `main` do 2026-02-26 **[commit `327eff3`, 2026-02-26]** | Talos w VM | [t01](technologie/01-platforma-i-orkiestracja.md) |
| kompose | 2025-08-11 **[commit `abcb648`, 2025-08-11]** | 2025-08-13 **[commit `f2082c1`, 2025-08-13]** | ręczne manifesty | [t01](technologie/01-platforma-i-orkiestracja.md) |
| Kustomize + Helm | 2025-09-12, `kubectl kustomize --enable-helm` w CI **[commit `06ecf16`, 2025-09-12]**; charty Helm zamiast surowych manifestów gałąź 2026-02-24 **[commit `b4e151c`, 2026-02-24]** (na `main` od 2026-02-26) | dziś | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| NVIDIA (sterownik w LXC + device plugin) | 2025-08-15 **[commit `02cbf60`, 2025-08-15]**; plugin 2025-08-16 **[commit `1b4af72`, 2025-08-16]** | gałąź 2025-12-17 **[commit `bc91666`, 2025-12-17]**; ostatnia aktualizacja na main 2026-01-23 **[commit `dafd355`, 2026-01-23]**; na `main` do 2026-02-26 **[commit `327eff3`, 2026-02-26]** | Intel Arc B580 z pluginem Intel GPU + NFD | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| `kubectl apply` z CI (push) | 2025-09-12 **[commit `06ecf16`, 2025-09-12]** | na `main` do 2026-02-26 **[commit `327eff3`, 2026-02-26]** | ArgoCD (pull) | [t02](technologie/02-iac-gitops-ci.md) |
| Talos Linux | gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26 **[commit `327eff3`, 2026-02-26]**) | dziś | nie dotyczy | [t01](technologie/01-platforma-i-orkiestracja.md) |
| ArgoCD (app-of-apps) | gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26 **[commit `327eff3`, 2026-02-26]**) | dziś | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| Longhorn | gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26 **[commit `327eff3`, 2026-02-26]**) | dziś | nie dotyczy | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| MetalLB | gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26 **[commit `327eff3`, 2026-02-26]**) | dziś | nie dotyczy | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| External Secrets + Bitwarden SM | gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26 **[commit `327eff3`, 2026-02-26]**) | dziś | nie dotyczy (zastąpiło sekrety w plikach `.env` i w GPG/artefaktach CI) | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| Reloader | gałąź 2026-01-27 **[commit `d0ae5b1`, 2026-01-27]** (na `main` od 2026-02-26 **[commit `327eff3`, 2026-02-26]**) | dziś | nie dotyczy | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| ClamAV | gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26); wcześniej, 2025-12-26, tylko wpis w planie migracji **[commit `9b06965`, 2025-12-26]** | 2026-06-21 **[commit `d65d546`, 2026-06-21]** | brak | [h04](historia/04-przebudowa-gitops.md) |
| oauth2-proxy | gałąź 2026-02-01 **[commit `fdd5bf3`, 2026-02-01]** (na `main` tylko w historii merge'a 2026-02-26) | gałąź 2026-02-20 **[commit `0242d78`, 2026-02-20]** (na `main` tylko w historii merge'a 2026-02-26) | Authentik | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| Middleware `private-chain` i `tailscale-only` | gałąź 2026-02-01 **[commit `fe05e6c`, 2026-02-01]** (na `main` od 2026-02-26) | 2026-08-21 **[commit `cf4cbd6`, 2026-08-21]** | `public-chain` + Authentik | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md) |
| Authentik (Kubernetes) | gałąź 2026-02-20 **[commit `e2a3a1b`, 2026-02-20]** (na `main` od 2026-02-26 **[commit `327eff3`, 2026-02-26]**) | dziś | nie dotyczy | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| nfs-csi | gałąź 2026-02-16 **[commit `6cba788`, 2026-02-16]** (na `main` tylko w historii merge'a 2026-02-26) | gałąź 2026-02-20 **[commit `a338df4`, 2026-02-20]** (na `main` tylko w historii merge'a 2026-02-26) | statyczne PV/PVC NFS | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| kube-api-lb | gałąź 2026-02-16 **[commit `6cba788`, 2026-02-16]** (na `main` tylko w historii merge'a 2026-02-26) | gałąź 2026-02-18 **[commit `066701e`, 2026-02-18]** (na `main` tylko w historii merge'a 2026-02-26) | VIP Talosa | [h04](historia/04-przebudowa-gitops.md) |
| `Terraform/apps` | gałąź 2026-02-16 **[commit `7a30c5b`, 2026-02-16]** (na `main` od 2026-02-26); stan w OCI od 2026-06-23 **[commit `eefc9d7`, 2026-06-23]** | dziś | nie dotyczy (zastąpiło skrypty konfiguracyjne i statyczne pliki konfiguracji) | [t02](technologie/02-iac-gitops-ci.md) |
| Stos obserwowalności (Grafana, Loki, Mimir, Alloy) | gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26 **[commit `327eff3`, 2026-02-26]**) | dziś | nie dotyczy | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| copyparty | gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26 **[commit `327eff3`, 2026-02-26]**) | dziś | nie dotyczy (zastąpiło Sambę **[wniosek]**) | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| copyparty-dav (WebDAV przez tailnet) | 2026-08-20 **[commit `3cdfd9b`, 2026-08-20]** | 2026-09-03 **[commit `6e9a4c5`, 2026-09-03]** | brak | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| Jellyseerr | compose 2024-01-15 **[commit `ba47ea5`, 2024-01-15]** | obraz Seerr gałąź 2026-02-19 **[commit `b9f0bfe`, 2026-02-19]** (na `main` od 2026-02-26), przemianowanie 2026-02-26 **[commit `6911d9a`, 2026-02-26]** (na `main` od 2026-02-26) | Seerr | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| homepage (strona `nerine.dev`) | w k8s gałąź 2026-02-19 **[commit `1d273cf`, 2026-02-19]** (na `main` od 2026-02-26); epizody w compose opisuje t05 **[plik `technologie/05-aplikacje-i-repatriacja.md`]** | 2026-08-21 **[commit `3fce217`, 2026-08-21]** | biblioteka aplikacji Authentika | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| mcpjungle | gałąź 2026-02-01 **[commit `6757719`, 2026-02-01]** (na `main` od 2026-02-26) | 2026-08-19 **[commit `096bd7e`, 2026-08-19]** | brak | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| Nadpisanie CoreDNS | gałąź 2026-02-24 **[commit `197d3cf`, 2026-02-24]** (na `main` od 2026-02-26) | 2026-05-14 **[commit `e42d919`, 2026-05-14]** | `hostAliases` w podzie | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| BorgBackup → Hetzner Storage Box | gałąź 2026-02-24 **[commit `16fdd8f`, 2026-02-24]** (na `main` od 2026-02-26) | dziś | nie dotyczy | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| pre-commit | gałąź 2026-02-24 **[commit `067462b`, 2026-02-24]** (na `main` od 2026-02-26) | dziś | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| Nix flake + direnv | 2026-03-01 **[commit `3b8be01`, 2026-03-01]** | 2026-05-03 **[commit `80cebb2`, 2026-05-03]** | mise | [t02](technologie/02-iac-gitops-ci.md) |
| mise | 2026-05-03 **[commit `80cebb2`, 2026-05-03]** | dziś | nie dotyczy | [t02](technologie/02-iac-gitops-ci.md) |
| MinIO | 2026-06-03 **[commit `145f097`, 2026-06-03]** | 2026-06-03 **[commit `59a11a8`, 2026-06-03]** | BorgBackup | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| hd-idle | 2026-06-14 **[commit `55389fa`, 2026-06-14]** | dziś | nie dotyczy | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| descheduler | 2026-06-27 **[commit `1fffc31`, 2026-06-27]** | dziś | nie dotyczy | [t01](technologie/01-platforma-i-orkiestracja.md) |
| NetworkPolicy egzekwowane (kube-network-policies) | 2026-08-19 **[commit `930e1e8`, 2026-08-19]** | dziś | nie dotyczy (wcześniej polityki istniały, ale Flannel je ignorował) | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| cloudflare-ddns | 2026-08-21 **[commit `5d7f26e`, 2026-08-21]** | dziś | nie dotyczy | [t03](technologie/03-siec-i-bezpieczenstwo.md) |
| HTTP/3 na Traefiku | 2026-08-20 **[PR #567]** | 2026-10-06 **[commit `6deeeaf`, 2026-10-06]** | HTTP/2 | [h05](historia/05-publiczne-wystawienie-i-stan-obecny.md) |
| mergerfs (pula pobierania NVMe + HDD) | 2026-09-01 **[commit `0bdd584`, 2026-09-01]** | dziś | nie dotyczy (zastąpiło pobieranie wprost na HDD) | [t04](technologie/04-dane-kopie-sekrety-monitoring.md) |
| byparr-proxy | 2026-08-08 **[commit `7855699`, 2026-08-08]** | 2026-11-05 **[commit `c854fe2`, 2026-11-05]** | natywne proxy FlareSolverr w Prowlarrze | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| scanservjs | w compose, powrót 2025-03-05 **[commit `52aafff`, 2025-03-05]** | 2025-09-01, koniec compose **[commit `28fbc9e`, 2025-09-01]**, **[wniosek]** | Pagewire 2026-11-25 **[commit `e3857f4`, 2026-11-25]** | [t05](technologie/05-aplikacje-i-repatriacja.md) |
| Pagewire | 2026-11-25 **[commit `e3857f4`, 2026-11-25]** | dziś | nie dotyczy | [t05](technologie/05-aplikacje-i-repatriacja.md) |

## Sprzęt w czasie

| Data | Co mówi źródło | Dowód | Uwagi |
| --- | --- | --- | --- |
| przed 2024-01 | Brak danych o sprzęcie | **[nieznane]** | |
| 2024-01-14 | Host domowy z co najmniej czterema dyskami (RAID10), `/dev/dri` (iGPU Intel) dla Jellyfina; model, CPU i RAM nieznane | **[commit `814bff1`, 2024-01-14]** | |
| 2024-03-26 | ZFS: dwa mirrory na czterech dyskach | **[commit `d68bcf6`, 2024-03-26]** | Dziś RAIDZ1 z pięciu HDD; kiedy pulę przebudowano: **[nieznane]** |
| 2025-03-13 | README: Intel Core i5-12600K, 32 GB DDR4, 1 TB NVMe + 5 × 3 TB HDD, iGPU UHD 770, Proxmox VE 8, Docker w VM. VPS Oracle: Ampere A1, 4 rdzenie, 20 GB RAM, Ubuntu 24.04 | **[commit `84ea802`, 2025-03-13]** | Tabela z tego commita przetrwała w README do dziś |
| 2025-07-26 | Terraform: VPS `argon` VM.Standard.A1.Flex 4 OCPU / 24 GB / 200 GB; LXC `nickel` 16 GB RAM | **[commit `6930efc`, 2025-07-26]** | VPS: 20 GB w README wobec 24 GB w Terraformie |
| 2025-07-27 → 2025-08-15 | W hoście karta NVIDIA (sterownik 580.76.05, `/dev/nvidia*` do LXC, time-slicing); LXC 24000 MB RAM | **[commit `02cbf60`, 2025-08-15]** | Model karty: **[nieznane]** |
| 2025-12-17 | Plan migracji: MSI MS-7C37, AMD Ryzen 9 3950X (16C/32T), 62,71 GiB RAM (64 GB DDR4), Intel Arc B580; węzły po 8 vCPU / 16 GiB | **[commit `bc91666`, 2025-12-17]** | Sprzeczne z README (i5-12600K / 32 GB). Kontrolery FCH z `AGENTS.md` też wskazują na płytę AMD **[wniosek]** |
| 2026-02-01 (gałąź, na `main` od 2026-02-26) | Arc B580 przekazany do `talos-1`; README zmienia GPU na B580, CPU i RAM zostają bez zmian. Oracle: `oracle-proxy` 1 OCPU / 6 GB / 50 GB i `oracle-compute` 3 OCPU / 18 GB / 150 GB; węzły 16/16/16 GiB | **[commit `6757719`, 2026-02-01]** | |
| 2026-02-16 → 2026-07-05 | RAM węzłów (`talos-1/2/3`, GiB): 8/8/8 (02-16), 16/12/12 (02-28), 10/8/8 (04-14), 10/12/12 i vCPU `talos-2/3` 4 → 6 (06-19), 16/8/8 (06-24), 16/12/8 (07-05) | **[commit `7a30c5b`, 2026-02-16]**, **[commit `d63f6af`, 2026-02-28]**, **[commit `81d2c97`, 2026-04-14]**, **[commit `c664dd4`, 2026-06-19]**, **[commit `7707c14`, 2026-06-24]**, **[commit `b1ea7f9`, 2026-07-05]** | |
| 2026-05-19 | Osobny dysk danych Longhorna na każdym węźle, `data_disk_size = 120` (źródła piszą raz GB, raz GiB) | **[commit `94d70a4`, 2026-05-19]** | |
| 2026-06-14 → 2026-06-18 | Specyfikacja oszczędzania prądu: Ryzen 9 3950X (105 W), 64 GB DDR4, 5 × 3 TB HDD 7200 rpm w RAIDZ1, 2 × 1 TB NVMe w mirrorze (`rpool`), Proxmox VE 9.2.3, dwie karty Realtek | **[commit `4367315`, 2026-06-18]** | Pliki usunięte z repo 2026-08-13 **[commit `c3bd45f`, 2026-08-13]** |
| 2026-06-15 | Oracle tnie limit Always Free A1 z 4 OCPU / 24 GB do 2 OCPU / 12 GB | **[źródło: https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm, dostęp 2026-11-27]**; datę zmiany podają InfoQ i Linuxiac, cytowane w `technologie/01-platforma-i-orkiestracja.md` | Kłóci się z VM 4 OCPU / 24 GB z 2026-08-20 |
| 2026-07-20 | Wyłączony boost CPU, ARC ZFS ograniczony do 4 GiB | **[commit `aeca5da`, 2026-07-20]** | |
| 2026-07-27 | Firmware Arc B580 21.1137 → 21.1182 (LVFS) | **[commit `711d818`, 2026-07-27]** | Wpis siedzi w commicie o CrowdSecu |
| 2026-08-19 | `talos-3` 8 → 12 GiB (stan: 16/12/12) | **[commit `1727f68`, 2026-08-19]** | |
| 2026-08-20 | Oracle: `oracle-proxy` (1/6) usunięta, `compute` 3 OCPU / 18 GB → 4 OCPU / 24 GB / 150 GB („the whole allowance”) | **[commit `7158f21`, 2026-08-20]**, **[PR #567]** | Zob. wiersz 2026-06-15 |
| 2026-08-31 | Dodany dysk NVMe 238 GiB (pula `ssdstage`); grupy IOMMU przenumerowane | **[commit `c939f49`, 2026-08-31]**, **[commit `b4744b4`, 2026-08-31]** | |
| 2026-09-22 | Router to Mercusys (`CN=mwlogin.net`), nie Orange Funbox; pula DHCP `.180-.253` | **[commit `ef00f2c`, 2026-09-22]**, **[commit `67466a5`, 2026-09-22]** | |
| 2026-11-25 | Drukarka Samsung SCX-4300 (USB `04e8:342e`) przekazana do `talos-2` | **[commit `e3857f4`, 2026-11-25]** | |
| 2026-11-27 (stan `main`) | `Terraform/variables.tf`: `talos-1` 4 vCPU / 16 GiB (GPU), `talos-2` i `talos-3` po 6 vCPU / 12 GiB, razem 16 vCPU i 40 GiB. README: nadal i5-12600K, 32 GB i węzły 3 × 8 vCPU / 16 GB | **[plik `Terraform/variables.tf`]**, **[plik `README.md`]** | Same VM Talosa (40 GiB) i ARC (4 GiB) przekraczają 32 GB z README, więc README jest nieaktualne **[wniosek]** |

Najważniejsze sprzeczności w danych o sprzęcie:

- CPU i RAM: README (od 2025-03-13) podaje i5-12600K / 32 GB, plan migracji (2025-12-17) i specyfikacja energii (2026-06) podają Ryzen 9 3950X / 64 GB. Git wspiera drugą wersję jako stan od co najmniej 2025-12: nowsze źródła są z odczytu sprzętu, a obecny przydział RAM nie mieści się w 32 GB **[wniosek]**. Czy i5-12600K był kiedyś w serwerze (wymiana płyty między 2025-03 a 2025-12?), wie tylko autor **[nieznane]**.
- GPU: iGPU Intel (2024, UHD 770 według README) → karta NVIDIA (2025-07 → 2025-12, model nieznany) → Arc B580 (gałąź 2026-02-01, na `main` od 2026-02-26).
- Oracle: README 2025-03 „4 rdzenie / 20 GB”; Terraform 2025-07 „4 OCPU / 24 GB / 200 GB”; 2026-02 dwie VM 1/6 + 3/18; 2026-08-20 jedna VM 4/24/150, choć od 2026-06-15 limit Always Free według Oracle to 2 OCPU / 12 GB.

## Wykres aktywności

Commity na `main` według miesiąca (data autora w UTC; w strefie autora inaczej wychodzą tylko czerwiec i lipiec 2026: 105 i 106). „Boty” to `renovate[bot]`, `dependabot[bot]` i `copilot-swe-agent[bot]`. Od kwietnia do czerwca 2024 nie ma ani jednego commita.

| Miesiąc | Razem | Boty | Ludzie | First-parent | Co się działo |
| --- | ---: | ---: | ---: | ---: | --- |
| 2024-01 | 151 | 0 | 151 | 150 | Start repo; 54 commity 2024-01-15 (52 w UTC) (WireGuard, iptables, pierwsze compose) |
| 2024-02 | 46 | 0 | 46 | 36 | AdGuard, Home Assistant, restrukturyzacja DMZ |
| 2024-03 | 2 | 0 | 2 | 2 | ZFS zamiast RAID10, koniec E1 |
| 2024-04 → 2024-06 | 0 | 0 | 0 | 0 | Cisza |
| 2024-07 | 97 | 5 | 92 | 93 | Przebudowa compose, CI, Renovate, CrowdSec |
| 2024-08 | 25 | 6 | 19 | 23 | |
| 2024-09 | 9 | 8 | 1 | 9 | |
| 2024-10 | 18 | 13 | 5 | 17 | |
| 2024-11 | 11 | 8 | 3 | 11 | |
| 2024-12 | 19 | 13 | 6 | 17 | |
| 2025-01 | 11 | 10 | 1 | 11 | |
| 2025-02 | 14 | 4 | 10 | 14 | Authentik zamiast Authelii |
| 2025-03 | 29 | 12 | 17 | 28 | HAProxy na VPS, nowe README |
| 2025-04 | 14 | 10 | 4 | 14 | |
| 2025-05 | 21 | 11 | 10 | 20 | |
| 2025-06 | 15 | 11 | 4 | 15 | |
| 2025-07 | 93 | 9 | 84 | 93 | Terraform, Ansible, CI (86 commitów od 2025-07-26) |
| 2025-08 | 160 | 5 | 155 | 158 | k3s, kompose, NVIDIA w LXC |
| 2025-09 | 41 | 9 | 32 | 39 | Koniec compose, CI z `kubectl apply` |
| 2025-10 | 27 | 18 | 9 | 20 | |
| 2025-11 | 13 | 13 | 0 | 13 | Tylko Renovate |
| 2025-12 | 17 | 10 | 7 | 12 | Start gałęzi migracyjnej (5 commitów na gałęzi) |
| 2026-01 | 13 | 12 | 1 | 12 | |
| 2026-02 | 296 | 21 | 275 | 150 | Migracja i merge (137 commitów z gałęzi, 92 commity 2026-02-26, 98 w UTC) |
| 2026-03 | 106 | 30 | 76 | 103 | Nix flake, poprawki po migracji |
| 2026-04 | 87 | 50 | 37 | 79 | |
| 2026-05 | 112 | 55 | 57 | 109 | mise, auto-apply w CI |
| 2026-06 | 112 | 37 | 75 | 111 | Oszczędzanie prądu, pętla restartów `talos-1` |
| 2026-07 | 99 | 58 | 41 | 99 | CrowdSec na Helm |
| 2026-08 | 199 | 67 | 132 | 189 | Wystawienie publiczne, NetworkPolicy, przegląd bezpieczeństwa |
| 2026-09 | 154 | 71 | 83 | 154 | Pula pobierania, incydent `talos-3`, ZFS a etcd |
| 2026-10 | 101 | 77 | 24 | 101 | |
| 2026-11 | 63 | 26 | 37 | 63 | clips-sftp, c-oop, Pagewire (do 2026-11-27) |

Źródło wszystkich liczb: **[wniosek: `TZ=UTC git log main --format='%ad|%an' --date=format-local:%Y-%m` i to samo z `--first-parent`]**.

## Pytania do autora

1. Jaki sprzęt (CPU, RAM, płyta) miał serwer w 2024 roku i czy i5-12600K z README był kiedykolwiek w `carbon`?
2. Kiedy i dlaczego wymieniono platformę na Ryzen 9 3950X / 64 GB?
3. Jaką kartę NVIDIA miał serwer w 2025 roku i kiedy zastąpił ją Arc B580?
4. Kiedy serwer przeszedł z instalacji bez hypervisora na Proxmoxa (między 2024-03 a 2025-03)?
5. Kiedy pula ZFS zmieniła się z dwóch mirrorów na czterech dyskach w RAIDZ1 z pięciu dysków?
6. Czy klaster Talosa działał przed merge'em z 2026-02-26 (gałąź od 2026-02-01), czy wdrożono go dopiero po merge'u?
7. Czym był kierowany ruch publiczny do domu między 2024-07 (koniec WireGuarda w repo) a 2025-03-13 (HAProxy w repo)?
8. Kiedy Home Assistant przeniósł się do osobnej VM?
9. Kiedy dokładnie zdarzyła się utrata danych po odtworzeniu app-of-apps (przed 2026-03-07)?
10. Czy przez cztery miesiące przerwy (2024-03-27 → 2024-07-13) serwer działał bez zmian, czy zmiany szły poza repo?

## Do której części pracy

- Wstęp i „Projekt”: tabela okresów jako streszczenie ewolucji.
- „Implementacja”: kamienie milowe i tabela technologii (co, kiedy, czym zastąpione).
- „Technologie”: kolumna „zastąpione przez” jako punkt wyjścia do porównań alternatyw.
- „Odtwarzanie po awarii”: incydenty z kamieni milowych (2026-02-27, 2026-06-19, 2026-08-19, 2026-08-31, 2026-09-21, 2026-10-02).
- „Analiza kosztów”: sekcja o sprzęcie (moc, Oracle Always Free) i wykres aktywności jako miara nakładu pracy.

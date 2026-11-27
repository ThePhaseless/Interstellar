# E4: przebudowa na Talos i GitOps (2026-02-01 → 2026-07-31)

## Streszczenie

W E4 homelab przeszedł z K3s w kontenerach LXC na Proxmoxie na trzywęzłowy klaster TalosOS w maszynach wirtualnych. Całym klastrem steruje jedna aplikacja ArgoCD, która renderuje drzewo Kustomize z gałęzi `main`. Przebudowa była przygotowywana na osobnej gałęzi od 2025-12-17, w jednym dużym commicie trafiła na nią 2026-02-01, a z `main` została scalona 2026-02-26. Potem przyszło pięć miesięcy poprawek: zmiany w składowaniu (Longhorn i NFS), w uwierzytelnianiu (oauth2-proxy zastąpiony przez Authentik), w sekretach (Bitwarden SM i ESO) i w CI (Terraform stosowany automatycznie na `main`), do tego seria incydentów, z których wzięła się większość wpisów „Key Gotchas”.

Liczby okresu według daty autora w UTC, tak jak w `historia/05-publiczne-wystawienie-i-stan-obecny.md` (`TZ=UTC git log main --format=%ad --date=short-local`, daty 2026-02-01 do 2026-07-31). Liczone w czasie warszawskim wychodzi 811, bo `cb3847a` (2026-07-31 22:48 UTC) wypada wtedy już 2026-08-01, a 7 commitów z 2026-06-30 po 23:00 UTC przechodzi do lipca:

| Miesiąc | Commity |
| ------- | ------: |
| 2026-02 | 296 |
| 2026-03 | 106 |
| 2026-04 | 87 |
| 2026-05 | 112 |
| 2026-06 | 112 |
| 2026-07 | 99 |
| razem | 812 |

246 commitów to `renovate[bot]`, 3 to `copilot-swe-agent[bot]`, 2 to `dependabot[bot]`. Pozostałe 561 to commity ludzkie pod dwiema tożsamościami git (537 i 24); [wniosek] obie należą do autora.


## 1. Stan na początku E4

- Klaster: K3s. Terraform (`Terraform/deployment.tf`) generował `random_password.k3s_token` i inwentarz Ansible z grupą `k3s_cluster`, a playbook `Ansible/k3s.yaml` instalował klaster **[commit `f50bd66`, 2026-01-30]**. Plan migracji opisuje stan wyjściowy jako „K3s running on Proxmox LXC containers” i „Manual configuration and deployments” **[plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w commicie `bc91666`, 2025-12-17]**.
- Manifesty: `Kubernetes/{home,infrastructure,media,utilities,test}`. W `infrastructure` były m.in. `traefik`, `nvidia-device-plugin`, `postfix` i `whoami` **[commit `f50bd66`]**. Nie było ArgoCD.
- Wejście z internetu: VPS w Oracle Cloud z HAProxy (`compose.proxy.yaml`, `haproxy.cfg`) przez Tailscale do serwera domowego. README opisuje to jako obejście braku publicznego IP od ISP **[plik `README.md` w `f50bd66`]**. README jest tu jednak nieaktualny: security list OCI w tym samym commicie ma port 443 zakomentowany i otwiera tylko SSH, 41641/UDP i 51820/UDP **[plik `Terraform/variables.tf` w `f50bd66`]**, a porty 80/443 wracają dopiero z gałęzią migracyjną (`6757719`, na `main` od 2026-02-26, `327eff3`). Czy VPS był wtedy faktycznie osiągalny z internetu, repo nie pokazuje; zob. `historia/03-iac-i-pierwszy-kubernetes.md` (wniosek o dostępie tylko przez Tailscale i LAN) **[wniosek]**.
- Sprzęt (źródła są sprzeczne): README z `f50bd66` podaje i5-12600K, 32 GB RAM i iGPU UHD 770. Plan migracji podaje dla tego samego hosta Ryzen 9 3950X, około 63 GiB RAM i Intel Arc B580 **[plik planu, `bc91666`]**. Tego nie rozstrzygam; patrz pytania.

## 2. Oś czasu przebudowy (trzy daty)

| Data | Zdarzenie | Dowód |
| ---- | --------- | ----- |
| 2025-12-15 | Punkt rozgałęzienia gałęzi migracyjnej (merge-base) | [commit `827e399`, 2025-12-15] |
| 2025-12-17 | „prepare for migration”: plan K3s → TalosOS (2810 linii) oraz usunięcie starych workflowów (`kubernetes.yaml`, `nvidia.yaml`, `proxy.yaml`, `maintenance.yaml`) i ról Ansible dla K3s/NVIDIA | [commit `bc91666`, 2025-12-17] |
| 2025-12-26 | ClamAV dopisany do planu | [commit `9b06965`, 2025-12-26] |
| 2026-01-27 | Ostatnia wersja planu (1144 linie) | [commit `d0ae5b1`, 2026-01-27] |
| 2026-02-01 | Na gałęzi: jeden commit „migrate” (262 pliki, +8295/−2755) z całym `Kubernetes/bootstrap`, `Kubernetes/apps`, `Terraform/talos.tf`, `Tailscale/policy.hujson` | [commit `6757719`, 2026-02-01] |
| 2026-02-01 | Na gałęzi: plan usunięty, zamiast niego „setup plan” (`SETUP.md`) | [commit `e050353`, 2026-02-01] |
| 2026-02-01 | Na `main`: workflow `terraform-destroy.yaml` („Plan Terraform Destroy (Excluding Proxmox)”), potem „remove proxmox from state”, „delete state after destroy” | [commit `b8daa33`, 2026-02-01], [commit `7bc377a`, 2026-02-01], [commit `0310f10`, 2026-02-01] |
| 2026-02-01 | Na gałęzi: przejście na OpenTofu o 17:40 i powrót do Terraform o 23:36 tego samego dnia | [commit `afad10b`, 2026-02-01], [commit `06e540f`, 2026-02-01] |
| 2026-02-16 | `app-of-apps` przestawione z `path: Kubernetes/talos` na `path: Kubernetes`; pojawia się `Terraform/apps` | [commit `6cba788`, 2026-02-16], [commit `7a30c5b`, 2026-02-16] |
| 2026-02-26 | Scalenie gałęzi z `main` (364 pliki, +17858/−3760) | [commit `327eff3`, 2026-02-26] |

Kiedy dokładnie nowy klaster zaczął obsługiwać ruch zamiast K3s, z repo nie wynika **[nieznane]**. Renovate obsługiwał w tym czasie obie gałęzie (`baseBranches` dla `main` i `migration`) **[commit `1d86508`, 2026-02-18]**, więc [wniosek] przez większość lutego działały równolegle dwie linie konfiguracji.

Sam plan nazwą i katalogiem (`.github/prompts/*.prompt.md`) przypomina plik promptu dla asystenta AI **[wniosek]**. Pasuje to do późniejszego stylu pracy (patrz rozdz. 7).

## 3. Co weszło w przebudowie

Wszystko poniżej pochodzi z commitu `6757719` (2026-02-01), chyba że zaznaczono inaczej. Daty w tej tabeli do 2026-02-26 to daty commitów na gałęzi migracyjnej; na `main` wszystko trafiło z `327eff3` (2026-02-26).

| Składnik | Rola w repo | Dalsze losy w E4 | Dowód |
| -------- | ----------- | ---------------- | ----- |
| TalosOS (`Terraform/talos.tf`) | 3 węzły control-plane + worker jako VM na Proxmoxie, obrazy z Image Factory (osobny schemat dla węzła GPU) | Talos v1.12.4 / K8s 1.35.0 → v1.13.4 / 1.36.2 | [commit `8dcd6e1`, 2026-02-16], [commit `7a54ac3`, 2026-06-12] |
| ArgoCD (`bootstrap/argocd`) | Jedna aplikacja `app-of-apps`: `path: Kubernetes`, `prune: true`, `selfHeal: true`, finalizer `resources-finalizer.argocd.argoproj.io` | Surowe manifesty → chart Helm 9.4.4; OIDC przez Authentik i wyłączony lokalny admin; `argocd/` wypadło z `bootstrap/kustomization.yaml` 2026-02-18 i wróciło 2026-06-23, więc przez cztery miesiące ArgoCD nie zarządzało samym sobą | [commit `b4e151c`, 2026-02-24], [commit `887009c`, 2026-02-25], [commit `9ed2824`, 2026-02-18], [commit `952e844`, 2026-06-23] |
| Longhorn | Bloki dla konfiguracji i baz aplikacji | Surowe manifesty → Helm 1.7.2 (02-24), potem 1.8.2 i 1.11.0 (02-26); `defaultReplicaCount: 2` i repliki 3 → 2 w `storageclass.yaml`, ale ten plik od 2026-02-25 (`9b810a8`) do 2026-08-19 (`81609a2`) nie był w żadnej kustomizacji, więc **[wniosek]** domyślna klasa `longhorn` z charta została przy 3 replikach; od 2026-05-19 osobny dysk danych | [commit `b4e151c`, 2026-02-24], [commit `2a4c717`, 2026-02-26], [commit `06093ff`, 2026-02-28], [commit `94d70a4`, 2026-05-19] |
| MetalLB | Adresy LoadBalancer (L2) | Bez zmian koncepcyjnych | [commit `6757719`] |
| Traefik w K8s | Ingress (`IngressRoute`), łańcuchy middleware | Surowe → Helm, `security-headers` w łańcuchach; certyfikat wildcard `*.nerine.dev` z Let's Encrypt: 02-18 na entrypoincie, od 02-19 znowu `certResolver: letsencrypt` w każdej trasie z domenami `nerine.dev` + `*.nerine.dev` (tak zostało na koniec E4, 20 plików) | [commit `edebb5c`, 2026-02-25], [commit `b85f139`, 2026-02-18], [commit `d42247e`, 2026-02-19] |
| tailscale-operator | Proxy do API K8s, usługi na tailnecie | Hostname'y bez prefiksów; grants `autogroup:admin` → `system:masters` | [commit `af6e6d7`, 2026-02-19], [commit `347fa09`, 2026-04-14] |
| External Secrets + Bitwarden SM | Sekrety z Bitwarden przez SDK server | API v1; token dla ESO tworzy Terraform; podział na `bitwarden-store` (ręczne) i `bitwarden-store-generated` (Terraform) | [commit `9ed2824`, 2026-02-18], [commit `c7e08a1`, 2026-02-18], [commit `0f79e5f`, 2026-02-25] |
| CrowdSec | LAPI (z `DISABLE_AGENT=true`) + bouncer jako plugin Traefika | Surowe manifesty → Helm 2026-07-24 (rozdz. 9C) | [plik `.github/MIGRATION-CROWDSEC.md` w `6757719`], [commit `b0099ce`, 2026-07-24] |
| Observability | Grafana, Loki, Mimir, Promtail, Alloy | Dashboardy, kube-state-metrics, GeoIP; logi jądra Talosa do Loki | [commit `4491ce8`, 2026-02-19], [commit `70fb7b4`, 2026-06-21] |
| intel-gpu-operator | Plugin GPU dla Arc B580 | Operator → zwykły DaemonSet + NFD; zasób `i915` → `xe` | [commit `9d423ce`, 2026-02-18] |
| Reloader | Restart podów po zmianie sekretu/ConfigMapy | Surowe → Helm 2.2.8 | [commit `b4e151c`, 2026-02-24] |
| `Tailscale/policy.hujson` | ACL tailnetu jako kod | Workflow `tailscale-acl.yaml` → zasób `tailscale_acl` w Terraform | [commit `633f8f6`, 2026-02-26], [plik `Terraform/tailscale.tf` w `cb3847a`] |
| ClamAV | Skanowanie pobranych i publicznych plików (CronJoby) | Usunięty 2026-06-21 | [commit `d65d546`, 2026-06-21] |
| mcpjungle, whoami | Proxy MCP za Authentikiem; usługa testowa | Nadal obecne na koniec E4 (usunięte w E5) | [commit `6757719`, 2026-02-01] (mcpjungle; aplikacja proxy w Authentiku dopiero [commit `2b33dec`, 2026-02-24]), [commit `fa77451`, 2026-02-01] |

### Elementy dodane i zastąpione w trakcie E4

| Było | Zostało | Okres | Powód wg repo | Dowód |
| ---- | ------- | ----- | ------------- | ----- |
| `kube-api-lb` (Service + CronJob + PushSecret) | VIP Talosa `192.168.1.100` | 02-16 → 02-18 | „native OS-level failover” | [commit `066701e`, 2026-02-18] |
| `nfs-csi` (dynamiczne PVC) | 5 statycznych par PV/PVC (`media-pvc`, `downloads-pvc`, `personal-pvc`, `immich-upload`) | 02-16 → 02-20 | Commit nie podaje motywu. W tym samym commicie poprawiono montowanie Jellyfin („movies/tv/downloads instead of UUID dirs”); [wniosek] chodziło o stałe ścieżki na ZFS | [commit `a338df4`, 2026-02-20] |
| oauth2-proxy (Google OAuth) | Authentik (chart 2025.12.4, wbudowany outpost, forward-auth) | 02-01 → 02-20 | Motyw nie podany. Zaraz potem pojawiły się grupy `admins`, `watchers`, `writers` zamiast listy e-maili VIP; [wniosek] potrzebny był RBAC na grupach | [commit `fdd5bf3`, 2026-02-01], [commit `e2a3a1b`, 2026-02-20], [commit `0242d78`, 2026-02-20], [commit `e78ea0b`, 2026-02-25] |
| CronJob K8s → Bitwarden → Terraform (synchronizacja IP Tailscale) | data source `tailscale_devices` | → 02-18 | Krótszy łańcuch (opisany w commicie) | [commit `0586eed`, 2026-02-18] |
| Intel Device Plugins Operator | DaemonSet + NodeFeatureRule | → 02-18 | „removing the cert-manager dependency” | [commit `9d423ce`, 2026-02-18] |
| `fbonalair/traefik-crowdsec-bouncer` (forward-auth) | plugin `maxlerebourg/crowdsec-bouncer-traefik-plugin` | 2026-02-01 deklaracja wtyczki; middleware forward-auth do starego bouncera zostaje do 2026-02-19 (`37f4e5e`, „broken ForwardAuth”), więc wtyczka działa dopiero od tej daty | Dokument migracji: stary bouncer „unmaintained”, brak dodatkowego skoku sieciowego, tryb stream, oszczędność około 200 MB | [plik `.github/MIGRATION-CROWDSEC.md` w `6757719`] |
| Statyczny `AdGuardHome.yaml` + init container | provider Terraform `gmichels/adguard` | → 02-25 | Konfiguracja przeniesiona do Terraform | [commit `81c3675`, 2026-02-25] |
| Skrypt `configure-jellyfin.sh` (202 linie) | `Terraform/apps/jellyfin.tf`, provider `ThePhaseless/jellyfin` | 05-14; typowany provider 0.2.x 07-22 | Brak opisu | [commit `43f6a34`, 2026-05-14], [commit `d1b0605`, 2026-07-22] |
| MinIO jako cel kopii Longhorna | zostaje BorgBackup | 06-03 (dodane i wycofane tego samego dnia) | „chunk-level deduplication and zstd compression keep backup sizes small compared to Longhorn native snapshots, which store full volume data per backup” | [commit `145f097`, 2026-06-03], [commit `59a11a8`, 2026-06-03] |
| CrowdSec z surowych manifestów | chart Helm `crowdsec/crowdsec` | 07-24 | Agent był wyłączony, więc kolekcje się nie instalowały (rozdz. 9C) | [commit `b0099ce`, 2026-07-24] |

Provider `ThePhaseless/jellyfin` nosi nazwę konta GitHub repozytorium. [wniosek] Autor napisał go sam; trzeba to potwierdzić (pytania).

## 4. Terraform/apps: druga warstwa IaC

- Start 2026-02-16: `servarr.tf`, `grafana.tf`, `bitwarden.tf`, providery `devopsarr/sonarr`, `devopsarr/radarr`, `devopsarr/prowlarr` **[commit `7a30c5b`, 2026-02-16]**. Później doszły `authentik.tf` **[commit `bee6057`, 2026-02-20]**, AdGuard **[commit `81c3675`]** i Jellyfin **[commit `43f6a34`]**. Na koniec E4 pliki to `adguard.tf`, `authentik.tf`, `bitwarden.tf`, `jellyfin.tf`, `servarr.tf` i katalog `files/` (HTML/CSS brandingu Jellyfin, od 2026-06-02) **[commit `3ac16d9`, 2026-06-02]**.
- Po co osobny katalog [wniosek]: główny root Terraform tworzy infrastrukturę (VM, Talos, DNS, Tailscale, Bitwarden), a `Terraform/apps` konfiguruje aplikacje przez ich API. Do tego potrzebuje działającego klastra i port-forwardów (`scripts/port-forward-apps.sh`) **[commit `2254309`, 2026-02-24]**, dlatego nie może być w tym samym przebiegu co tworzenie klastra.
- Stan: najpierw backend `kubernetes` w sekrecie klastra (`Terraform/apps/README.md`), od 2026-06-23 backend OCI **[commit `eefc9d7`, 2026-06-23]**. README nadal opisywało backend Kubernetes na koniec E4 **[plik `Terraform/apps/README.md` w `cb3847a`]**, więc dokument był nieaktualny.
- Sekrety jako kod: `secrets.tf` z `random_password` → `bitwarden-secrets_secret` **[commit `d3f5333`, 2026-02-19]**; sekrety wpisywane ręcznie sprawdzane przez `postcondition` **[commit `f8ee188`, 2026-02-26]**.
- Nowa infrastruktura w głównym roocie (2026-02-24): OCI Email Delivery z rekordami SPF/DKIM/DMARC w Cloudflare (dla Postfixa) oraz Hetzner Storage Box BX11 jako cel BorgBackup, z kluczem SSH generowanym do Bitwarden **[commit `2b33dec`, 2026-02-24]**. Plan snapshotów Storage Boxa doszedł 2026-03-11 **[commit `51d2c72`, 2026-03-11]**.

## 5. Usługi pomocnicze z końca lutego

| Element | Data | Po co (wg repo) | Dowód |
| ------- | ---- | --------------- | ----- |
| `coredns-override` | 2026-02-24 | „in-cluster DNS queries for *.nerine.dev resolve to the internal Traefik LoadBalancer IP instead of the public IP, avoiding hairpin NAT issues”. W maju lekcja: dla pojedynczej usługi lepsze `hostAliases` w podzie niż globalna zmiana CoreDNS | [commit `197d3cf`, 2026-02-24], [commit `e42d919`, 2026-05-14] |
| BorgBackup | 2026-02-24 | CronJob kopii poza siedzibę na Hetzner Storage Box | [commit `16fdd8f`, 2026-02-24] |
| Postfix | 2026-02-24 | Przekaźnik SMTP przez OCI Email Delivery dla powiadomień | [commit `16fdd8f`] |
| Byparr | 2026-02-24 | Rozwiązywanie CAPTCHA zgodne z FlareSolverr dla Prowlarra | [commit `16fdd8f`] |
| pre-commit | 2026-02-24 | Hooki formatowania i walidacji, potem przeformatowanie całego repo | [commit `067462b`, 2026-02-24], [commit `55aca7a`, 2026-02-24] |
| `docs/` | 2026-02-28 | Notatki z incydentu Longhorn/Mimir (`docs/checkpoints`), usunięte tego samego dnia. Od czerwca specyfikacje i plany w `docs/superpowers` | [commit `06093ff`, 2026-02-28], [commit `02e22ab`, 2026-02-28], [commit `4367315`, 2026-06-18] |
| metrics-server | 2026-02-28 | `metrics.k8s.io`, `kubectl top`; parametry kubeleta pod Talosa | [commit `fe74ed3`, 2026-02-28] |
| homepage | 2026-02-19 | Statyczna strona nginx dla gołej domeny `nerine.dev` | [commit `1d273cf`, 2026-02-19] |

## 6. CI/CD i automatyzacja

- Workflowy na koniec E4: `ansible-lint`, `ansible`, `kubernetes-lint`, `terraform-apps`, `terraform-destroy`, `terraform` **[plik `.github/workflows/` w `cb3847a`]**. Kubernetes nie ma workflowu wdrożeniowego; to robi ArgoCD.
- Uruchomienie CI po scaleniu, 2026-02-26/27: około 50 commitów o CI w dwa dni (tematy `github-actions`, `terraform-apps-ci`, `ci`). Główne problemy: mapowanie sekretów Bitwarden na zmienne, połączenie runnera z klastrem przez Tailscale (`tag:ci`, kubeconfig z talosconfig) i token GitHub. Domyślny `GITHUB_TOKEN` nie wystarczał do odczytu zmiennych i sekretów repo, więc wszedł token GitHub App **[commit `9e54672`, 2026-02-26]**. Próba powrotu do `GITHUB_TOKEN` 2026-05-23 skończyła się revertem **[commit `1175624`, 2026-05-23], [commit `484e046`, 2026-05-23]**, a z tego powstał wpis w gotchas.
- Automatyczny apply na `main`: „apply on any main branch event where plan detects changes” **[commit `ffea00e`, 2026-05-23]**. Konsekwencję widać 2026-06-19: „the previous CI apply recreated talos-1 due to stale state” **[commit `87e4810`, 2026-06-19]** (rozdz. 9D). Dziś instrukcje projektu wymagają planu i applyu lokalnie przed pushem **[plik `AGENTS.md` na `main`, `CLAUDE.md` to symlink]**.
- Dostęp CI do Talosa: seria poprawek z 2026-05-02 (MagicDNS, `tailscale ping`, czekanie na peery) **[commit `3e048ed`, 2026-05-02]**, w maju kolejne („Keep CI off tailnet DNS”) **[commit `6020ea7`, 2026-05-19]**.
- Grupy współbieżności w workflowach, z ochroną trwających applyów przed anulowaniem **[commit `f3aaf38`, 2026-04-14], [commit `515e526`, 2026-04-14]**.
- Renovate: Dependabot zastąpiony Renovate'em w PR przygotowanym przez agenta Copilot **[PR #311]**, poprawka regexu **[PR #313]**; `renovate.json` → `renovate.json5` **[commit `615d950`, 2026-05-03]**; automerge lockfile maintenance **[commit `d33e230`, 2026-05-02], [commit `9e4c94a`, 2026-07-01]**. Zbiorczy PR z aktualizacjami cofnięto dzień po scaleniu migracji **[PR #271]**; powodu nie podano.

## 7. Narzędzia dewelopera

| Data | Zmiana | Dowód |
| ---- | ------ | ----- |
| 2026-02-01 | `AGENTS.md` jako instrukcja dla agentów AI i zbiór „gotchas”; od 2026-08-18 `CLAUDE.md` jest symlinkiem do niego | [commit `fe05e6c`, 2026-02-01], [commit `300b202`, 2026-08-18] |
| 2026-02-27 | Python przypięty do 3.13 (uv) | [commit `6db6393`, 2026-02-27] |
| 2026-03-01 | Nix flake (devShell) + direnv (`.envrc`), integracja z `setup-env.sh` | [commit `3b8be01`, 2026-03-01], [commit `af843c0`, 2026-03-01] |
| 2026-03-07 | Zasady bezpieczeństwa dla agentów w `AGENTS.md` („NEVER recreate…”, „Always push changes to test them”) | [commit `4f47a7b`, 2026-03-07] |
| 2026-05-03 | Nix → mise: `.mise.toml` z przypiętymi narzędziami (terraform, kubectl, kustomize, helm, talosctl, kube-linter, tflint, bws…) i zadaniami `lint-*`; flake i `.envrc` usunięte | [commit `80cebb2`, 2026-05-03] |
| 2026-05-03 | `package.json` („interstellar-pre-commit-hooks”) dodany w commicie migracji na mise i usunięty tego samego dnia | [commit `80cebb2`], [commit `bb145d6`, 2026-05-03] |
| 2026-06-12 | `docker/` z własnym Dockerfile dla borg dodany i wycofany tego samego dnia | [commit `e8c121f`, 2026-06-12], [commit `f686e83`, 2026-06-12] |
| 2026-06-18 | Specyfikacje i plany w `docs/superpowers/` (optymalizacja energii, firmware DMC) | [commit `4367315`, 2026-06-18], [commit `2c067f9`, 2026-06-18] |
| 2026-06-22 | `.opencode/tmp/GPU-Crash-Investigation.md` (raport z dochodzenia, usunięty następnego dnia) | [commit `d033e3c`, 2026-06-22], [commit `eefc9d7`, 2026-06-23] |

Mise ma ograniczenie, które trafiło do gotchas: ładuje tylko statyczne środowisko (`.env`, `.venv`), a eksporty z Bitwarden/Tailscale nadal wymagają `source scripts/setup-env.sh` **[commit `80cebb2`]**.

[wniosek] W E4 agenci AI stają się stałą częścią pracy: `AGENTS.md`, trailery Co-authored-by z Copilotem (3 commity), PR-y `copilot-swe-agent`, katalogi `.opencode` i `docs/superpowers`. Gotchas pełnią rolę pamięci projektu: każdy incydent kończy się wpisem, który ma powstrzymać następnego agenta (albo autora) przed tym samym błędem.

## 8. Od marca do lipca w skrócie

| Miesiąc | Najważniejsze zmiany | Dowód |
| ------- | -------------------- | ----- |
| 03 | Dashboardy GeoIP, mapowanie grup Authentik → role Grafany; usunięcie IP Tailscale z publicznego DNS (publicznie tylko VPS); Immich ML na OpenVINO dla Arc; exit node Tailscale na Proxmoxie (wymaga `ip_forward`) | [commit `4e08b0e`, 2026-03-02], [commit `f54f772`, 2026-03-01], [commit `bf8056e`, 2026-03-09], [commit `3b51258`, 2026-03-10], [commit `55e61c1`, 2026-03-23] |
| 04 | Tag Minecraft w ACL Tailscale; SMB w Copyparty włączony i po dniu wyłączony; zmniejszenie RAM węzłów („scale down”); grants Tailscale do API K8s | [commit `7168368`, 2026-04-08], [commit `f579311`, 2026-04-12], [commit `1046635`, 2026-04-13], [commit `81d2c97`, 2026-04-14], [commit `347fa09`, 2026-04-14] |
| 05 | mise; odbudowa klastra 05-14 (emergency_ro, etcd); Longhorn na osobnym dysku 05-19; kopie `home`/`media`/`observability` i automatyczny apply 05-23 | [commit `80cebb2`], [commit `43f6a34`, 2026-05-14], [commit `94d70a4`, 2026-05-19], [commit `441eb36`, 2026-05-23] |
| 06 | Wyższe requesty pamięci podów GPU; próba MinIO; refaktor kopii; początek oszczędzania energii (06-14); talos-1 odtworzony przez CI (06-19); logi jądra do Loki, ClamAV usunięty (06-21); descheduler (06-27/28) | [commit `d528c48`, 2026-06-02], [commit `a3e6c50`, 2026-06-04], [commit `aee76cc`, 2026-06-14], [commit `70fb7b4`, 2026-06-21], [commit `1fffc31`, 2026-06-27], [commit `ae206b4`, 2026-06-28] |
| 07 | node-exporter i poprawione alerty; Bitwarden: nowa organizacja; limit ARC ZFS 4 GiB; qBittorrent a uśpienie HDD; hardening (SSH, TLS tylko AEAD, `sniStrict`); CrowdSec na Helm + AppSec; firmware B580; SSO Jellyfin przez plugin JellyfinSecurity i poprawka OIDC SSRF | [commit `d7f1515`, 2026-07-16], [commit `24834b9`, 2026-07-19], [commit `aeca5da`, 2026-07-20], [commit `ab5882d`, 2026-07-21], [commit `46ae919`, 2026-07-24], [commit `38dcd4e`, 2026-07-27], [commit `ccb3005`, 2026-07-28], [commit `222d411`, 2026-07-30] |

Oszczędzanie energii (od 2026-06-14) zaczyna się w E4, ale ciągnie się dalej; pełny opis jest w pliku E5. Tu tylko kroki z E4: usunięcie telemetrii GPU („adds ~8W idle power draw”) **[commit `aee76cc`]**; rozszerzenie `siderolabs/i915` z firmware DMC, dzięki któremu działa runtime PM GPU („~8W saving”) **[commit `08b837f`, 2026-06-18]**; hd-idle, `atime=off`, `zfs_txg_timeout=30` **[commit `55389fa`, 2026-06-14], [commit `b175bfb`, 2026-06-18], [commit `0eb5f62`, 2026-06-18], [commit `2027bad`, 2026-06-18]**; flashowanie firmware B580 21.1137 → 21.1182 z LVFS 2026-07-27 na wentylator w spoczynku **[commit `711d818`, 2026-07-27]**.

### Rozmiar węzłów (RAM w GiB, z `Terraform/variables.tf`)

| Od | talos-1 (GPU) | talos-2 | talos-3 | Powód wg repo | Dowód |
| -- | ---: | ---: | ---: | --- | --- |
| plan | 16 | 16 | 16 | 8 vCPU / 16 GiB na węzeł | [plik planu, `bc91666`] |
| 2026-02-01 | 16 | 16 | 16 | brak opisu | [commit `6757719`] |
| 2026-02-16 | 8 | 8 | 8 | jawne wartości usunięte, domyślne 8192 | [commit `7a30c5b`] |
| 2026-02-28 | 16 | 12 | 12 | „reduce node-level OOM pressure during storage churn” | [commit `d63f6af`, 2026-02-28] |
| 2026-04-14 | 10 | 8 | 8 | „scale down”, bez opisu | [commit `81d2c97`] |
| 2026-06-19 | 10 | 12 | 12 | talos-2/3 także 4 → 6 vCPU: „CPU starvation and probe-timeout crashes” | [commit `c664dd4`, 2026-06-19] |
| 2026-06-24 | 16 | 8 | 8 | „rebalance node memory” | [commit `7707c14`, 2026-06-24] |
| 2026-07-05 | 16 | 12 | 8 | talos-2 na 84% pamięci, OOM podów BestEffort (share-manager Longhorna) przy migracji Immich v3 | [commit `b1ea7f9`, 2026-07-05] |

[wniosek] Rozmiar węzłów zmieniał się w E4 sześć razy. Pamięć była głównym ograniczeniem: host dzieli RAM między trzy VM, ARC ZFS (limit 4 GiB od 07-20) i pozostałe maszyny. Dobrym materiałem do rozdziału o kosztach jest pytanie, dlaczego w kwietniu zmniejszano RAM.

## 9. Studia przypadków

### 9A. Longhorn: DiskPressure i Mimir (2026-02-27)

- Objaw: alerty „Volume Degraded/Faulted”, PVC prawie pełne, błędy I/O w Mimirze i Seerr, w treści alertów „[no value]” **[plik `docs/checkpoints/2026-02-27-longhorn-storage-checkpoint.md` w `06093ff`]**.
- Diagnoza: wszystkie 3 dyski Longhorna (po 61,79 GiB) niedostępne do planowania (`DiskPressure`), zaplanowane od 74 do 85 GiB na każdym przy `over-provisioning` 150% i 3 replikach. Wolumen Mimira zajmował około 9 GiB, choć system plików pokazywał około 1 GiB; różnicę stanowił snapshot Longhorna **[ten sam plik]**.
- Poprawka: repliki 3 → 2, over-provisioning 150 → 200%, PVC Mimira 10 → 16 Gi, poprawione szablony alertów **[commit `06093ff`]**. Tydzień później: usunięcie 17 starych VolumeSnapshotów (około 36 GiB), over-provisioning 200 → 100% (przed incydentem było 150%), retencja Mimira 31 → 14 dni, auto-balans replik **[commit `142f214`, 2026-03-06]**. PVC nie da się zmniejszyć w miejscu, więc nastąpiła migracja na PVC „v2” i powrót do kanonicznych nazw w mniejszym rozmiarze **[commit `b8ab06b`, 2026-02-27] → [commit `f713900`, 2026-02-28]**.
- Poprawka strukturalna: od 2026-05-19 Longhorn ma na każdym węźle osobny dysk 120 GiB (`UserVolumeConfig`, `/var/mnt/longhorn`) **[commit `94d70a4`]**. [wniosek] W lutym Longhorn dzielił z systemem 64-gigabajtowy dysk VM, stąd presja.
- Lekcja: replikacja i snapshoty mnożą zajętość. Pojemność do planowania trzeba liczyć z replikami i snapshotami, nie z tego, co widać w PVC [wniosek].

### 9B. „Utrata wszystkich danych” przez odtworzenie app-of-apps (przed 2026-03-07)

- Jedyny dowód: wpis z 2026-03-07: „ArgoCD app-of-apps was once recreated by changing resource names/structure, causing all data loss. NEVER do this.” Razem z nim reguły: nie usuwać PVC, StatefulSetów i Deploymentów, nie odtwarzać zasobów zarządzanych przez ArgoCD **[commit `4f47a7b`, 2026-03-07]**.
- Mechanizm [wniosek]: `app-of-apps` ma finalizer `resources-finalizer.argocd.argoproj.io` i `prune: true` **[plik `Kubernetes/bootstrap/argocd/app-of-apps.yaml`]**. Usunięcie tej aplikacji (albo zmiana jej nazwy, czyli usunięcie i utworzenie nowej) kaskadowo usuwa wszystko, czym zarządza, w tym PVC.
- Kiedy i co dokładnie: **[nieznane]**. Kandydaci z historii to zmiana `path` 2026-02-16 **[commit `6cba788`]** albo scalenie 2026-02-26; dowodu nie ma. 2026-03-02 commit mówi „re-enable ArgoCD auto-sync” **[commit `4e08b0e`, 2026-03-02]** bez zmiany w manifeście, więc [wniosek] auto-sync był wcześniej wyłączony ręcznie na klastrze.
- Lekcja (wg repo): zmieniać zasoby GitOps w miejscu, nigdy przez usuń-i-utwórz; przed pushem sprawdzać, czy diff nie usuwa ani nie przemianowuje zasobów **[commit `4f47a7b`]**. Dla rozdziału o odtwarzaniu: [wniosek] na koniec E4 jedyną kopią danych aplikacji poza klastrem i poza hostem był Borg na Hetznerze.

### 9C. CrowdSec działał „na ślepo” przez pół roku (2026-02-01 → 2026-07-24)

- Objaw: „0 alerts, 0 decisions, no log ingestion” **[commit `b0099ce`, 2026-07-24]**.
- Przyczyna: LAPI uruchomione z `DISABLE_AGENT=true` od pierwszego commitu migracji **[commit `6757719`, 2026-02-01]**. Entrypoint w takim przypadku pomija instalację kolekcji z `COLLECTIONS`, więc nic nie parsowało logów **[commit `b0099ce`]**.
- Poprawka: chart Helm (LAPI jako Deployment, agent jako DaemonSet czytający logi kontenerów Traefika i Jellyfin z `/var/log/containers`). Wyszły przy tym kolejne pułapki: chart nie ustawia `metadata.namespace` (łatki JSON 6902), namespace potrzebuje PSA `privileged` (hostPath), zmienna musi się nazywać `BOUNCER_KEY_traefik`, whitelist zakresów wymaga pola `cidr:` **[commit `2f331b6`, 2026-07-24], [commit `5bdb861`, 2026-07-26], [commit `8144b27`, 2026-07-26], [commit `8347e9c`, 2026-07-27]**. Potem AppSec (WAF), kolekcja `http-dos` i dashboard **[commit `38dcd4e`, 2026-07-27]**.
- Lekcja [wniosek]: komponent bezpieczeństwa, który „działa” (pody Ready), może niczego nie chronić. Trzeba mierzyć jego wyjście (liczbę decyzji), nie tylko stan.

### 9D. Pętla restartów węzła GPU (czerwiec 2026)

- Tło: najpóźniej 2026-06-19 automatyczny apply w CI odtworzył talos-1 przez nieaktualny stan Terraform (commit mówi o „previous CI apply”). Gotcha z tego samego dnia opisuje odbudowę węzła po pustych binariach w containerd: zatrzymanie VM, nowy ZVOL dysku systemowego, ISO Talosa i `apply-config --insecure` **[commit `f33592a`, 2026-06-19]**; [wniosek] to po tej odbudowie na EPHEMERAL mogły zostać stare dane etcd. Domyślny endpoint providera Kubernetes przeniesiono na talos-2, bo węzeł GPU „is recreated more often and its Tailscale identity does not survive reinstallation” **[commit `87e4810`, 2026-06-19]**.
- Objaw: Flannel na węźle GPU restartował się mniej więcej co 73 minuty (42 razy w 2 dni i 2 godziny), pody Jellyfin/Immich-ML w `UnexpectedAdmissionError`/`Unknown`, ArgoCD `selfHeal` tworzył nowe pody w pętli **[commit `70fb7b4`, 2026-06-21]**.
- Hipoteza 1 (wycofana): GPU za wirtualnym mostkiem PCIe QEMU nie wraca z runtime PM. Dodana i cofnięta tego samego dnia **[commit `5d2de70`, 2026-06-21], [commit `ed9b854`, 2026-06-21]**; D3cold włączony ponownie **[commit `d0c61f2`, 2026-06-21]**.
- Hipoteza 2: burza odświeżeń SDK Bitwarden o pełnej godzinie i OOM-kill Flannela na węźle 10 GiB. Dodano wysyłanie logów jądra do Loki i skrypt `wait-for-gpu-crash.sh` **[commit `70fb7b4`], [commit `5700fbf`, 2026-06-21]**.
- Przyczyna wg raportu z dochodzenia: konsola szeregowa (dodana do VM **[commit `32e848b`, 2026-06-21]**) pokazała w każdym cyklu `error adding member: etcdserver: unhealthy cluster`, a po około 70 minutach reboot. Węzeł po przebudowie dostał nową tożsamość (`talos-s97-8fh` → `talos-9jv-bx9`), a na partycji EPHEMERAL zostały stare dane etcd. Poprawka 2026-06-22: `talosctl reset --system-labels-to-wipe EPHEMERAL`, węzeł dołączył jako learner i awansował do pełnego członka **[plik `.opencode/tmp/GPU-Crash-Investigation.md` w `d033e3c`]**.
- Co zostało w dokumentacji: wpis o Flannelu i Bitwarden przetrwał w skróconej formie („Always read kernel logs via Loki…”) do dzisiejszych instrukcji projektu **[plik `AGENTS.md` na `main`]**; o pozostałościach etcd po przebudowie węzła instrukcje mówią tylko tyle, że etcd leży w EPHEMERAL. RAM talos-1 podniesiono do 16 GiB 2026-06-24 **[commit `7707c14`]**. [wniosek] Logi jądra w Loki i konsola szeregowa zostały jako trwałe narzędzia diagnostyczne, ale pętlę zatrzymał dopiero reset EPHEMERAL.
- Lekcja: zanim zgadniesz, czytaj logi jądra lub konsoli; przy przebudowie węzła control-plane trzeba posprzątać członkostwo etcd. Etcd siedzi w EPHEMERAL, nie na osobnej partycji (gotcha z 2026-05-14 **[commit `43f6a34`]**).

### 9E. Longhorn `emergency_ro` (maj 2026)

- Objaw: aplikacje zgłaszają „Read-only file system”, a wolumen w Longhornie jest `attached`/`healthy` **[commit `43f6a34`, 2026-05-14]**.
- Diagnoza: `/proc/mounts` na węźle pokazuje `emergency_ro` **[commit `43f6a34`]**.
- Poprawka: ręczne snapshoty, skalowanie aplikacji do 0 aż do odłączenia wolumenu, ponowne skalowanie w górę; montowania wróciły do `rw` bez odtwarzania zasobów **[commit `43f6a34`]**. Procedura awaryjna („Never delete the PVC as a first step”, kopia, potem `e2fsck`) **[commit `91c55e5`, 2026-05-23]**.
- Przyczyna: **[nieznane]**; commity z 05-14 i 05-19 nie mają opisów.

### 9F. OOM na węźle GPU i rozmiary requestów (czerwiec i lipiec 2026)

- Objaw i przyczyna: „immich-ml peaked at 6Gi and jellyfin at 2Gi on talos-ueo-rhk (9.5Gi allocatable). Both had 1Gi requests”, scheduler upychał pody, kernel zabijał je (exit 137), co psuło odbudowy Longhorna („EOF”) **[commit `d528c48`, 2026-06-02]**.
- Poprawki: wyższe requesty; Grafana 1 GiB **[commit `a512545`, 2026-06-14]**; Jellyfin tylko requesty bez limitów **[commit `4fcb5b2`, 2026-06-24]**; descheduler (CronJob co 4 h, LowNodeUtilization), następnie progi z rzeczywistych metryk 50/80% **[commit `1fffc31`], [commit `ae206b4`]**; ograniczenie współbieżności ML Immicha na GPU **[commit `1fb2b9e`, 2026-07-06]**.
- Lekcja [wniosek]: scheduler planuje według requestów, nie według zużycia. Request 1 GiB przy szczycie 6 GiB pozwala upchnąć na węźle więcej, niż się zmieści, więc requesty muszą wynikać z pomiaru. Pody bez requestów (BestEffort) giną pierwsze przy presji pamięci, co widać przy talos-2 w lipcu.

### 9G. Kopie zapasowe: Borg zamiast MinIO

- 2026-02-24 BorgBackup na Hetzner **[commit `16fdd8f`]**; 2026-05-23 zadania dla `media`, `home`, `observability` **[commit `441eb36`]**.
- Problem: CronJoby „could not mount RWO Longhorn PVCs from different nodes and running services into a single pod” **[commit `145f097`, 2026-06-03]**. Próba z MinIO jako celem kopii Longhorna, wycofana tego samego dnia z przytoczonym powodem (deduplikacja i kompresja Borga) **[commit `59a11a8`]**.
- Rozwiązanie: orkiestrator skaluje AdGuard w dół, uruchamia Job kopii i skaluje z powrotem; prace na wspólnym repo Borga idą sekwencyjnie, bo równoległe walczyły o lock **[commit `c664dd4`, 2026-06-19]**; jeden skrypt i archiwa per aplikacja **[commit `a3e6c50`, 2026-06-04]**.

## 10. Plan a realizacja

| Plan (`bc91666`/`d0ae5b1`) | Stan na koniec E4 (`cb3847a`) | Dowód |
| -------------------------- | ------------------------------ | ----- |
| Longhorn na targetach iSCSI (zvole ZFS przez targetcli) | Longhorn na dyskach VM (od 05-19 osobny dysk 120 GiB); dane mediów przez statyczne PV NFS; `iscsi-tools` tylko jako rozszerzenie Talosa | [plik `Terraform/variables.tf` w `cb3847a`], [commit `a338df4`], [commit `94d70a4`] |
| Osobny VLAN 100 (`10.100.0.0/24`) i izolacja klastra od LAN | Węzły w LAN `192.168.1.x` (VIP `192.168.1.100`, węzeł GPU `192.168.1.110`); `git grep vlan` nic nie znajduje | [commit `066701e`], [plik `.opencode/tmp/GPU-Crash-Investigation.md` w `d033e3c`] |
| ArgoCD z ApplicationSets | Jedna `Application` na całe `Kubernetes/` | [plik `Kubernetes/bootstrap/argocd/app-of-apps.yaml` w `cb3847a`] |
| 3 × 8 vCPU / 16 GiB | 4/6/6 vCPU, 16/12/8 GiB | [plik `Terraform/variables.tf` w `cb3847a`] |
| Copyparty z OAuth2-Proxy i SMB przez Tailscale | Copyparty z nagłówkami grup Authentika; SMB wypróbowany i wyłączony | [commit `c4d511c`, 2026-02-25], [commit `1046635`] |
| Oracle VPS jako wejście HAProxy | Bez zmian przez całe E4 (`compose.proxy.yaml`, `haproxy.cfg`) | [plik `compose.proxy.yaml` w `cb3847a`] |
| Grafana + Loki + Mimir + Promtail | Zrealizowane, doszły Alloy i logi jądra | [commit `4491ce8`], [commit `70fb7b4`] |

Powody odejść od planu repo podaje tylko częściowo; resztę zebrałem w pytaniach.

## 11. Wnioski z E4 zrewidowane później

| Twierdzenie z E4 | Co się stało potem | Dowód |
| ---------------- | ------------------ | ----- |
| „Public DNS (Cloudflare) only has Oracle VPS IP” | W 2026-08 usługi wystawiono publicznie bezpośrednio przez Traefik na domowym IP, wszystkie hosty na `public-chain` (E5) | [commit `bf8056e`, 2026-03-09], [commit `5d7f26e`, 2026-08-21] |
| Longhorn z `recurring-job-group…: enabled` automatycznie usuwa snapshoty użytkownika | Pomiar z 2026-09-22: snapshot przetrwał 30 minut; grupa jest martwa, bo nie ma `RecurringJob` | [commit `1ff0808`, 2026-06-03], [commit `2924c95`, 2026-09-22] |
| Arc za mostkiem QEMU nie wraca z żadnego stanu runtime PM | Wycofane tego samego dnia | [commit `5d2de70`], [commit `ed9b854`] |
| Restarty Flannela przez OOM po odświeżeniu Bitwarden | Raport z dochodzenia wskazuje stare dane etcd; wpis o OOM i tak został. Źródła się różnią: `CLAUDE.md` na `main` nadal podaje OOM jako fakt (tak też `technologie/04-dane-kopie-sekrety-monitoring.md`), git nie rozstrzyga | [commit `70fb7b4`], [plik `.opencode/tmp/GPU-Crash-Investigation.md` w `d033e3c`] |
| „Bitwarden provider is pre-release 0.5.4-pre” | Usunięte jako błędne; oba rooty mają stabilne 1.0.1 | [commit `4d3964d`, 2026-07-23] |
| `zfs_txg_timeout=30` dla uśpienia HDD | Parametry ZFS są globalne: we wrześniu długie synchronizacje txg na `rpool` spowalniały etcd i wywoływały wybory lidera; bufor zmniejszono do 256 MiB (E5) | [commit `2027bad`, 2026-06-18], [commit `34899c2`, 2026-09-21], [commit `d795946`, 2026-09-21] |
| CrowdSec przeniesiony na chart Helm uznany za naprawiony | Chart przy każdym renderze losował sekret LAPI, więc ArgoCD nie mógł się zsynchronizować; sekret przeniesiono do Bitwarden przez ExternalSecret (E5) | [commit `b0099ce`, 2026-07-24], [commit `7c7a702`, 2026-08-08] |

## 12. Stan na koniec E4 (commit `cb3847a`, 2026-07-31)

Uwaga o granicy: `cb3847a` ma datę autora 2026-07-31 22:48 UTC, czyli 2026-08-01 00:48 w Warszawie. Ten plik liczy w UTC, więc to ostatni commit E4; `historia/05-publiczne-wystawienie-i-stan-obecny.md` bierze za punkt odniesienia `28cd19a` (2026-07-31 19:44 UTC). Oba punkty dzieli jeden commit, aktualizacja `uv` (PR #518).

- Klaster: TalosOS v1.13.4, Kubernetes 1.36.2, trzy węzły control-plane + worker (talos-1 z Arc B580: 4 vCPU/16 GiB; talos-2: 6/12; talos-3: 6/8) **[plik `Terraform/variables.tf` w `cb3847a`]**.
- `Kubernetes/bootstrap`: argocd, authentik, coredns-override, crowdsec, external-secrets, intel-gpu-operator, longhorn, metallb, metrics-server, observability, reloader, tailscale-operator, traefik.
- `Kubernetes/apps`: adguard, bazarr, borgbackup, byparr, common, copyparty, decluttarr, descheduler, home-backup, homepage, immich, jellyfin, mcpjungle, media-backup, postfix, prowlarr, qbittorrent, radarr, recyclarr, seerr, sonarr, whoami **[`git ls-tree cb3847a`]**.
- Terraform (główny root): bitwarden, cloudflare, email, github, hetzner, kubernetes, oracle, proxmox, secrets, tailscale, talos; stan w OCI Object Storage. `Terraform/apps`: adguard, authentik, bitwarden, jellyfin, servarr; stan w OCI.
- Dostęp: publicznie przez Oracle VPS (HAProxy) i Tailscale do Traefika; AdGuard robi split-horizon dla LAN i tailnetu; Authentik jako forward-auth i OIDC.
- Kopie: BorgBackup na Hetzner Storage Box, archiwa per aplikacja.
- Narzędzia: mise (`.mise.toml`, `mise.lock`), uv i Python, pre-commit, Renovate (`renovate.json5`), `AGENTS.md` z gotchas, `SETUP.md`.


## Pytania do autora

1. Na jakim sprzęcie działał serwer w E4? README z 2026-01 podaje i5-12600K, 32 GB i UHD 770, a plan migracji Ryzen 9 3950X, około 64 GB i Arc B580. Kiedy zmieniono sprzęt?
2. Kiedy nowy klaster Talos zaczął obsługiwać ruch produkcyjny zamiast K3s: 2026-02-01, w trakcie lutego czy dopiero po scaleniu 2026-02-26?
3. Co usuwał workflow `terraform-destroy.yaml` 2026-02-01 (poza Proxmoxem) i czy było to celowe wygaszenie starej infrastruktury?
4. Dlaczego 2026-02-01 przeszedłeś na OpenTofu i po sześciu godzinach wróciłeś do Terraform?
5. Dlaczego Authentik zastąpił oauth2-proxy 2026-02-20? Chodziło o grupy i RBAC, o jedno logowanie dla wszystkich aplikacji, czy o coś innego?
6. Dlaczego zrezygnowałeś z `nfs-csi` (dynamiczne PVC) na rzecz statycznych PV już po czterech dniach?
7. Którego dnia i przy jakiej zmianie doszło do „all data loss” po odtworzeniu app-of-apps (wpis z 2026-03-07)? Co przepadło i co odzyskano?
8. Dlaczego nie zrealizowano z planu Longhorna na iSCSI, osobnego VLAN-u dla klastra i ApplicationSets?
9. Dlaczego w marcu wprowadziłeś Nix flake, a w maju zastąpiłeś go mise?
10. Czy provider Terraform `ThePhaseless/jellyfin` napisałeś sam, i dlaczego zamiast istniejącego?
11. Co się stało 2026-05-14 („Stabilize cluster recovery”), co spowodowało `emergency_ro` i czy przy tym przebudowywano członka etcd?
12. Dlaczego 2026-04-14 zmniejszono RAM węzłów (16/12/12 → 10/8/8 GiB): z powodu prądu, potrzeb innych VM, czy czegoś innego?
13. Dlaczego 2026-07-19 trzeba było odtworzyć organizację w Bitwarden?
14. Dlaczego usunięto ClamAV 2026-06-21?
15. Co naprawdę powodowało restarty węzła GPU w czerwcu 2026: OOM Flannela po odświeżeniu sekretów Bitwarden (wpis, który został w instrukcjach) czy stare dane etcd na EPHEMERAL (usunięty raport `.opencode/tmp/GPU-Crash-Investigation.md`)? I czy talos-1 odtworzył wtedy apply z CI, czy ręczna odbudowa po pustych binariach w containerd?
16. Jakich asystentów AI używałeś w E4 (Copilot, OpenCode, Claude, inne) i do czego: planowania, kodu czy diagnozy?
17. Dlaczego PR #271 cofnął zbiorczą aktualizację zależności dzień po scaleniu migracji?

## Do której części pracy

- Implementacja: rozdz. 2-8 i 12 (przebieg przebudowy, składniki, Terraform/apps, CI, stan końcowy).
- Projekt: rozdz. 10 (plan a realizacja), tabela zastąpień w rozdz. 3, rozmiar węzłów w rozdz. 8.
- Odtwarzanie po awarii: rozdz. 9 (zwłaszcza 9B, 9D, 9E, 9G) i reguły z `AGENTS.md` (`4f47a7b`); ArgoCD jako źródło prawdy i Borg jako jedyna kopia spoza klastra.
- Technologie: składniki z rozdz. 3 z powodami wyboru, które podaje repo (VIP Talosa, plugin CrowdSec, Borg zamiast MinIO, DaemonSet zamiast operatora GPU).
- Analiza kosztów: rozmiar węzłów (rozdz. 8) i początek oszczędzania energii (pełniej w pliku E5).
- Podsumowanie: rozdz. 11 (wnioski zrewidowane) i obserwacja o gotchas jako pamięci projektu.

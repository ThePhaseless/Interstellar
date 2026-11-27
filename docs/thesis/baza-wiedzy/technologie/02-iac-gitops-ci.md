# Infrastructure as Code, GitOps, CI/CD i narzędzia dewelopera

Plik obejmuje: Terraform (razem z dwoma krótkimi epizodami OpenTofu), Ansible, Kustomize z Helmem, Argo CD (app-of-apps), GitHub Actions (z `act`), Renovate (i Dependabota), pre-commit z linterami oraz środowisko dewelopera (devcontainer, Nix flake, mise, uv). Stan obecny opisuję według brancha `main` na dzień 2026-11-27. Uwaga o datach: przebudowę E4 (od `bc91666` z 2025-12-17 do commitów z lutego 2026) autor robił na bocznej gałęzi, scalonej do `main` dopiero commitem `327eff3` 2026-02-26. Daty w tabelach to daty commitów; tam, gdzie to ważne, podaję osobno datę pojawienia się na `main`. Okresy E1-E5 mają nazwy i granice ze wspólnego briefu.

Oznaczenia: [commit `hash`, data], [plik `ścieżka`], [PR #N] to dowody z repo; [wniosek] to moje rozumowanie; [źródło: URL, dostęp 2026-11-27] to strona WWW; [nieznane] to brak danych. Wszystkie strony WWW otwarto 2026-11-27.

## 1. Mapa: co czym jest dziś zarządzane

| Warstwa | Narzędzie | Gdzie w repo | Jak zmiana trafia na produkcję |
|---|---|---|---|
| VM-ki na Proxmoxie, konfiguracja maszyn Talos, Oracle Cloud, DNS w Cloudflare, Tailscale (ACL, klucze), sekrety w Bitwarden, Hetzner Storage Box, zmienne i sekrety GitHub Actions | Terraform, root `Terraform/` | `Terraform/*.tf`, moduł `Terraform/modules/talos-node` | lokalny `plan`/`apply`, potem workflow `terraform.yaml` na `main` |
| Konfiguracja aplikacji przez ich API (Sonarr, Radarr, Prowlarr, AdGuard, Authentik, Jellyfin) | Terraform, root `Terraform/apps/` | `Terraform/apps/*.tf` | lokalnie z `scripts/port-forward-apps.sh`, potem `terraform-apps.yaml` |
| Host Proxmox (serwer NFS, oszczędzanie energii, alerty smartd/ZFS, passthrough drukarki), urządzenia osobiste | Ansible | `Ansible/*.yaml` | workflow `ansible.yaml` na `main` |
| Wszystko, co działa w Kubernetesie | Kustomize + Helm, Argo CD | `Kubernetes/` | `git push`, potem auto-sync Argo CD |
| Wersje obrazów, chartów, providerów, akcji i narzędzi | Renovate | `renovate.json5` + wspólny preset `ThePhaseless/renovate-config` | PR-y, część scalana automatycznie |
| Narzędzia CLI dewelopera | mise (+ uv dla Pythona) | `.mise.toml`, `mise.lock`, `pyproject.toml`, `uv.lock` | lokalnie `mise install`, `mise run install` |

[plik `.github/workflows/terraform.yaml`] [plik `.github/workflows/terraform-apps.yaml`] [plik `.github/workflows/ansible.yaml`] [plik `Kubernetes/bootstrap/argocd/app-of-apps.yaml`] [plik `renovate.json5`] [plik `.mise.toml`]

## 2. Oś czasu narzędzi

| Data | Zdarzenie | Dowód |
|---|---|---|
| 2024-02-08 | Devcontainer i `.github/dependabot.yml`; Dependabot śledzi tylko ekosystem `devcontainers` | [commit `44e2ac5`, 2024-02-08] |
| 2024-07-14 | Pierwszy workflow wdrożeniowy: GitHub Actions łączy się przez Tailscale SSH z serwerem i uruchamia `scripts/deploy.sh` (`git pull`, `docker compose pull`, `docker compose up -d`) | [commit `9de8f42`, 2024-07-14] [plik `scripts/deploy.sh` w commicie `4c84a73`] |
| 2024-07-17 | Renovate (`renovate.json` z `config:recommended`); tego samego dnia scalony PR onboardingowy Renovate „Configure Renovate”; pierwszy PR z aktualizacją (Sonarr 4.0.8) scalony 2024-07-18 | [commit `5b2f015`, 2024-07-17] [PR #3] [PR #5] |
| 2025-07-26 | Terraform (provider `Telmate/proxmox`, backend `oci` jeszcze zakomentowany), Ansible, `pyproject.toml` + `uv.lock`, pierwsze workflow Terraform i Ansible. Pierwszy lock file powstał przez `tofu init`; 13 minut później powrót na Terraform (pierwszy epizod OpenTofu) | [commit `6930efc`, 2025-07-26] [commit `75e604b`, 2025-07-26] [commit `162b32c`, 2025-07-26] [commit `7a357aa`, 2025-07-26] [commit `6c341db`, 2025-07-26] |
| 2025-07-31 | `act` do lokalnego uruchamiania workflow (`.actrc`) | [commit `7b3ce98`, 2025-07-31] |
| 2025-09-12 | Workflow `kubernetes.yaml`: CI wykonuje `kubectl kustomize --enable-helm \| kubectl apply` na klastrze k3s | [commit `06ecf16`, 2025-09-12] |
| 2025-12-17 | Na `main`: usunięcie wyzwalaczy starych workflow (pliki zostają). Na bocznej gałęzi: początek przygotowań do migracji k3s → Talos, plan migracji z Argo CD jako docelowym mechanizmem wdrożeń | [commit `f3f7297`, 2025-12-17] [commit `bc91666`, 2025-12-17] |
| 2026-02-01 | Na bocznej gałęzi: migracja (Argo CD app-of-apps, provider `bpg/proxmox`, `kube-linter`), tego samego dnia drugi epizod OpenTofu i powrót na Terraform. Na `main`: workflow apply zamieniony na sam plan, dodany `terraform-destroy.yaml` | [commit `6757719`, 2026-02-01] [commit `afad10b`, 2026-02-01] [commit `06e540f`, 2026-02-01] [commit `b8daa33`, 2026-02-01] |
| 2026-02-26 | Scalenie gałęzi migracyjnej do `main`: nowy układ (`Kubernetes/bootstrap`, `apps`, Argo CD, Talos) zastępuje na `main` stary Terraform LXC/k3s i playbooki Ansible z E3 | [commit `327eff3`, 2026-02-26] |
| 2026-02-16 | Drugi root `Terraform/apps/` (stan w sekrecie Kubernetesa) | [commit `7a30c5b`, 2026-02-16] |
| 2026-02-19 | Dynamiczny inwentarz Ansible budowany z `tailscale status --json` | [commit `ecfff6f`, 2026-02-19] |
| 2026-02-24 | pre-commit (ruff, terraform fmt/validate/tflint, prettier, detect-private-key) | [commit `067462b`, 2026-02-24] |
| 2026-02-25/26 | Stan głównego roota w OCI Object Storage; aktualizacja do Terraform 1.14.4 „to support native oci backend”; token GitHub App w CI | [commit `e78ea0b`, 2026-02-25] [commit `88ee4dc`, 2026-02-26] [commit `9e54672`, 2026-02-26] |
| 2026-03-01 | Nix flake + direnv jako środowisko dewelopera | [commit `3b8be01`, 2026-03-01] |
| 2026-04-06 | Usunięcie Dependabota, naprawa wykrywania obrazów przez Renovate | [commit `bd423ac`, 2026-04-06] [PR #311] |
| 2026-05-03 | Nix flake → mise; `renovate.json` → `renovate.json5` | [commit `80cebb2`, 2026-05-03] [commit `615d950`, 2026-05-03] |
| 2026-05-23 | Apply w CI przy każdym zdarzeniu na `main`, jeśli plan nie jest pusty | [commit `ffea00e`, 2026-05-23] |
| 2026-06-23 | Stan `Terraform/apps/` przeniesiony z sekretu Kubernetesa do OCI | [commit `eefc9d7`, 2026-06-23] |
| 2026-08-19 | Reguła: `terraform plan`/`apply` lokalnie przed pushem, CI tylko jako potwierdzenie | [commit `111db10`, 2026-08-19] |
| 2026-10-02 | Moduł `talos-node`: aktualizacje węzłów jeden po drugim, z bramkami zdrowia Longhorna | [commit `feb2ee9`, 2026-10-02] |

## 3. Terraform

### Rola
Terraform opisuje warstwę poniżej Kubernetesa i wszystko, co jest „na zewnątrz” klastra.
- Główny root ma 12 providerów: `integrations/github`, `bpg/proxmox`, `siderolabs/talos`, `oracle/oci`, `cloudflare/cloudflare`, `tailscale/tailscale`, `bitwarden/bitwarden-secrets`, `hashicorp/kubernetes`, `hetznercloud/hcloud`, `hashicorp/tls`, `hashicorp/random`, `magodo/restful` [plik `Terraform/backend.tf`].
- Root `Terraform/apps/` konfiguruje aplikacje przez ich API: `devopsarr/sonarr`, `devopsarr/radarr`, `devopsarr/prowlarr`, `gmichels/adguard`, `goauthentik/authentik` oraz `ThePhaseless/jellyfin`, czyli provider napisany przez samego autora (repo utworzone 2026-03-27) [plik `Terraform/apps/versions.tf`] [źródło: https://github.com/ThePhaseless/terraform-provider-jellyfin, dostęp 2026-11-27].
- Terraform zasila też własne CI. `Terraform/github.tf` zapisuje identyfikatory sekretów Bitwarden jako zmienne repozytorium `BWS_ID_*` i składa sekret `PROXMOX_VE_API_TOKEN`. Workflow czyta potem te zmienne, żeby pobrać sekrety z Bitwarden [plik `Terraform/github.tf`] [plik `.github/workflows/terraform.yaml`].
- Konfigurację węzłów Talos generuje provider `siderolabs/talos`. Moduł `talos-node` wywoływany jest łańcuchem `talos_1` → `talos_2` → `talos_3`, a aktualizacje OS czekają na zdrowie Longhorna [commit `feb2ee9`, 2026-10-02] [plik `Terraform/talos.tf`].

### Podział na dwa rooty i stan
| Root | Backend dziś | Historia |
|---|---|---|
| `Terraform/` | `oci` (OCI Object Storage), klucz `interstellar/terraform.tfstate`; bucket i namespace przez `-backend-config` | Od 2025-07-26 backend był zakomentowany, czyli stan leżał lokalnie [commit `6930efc`, 2025-07-26]. Backend `oci` włączony 2026-02-25 [commit `e78ea0b`, 2026-02-25], a Terraform podniesiony do 1.14.4 dla natywnego backendu [commit `88ee4dc`, 2026-02-26]. |
| `Terraform/apps/` | `oci`, klucz `interstellar/servarr.tfstate` | Od 2026-02-16 stan w sekrecie Kubernetesa (`backend "kubernetes"`) [commit `7a30c5b`, 2026-02-16]. 2026-06-23 przeniesiony do OCI w commicie o tytule „recovery: fix perpetual drift…” [commit `eefc9d7`, 2026-06-23]. |

- Powód podziału: główny root tworzy klaster, a `apps` potrzebuje działających aplikacji i port-forwardu do nich (`scripts/port-forward-apps.sh`) [plik `Terraform/AGENTS.md`] [plik `CLAUDE.md`]. [wniosek] Jeden root miałby zależność „provider potrzebuje zasobu z tego samego planu”, czego Terraform nie obsługuje dobrze.
- [wniosek] Stan `apps` trzymany w sekrecie klastra, którym ten root zarządza, ginąłby razem z klastrem. Przeniesienie do OCI w commicie „recovery” wygląda na lekcję z odtwarzania. Warto to opisać w rozdziale o odtwarzaniu po awarii (pytanie 3).
- Rozbieżność w dokumentacji: `Terraform/AGENTS.md` na `main` nadal podaje, że `Terraform/apps/` używa `backend "kubernetes"`, a `Terraform/apps/backend.tf` ma od 2026-06-23 `backend "oci"` [plik `Terraform/AGENTS.md`] [plik `Terraform/apps/backend.tf`].
- Natywny backend `oci` pojawił się w Terraform 1.12.0 (2025-05-14) i blokuje stan zapisem warunkowym `If-None-Match` [źródło: https://raw.githubusercontent.com/hashicorp/terraform/v1.12/CHANGELOG.md, dostęp 2026-11-27] [źródło: https://developer.hashicorp.com/terraform/language/backend/oci, dostęp 2026-11-27]. Oracle zaleca ten backend, a drogę przez API zgodne z S3 oznacza jako przestarzałą [źródło: https://docs.oracle.com/en-us/iaas/Content/dev/terraform/object-storage-state.htm, dostęp 2026-11-27].

### Co zastąpił
- W E1-E2 nie było IaC dla maszyn: był `install.sh` oraz pliki compose uruchamiane skryptem [plik `install.sh` w pierwszym commicie; szczegóły w plikach historii E1/E2].
- E3: Terraform tworzył kontenery LXC na Proxmoxie (`proxmox_lxc`, provider Telmate), generował inwentarz Ansible i zapisywał go w OCI Object Storage, a Ansible instalował na nich k3s [plik `Terraform/proxmox.tf` i `Terraform/deployment.tf` w commicie `bc91666^`] [commit `9cc822b`, 2025-07-31]. Te pliki były na `main` aż do scalenia gałęzi migracyjnej [plik `Terraform/proxmox.tf` w commicie `327eff3^1`] [commit `327eff3`, 2026-02-26].
- E4: provider `bpg/proxmox` w miejsce `Telmate/proxmox` [commit `6757719`, 2026-02-01] i maszyny wirtualne Talos zamiast LXC z k3s. Powodu zmiany providera repo nie podaje [nieznane] (pytanie 4).

### Dwa epizody OpenTofu (2025-07-26 i 2026-02-01)

Epizod 1, E3, 2025-07-26 (na `main`):
- 15:27 „add terraform files”: pierwszy `Terraform/.terraform.lock.hcl` ma nagłówek „maintained automatically by "tofu init"” i providery z `registry.opentofu.org` [commit `6930efc`, 2025-07-26].
- 15:40 „migrate back to terraform”: ten sam lock file przepisany na `registry.terraform.io`; to jedyna zmiana w commicie [commit `75e604b`, 2025-07-26].
- [wniosek] OpenTofu był tu użyty co najmniej lokalnie, bo lock file wygenerował `tofu init`. Backend był wtedy zakomentowany, więc powodem powrotu nie był backend `oci`. Repo innego powodu nie podaje [nieznane] (pytanie 1).

Epizod 2, E4, 2026-02-01 (na bocznej gałęzi migracyjnej):
- 17:40 „migrate to opentofu”: katalog `OpenTofu/` (backend, Oracle, zmienne), workflow `opentofu.yaml` z `opentofu/setup-opentofu`, skrypt `lint-opentofu.sh` [commit `afad10b`, 2026-02-01]. Wieczorem poprawki workflow [commit `f1d3f46`, 2026-02-01].
- 23:36 „migrate to terraform”: katalog usunięty, workflow i SETUP.md wróciły do `terraform` [commit `06e540f`, 2026-02-01].
- Czy OpenTofu był faktycznie użyty: API GitHub Actions nie pokazuje 2026-02-01 żadnego uruchomienia poza Dependabotem, a na `main` workflow nie miały wyzwalaczy od 2025-12-17. Workflow `opentofu.yaml` istniał zresztą tylko na bocznej gałęzi [GitHub API `actions/runs?created=2026-02-01..2026-02-02`, odczyt 2026-11-27] [commit `f3f7297`, 2025-12-17]. Lokalnego `tofu apply` repo nie potwierdza ani nie wyklucza [nieznane] (pytanie 1).
- [wniosek] Prawdopodobny powód drugiego powrotu: `OpenTofu/backend.tf` deklarował `backend "oci" {}`, a OpenTofu nie ma takiego backendu. Dokumentacja OpenTofu wymienia tylko azurerm, consul, cos, gcs, http, kubernetes, local, oss, pg, remote i s3, a backendów nie da się dodać wtyczką [źródło: https://opentofu.org/docs/language/settings/backends/configuration/, dostęp 2026-11-27]. Commit powrotny od razu przywraca w `Terraform/backend.tf` `backend "oci"` z `required_version >= 1.11.4` [commit `06e540f`, 2026-02-01]. „OCI” w OpenTofu 1.10 oznacza rejestry kontenerów (Open Container Initiative) jako źródło providerów, nie Oracle [źródło: https://opentofu.org/blog/opentofu-1-10-0/, dostęp 2026-11-27]. To wniosek; autor powodu nie zapisał.
- [wniosek] Drugi epizod nadaje się do pracy jako przykład, że o wyborze narzędzia IaC zdecydowała dostępność backendu stanu u używanego dostawcy chmury. Licencja (BUSL kontra MPL) nie przeważyła, choć autor dwa razy próbował OpenTofu.

### Licencja i alternatywy

| Narzędzie | Licencja / zarządzanie | Ograniczenia istotne dla homelabu | Źródło |
|---|---|---|---|
| Terraform (wybrany) | Od 2023-08-10 BUSL 1.1 (wcześniej MPL 2.0); API i SDK zostały na MPL. Licencjodawcą jest dziś IBM Corp.; każda wersja przechodzi na MPL 2.0 po 4 latach. IBM zamknął przejęcie HashiCorp 2025-02-27. | Additional Use Grant zakazuje oferowania Terraform stronom trzecim „on a hosted or embedded basis in order to compete”. [wniosek] Prywatnego homelabu to nie dotyczy. Nixpkgs oznacza `terraform` jako niewolny (`bsl11`, `free = false`), więc flake w repo potrzebował `allowUnfreePredicate` [plik `flake.nix` w commicie `3b8be01`]. | https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license ; https://raw.githubusercontent.com/hashicorp/terraform/main/LICENSE ; https://newsroom.ibm.com/2025-02-27-ibm-completes-acquisition-of-hashicorp,-creates-comprehensive,-end-to-end-hybrid-cloud-platform ; https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/te/terraform/package.nix ; https://raw.githubusercontent.com/NixOS/nixpkgs/master/lib/licenses/licenses.nix (dostęp 2026-11-27) |
| OpenTofu | MPL-2.0; fork po zmianie licencji, w Linux Foundation od 2023-09-20; GA 1.6.0 2024-01-10; CNCF Sandbox od 2025-04-23 | Brak backendu `oci` (patrz wyżej). Ma za to funkcje, których Terraform nie ma: szyfrowanie stanu i planu od 1.7.0 (2024-04-30, klucze z PBKDF2, KMS, OpenBao), a od 1.10 natywne blokowanie stanu w S3. | https://github.com/opentofu/opentofu ; https://www.linuxfoundation.org/press/announcing-opentofu ; https://opentofu.org/blog/opentofu-is-going-ga/ ; https://www.cncf.io/projects/opentofu/ ; https://opentofu.org/blog/opentofu-1-7-0/ ; https://opentofu.org/docs/language/state/encryption/ (dostęp 2026-11-27) |
| Pulumi | Apache-2.0 | Infrastruktura w językach ogólnego przeznaczenia (TS/JS, Python, Go, .NET, Java, YAML). [wniosek] Większy próg wejścia niż HCL i mniej gotowych providerów niszowych (np. *arr) bez mostkowania z Terraformem; tego nie weryfikowałem. | https://github.com/pulumi/pulumi ; https://www.pulumi.com/docs/iac/languages-sdks/ (dostęp 2026-11-27) |
| Crossplane | Apache 2.0; CNCF Graduated od 2025-10-28 | Instaluje się „into an existing Kubernetes cluster”, więc nie stworzy klastra, w którym sam działa. Tu klaster trzeba najpierw postawić (Proxmox + Talos). | https://www.cncf.io/projects/crossplane/ ; https://docs.crossplane.io/latest/get-started/install/ (dostęp 2026-11-27) |

Kiedy wybrać coś innego:
- OpenTofu, gdy liczy się licencja open source albo szyfrowanie stanu, a backend jest na liście OpenTofu (np. S3).
- Pulumi, gdy zespół woli pisać infrastrukturę w znanym języku programowania.
- Crossplane, gdy klaster już istnieje i zasoby chmurowe mają być uzgadniane ciągle, jak manifesty Kubernetesa.

### Ograniczenia napotkane w repo
- Auto-apply na `main` i dryf. Od 2026-05-23 apply rusza przy każdym zdarzeniu na `main` (push lub `workflow_dispatch`), jeśli plan coś zmienia [commit `ffea00e`, 2026-05-23]. Zmiany wprowadzone ręcznie, np. przy odbudowie węzła GPU, mogą sprawić, że następny push wygeneruje plan niszczący [plik `CLAUDE.md`, Key Gotchas „Terraform CI auto-applies on main branch”]. Stąd reguła z 2026-08-19: plan i apply lokalnie, CI tylko potwierdza. Commit podaje konkretny przypadek: StorageClass, którą zarządzał longhorn-manager i jednocześnie deklarowało repo, z niezmiennymi parametrami, które się różniły [commit `111db10`, 2026-08-19].
- Token GitHub App. Provider `github` czyta zmienne i sekrety repozytorium, a domyślny `GITHUB_TOKEN` na to nie wystarcza [plik `CLAUDE.md`, Key Gotchas]. Dokumentacja GitHub to potwierdza: lista uprawnień `permissions:` nie ma zakresu `variables` ani `secrets`, a endpoint `actions/variables` wymaga uprawnienia aplikacji „Variables: read” [źródło: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax, dostęp 2026-11-27] [źródło: https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps, dostęp 2026-11-27]. Historia: wprowadzenie 2026-02-26 („resolve 403 errors”) [commit `9e54672`, 2026-02-26]; 2026-05-23 usunięty jako „broken” [commit `1175624`, 2026-05-23] i w ciągu kilku minut przywrócony, z wyjaśnieniem, że główny workflow potrzebuje tokenu aplikacji [commit `484e046`, 2026-05-23].
- Wykrywanie adresów w CI. Workflow sam szuka adresu Proxmoxa (`carbon`) i API Talosa w `tailscale status` [plik `.github/workflows/terraform.yaml`]. Skraca też keepalive TCP, bo podczas restartu przy aktualizacji Talos wyłącza Tailscale przed apid i strumień zdarzeń providera wisiałby do 2 h (komentarz w workflow) [plik `.github/workflows/terraform.yaml`].
- Zmiana konfiguracji kubeleta położyła wszystkie węzły naraz, bo łańcuch modułów serializuje tylko aktualizacje OS, nie zmiany konfiguracji [plik `CLAUDE.md`, Key Gotchas „Adding `shutdownGracePeriodByPodPriority`…”].
- Plan jest szyfrowany (`gpg --symmetric`) przed zapisaniem jako artefakt, bo zawiera wartości wrażliwe [plik `.github/workflows/terraform.yaml`].

## 4. Ansible

### Rola
Dziś Ansible konfiguruje tylko to, czego nie obejmuje Terraform ani Talos [plik `Ansible/setup-proxmox.yaml`] [plik `Ansible/maintenance.yaml`] [plik `Ansible/setup-personal.yaml`]:
- host Proxmox `carbon`: serwer NFS z testami montowania, sysctl forwardingu dla exit node Tailscale, TLP, hd-idle, powertop, wyłączanie nieużywanych urządzeń, alerty smartd/ZFS na Discord, logowanie konsoli szeregowej VM, passthrough drukarki do talos-2;
- aktualizacje Proxmoxa (`maintenance.yaml`);
- unattended-upgrades na urządzeniach osobistych.

Inwentarz jest dynamiczny: `inventory_tailscale.py` buduje grupy z tagów urządzeń w `tailscale status --json`, więc działa z dowolnego miejsca w tailnecie, także z runnera GitHub [commit `ecfff6f`, 2026-02-19] [plik `Ansible/inventory_tailscale.py`].

### Od kiedy i co zastąpił
- Od 2025-07-26 [commit `162b32c`, 2025-07-26]. Wcześniej konfigurację hosta robiły skrypty powłoki (`install.sh`, `scripts/`) [wniosek, na podstawie szkieletu osi czasu].
- E3: Ansible instalował k3s w kontenerach LXC (`Ansible/k3s.yaml`) oraz sterowniki NVIDIA [plik `Ansible/k3s.yaml` w commicie `bc91666^`]. Przy migracji na Talos te playbooki usunięto na bocznej gałęzi [commit `bc91666`, 2025-12-17]; z `main` zniknęły przy scaleniu [commit `327eff3`, 2026-02-26]. Konfigurację węzłów przejęła konfiguracja maszyn Talos generowana przez Terraform.
- Inwentarz: najpierw statyczny szablon z Terraformu (`Terraform/Templates/inventory-static.tpl`) [commit `6930efc`, 2025-07-26], potem plik w OCI [commit `9cc822b`, 2025-07-31], od 2026-02-19 skrypt Tailscale.

### Alternatywy

| Narzędzie | Licencja / zarządzanie | Uwagi | Źródło |
|---|---|---|---|
| Ansible (wybrany) | GPL-3.0-or-later, sponsor Red Hat | Bezagentowy (SSH). [wniosek] Pasuje do jednego hosta Proxmox, do którego i tak jest SSH przez Tailscale. | https://github.com/ansible/ansible (dostęp 2026-11-27) |
| Salt | Apache 2.0; po przejęciu VMware przez Broadcom zarządza nim Broadcom | Pod koniec października 2024 przeniesiono repozytoria pakietów do packages.broadcom.com, co zepsuło skrypty instalacyjne. Zespół zmniejszono w 2024, część komponentów oddano społeczności. | https://github.com/saltstack/salt ; https://saltproject.io/blog/upcoming-salt-project-docs-and-repo-migration/ ; https://saltproject.io/blog/2025-01-16-open-hour/ (dostęp 2026-11-27) |
| Chef (Progress) | Kod Apache 2.0, ale binaria „require a license and aren't considered open source” (EULA); darmowy plan tylko do użytku niekomercyjnego lub osobistego | Agent na każdym węźle, Ruby DSL | https://github.com/chef/chef ; https://docs.chef.io/licensing/ (dostęp 2026-11-27) |
| Puppet (Perforce) / OpenVox | Od 2025 nowe binaria Puppet w prywatnym repozytorium (EULA, powyżej 25 węzłów licencja komercyjna); kod nadal Apache 2.0. OpenVox (Vox Pupuli) to zamiennik „drop-in”, pierwsze wydanie 2025-01-21. | Model agent-serwer, cięższy dla jednego hosta [wniosek] | https://www.puppet.com/blog/open-source-puppet-updates-2025 ; https://voxpupuli.org/blog/2025/01/21/openvox-release/ (dostęp 2026-11-27) |
| cloud-init | GPLv3 lub Apache 2.0 do wyboru (Canonical) | Działa przy pierwszym uruchomieniu; [wniosek] nie pilnuje dryfu później. | https://raw.githubusercontent.com/canonical/cloud-init/main/LICENSE (dostęp 2026-11-27) |
| Konfiguracja maszyn Talos | Talos Linux: MPL-2.0 | „No SSH, no shell, no package manager”, cała konfiguracja w jednym manifeście YAML, zarządzanie przez API gRPC z mTLS. W tym repo zastąpiła Ansible na węzłach Kubernetesa. | https://www.siderolabs.com/talos-linux/ ; https://docs.siderolabs.com/talos/latest/learn-more/philosophy (dostęp 2026-11-27) |

Kiedy wybrać coś innego: przy dziesiątkach serwerów z ciągłym wymuszaniem stanu sprawdzi się model agentowy (Salt, Puppet/OpenVox). Przy samych maszynach wirtualnych ustawianych raz wystarczy cloud-init. Gdy węzły służą tylko Kubernetesowi, system niezmienny typu Talos usuwa potrzebę zarządzania konfiguracją w ogóle.

### Ograniczenia napotkane w repo
- Proxmox pozwala na surowy `usb: host=` tylko kontu root@pam, dlatego passthrough drukarki robi Ansible (`qm set` z warunkiem idempotencji), a nie Terraform [plik `CLAUDE.md`, Key Gotchas „The Pagewire printer…”].
- `pveupgrade` przerywa się bez TTY, więc automatyzacja wywołuje `pveupdate` i `apt-get dist-upgrade` przez moduł `apt` [plik `CLAUDE.md`, Key Gotchas] [PR #761].
- Wyjście `iptables-save` nigdy nie jest identyczne między uruchomieniami (data, liczniki), więc play musi je oczyszczać, inaczej zawsze raportuje `changed` [plik `CLAUDE.md`, Key Gotchas].
- Wybór playbooka w CI zależy od zmienionych plików (`git diff` względem `github.event.before`). Push, który nie zmienia obsługiwanego pliku, kończy się błędem [plik `.github/workflows/ansible.yaml`].

## 5. Kustomize i Helm

### Rola
Każdy katalog w `Kubernetes/` ma `kustomization.yaml`; root łączy `bootstrap/` i `apps/` i wstrzykuje adres serwera NFS przez `replacements` [plik `Kubernetes/kustomization.yaml`]. Charty Helm nie są instalowane przez `helm install`: 12 komponentów infrastruktury (Argo CD, Authentik, CrowdSec, External Secrets, Intel GPU, Longhorn, MetalLB, metrics-server, obserwowalność, Reloader, operator Tailscale, Traefik) jest renderowanych przez `helmCharts:` w Kustomize [`git grep helmCharts: main -- Kubernetes`]. Argo CD uruchamia Kustomize z `--enable-helm` [plik `Kubernetes/bootstrap/argocd/patches/argocd-cm.yaml`].

### Historia
- `kubectl kustomize Kubernetes/ --enable-helm | kubectl apply` w CI już w E3 [commit `06ecf16`, 2025-09-12].
- 2026-02-24 część komponentów (Argo CD, Longhorn, Reloader) przeszła z surowych manifestów na charty Helm [commit `b4e151c`, 2026-02-24].

### Alternatywy

| Narzędzie | Licencja / status | Uwagi | Źródło |
|---|---|---|---|
| Kustomize (wybrany jako warstwa główna) | wbudowany w kubectl od 1.14 (`kubectl apply -k`) | Binarka samodzielna wychodzi częściej niż wersja w kubectl. Repo wymaga kustomize ≥ v5.8.1 [plik `scripts/lint-kubernetes.sh`]. | https://kubernetes.io/blog/2019/03/25/kubernetes-1-14-release-announcement/ (dostęp 2026-11-27) |
| Helm (używany przez Kustomize) | CNCF Graduated od 2020-05-01; Helm 4.0.0 wydany 2025-11-12; Helm 3 dostaje poprawki bezpieczeństwa do 2026-11-11, czyli ten termin już minął | Repo przypina Helm 4.3.2 [plik `.mise.toml`] | https://www.cncf.io/projects/helm/ ; https://helm.sh/blog/helm-4-released (dostęp 2026-11-27) |
| Jsonnet / Tanka | Apache-2.0 (google/jsonnet; Grafana Tanka) | Pełny język z funkcjami; [wniosek] większy próg wejścia i mniej gotowych pakietów niż charty | https://github.com/google/jsonnet ; https://github.com/grafana/tanka (dostęp 2026-11-27) |

Kiedy wybrać coś innego: samym Helmem (np. umbrella chart), gdy wszystko i tak pochodzi z chartów i potrzebne są `helm rollback` i historia wydań. Jsonnet/Tanka, gdy jest dużo podobnych środowisk generowanych z kodu.

### Ograniczenia napotkane w repo
- Chart CrowdSec generuje losowy sekret przy każdym renderze, więc Argo CD nigdy nie jest zsynchronizowane [plik `CLAUDE.md`, Key Gotchas].
- Ten sam chart nie ustawia `metadata.namespace`, a transformer `namespace:` Kustomize nie działa na jego wyjściu; potrzebne są łaty JSON 6902 [plik `CLAUDE.md`, Key Gotchas].
- Helm przyjmuje bez błędu nieznane klucze wartości. Klucz pod złą nazwą (`operator` zamiast `operatorConfig` w operatorze Tailscale) po cichu przepadł; weryfikacja to `kustomize build | grep` [plik `CLAUDE.md`, Key Gotchas].

## 6. Argo CD (app-of-apps)

### Rola
Jedna aplikacja Argo CD `app-of-apps` wskazuje na ścieżkę `Kubernetes` w gałęzi `main` i renderuje całe drzewo, łącznie z samym Argo CD. Ma `automated: {prune: true, selfHeal: true}`, `PruneLast=true` i 5 ponowień [plik `Kubernetes/bootstrap/argocd/app-of-apps.yaml`]. W repo nie ma innych obiektów `Application` ani `ApplicationSet` [`git grep 'kind: Application' main`]. [wniosek] Mimo nazwy nie jest to klasyczny wzorzec „aplikacja tworzy aplikacje”, tylko jedna aplikacja dla całego repo, zarządzająca też sobą. Własna reguła zdrowia (Lua) w `argocd-cm` oznacza `app-of-apps` jako Degraded, gdy któryś zasób nie jest Synced, z pominięciem zasobów czekających na prune [plik `Kubernetes/bootstrap/argocd/patches/argocd-cm.yaml`]. Logowanie tylko przez OIDC Authentik, konto admin wyłączone [ten sam plik].

### Od kiedy i co zastąpił
- E2: push z CI przez Tailscale SSH i `docker compose up` [commit `9de8f42`, 2024-07-14].
- E3: push z CI na k3s (`kubectl apply`), kubeconfig kopiowany przez `scp` z węzła [plik `.github/workflows/kubernetes.yaml` w commicie `bc91666^`].
- E4: Argo CD od migracji 2026-02-01 na bocznej gałęzi [commit `6757719`, 2026-02-01], na `main` od scalenia 2026-02-26 [commit `327eff3`, 2026-02-26]. Plan migracji z 2025-12-17 wymienia „GitOps with ArgoCD for application deployment” jako stan docelowy, a przejściowy workflow `kubectl apply` „will eventually be automated by ArgoCD on Git push” [plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` w commicie `bc91666`]. Dlaczego Argo CD, a nie Flux, plan nie mówi [nieznane] (pytanie 5).
- W E3 przez 9 dni (2025-08-16 → 2025-08-25) w repo leżał jeden obiekt `Application` dla nvidia-device-plugin [commit `1b4af72`, 2025-08-16] [commit `580e44a`, 2025-08-25]. Instalacji Argo CD w tamtym drzewie nie ma [nieznane] (pytanie 6).

### Alternatywy

| Narzędzie | Licencja / zarządzanie | Uwagi | Źródło |
|---|---|---|---|
| Argo CD (wybrany) | Apache-2.0; CNCF Graduated 2022-12-06 | Ma interfejs WWW i SSO (tu Authentik), widok drzewa zasobów, ręczny sync | https://github.com/argoproj/argo-cd ; https://www.cncf.io/projects/argo/ (dostęp 2026-11-27) |
| Flux CD | Apache-2.0; CNCF Graduated 2022-11-30 | Firma Weaveworks, główny sponsor Fluxa, ogłosiła zamknięcie 2024-02-05; projekt trwa dalej („Flux isn't dying”, CNCF, 2024-04-08). [wniosek] Brak wbudowanego GUI. | https://github.com/fluxcd/flux2 ; https://www.cncf.io/projects/flux/ ; https://techcrunch.com/2024/02/05/cloud-native-container-management-platform-weaveworks-shuts-its-doors/ ; https://www.cncf.io/news/2024/04/08/the-new-stack-why-flux-isnt-dying-after-weaveworks/ (dostęp 2026-11-27) |
| Push z CI (`kubectl apply`, jak w E3) | brak | CI potrzebuje poświadczeń do klastra i dostępu sieciowego. Nie wykrywa dryfu między pushami. | [plik `.github/workflows/kubernetes.yaml` w commicie `bc91666^`] [wniosek] |

Kiedy wybrać coś innego: Flux, gdy GUI jest zbędne, a ważniejsze są mniejsze zużycie zasobów i składanie z kontrolerów. Push z CI, gdy klaster jest jednorazowy albo testowy.

### Ograniczenia napotkane w repo
- Argo CD nie może być pierwszym elementem w pustym klastrze. Bootstrap przechodzi ręcznie przez `scripts/apply-kubernetes.sh` warstwa po warstwie (MetalLB, Reloader, Longhorn, ESO, Traefik, CrowdSec, Tailscale, …), dopiero potem aplikacje, Terraform `apps`, a Argo CD na końcu [plik `SETUP.md`, sekcja Bootstrap Runbook]. Skrypt robi `kubectl apply --server-side --force-conflicts` z 3 ponowieniami [plik `scripts/apply-kubernetes.sh`].
- Duże CRD wymagały server-side apply [commit `65b252c`, 2026-02-26]. Niezmienny szablon PVC w StatefulSecie Mimira blokował sync [commit `5dd5867`, 2026-02-28].
- Incydent z historii: przebudowa app-of-apps przez zmianę nazw i struktury zasobów skończyła się utratą danych. Stąd zakazy usuwania i odtwarzania zasobów zarządzanych przez Argo CD [plik `CLAUDE.md`, Key Gotchas „Critical incident history”]. Daty incydentu w repo nie ma [nieznane] (pytanie 7).
- `prune: true` oznacza, że usunięcie pliku z repo usuwa zasób z klastra; [wniosek] dla PVC to ryzyko utraty danych, co tłumaczy powyższe zakazy.

## 7. GitHub Actions i `act`

### Workflow na `main`

| Plik | Wyzwalacz | Co robi |
|---|---|---|
| `terraform.yaml` | push/PR na `main` w `Terraform/**` (bez `apps`) i `Tailscale/**`, `workflow_dispatch` | sekrety z Bitwarden (`bitwarden/sm-action`), token GitHub App, Tailscale (`tag:ci`), wykrycie `carbon` i API Talosa, `fmt`/`validate`/`plan -detailed-exitcode`, zaszyfrowany plan jako artefakt; apply tylko poza PR i tylko z niepustym planem, limit 180 min |
| `terraform-apps.yaml` | push/PR w `Terraform/apps/**` | jak wyżej, plus kubeconfig przez `talosctl` i port-forward do aplikacji |
| `terraform-destroy.yaml` | tylko ręcznie | plan zniszczenia, apply za bramką akceptacji w środowisku `server` |
| `ansible.yaml` | push w wybranych plikach Ansible, ręcznie | `uv`, `ansible-galaxy`, SSH przez Tailscale, wybór playbooka |
| `ansible-lint.yaml`, `kubernetes-lint.yaml` | push/PR | `ansible-lint`; `kustomize build` + `kube-linter` |

[plik `.github/workflows/*.yaml`]. Wszystkie akcje są przypięte do SHA z komentarzem wersji [wniosek: efekt presetu Renovate `config:best-practices`, który przypina digesty; plik `renovate.json5` + preset].

Liczba uruchomień od początku istnienia plików (sukces / porażka): `terraform.yaml` 327/121, `terraform-apps.yaml` 171/55, `ansible.yaml` 51/9, `kubernetes-lint.yaml` 850/52, `ansible-lint.yaml` 112/6, `terraform-destroy.yaml` 0/0 [GitHub API `actions/workflows/<plik>/runs?status=…`, odczyt 2026-11-27]. [wniosek] Co czwarte uruchomienie Terraform kończy się błędem, co zgadza się z decyzją, żeby plan i apply robić najpierw lokalnie.

### `act`
- `.actrc` z obrazem `catthehacker/ubuntu:act-latest` od 2025-07-31 [commit `7b3ce98`, 2025-07-31], poprawka Tailscale w `act` [commit `1684c0a`, 2025-08-02], usunięty 2026-02-17 jako „unused” [commit `d294d1c`, 2026-02-17].
- `act` (MIT) ignoruje m.in. `concurrency`, `timeout-minutes`, `continue-on-error`, `permissions` i `environment`, a OIDC i kontekst `github` są niepełne [źródło: https://github.com/nektos/act, dostęp 2026-11-27] [źródło: https://nektosact.com/not_supported.html, dostęp 2026-11-27]. [wniosek] Workflow tego repo opierają się na Tailscale, sekretach i dostępie do domowej sieci, więc lokalna symulacja daje niewiele. Zastąpił ją lokalny `terraform plan` przez `mise` i `scripts/setup-env.sh`.

### Alternatywy CI

| System | Licencja / koszt | Uwagi | Źródło |
|---|---|---|---|
| GitHub Actions (wybrany) | runnery hostowane i self-hosted darmowe dla repozytoriów publicznych. Opłata $0.002/min za self-hosted, ogłoszona 2025-12-16, została odłożona bez nowej daty. | Repo i tak jest na GitHubie; gotowe akcje Tailscale, Bitwarden, Terraform | https://docs.github.com/en/billing/concepts/product-billing/github-actions ; https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/ (dostęp 2026-11-27) |
| GitLab CI | GitLab.com Free: 400 minut na grupę miesięcznie; własne runnery bez limitu; kod CE na MIT | Wymaga przeniesienia repo albo mirrora | https://about.gitlab.com/pricing/ ; https://gitlab.com/gitlab-org/gitlab-foss (dostęp 2026-11-27) |
| Forgejo Actions | Forgejo: GPLv3+ od v9.0 | Do samodzielnego hostowania; „not designed to be compatible” z GitHub Actions, migracja wymaga „minimal tweaking”; ignoruje job-level `permissions` i `continue-on-error` | https://codeberg.org/forgejo/forgejo ; https://forgejo.org/docs/latest/user/actions/overview/ ; https://forgejo.org/docs/latest/user/actions/github-actions/ (dostęp 2026-11-27) |
| Woodpecker CI | Apache-2.0; fork Drone 0.8 z 2019 | Mały: ok. 100 MB RAM serwer, 30 MB agent | https://woodpecker-ci.org/about (dostęp 2026-11-27) |

Kiedy wybrać coś innego: przy pełnej repatriacji, gdy także kod ma być u siebie, Forgejo z Forgejo Actions albo Woodpecker. [wniosek] Tu CI musi działać, gdy domowy serwer leży (odtwarzanie po awarii), więc runner hostowany poza domem jest zaletą.

## 8. Renovate (i Dependabot)

### Rola
Renovate otwiera PR-y z aktualizacjami obrazów, chartów Helm w `helmCharts`, providerów Terraform, akcji GitHub, hooków pre-commit i narzędzi z `.mise.toml`. Od 2026-05-03 konfiguracja jest w `renovate.json5` i rozszerza wspólny preset autora `local>ThePhaseless/renovate-config` [plik `renovate.json5`]. Preset ma [źródło: https://github.com/ThePhaseless/renovate-config, plik `default.json`, dostęp 2026-11-27]:
- `config:best-practices`, `minimumReleaseAge: 3 days`, alerty OSV;
- grupę „All non-major dependencies” z automerge;
- automerge dla lockfile maintenance i pre-commit.

Reguły lokalne w repo:
- Pagewire wyłączony, dopóki nie ma pierwszego wydania;
- filtr starych tagów qBittorrent;
- grupa `talos-cluster` (Talos + Kubernetes);
- podbicia minor/major Kubernetesa bez automerge, bo każdy minor Talosa ogranicza wersję Kubernetesa, a `upgrade-k8s` przechodzi o jeden minor naraz (komentarz w pliku) [plik `renovate.json5`].

Skala: 677 scalonych PR-ów Renovate od 2024-07-17 do 2026-11-23, wobec 20 PR-ów autora i 3 Dependabota [`gh pr list --state merged`, odczyt 2026-11-27].

### Historia i Dependabot
- Dependabot od 2024-02-08, tylko dla devcontainera [commit `44e2ac5`, 2024-02-08]. Renovate od 2024-07-17 [commit `5b2f015`, 2024-07-17].
- 2026-04-06 Dependabot usunięty. PR podaje powód wprost: Dependabot „was only watching devcontainers”, a Renovate „was also silently missing all images”, bo manager `kubernetes` domyślnie szuka ścieżek małymi literami, a repo ma `Kubernetes/` [PR #311] [commit `bd423ac`, 2026-04-06]. Commit ma `Agent-Logs-Url`, czyli przygotował go agent Copilot [commit `bd423ac`, 2026-04-06].
- Mimo usunięcia pliku Dependabot nadal otwierał PR-y bezpieczeństwa dla `uv.lock` (3 scalone, ostatni 2026-08-19) [`gh pr list --author app/dependabot`]. [wniosek] To alerty bezpieczeństwa włączone w ustawieniach repo, niezależne od `dependabot.yml`.
- Przynajmniej raz automerge grupy non-major trzeba było cofnąć [PR #271]. Repo nie podaje, co się zepsuło [nieznane].

### Alternatywy

| Narzędzie | Licencja | Pokrycie ekosystemów tego repo | Źródło |
|---|---|---|---|
| Renovate (wybrany) | AGPL-3.0-only, Mend.io | ma managery `mise` (z `mise.lock`) i `kustomize` (obrazy, bazy, `helmCharts`) | https://github.com/renovatebot/renovate ; https://docs.renovatebot.com/modules/manager/mise/ ; https://docs.renovatebot.com/modules/manager/kustomize/ (dostęp 2026-11-27) |
| Dependabot | usługa GitHub | Helm v3, Terraform ≤ 1.15.x, OpenTofu, Actions, Docker, pre-commit, uv; brak Kustomize i mise | https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories (dostęp 2026-11-27) |

Kiedy wybrać coś innego: Dependabot wystarczy w repo z samymi pakietami języka (npm, pip) i akcjami, bez Kustomize. [wniosek] Uwaga: Dependabot deklaruje Terraform do 1.15.x, a repo przypina 1.17.2 [plik `.mise.toml`].

## 9. pre-commit i lintery

| Narzędzie | Od kiedy | Gdzie działa | Licencja | Źródło licencji |
|---|---|---|---|---|
| pre-commit | 2026-02-24 [commit `067462b`] | lokalnie | MIT | https://github.com/pre-commit/pre-commit |
| ruff (format + check) | 2026-02-24 [commit `067462b`] | pre-commit | MIT, Astral | https://github.com/astral-sh/ruff |
| terraform fmt/validate, tflint | tflint w CI od 2025-07-26 [commit `6c341db`]; dziś w pre-commit i `mise run lint-terraform`; w CI zostały `terraform fmt -check` (z `continue-on-error`) i `validate` | lokalnie, CI | tflint: „MPL 2.0 + BUSL 1.1” (część plików z kodu Terraform); ruleset terraform MPL-2.0 | https://github.com/terraform-linters/tflint |
| kube-linter | 2026-02-01 [commit `6757719`] | CI `kubernetes-lint.yaml`, `mise run lint-kubernetes` | Apache 2.0 (StackRox/Red Hat) | https://github.com/stackrox/kube-linter |
| ansible-lint | 2025-07-26 [commit `6c341db`] | CI `ansible-lint.yaml`, `mise run lint-ansible` | rozpowszechniany jako GPL-3.0 | https://github.com/ansible/ansible-lint |
| prettier, check-yaml/json, detect-private-key | 2026-02-24 [commit `067462b`] | pre-commit | brak | [plik `.pre-commit-config.yaml`] |

(dostęp do źródeł licencji: 2026-11-27)

Konfiguracja:
- `.kube-linter.yaml` świadomie wyłącza m.in. `run-as-non-root`, `no-read-only-root-fs` i wymaganie limitów CPU/pamięci, każdorazowo z komentarzem [plik `.kube-linter.yaml`].
- Brak limitów jest decyzją projektową, która ma skutek opisany w Key Gotchas: OOM controller Talosa zabija najpierw pody BestEffort [plik `CLAUDE.md`, Key Gotchas „Containers dying with exit 137…”].
- `.tflint.hcl` włącza konwencję nazewnictwa oraz wymóg dokumentowania zmiennych i wyjść [plik `Terraform/.tflint.hcl`].

## 10. Środowisko dewelopera: devcontainer → Nix flake → mise, uv

| Okres | Rozwiązanie | Dowód |
|---|---|---|
| od 2024-02-08 (nadal w repo) | Dev Container (`.devcontainer/`): Dockerfile, rozszerzenia VS Code, feature'y terraform, actionlint, tailscale, `uv sync` | [commit `44e2ac5`, 2024-02-08] [plik `.devcontainer/devcontainer.json`] |
| od 2025-07-26 | uv + `pyproject.toml`/`uv.lock` dla Pythona (ansible-dev-tools, oci-cli, pre-commit); w CI `astral-sh/setup-uv` | [commit `7a357aa`, 2025-07-26] [commit `7fe8c71`, 2025-07-26] [plik `pyproject.toml`] |
| 2026-03-01 → 2026-05-03 | Nix flake (`nixos-unstable`) + direnv: uv, kubectl, kustomize, helm, kube-linter, terraform, tflint, tailscale, bws, jq; terraform i bws dopuszczone przez `allowUnfreePredicate` | [commit `3b8be01`, 2026-03-01] [commit `af843c0`, 2026-03-01] |
| od 2026-05-03 | mise: wersje narzędzi przypięte w `.mise.toml` + `mise.lock`, zadania `install`/`lint*`, `.env` ładowany automatycznie, venv tworzony przez uv | [commit `80cebb2`, 2026-05-03] [plik `.mise.toml`] |

- Powodu przejścia z Nix na mise commit nie podaje; ma dopisek „Co-authored-by: Copilot” [commit `80cebb2`, 2026-05-03] [nieznane] (pytanie 2).
- [wniosek] Możliwe czynniki widoczne w plikach: flake brał wszystko z `nixos-unstable` bez przypinania wersji pojedynczych narzędzi, a mise przypina każdą wersję. Renovate ma manager `mise`, a ten sam commit włącza w Renovate aktualizacje pre-commit [commit `80cebb2`]. Nix wymaga też włączenia funkcji eksperymentalnych `flakes`/`nix-command` [źródło: https://nix.dev/manual/nix/stable/development/experimental-features, dostęp 2026-11-27].
- Ograniczenie mise z Key Gotchas: mise ładuje tylko statyczne `.env` i `.venv`. Sekrety z Bitwarden i zmienne Tailscale trzeba za każdym razem wczytać przez `source scripts/setup-env.sh` [plik `CLAUDE.md`, Key Gotchas „Mise only auto-loads static repo env”] [commit `80cebb2`, 2026-05-03].

| Narzędzie | Licencja / status | Uwagi | Źródło |
|---|---|---|---|
| mise (wybrany) | MIT | „Dev tools, env vars, and tasks in one CLI”; czyta `.tool-versions`, ale „does not emulate asdf completely” | https://github.com/jdx/mise ; https://mise.jdx.dev/dev-tools/comparison-to-asdf.html |
| Nix flakes | flakes nadal oznaczone jako eksperymentalne | pełna powtarzalność, ale osobny język i wolne pakiety tylko przez wyjątki dla licencji niewolnych | https://nix.dev/manual/nix/stable/development/experimental-features |
| asdf | v0.16.0 (2025-01-30) przepisany w Go, ze zmianami niekompatybilnymi (`global`/`local` → `set`) | brak zadań i obsługi env w jednym narzędziu [wniosek] | https://github.com/asdf-vm/asdf/releases/tag/v0.16.0 ; https://asdf-vm.com/guide/upgrading-to-v0-16.html |
| Dev Containers | otwarta specyfikacja (CC-BY-4.0, kod MIT) | wymaga Dockera; dobre dla edytora, gorsze dla zwykłego terminala [wniosek] | https://containers.dev/ ; https://github.com/devcontainers/spec |
| uv | MIT/Apache-2.0, Astral; OpenAI ogłosiło 2026-03-19 zamiar przejęcia Astral (zamknięcia transakcji nie potwierdzono) | szybki menedżer pakietów i wersji Pythona | https://github.com/astral-sh/uv ; https://openai.com/index/openai-to-acquire-astral |

(dostęp do źródeł: 2026-11-27)

Kiedy wybrać coś innego: Nix, gdy potrzebna jest bitowa powtarzalność środowiska na wielu maszynach albo cały system jest na NixOS. Devcontainer, gdy zespół pracuje w VS Code/Codespaces i nie chce instalować niczego lokalnie.

[wniosek] Devcontainer został w repo, ale jego lista narzędzi (terraform, actionlint, tailscale) nie pokrywa `.mise.toml` (brak talosctl, kube-linter, helm). Wygląda na nieutrzymywany poza aktualizacjami od Renovate (pytanie 8).

### Agenci AI jako narzędzie dewelopera
Repo zawiera instrukcje dla agentów (`AGENTS.md` od 2026-02-01, `CLAUDE.md` od 2026-08-18) z sekcją Key Gotchas, którą agent ma uzupełniać po każdym nieoczywistym odkryciu [plik `CLAUDE.md`, sekcja „Maintaining These Docs”]. Ślady użycia:
- workflow Claude Code z 2025-10-31 [PR #174];
- PR agenta Copilot [PR #311];
- dopiski „Co-authored-by: Copilot” [commit `80cebb2`, 2026-05-03].

[wniosek] To element metody pracy wart jednego akapitu w pracy, bo Key Gotchas jest zarazem dziennikiem decyzji.

## 11. Przepływ zmiany od commita do działającej usługi

### A. Zmiana w Kubernetesie (aplikacja, chart, konfiguracja)
1. Edycja manifestu w `Kubernetes/…`. Lokalnie `mise run lint-kubernetes`, czyli `kustomize build --enable-helm` + `kube-linter` [plik `.mise.toml`] [plik `scripts/lint-kubernetes.sh`]. Przy commicie uruchamia się pre-commit (yaml, prettier, wykrywanie kluczy) [plik `.pre-commit-config.yaml`].
2. `git push` na `main` (albo PR). CI `kubernetes-lint.yaml` powtarza lint [plik `.github/workflows/kubernetes-lint.yaml`].
3. Argo CD widzi nowy commit w `main` i renderuje `Kubernetes/` z `--enable-helm`. `selfHeal` cofa ręczne zmiany w zarządzanych polach, `prune` usuwa zasoby skasowane z repo, `PruneLast` robi to na końcu [plik `Kubernetes/bootstrap/argocd/app-of-apps.yaml`] [plik `Kubernetes/bootstrap/argocd/patches/argocd-cm.yaml`].
4. Sekrety nie są w repo. ExternalSecret pobiera je z Bitwarden przez ESO [plik `CLAUDE.md`, sekcja Conventions]. Reloader restartuje pody po zmianie ConfigMap lub Secretu [wniosek: komponent `Kubernetes/bootstrap/reloader`].
5. Zmiana jest gotowa, gdy Argo CD pokazuje Synced/Healthy. Tymczasowe poprawki ręczne są dozwolone tylko tam, gdzie Argo CD ich nie cofnie [plik `CLAUDE.md`, sekcja Workflow].

### B. Zmiana infrastruktury (Terraform, root `Terraform/`)
1. `source scripts/setup-env.sh` (sekrety z Bitwarden), `terraform plan`, a potem `terraform apply` lokalnie: to jest kontrola dryfu [plik `CLAUDE.md`, sekcja Workflow] [commit `111db10`, 2026-08-19]. Pre-commit: `terraform_fmt`, `terraform_validate`, `terraform_tflint`.
2. Push. CI `terraform.yaml` wykonuje plan; na PR na tym się kończy.
3. Na `main`, jeśli plan nie jest pusty (`-detailed-exitcode` = 2), job `apply` odszyfrowuje plan i wykonuje go z `-auto-approve -lock-timeout=10m`. Po lokalnym apply plan w CI powinien być pusty, więc CI tylko potwierdza [plik `.github/workflows/terraform.yaml`] [commit `ffea00e`, 2026-05-23].
4. Zmiana konfiguracji Talosa trafia na węzły przez provider Talos. Aktualizacja OS przechodzi węzeł po węźle z bramkami Longhorna [commit `feb2ee9`, 2026-10-02]. Przed planowanym restartem węzła trzeba zrobić drain [plik `CLAUDE.md`, sekcja Workflow].

### C. Konfiguracja aplikacji (root `Terraform/apps/`)
To samo co B, ale lokalnie potrzebny jest `./scripts/port-forward-apps.sh`, a CI sam generuje kubeconfig przez `talosctl` i port-forward [plik `CLAUDE.md`, sekcja Workflow] [plik `.github/workflows/terraform-apps.yaml`]. Kolejność wynika z bootstrapu: aplikacja musi już działać w klastrze, zanim Terraform ją skonfiguruje [plik `SETUP.md`, kroki F i G].

### D. Host Proxmox (Ansible)
Push zmiany w `Ansible/setup-proxmox.yaml`, `vars/proxmox.yaml`, `maintenance.yaml` lub `inventory_tailscale.py` uruchamia `ansible.yaml`. Workflow wybiera playbook na podstawie zmienionych plików i wykonuje go przez Tailscale SSH [plik `.github/workflows/ansible.yaml`].

### E. Aktualizacje zależności
Renovate otwiera PR. Grupa non-major i lockfile maintenance scalają się automatycznie po 3 dniach od wydania. Dalej zmiana płynie ścieżką A, B lub D zależnie od pliku [plik `renovate.json5` + preset]. [wniosek] Automerge na `main` w połączeniu z auto-apply oznacza, że podbicie providera Terraform może zostać zastosowane bez udziału człowieka; łagodzi to tylko `minimumReleaseAge` i to, że plan w CI musi przejść.

### Porównanie z wcześniejszymi okresami

| Okres | Model | Kto ma poświadczenia do serwera | Wykrywanie dryfu |
|---|---|---|---|
| E1 | ręcznie / skrypty | człowiek | brak |
| E2 | push: CI → Tailscale SSH → `docker compose up` | CI (Tailscale OAuth, SSH) | brak |
| E3 | push: CI → `kubectl apply` na k3s, Terraform + Ansible z CI | CI (kubeconfig z `scp`) | brak dla k8s; `terraform plan` |
| E4-E5 | pull: Argo CD dla k8s; Terraform lokalnie + CI; Ansible z CI | Argo CD w klastrze; CI tylko dla Terraform/Ansible | Argo CD (ciągle), `terraform plan` (przy zmianie) |

[commit `9de8f42`, 2024-07-14] [commit `06ecf16`, 2025-09-12] [commit `6757719`, 2026-02-01] [wniosek: kolumny 3-4]

## Pytania do autora

1. OpenTofu pojawił się w repo dwa razy i za każdym razem został wycofany tego samego dnia: 2025-07-26 (lock file z `tofu init`, powrót po 13 minutach) i 2026-02-01 (katalog `OpenTofu/`, powrót po 6 godzinach). Co przesądziło o powrocie za pierwszym razem? Czy za drugim był to brak backendu `oci` w OpenTofu? Czy 2026-02-01 coś zostało zastosowane przez `tofu apply`?
2. Dlaczego 2026-05-03 środowisko dewelopera przeszło z Nix flake + direnv na mise? (np. przypinanie wersji, obsługa przez Renovate, wolne `nix develop`, praca na maszynie bez Nix)
3. Czy przeniesienie stanu `Terraform/apps` z sekretu Kubernetesa do OCI (2026-06-23, commit „recovery”) nastąpiło po realnej utracie stanu przy odbudowie klastra? Jeśli tak, kiedy i co trzeba było odtworzyć?
4. Dlaczego przy migracji na Talos zmieniono provider Proxmoxa z `Telmate/proxmox` na `bpg/proxmox`?
5. Dlaczego Argo CD, a nie Flux CD? Czy liczył się interfejs WWW z SSO, czy znajomość narzędzia?
6. Czy w E3 (sierpień 2025) Argo CD był zainstalowany na k3s ręcznie, skoro w repo był obiekt `Application` dla nvidia-device-plugin, ale bez instalacji Argo CD?
7. Kiedy wydarzył się incydent z utratą danych po przebudowie app-of-apps (Key Gotchas „Critical incident history”) i co dokładnie zginęło?
8. Czy devcontainer jest jeszcze używany, czy można go w pracy opisać jako porzucony etap?
9. Dlaczego do konfiguracji Jellyfin powstał własny provider Terraform (`ThePhaseless/jellyfin`) i czy jest opublikowany w Terraform Registry?
10. Co zepsuła automatycznie scalona aktualizacja cofnięta w PR #271 (2026-02-27)?
11. Czy rozbieżność w `Terraform/AGENTS.md` (backend `kubernetes` dla `apps`, a w kodzie `oci`) ma zostać poprawiona przed oddaniem pracy? Repo jest cytowane jako źródło.

## Do której części pracy

- Technologie: sekcje 3-10 (rola, licencje, tabele alternatyw, „kiedy wybrać coś innego”).
- Projekt: sekcja 1 (podział odpowiedzialności), sekcja 3 (dwa rooty i stan w OCI), sekcja 11 (przepływ zmiany i porównanie modeli push/pull).
- Implementacja: sekcje 3, 4, 6, 7 (workflow, bootstrap, moduł `talos-node`, ograniczenia napotkane w repo).
- Odtwarzanie po awarii: stan Terraform w OCI (sekcja 3), bootstrap przez `apply-kubernetes.sh` przed Argo CD (sekcja 6), CI poza domem (sekcja 7), `terraform-destroy.yaml` z bramką akceptacji.
- Analiza kosztów: koszty narzędzi = 0 zł dla repo publicznego (GitHub Actions, Renovate); ryzyko licencyjne Terraform BUSL (sekcja 3) i ewentualnej opłaty za runnery self-hosted (sekcja 7).
- Podsumowanie: epizody OpenTofu (zwłaszcza drugi) jako przykład, że o wyborze narzędzia zdecydowało dopasowanie do dostawcy (backend stanu), mimo że licencja przemawiała za OpenTofu.

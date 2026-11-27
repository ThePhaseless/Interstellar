# Pytania do autora

Na te pytania repo nie odpowiada: brakuje w nim motywów decyzji, cen, faktur i wydarzeń spoza gita. Odpowiedzi trafią do pracy, głównie do rozdziałów 1 (wstęp), 5 (odtwarzanie po awarii) i 6 (analiza kosztów). Lista łączy sekcje „Pytania do autora” z 11 plików bazy wiedzy; przy każdym pytaniu w nawiasie są pliki, z których pochodzi.

Plik jest publiczny. W odpowiedziach nie wpisuj haseł, tokenów, danych osobowych ani domowego adresu IP.

## Najpierw

Bez tych odpowiedzi nie da się zamknąć rozdziałów 5 i 6 albo podjąć decyzji o teście.

- [ ] Na jakim sprzęcie działa `carbon`? README (2025-03, nadal na `main`) podaje Intel i5-12600K, 32 GB RAM, iGPU UHD 770, „1TB NVMe” i węzły po 8 vCPU / 16 GB. Plan migracji na Talosa (commit `bc91666`, 2025-12-17) i specyfikacja energii z 2026-06 podają AMD Ryzen 9 3950X na płycie MSI MS-7C37, około 64 GB RAM, Intel Arc B580 i 2 × 1 TB NVMe; repo wspomina też kontrolery FCH (AMD). Która konfiguracja jest aktualna? Jeśli i5 to wcześniejsza maszyna, kiedy ją wymieniono i dlaczego? Jaki sprzęt był serwerem w 2024 roku (CPU, RAM, GPU, dyski) i czy to ten sam komputer co dzisiejszy `carbon`? Czy README z węzłami 8 vCPU / 16 GB jest po prostu nieaktualne wobec `Terraform/variables.tf` (dziś 4/16, 6/12, 6/12)? (historia/01, historia/03, historia/04, historia/05, technologie/01, odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Czy konto Oracle Cloud jest w trybie Free Tier, czy Pay As You Go? Pliki bazy wiedzy podają, że od 2026-06-15 darmowy limit A1 wynosi 2 OCPU / 12 GB. Do 2026-08-20 działały dwie VM: `oracle-proxy` (HAProxy, 1 OCPU / 6 GB) i `compute` (3 OCPU / 18 GB). Commit `7158f21` (2026-08-20, PR #567) usunął `oracle-proxy` i podniósł `compute` do 4 OCPU / 24 GB. Czy OCI naliczało opłaty od czerwca, w którym z tych dwóch układów, i czy budżet `free-tier-guard` zgłosił przekroczenie? (technologie/01, technologie/05, odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Które płatne usługi miałeś przed homelabem lub w trakcie (np. Netflix, Disney+, HBO Max, SkyShowtime, Prime, Spotify, Google One / Zdjęcia Google, iCloud+, Dropbox, Microsoft 365, Plex Pass, NextDNS, VPN, hosting serwerów gier), ile za każdą płaciłeś miesięcznie, z których zrezygnowałeś dzięki homelabowi i kiedy (miesiąc i rok)? (technologie/05, odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Który sprzedawca i który dystrybutor (OSD) energii obsługują lokalizację serwera, jaka jest taryfa (G11, G12, G12w, inna) i jaka cena za kWh wynika z ostatniej faktury (z opłatami dystrybucyjnymi)? (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Czy możesz wyeksportować z Home Assistanta historię `sensor.serwer_current_consumption` za ostatnie 30-90 dni (średnia moc i kWh)? Jakie urządzenia poza serwerem są podłączone do tej wtyczki? (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Który wariant testu odtworzenia po awarii jest akceptowalny: S1 (odbudowa jednego węzła), S2 (cały klaster), S3 (host od zera na zapasowym dysku)? Czy w trakcie testu dopuszczasz przestój dla innych użytkowników, a jeśli tak, jak długi i w jakich godzinach? (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Jak przedstawić w pracy Sonarr, Radarr, Prowlarr i qBittorrent: jako automatyzację legalnych źródeł (np. własnych płyt), jako opis czysto techniczny bez mówienia o źródle treści, czy pominąć tę część? (technologie/05)
  Odpowiedź:

- [ ] Ile kosztował każdy element serwera i kiedy go kupiłeś (CPU, płyta MSI MS-7C37, RAM, Arc B580, dyski)? Które części kupiłeś specjalnie na homelab, a które pochodzą z dawnego komputera? (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Na wypadek utraty domu: gdzie poza infrastrukturą leżą `BWS_ACCESS_TOKEN`, dane logowania do Bitwardena, Hetznera, OCI i Tailscale oraz hasło repozytorium Borg i klucz SSH do Storage Boxa? Czy istnieje kopia offline niezależna od Bitwardena i stanu Terraform? Bez hasła i klucza archiwa Borg są nie do odczytania. (technologie/04, odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Czy wykonałeś pełny test odtworzenia z Borga (np. archiwa `verifytest-*` z 2026-08), a jeśli tak, kiedy, co odtwarzałeś i ile to trwało? Czy przy którejś awarii zanotowałeś długość przestoju i odbudowy: przeinstalowanie hosta, odtworzenie ZVOL talos-1 w czerwcu 2026, padnięcie kubeleta 2026-08-19, zablokowany start 2026-08-31? (technologie/04, odtwarzanie-i-koszty)
  Odpowiedź:

## Stan sprzed repo i początki

- [ ] Od kiedy działał serwer przed pierwszym commitem (2024-01-01) i jakie usługi już na nim były (media, AdGuard, Samba, Portainer)? (historia/01)
  Odpowiedź:

- [ ] Skąd nazwy „Fireword”, „litwave” i „Interstellar”? Kiedy domena zmieniła się z `fireword.xyz` na `nerine.dev`? (historia/01)
  Odpowiedź:

- [ ] Skąd przerwa w commitach od kwietnia do połowy lipca 2024? Czy serwer był w tym czasie zmieniany ręcznie poza repo? (historia/01)
  Odpowiedź:

## Sprzęt i koszty

- [ ] Jaką kartę NVIDIA miał serwer w 2025 roku (sterownik 580.76.05 w LXC od commitu `02cbf60`, 2025-08-15)? Kiedy i dlaczego wymieniłeś ją na Intel Arc B580? (historia/03, technologie/01, technologie/05, odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Jakie są dokładne modele i daty zakupu dysków (5 × HDD 3 TB, 2 × NVMe 1 TB, NVMe 238 GiB dodany około 2026-08-31)? Jaki jest zasilacz i obudowa? (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Czy serwer ma UPS? Jeśli tak, jaki, i czy jest podłączony do tej samej wtyczki pomiarowej? (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Czy masz pomiary poboru mocy (W) hosta sprzed i po zmianach oszczędzających prąd z 2026 roku (hd-idle, `atime=off`, odłączenie Wi-Fi, TLP)? Czy odczyt wtyczki Tuya porównałeś kiedyś z niezależnym watomierzem? (historia/05, odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Ile kosztowały VPS-y przez cały okres: VPS z 2024 roku (czy to Oracle Always Free, ARM Ampere czy x86), `argon` z 2025 roku i `oracle-proxy` z HAProxy, wycofany 2026-08-20 (commit `7158f21`)? Jak długo szukano przyczyny rzekomej „blokady 80/443” przed tym wycofaniem? (historia/01, historia/05, technologie/03)
  Odpowiedź:

- [ ] U którego rejestratora jest domena `nerine.dev` i ile kosztuje rocznie? (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Na jakich planach są Cloudflare, Tailscale i Bitwarden Secrets Manager: darmowych czy płatnych? (odtwarzanie-i-koszty)
  Odpowiedź:

## Platforma

- [ ] Kiedy (między 2024-01 a 2025-03) i dlaczego serwer przeszedł z Ubuntu bez hypervisora na Proxmox VE z VM dla Dockera? Czy na decyzję wpłynęły zmiany licencji VMware/Broadcom albo porównanie z XCP-ng lub ESXi? Jaka jest dokładna wersja Proxmox VE dziś (wsparcie PVE 8 kończy się w 2026-08)? (historia/02, technologie/01)
  Odpowiedź:

- [ ] Kiedy i dlaczego Proxmox został przeinstalowany z ext4 na ZFS? Commit `a3383c1` (2026-09-21) opisuje `rpool` jako lustro NVMe: czy to potwierdzasz? Ile trwała odbudowa i co trzeba było odtworzyć ręcznie? (technologie/04, odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Co w lipcu 2025 przesądziło o przejściu z docker-compose na Terraform, Ansible i Kubernetes (k3s): nauka, praca inżynierska, wysoka dostępność, GitOps, coś innego? (historia/02, technologie/01)
  Odpowiedź:

- [ ] Ile węzłów miał klaster k3s w latach 2025-08 → 2026-01 i które hosty miały tagi Tailscale `server` i `agent`? Czy VPS `argon` był kiedykolwiek węzłem (agentem z Flannelem po `tailscale0`), czy klaster był tylko w LXC `nickel`? (historia/03, technologie/01)
  Odpowiedź:

- [ ] Ile z manifestów wygenerowanych przez kompose (commit `abcb648`, 2025-08-11) przetrwało ręczne poprawki z sierpnia 2025? Czy próbowałeś innych narzędzi do konwersji? (historia/03)
  Odpowiedź:

- [ ] Co skłoniło do przejścia z k3s w LXC na Talosa w VM (awaria, wydajność, utrzymanie, GPU, GitOps)? Czy było jakieś zdarzenie w grudniu 2025? Dlaczego Talos, a nie np. k3s w VM z Ubuntu, Flatcar albo RKE2, i czy porównywałeś je przed migracją? (historia/03, technologie/01)
  Odpowiedź:

- [ ] Co obsługiwało usługi w okresie przejściowym? Commit `bc91666` (2025-12-17) usunął kod k3s tylko na gałęzi migracyjnej, a na `main` kod został do scalenia `327eff3` (2026-02-26). Czy stary k3s działał do tego czasu? Kiedy Talos zaczął obsługiwać ruch produkcyjny: 2026-02-01, w trakcie lutego czy dopiero po scaleniu gałęzi 2026-02-26? (historia/04, technologie/01)
  Odpowiedź:

- [ ] Dlaczego trzy węzły control-plane na jednym hoście, a nie jeden węzeł: rolling upgrade, nauka HA, repliki Longhorna? (technologie/01)
  Odpowiedź:

- [ ] Dlaczego nie zrealizowano z planu migracji Longhorna na iSCSI z zvoli ZFS, osobnego VLAN-u dla klastra i ApplicationSets? (historia/04)
  Odpowiedź:

- [ ] Dlaczego commit `81d2c97` (2026-04-14, „scale down”) zmniejszył RAM węzłów z 16/12/12 do 10/8/8 GiB: z powodu prądu, potrzeb innych VM, czy czegoś innego? (historia/04)
  Odpowiedź:

- [ ] Dlaczego 2026-08-19 zdecydowałeś „no default memory requests” (commit `787476f` wycofał LimitRange), zamiast zostawić domyślne requesty pamięci? (historia/05)
  Odpowiedź:

- [ ] Jakie VM poza trzema węzłami Talosa działają na `carbon` (Home Assistant, inne) i ile mają RAM i vCPU? (historia/05, odtwarzanie-i-koszty)
  Odpowiedź:

## IaC i CI

- [ ] Skąd pochodziły pliki Terraform z 2025-07-26? Plik `.terraform.lock.hcl` z pierwszego commitu Terraform wygenerował `tofu init`, a 13 minut później pojawił się commit „migrate back to terraform”. Czy te pliki powstały pod OpenTofu w innym repo, czy w ogóle wcześniej używałeś Terraformu lub OpenTofu, i co przesądziło o powrocie do Terraformu? (historia/02, historia/03, technologie/02)
  Odpowiedź:

- [ ] Dlaczego 2026-02-01 przeszedłeś na OpenTofu (katalog `OpenTofu/`, commit `afad10b`, 17:40) i po sześciu godzinach wróciłeś do Terraformu (commit `06e540f`, 23:36)? Czy cokolwiek zostało wtedy zastosowane przez `tofu apply`? Czy powodem był brak backendu `oci` w OpenTofu, czy coś innego? (historia/04, technologie/02)
  Odpowiedź:

- [ ] Czym były osadzone repozytoria `Kubernetes` (2025-07-27 → 2025-08-11) i `proxmox` (2025-08-16 → 2025-08-25)? Czy to przypadkowe `git add` katalogów z własnym `.git`? (historia/03)
  Odpowiedź:

- [ ] Jak w latach 2025-08 → 2025-12 trafiały do klastra prawdziwe wartości sekretów (Cloudflare, Bazarr), skoro w repo były puste, a CI robiło `kubectl apply` przy każdym pushu? Czy apply nie nadpisywał ich pustymi? (historia/03)
  Odpowiedź:

- [ ] Czy w sierpniu 2025 Argo CD był zainstalowany na k3s ręcznie? W repo był obiekt `Application` dla nvidia-device-plugin, ale nie było instalacji Argo CD. (technologie/02)
  Odpowiedź:

- [ ] Czy między 2025-12-17 (commit „disable workflow files” usunął wyzwalacze `push`) a 2026-02-01 uruchamiałeś ręcznie workflow `kubernetes.yaml` albo `terraform.yaml`? Dlaczego przygotowania do Talosa szły na osobnej gałęzi, scalonej dopiero 2026-02-26? (historia/03)
  Odpowiedź:

- [ ] Co usuwał workflow `terraform-destroy.yaml` („Plan Terraform Destroy (Excluding Proxmox)”, commit `b8daa33`, 2026-02-01) i czy było to celowe wygaszenie starej infrastruktury? (historia/04)
  Odpowiedź:

- [ ] Dlaczego przy migracji na Talosa zmieniłeś provider Proxmoxa z `Telmate/proxmox` na `bpg/proxmox`? (technologie/02)
  Odpowiedź:

- [ ] Dlaczego Argo CD, a nie Flux CD? Liczył się interfejs WWW z SSO, znajomość narzędzia, coś innego? (technologie/02)
  Odpowiedź:

- [ ] Dlaczego w marcu 2026 wprowadziłeś Nix flake z direnv (commit `3b8be01`, 2026-03-01), a 2026-05-03 zastąpiłeś go mise (commit `80cebb2`)? Przypinanie wersji, obsługa przez Renovate, wolne `nix develop`, praca na maszynie bez Nix? (historia/04, technologie/02)
  Odpowiedź:

- [ ] Czy provider Terraform `ThePhaseless/jellyfin` napisałeś sam, dlaczego zamiast istniejącego i czy jest opublikowany w Terraform Registry? (historia/04, technologie/02)
  Odpowiedź:

- [ ] Czy przeniesienie stanu `Terraform/apps` z sekretu Kubernetesa do OCI (commit `eefc9d7`, 2026-06-23, „recovery”) nastąpiło po realnej utracie stanu przy odbudowie klastra? Jeśli tak, kiedy i co trzeba było odtworzyć? (technologie/02)
  Odpowiedź:

- [ ] Czy rozbieżność w `Terraform/AGENTS.md` (backend `kubernetes` dla `apps`, a w kodzie `oci`) ma zostać poprawiona przed oddaniem pracy? Repo jest cytowane jako źródło. (technologie/02)
  Odpowiedź:

- [ ] Czy automatyczne commity „[skip ci] Synced latest changes” z serwera (od commitu `a0ed77e`, 2025-04-23) były świadomym wyborem, czy obejściem tego, że AdGuard zapisuje ustawienia z UI do pliku? (historia/02)
  Odpowiedź:

## Sieć i dostęp

- [ ] Czy łącze domowe w latach 2024-2025 naprawdę było za CGNAT? README z 2024-01-02 mówi „bypass CGNAT”, a README z 2025 (commit `84ea802`) o braku publicznego IP od ISP. 2026-08-21 sprawdzono, że łącze Orange przyjmuje ruch na 80/443. Czy wcześniej był inny operator albo inna umowa, czy to była ta sama błędna diagnoza co w 2026-08? Jeśli CGNAT był, kiedy i dlaczego to się zmieniło (zmiana operatora lub taryfy, prośba o publiczny IP)? (historia/01, historia/02, technologie/03)
  Odpowiedź:

- [ ] Co oznaczała nazwa „DMZ” dla serwera domowego w 2024? Czy był w osobnej sieci lub VLAN-ie? (historia/01)
  Odpowiedź:

- [ ] Dlaczego w 2024 Traefik i Authelia przeniosły się z VPS do domu, a VPS został tylko przekaźnikiem WireGuard? Co nie działało w wariancie Tailscale + DnsMasq? (historia/01)
  Odpowiedź:

- [ ] Czym w okresie 2024-07 → 2025-03 ruch publiczny trafiał do domu? Katalog `VPS/` z WireGuardem usunięto 2024-07-14, a HAProxy na VPS z PROXY protocol przez Tailscale pojawił się w repo dopiero 2025-03-13. Czy HAProxy na Oracle free tier działał wcześniej poza repo i od kiedy? (historia/02, technologie/03)
  Odpowiedź:

- [ ] Dlaczego zrezygnowałeś z własnego tunelu WireGuard na rzecz Tailscale? (technologie/03)
  Odpowiedź:

- [ ] Dlaczego pierwotnie wybrałeś Traefika (2024 lub wcześniej), a nie nginx albo Caddy? (technologie/03)
  Odpowiedź:

- [ ] Czy rozważałeś Cloudflare Tunnel zamiast VPS z HAProxy, a jeśli tak, dlaczego go odrzuciłeś? (technologie/03)
  Odpowiedź:

- [ ] Dlaczego 2025-08-31 wyłączono HTTPS na VPS (commit „disable https proxying”, port 443 trzy razy zmieniany tego dnia)? Czy w okresie 2025-09 → 2026-01 jakakolwiek usługa była dostępna z internetu bez Tailscale? (historia/03)
  Odpowiedź:

- [ ] Dlaczego dzień po przejściu na certyfikat wildcard na entrypoincie Traefika (commit `b85f139`, 2026-02-18) przywróciłeś `certResolver` w każdej IngressRoute (commit `d42247e`, 2026-02-19)? (technologie/03)
  Odpowiedź:

- [ ] Co dokładnie było źle w przekierowaniu portów 80/443 na routerze, poprawionym 2026-08-21? (historia/05)
  Odpowiedź:

- [ ] Czy konfiguracja routera Mercusys (przekierowania 80/443, pula DHCP .180-.253, restart w poniedziałki o 03:00) jest gdzieś zapisana poza `CLAUDE.md`, np. jako eksport ustawień? (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Czy rozważałeś zmianę CNI na Cilium lub Calico zamiast `kube-network-policies` obok Flannela? (technologie/03)
  Odpowiedź:

- [ ] Dlaczego reguła Tailscale `tag:secured → compute:22` (commit `8575c0b`) została wycofana tego samego dnia, 2026-11-10 (commit `c958239`)? (historia/05)
  Odpowiedź:

## Uwierzytelnianie

- [ ] Dlaczego 2024-01-17 domyślna polityka Authelii zmieniła się z `two_factor` na `one_factor` (commit `c4c1044`, „ignore authelia status”)? (historia/01)
  Odpowiedź:

- [ ] Po co Authelii był LDAP zamiast pliku użytkowników (wspólne konta dla aplikacji?) i dlaczego 2024-01-17 zamieniłeś lldap na OpenLDAP (commit `8cf1bc9`), a 2024-02-11 wróciłeś do lldap (commit `731bdac`)? (historia/01)
  Odpowiedź:

- [ ] Dlaczego 2025-02-12 Authelię i LLDAP zastąpił Authentik (commit `c8dccdd`, „refactor and migrate to authentik”, bez opisu)? Chodziło o outpost LDAP lub OIDC dla Jellyfina, o interfejs, czy o coś innego? (historia/02, technologie/03)
  Odpowiedź:

- [ ] Jak były chronione usługi w pierwszym Kubernetesie (2025-09 → 2026-02), skoro IngressRoute nie miały middleware uwierzytelniania, a Authentik zniknął z compose 2025-09-01 i nie trafił do k8s? Czy Authentik działał wtedy gdzieś poza repo? (historia/03, technologie/03)
  Odpowiedź:

- [ ] Dlaczego w nowym klastrze 2026-02-01 najpierw postawiłeś oauth2-proxy z Google OAuth, a 2026-02-20 (m.in. commit `28621db`) zastąpiłeś go Authentikiem? Chodziło o grupy i RBAC, o jedno logowanie dla wszystkich aplikacji, czy o coś innego? (historia/04, technologie/03)
  Odpowiedź:

- [ ] Dlaczego aplikacja Authentika bez wiązań polityk 2026-08-13 wpuszczała każde konto Google (commit `c3bd45f`), a 2026-09-03 aplikacja Copyparty w tej samej sytuacji odmawiała wszystkim (commit `47f966a`)? Czy flaga `core_default_app_access` była zmieniana ręcznie? (historia/05)
  Odpowiedź:

## Dane i kopie

- [ ] Dlaczego w 2024-03 zastąpiłeś mdadm RAID10 (skrypt `DMZ/setup_raid10.sh` z 2024-01) ZFS-em? (technologie/04)
  Odpowiedź:

- [ ] Czy pula ZFS z dwóch mirrorów na 4 dyskach ze skryptu z 2024-03-26 (commit `d68bcf6`) rzeczywiście powstała? Kiedy i dlaczego zastąpiła ją obecna `Storage` RAIDZ1 z 5 dysków, i czy dane przenoszono, czy pulę zbudowano od nowa? (historia/01, technologie/04)
  Odpowiedź:

- [ ] Dlaczego 2026-02-20 (commit `a338df4`) zrezygnowałeś z `nfs-csi` z dynamicznymi PVC na rzecz statycznych PV po czterech dniach? (historia/04)
  Odpowiedź:

- [ ] Dlaczego Longhorn, a nie Rook-Ceph, OpenEBS albo `democratic-csi` na ZFS hosta, skoro wszystkie węzły są VM na jednym hoście? (technologie/04)
  Odpowiedź:

- [ ] Dokąd Duplicati robił kopie w 2024 (dysk lokalny czy chmura)? Czego używałeś do kopii między usunięciem Duplicati (2024-02-26, commit `06b7e79`) a BorgBackup (2026-02) i czy w tym czasie była jakakolwiek kopia poza domem? (technologie/04, technologie/05)
  Odpowiedź:

- [ ] Dlaczego Borg z Hetzner Storage Box, a nie restic lub Kopia do B2 lub S3? Liczyła się cena, natywna obsługa Borga przez Storage Box, czy coś innego? (technologie/04)
  Odpowiedź:

- [ ] Które dane są celowo bez kopii: biblioteka mediów `/Storage/Media` („da się pobrać ponownie”), Pagewire (`pagewire-data`, `pagewire-blobs`), `clips-sftp-state`? (technologie/04)
  Odpowiedź:

- [ ] Jak robiona jest kopia VM Home Assistanta (VMID 102): vzdump, kopia z samego HA, żadna? Czy kiedykolwiek ją odtwarzałeś? (technologie/04, odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Czy bazę Authentika odtwarza się z `pg_restore` przed czy po `terraform apply` w `Terraform/apps`? Od tej kolejności zależy, czy aplikacje Authentika zachowają te same ID. (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] W jakiej strefie czasowej działają CronJoby kopii (UTC czy czas lokalny)? (odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Czy nocne zatrzymanie AdGuarda na czas `home-backup` (od 04:30) przerywa DNS w LAN, czy klienci mają zapasowy resolver? (technologie/04)
  Odpowiedź:

- [ ] Dlaczego Bitwarden Secrets Manager, a nie SOPS lub Sealed Secrets w Git? Czy wpływ miało to, że używasz już Bitwardena jako menedżera haseł? (technologie/04)
  Odpowiedź:

- [ ] Dlaczego 2026-07-19 trzeba było założyć organizację Bitwarden od nowa (commit `24834b9`)? (historia/04, technologie/04)
  Odpowiedź:

- [ ] Jak monitorowałeś serwer przed 2026-02? Dlaczego Mimir i Alloy, a nie zwykły Prometheus? (technologie/04)
  Odpowiedź:

- [ ] Czy dopuszczasz, że przy awarii całego klastra alerty nie wyjdą, czy planujesz zewnętrzny monitoring dostępności? (technologie/04)
  Odpowiedź:

- [ ] Czy planujesz migrację z Promtaila (koniec wsparcia 2026-03-02) do Alloya? (technologie/04)
  Odpowiedź:

## Aplikacje i repatriacja

- [ ] Dlaczego 2024-02-11 wyłączyłeś Immicha (commit `334c89d`, „dont use Immich”) i czego używałeś do zdjęć do jego powrotu w Kubernetesie 2026-02-01? (historia/01, technologie/05)
  Odpowiedź:

- [ ] Czy telefony domowników robią kopię zdjęć tylko do Immicha, czy nadal także do Zdjęć Google lub iCloud? (technologie/05)
  Odpowiedź:

- [ ] Dlaczego Jellyfin, a nie Plex albo Emby? (technologie/05)
  Odpowiedź:

- [ ] Dlaczego 2025-02-12 (commit `c8dccdd`) usunąłeś Portainera i Sambę i co zastąpiło Sambę w latach 2025-2026, zanim pojawił się copyparty (np. udział na hoście Proxmox)? (historia/02, technologie/05)
  Odpowiedź:

- [ ] Czy Byparr (od 2024-07-25) powstał dlatego, że FlareSolverr przestał przechodzić wyzwania Cloudflare w lipcu 2024? (historia/02)
  Odpowiedź:

- [ ] Dlaczego usunąłeś serwery gier (FTB Skies Expert, DawnCraft, PufferPanel; pliki skasowane 2025-02-12 w commicie `c8dccdd`)? Czy działały potem gdzie indziej, skoro README z 2025-03 wymienia „Game server sharing” przez Tailscale? (historia/02)
  Odpowiedź:

- [ ] Gdzie dziś działa serwer Minecraft z tagiem `tag:minecraft` (od commitu `7168368`, 2026-04-08): Oracle VPS, Proxmox, inny komputer? Co jest na porcie 8100? (technologie/05)
  Odpowiedź:

- [ ] Do czego służyły kontener MSSQL („test mssql”, commit `534fc1f`, 2025-03-03) i projekt Magnum w `docker-compose.dev.yaml` (commit `c0d65d8`, 2024-12-03)? (historia/02)
  Odpowiedź:

- [ ] Dlaczego 2026-06-21 usunąłeś ClamAV (commit `d65d546`)? (historia/04)
  Odpowiedź:

- [ ] Czy VM Home Assistanta to HA OS, od kiedy działa jako VM i dlaczego przeszła z kontenera w compose na VM? (technologie/05)
  Odpowiedź:

- [ ] Czy urządzenia Tuya i Aqara są nadal sparowane z aplikacjami producentów, czy działają już tylko lokalnie przez ZHA? (technologie/05)
  Odpowiedź:

- [ ] Czy poczta z domeny przeszła z Gmaila do zewnętrznego dostawcy opisanego w `docs/email-provider-research.md` (np. Zoho Mail Lite)? Jeśli tak, do kogo i za ile? (historia/05, technologie/05)
  Odpowiedź:

- [ ] Ile osób poza Tobą korzysta z homelabu, w przybliżeniu w grupach `vips`, `watchers`, `photos`, `writers`? (historia/05, technologie/05)
  Odpowiedź:

- [ ] Do czego służy c-oop (`c-oop.nerine.dev`, od commitu `d9446b8`, 2026-11-22): zajęcia z programowania obiektowego w C++, nauka z innymi? Czy chcesz go opisać w pracy? (historia/05, technologie/05)
  Odpowiedź:

- [ ] Czy portfolio z `DMZ/Compose/Home/website` działa dziś gdzieś indziej? (technologie/05)
  Odpowiedź:

## Incydenty

- [ ] Kiedy i przy jakiej zmianie odtworzenie app-of-apps ArgoCD skasowało dane („all data loss”, wpis w instrukcjach z 2026-03-07)? Co przepadło i co odzyskano? (historia/04, technologie/02, odtwarzanie-i-koszty)
  Odpowiedź:

- [ ] Co się zepsuło po automatycznej aktualizacji `nvidia-device-plugin` do v0.18.0 (PR #166, 2025-10-22), że trzeba było ją cofnąć (PR #173, 2025-10-31)? (historia/03)
  Odpowiedź:

- [ ] Co zepsuła zbiorcza aktualizacja zależności cofnięta w PR #271 (2026-02-27), dzień po scaleniu migracji? (historia/04, technologie/02)
  Odpowiedź:

- [ ] Co się stało 2026-05-14 (commit `43f6a34`, „Stabilize cluster recovery”): co spowodowało `emergency_ro` w Longhornie i czy przy tym przebudowywano członka etcd? (historia/04)
  Odpowiedź:

- [ ] Co naprawdę powodowało restarty węzła GPU w czerwcu 2026: OOM Flannela po odświeżeniu sekretów Bitwarden (wpis, który został w instrukcjach), czy stare dane etcd na partycji EPHEMERAL (usunięty raport `.opencode/tmp/GPU-Crash-Investigation.md`)? Czy talos-1 odtworzył wtedy apply z CI, czy ręczna odbudowa po pustych binariach w containerd? (historia/04)
  Odpowiedź:

- [ ] Czy restarty authentik-server (92 w 3 dni i 7 godzin, do 2026-09-21) zaczęły się przed poniedziałkowym restartem routera o 03:00, czy dopiero po nim? (historia/05)
  Odpowiedź:

## Narzędzia

- [ ] Z jakich środowisk powstawały commity w styczniu i lutym 2024 (laptop, VS Code tunnel na serwerze, devcontainer, Codespaces)? Czy ich opisy były generowane automatycznie? (historia/01)
  Odpowiedź:

- [ ] Czy plan `.github/prompts/plan-k3sToTalosOsMigration.prompt.md` (commit `bc91666`, 2025-12-17) pisałeś z asystentem AI (Copilot, Claude, inny)? Jak bardzo realizacja z 2026 roku różni się od niego? (historia/03)
  Odpowiedź:

- [ ] Jakich asystentów AI używałeś od 2026-02 (Copilot, OpenCode, Claude, inne) i do czego: planowania, kodu, diagnozy? Jak duży był udział agenta (trailer `Claude-Session` w commitach) w diagnozach i zmianach od 2026-08 i czy praca ma to opisać? (historia/04, historia/05)
  Odpowiedź:

- [ ] Czy devcontainer (od commitu `f61e660`, 2025-07-26) jest jeszcze używany, czy można go opisać jako porzucony etap? (technologie/02)
  Odpowiedź:

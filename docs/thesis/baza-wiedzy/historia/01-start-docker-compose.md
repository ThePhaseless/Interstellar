# E1: start repozytorium i Docker Compose (2024-01-01 do 2024-07-13)

Okres obejmuje 199 commitów na `main`: 151 w styczniu 2024, 46 w lutym i 2 w marcu. Od 2024-03-27 do 2024-07-13 nie ma ani jednego commita w żadnej gałęzi obecnej w lokalnym klonie [commit `d68bcf6`, 2024-03-26; commit `9de8f42`, 2024-07-14]. Repo ma jeden korzeń (`386f12a`), a pierwszy commit E2 (`9de8f42`) ma za rodzica ostatni commit E1 (`d68bcf6`). W E1 są dwa merge: gałęzi z GitHuba [commit `b24be4c`, 2024-01-14] i PR #1 [commit `22da590`, 2024-02-14].

Oznaczenia: [commit `hash`, data] i [plik `ścieżka`] to dowód z repo, [wniosek] to rozumowanie na podstawie dowodów, [nieznane] oznacza brak danych. Pliki compose pokazują, co było zadeklarowane, a nie to, co faktycznie działało. Konfiguracja leżąca poza repo (katalog `${CONFIG_PATH}`, pliki dynamiczne Traefika, baza Authelii) jest niewidoczna.

## 1. Stan sprzed repozytorium

### Dowody

Pierwszy commit `386f12a` (2024-01-01, „first commit”) dodaje od razu 21 plików i 807 linii działających skryptów [commit `386f12a`, 2024-01-01]. Zawiera:

| Katalog | Zawartość | Co mówi o istniejącym serwerze |
| --- | --- | --- |
| `host/` | `install.sh`, `setup_mergerfs.sh`, `setup_raid0.sh`, `run_portainer.sh`, `screen-off.service`, `.env` | domowa maszyna z dyskami HDD i SSD, do wyboru JBOD przez RAID0 (mdadm) albo mergerfs; Portainer uruchamiany jednym `docker run`; usługa systemd wygaszająca konsolę po 1 i wyłączająca ekran po 2 minutach |
| `proxy/` | `docker-compose.yml` (Watchtower, Traefik, Authelia), `install.sh`, `update_proxy_stack.sh`, `upload_acme.sh`, `.env` | osobna maszyna „proxy” z Traefikiem i Authelią, certyfikaty z Let's Encrypt przez DNS challenge Cloudflare |
| `general/` | `setup_docker.sh`, `setup_samba.sh`, `setup_sudo_patch.sh`, `setup_tailscale.sh`, `setup_vscode.sh`, `setup_zsh.sh`, `.zshrc` | wspólne skrypty obu maszyn: Docker z oficjalnego repo apt, Samba, sudo bez hasła, Tailscale, VS Code CLI jako usługa `code tunnel`, zsh z oh-my-zsh |
| katalog główny | `install.sh` (menu „host czy proxy”), `.gitignore`, `.vscode/extensions.json` | jeden punkt wejścia dla obu ról |

Ślady wcześniejszej wersji, której w repo nie ma:

- `.gitignore` zawiera tylko jedną linię, `/general_old` [plik `.gitignore` w `386f12a`]. W katalogu roboczym autora leżała więc starsza kopia skryptów `general`.
- `install.sh` wykonuje `chmod +x fireword-install.sh`, a `host/install.sh` w komentarzu odwołuje się do `fireword.env` i woła `./Scripts/setup_sudo_patch.sh`, `./Scripts/setup_RAID0.sh`, `./Scripts/update_traefik_conf.sh`. Żaden z tych plików ani katalog `Scripts/` nie istnieje w commicie [commit `386f12a`, 2024-01-01]. To pozostałości poprzedniego układu katalogów.
- Zmienne globalne zapisywane są do `/etc/profile.d/litwave.sh`, a domyślne ścieżki z `host/.env` to `$HOME/litwave/...` [plik `host/install.sh`, `host/.env` w `386f12a`]. Merge z 2024-01-14 nosi tytuł „Merge branch 'main' of https://github.com/ThePhaseless/litwave”, czyli repo nazywało się wtedy na GitHubie `litwave` [commit `b24be4c`, 2024-01-14]. W lutym AdGuard dostaje rewrite nazwy `litwave` na `192.168.1.10` [commit `a66fd41`, 2024-02-25].
- Domena publiczna przed lutym 2024 to `fireword.xyz`. Strona startowa zmienia tytuł z „Fireword” na „Nerine”, a linki z `*.fireword.xyz` na `*.nerine.dev` w commicie „fireword to nerine change” [commit `4488451`, 2024-02-11].
- `upload_acme.sh` ma wpisane na sztywno ścieżki `/home/ubuntu/Proxy/Traefik/cert` (proxy) i `/public/SSD/Config/Traefik/cert` (host) [plik `proxy/upload_acme.sh` w `386f12a`]. Ścieżka `/public/...` wraca potem jako domyślna w `DMZ/.env.example` (`/public/Storage`, `/public/SSD`) [commit `814bff1`, 2024-01-14]. Na hoście istniał więc już układ `/public/SSD/Config` z katalogiem certyfikatów Traefika.
- Proxy jest opisane jako „fresh proxy for server … installing and configuring Ubuntu Server”, autor i data w nagłówku: „January 1, 2024” [plik `proxy/install.sh` w `386f12a`]. Docker instalowany jest z repozytorium `download.docker.com/linux/ubuntu` [plik `general/setup_docker.sh` w `386f12a`].
- `setup_vscode.sh` rozpoznaje architekturę `x86_64` i `aarch64` [plik `general/setup_vscode.sh` w `386f12a`].
- README z 2024-01-02 opisuje cel: „docker-compose to run a number of services connected to an internal and external reverse proxy to bypass CGNAT”. Wymagania: domena, konto Cloudflare, konto SMTP (np. Gmail), maszyna z publicznym IP i własna maszyna na usługi [commit `511a120`, 2024-01-02].
- Skrypt VPS z 2024-01-15 ostrzega przed czyszczeniem iptables, „because firewall is already managed by Oracle VCN” [commit `b946160`, 2024-01-15]. To jedyny dowód, że maszyną z publicznym IP była instancja w Oracle Cloud.

### Wnioski

- Serwer domowy działał przed 2024-01-01 na Ubuntu (Server), z Dockerem, Portainerem, Sambą i Tailscale. Projekt przeszedł co najmniej przez nazwy „Fireword” i „litwave”, zanim README nazwało go „Interstellar” [wniosek z dowodów powyżej].
- Pierwotna architektura miała dwie maszyny. Dom był za CGNAT (według README), więc ruch z internetu wchodził na maszynę z publicznym IP, a dalej do domu przez Tailscale. Certyfikat wystawiał Traefik na proxy (wildcard od 2024-01-02, commit `a1042ba`), a `upload_acme.sh` co 30 dni kopiował `acme.json` przez `scp` na hosta, co sugeruje, że host też terminował TLS tym samym certyfikatem („internal reverse proxy”) [wniosek z `proxy/upload_acme.sh`, `readme.md`].
- Proxy to prawdopodobnie Ubuntu w Oracle Cloud (domyślny użytkownik `ubuntu` w ścieżce `/home/ubuntu/Proxy`, wzmianka o Oracle VCN, obsługa `aarch64`). Czy była to instancja Always Free na ARM, repo nie mówi [wniosek, częściowo nieznane].
- Usługi aplikacyjne (media, AdGuard, Homepage itd.) pojawiają się w repo dopiero 2024-01-15 od razu jako kompletne pliki compose, z 10 usługami w stosie mediów [commit `ba47ea5`, 2024-01-15]. Najpewniej działały wcześniej poza repo i zostały do niego przeniesione [wniosek].
- Sprzęt hosta: dyski HDD i SSD, później cztery dyski pod RAID10 (skrypt odmawia przy mniej niż 4) [commit `814bff1`, 2024-01-14]; `/dev/dri` przekazywane do Jellyfina [plik `DMZ/media-compose.yaml` w `ba47ea5`], więc był iGPU lub GPU do transkodowania; podłączony monitor lub konsola (usługa wygaszania ekranu); USB dla skanera (`scanservjs`) i Home Assistanta. Model, CPU i RAM są [nieznane].

DnsMasq nie należy do stanu sprzed repo. Pojawia się 2024-01-06 i znika tydzień później (sekcja 2.2).

## 2. Chronologia E1 (tematycznie)

### 2.1. Traefik, Authelia i certyfikaty (2024-01-01 do 2024-01-02)

- Pierwszy stos na proxy: Watchtower, `traefik:latest` z dashboardem (`--api.insecure=true`, port 8080), przekierowanie HTTP na HTTPS, provider Docker i provider plików, resolver `cloudflare` z DNS challenge, plus `authelia/authelia:latest` z bazą użytkowników w pliku i powiadomieniami przez SMTP Gmaila [commit `386f12a`, 2024-01-01].
- Tego samego wieczoru domyślną polityką Authelii staje się `two_factor` [commit `4f203a2`, 2024-01-01], a Authelia dostaje etykiety Traefika z middleware `forwardAuth` na `/api/verify` i nagłówkami `Remote-User`, `Remote-Groups`, `Remote-Name`, `Remote-Email` [commit `73ad349`, 2024-01-01].
- 2024-01-02: middleware przekierowania z subdomen na domenę główną [commit `93e1059`], przejście z `Host` na `HostRegexp` [commit `de6af16`] i certyfikat wildcard: `tls.domains[0].main=${PUBLIC_HOSTNAME}`, `sans=*.${PUBLIC_HOSTNAME}` [commit `a1042ba`, 2024-01-02]. Tego dnia powstaje też README [commit `511a120`, 2024-01-02], a `upload_acme.sh` dostaje `chmod 777` katalogu docelowego na hoście [commit `2db1854`, 2024-01-02].

Wildcard przez DNS-01 oznacza jeden certyfikat dla wszystkich subdomen bez wystawiania portu 80 hosta do walidacji HTTP-01 [wniosek]. Repo nie podaje motywu wyboru.

### 2.2. Eksperyment z DnsMasq na proxy (2024-01-06 do 2024-01-13)

- Pliki `.env` z przykładowymi wartościami zostają usunięte z repo [commit `e7846ad`, `3b5f394`, 2024-01-06].
- Nowy skrypt `proxy/redirect_hostname.sh` pyta o IP serwera „(from Tailscale)” i nazwę hosta, instaluje DnsMasq i zapisuje `address=/<hostname>/<IP z Tailscale>` [commit `1a16b19`, 2024-01-06]. Kolejne commity wyłączają `systemd-resolved`, usuwają symlink `/etc/resolv.conf` [commit `c5cb2ca`, 2024-01-06], dopisują DnsMasq do `resolv.conf` i `dhclient.conf` [commit `d86f39f`, 2024-01-06] i sprawdzają pingiem, czy IP z Tailscale odpowiada [commit `211608f`, 2024-01-06].
- Traefik na proxy działa wtedy w `network_mode: host` z routerem łapiącym każdy host (`HostRegexp(.*$)`) i middleware `authelia, redirect-to-host` [plik `proxy/docker-compose.yml` w `4315997`].
- 2024-01-13 całość zostaje usunięta: `proxy/docker-compose.yml`, `redirect_hostname.sh` i pliki `proxy/traefik/conf/*.yaml` [commit `3dc86c2`, 2024-01-13], a `upload_acme.sh` wypada z crona [commit `681a085`, 2024-01-13].

Cel był prawdopodobnie taki, żeby proxy rozwiązywało publiczną nazwę na adres domowego serwera w tailnecie i przekazywało do niego ruch [wniosek]. Repo nie mówi, dlaczego z tego zrezygnowano (pytanie 6).

### 2.3. Odwrócenie architektury: host/proxy/general na DMZ/VPS/General (2024-01-14 do 2024-01-15)

To najważniejsza zmiana E1: razem ze zmianą nazw katalogów reverse proxy przenosi się z VPS do domu.

- Commit opisany jako „remove unnecesary extentions” faktycznie przenosi `host/` do `DMZ/` i `proxy/install.sh` do `VPS/install.sh`, oraz dodaje `DMZ/setup_wireguard.sh`, `VPS/setup_wireguard.sh`, `DMZ/setup_raid10.sh`, `DMZ/setup_samba.sh` [commit `814bff1`, 2024-01-14]. Commit „Change dir names” zmienia tylko `install.sh` [commit `42356a2`, 2024-01-14].
- `general/` staje się `General/` [commit `3dc5b1c`, 2024-01-15], stary katalog zostaje usunięty [commit `a979da8`, 2024-01-15].
- Stos reverse proxy (Traefik, Authelia) pojawia się po stronie DMZ [commit `f1b8f7b`, 2024-01-15, „add reverse proxy”].
- VPS dostaje tunel WireGuard do DMZ (podsieć `192.168.5.0/24`, VPS `.1`, DMZ `.2`, port 51820, `PersistentKeepalive = 25` po stronie DMZ) [plik `VPS/.env.example`, `DMZ/wireguard.env.example` w `d68bcf6`]. Na VPS iptables: `FORWARD` domyślnie `DROP`, przepuszczane są tylko nowe połączenia TCP na 80 i 443 z interfejsu publicznego do `wg0`, DNAT tych portów na adres DMZ w tunelu i SNAT na adres VPS w tunelu [plik `VPS/setup_wireguard.sh` w `d68bcf6`].
- Pierwsza wersja skryptu VPS otwiera porty 22, 80, 443 i port WireGuard przez `ufw allow` [commit `814bff1`, 2024-01-14]. W ciągu 2024-01-15 komentarze „UFW profile” zmieniają się na „iptables chain” [commit `407d2ea`, 2024-01-15], blok `ufw allow` wraca jeszcze w „Enable UFW…” [commit `0661a04`, 2024-01-15], a wieczorem znika na dobre. Ten sam commit dodaje czyszczenie iptables z komentarzem o Oracle VCN [commit `b946160`, 2024-01-15]. Na końcu E1 skrypt nie wywołuje już `ufw`, filtruje tylko łańcuch `FORWARD` [plik `VPS/setup_wireguard.sh` w `d68bcf6`]. Reguły dostają komentarze „VPS to DMZ”/„DMZ to VPS”, żeby dało się je usuwać przy ponownym uruchomieniu [commit `78e20c0`, `72f0ca0`, 2024-01-15], a zapisuje je `netfilter-persistent` [plik `VPS/setup_wireguard.sh` w `d68bcf6`].

Skutek [wniosek]: VPS przestaje terminować TLS i tylko przekazuje pakiety 80/443 do domu, więc certyfikaty i Authelia żyją w jednym miejscu, a `upload_acme.sh` przestaje być potrzebny. Ruch z SNAT dociera do Traefika z adresu VPS w tunelu, a nie z prawdziwego IP klienta. Repo w E1 tego nie komentuje.

Nazwa „DMZ” dla domowego serwera nie jest w repo wyjaśniona [nieznane].

### 2.4. Usługi w Docker Compose (2024-01-15 do 2024-02-29)

- Pierwsze pliki: `DMZ/home-compose.yaml` (httpd, Homepage, PufferPanel, własny bot Discord, File Browser, AdGuard Home, scanservjs, WOL) i `DMZ/media-compose.yaml` (Recyclarr, Bazarr, Radarr, Sonarr, Prowlarr, qBittorrent, Jellyseerr, Jellyfin, Watchtower, FlareSolverr) [commit `ba47ea5`, 2024-01-15]. Tego samego dnia dochodzi stos Immich [commit `8f3e37d`, 2024-01-15], a pliki zostają rozłożone na `DMZ/Compose/<Stos>/docker-compose.yaml` [commit `370fea4`, 2024-01-15].
- Do 2024-01-15 w stosie Home PufferPanel, File Browser i wolweb zostają zastąpione przez Duplicati i GPT-Wol [plik `DMZ/Compose/Home/docker-compose.yaml` w `4689c1f`]. Bot Discord zmienia obraz na `ghcr.io/thephaseless/renamer` [commit `2706f22`, 2024-01-19].
- Strona startowa na httpd [commit `05b109f`, 2024-01-19], przerobiona w PR „New frontpage” [PR #1, 2024-02-14; commit `22da590`].
- Portainer przechodzi do stosu Home [commit `34a5add`, 2024-02-08]. Duplicati trafia do stosu Immich [commit `8d6dcf4`, 2024-02-10], Immich zostaje wykomentowany w `include` („dont use Immich”) [commit `334c89d`, 2024-02-11], a 2024-02-26 oba znikają z repo [commit `06b7e79`, 2024-02-26]. Powód rezygnacji jest [nieznane].
- Polityka `restart: unless-stopped` dla usług [commit `ed592a1`, `954980e`, 2024-02-12].
- AdGuard Home: poprawka portów DNS na `53/tcp` i `53/udp` [commit `52e8c58`, 2024-02-21], plik konfiguracyjny w repo [commit `775a8a8`, 2024-02-21]. Konfiguracja zawiera rewrite `*.nerine.dev` i `nerine.dev` na `192.168.1.10` oraz upstream DoT Cloudflare [plik `DMZ/Docker/Configs/Home/AdGuard/conf/AdGuardHome.yaml` w `d68bcf6`]. Split-horizon DNS dla LAN istnieje więc od lutego 2024; dziś ten sam mechanizm wskazuje na `192.168.1.11` (MetalLB Traefika) [plik `AGENTS.md` na `main`; `CLAUDE.md` jest do niego dowiązaniem].
- Home Assistant dochodzi 2024-02-25 [commit `acfb3af`, 2024-02-25]. Dwa dni później dostaje `network_mode: host` i traci etykiety Traefika [commit `e22b85d`, 2024-02-27]. Traefik dostaje stały adres `172.21.0.255` w sieci `172.21.0.0/16`, „static ip for traefik as fix for home assistant”, a HA ufa temu adresowi w `trusted_proxies` [commit `a0770b7`, 2024-02-27]; Traefik dostaje też `host.docker.internal:host-gateway` [commit `04a94d6`, 2024-02-27]. Jak HA był routowany na końcu E1, z repo nie widać [nieznane]; najpewniej przez plikowy provider Traefika, którego konfiguracja leżała poza repo [wniosek].
- Restrukturyzacja „restructurise DMZ Docker”: jeden projekt `dmz` z `include` czterech plików `docker-compose.{game-servers,reverse-proxy,home,media}.yaml`, sekrety rozdzielone na `envs/.env.*`, skrypt `start_all.sh`, pierwszy serwer gry (modpack Minecraft FTB Skies Expert na `eclipse-temurin:17-jre`) [commit `06b7e79`, 2024-02-26]. Nowy skrypt startowy [commit `a18b138`, 2024-02-29].

### 2.5. Uwierzytelnianie: Authelia z LDAP

| Data | Zmiana | Dowód |
| --- | --- | --- |
| 2024-01-01 | Authelia z plikiem użytkowników, `two_factor` domyślnie | [commit `386f12a`], [commit `4f203a2`] |
| 2024-01-13 | stos na proxy usunięty, razem z ustawieniem `two_factor` | [commit `3dc86c2`, 2024-01-13] |
| 2024-01-15 | stos na DMZ znowu z `two_factor` | [commit `370fea4`, 2024-01-15] |
| 2024-01-15 | backend LDAP: lldap | [commit `4689c1f`, 2024-01-15] |
| 2024-01-17 | zamiana na `bitnami/openldap` z `wheelybird/ldap-user-manager` | [commit `8cf1bc9`, 2024-01-17] |
| 2024-01-17 | domyślna polityka zmieniona na `one_factor` w commicie „ignore authelia status” | [commit `c4c1044`, 2024-01-17] |
| 2024-02-11 | powrót do lldap („use lldap instead of openldap”) | [commit `731bdac`, 2024-02-11] |
| 2024-03-26 | nadal `one_factor` | [plik `DMZ/Docker/Compose/envs/.env.authelia.example` w `d68bcf6`] |

Domyślne 2FA było zadeklarowane w dwóch odcinkach: 2024-01-01 do 2024-01-13 na proxy i 2024-01-15 do 2024-01-17 na DMZ. Commit, który je wyłączył, nie wspomina o tym w opisie, a powód jest [nieznane]. Repo nie podaje też, po co Authelii backend LDAP zamiast pliku użytkowników (pytanie 8).

### 2.6. Dyski i udziały

| Data | Wariant | Dowód |
| --- | --- | --- |
| 2024-01-01 | do wyboru RAID0 (mdadm, ext4) albo mergerfs | [commit `386f12a`] |
| 2024-01-14 | skrypty RAID0 i mergerfs usunięte, w ich miejsce `DMZ/setup_raid10.sh` (mdadm: pary RAID1 złożone w RAID10, minimum 4 dyski) | [commit `814bff1`, 2024-01-14] |
| 2024-01-19/20 | RAID10 podpięty do `DMZ/install.sh` i dokończony (ext4, wpis w `fstab`) | [commit `8d8b6a6`, 2024-01-19], [commit `d998e1b`, 2024-01-20] |
| 2024-03-26 | ZFS: `zpool create -m /public/Storage mirror d0 d1 mirror d2 d3` (dwa mirrory w stripe) | [commit `d68bcf6`, 2024-03-26] |

Samba udostępnia `[HDD]`/`[SSD]` z `guest ok = yes` i zapisem dla gościa [plik `general/setup_samba.sh` w `386f12a`]; później konfiguracja trafia do `DMZ/shares.conf` [commit `814bff1`, 2024-01-14]. Czy skrypt ZFS został uruchomiony w E1, repo nie pokazuje [nieznane]. Obecna pula `Storage` to RAIDZ1 z 5 dysków [plik `AGENTS.md` na `main`].

### 2.7. Narzędzia: .devcontainer i .github (2024-02-08)

- `.devcontainer/devcontainer.json` na obrazie `mcr.microsoft.com/devcontainers/base:bullseye` z feature `docker-outside-of-docker` i `.github/dependabot.yml` aktualizujący wyłącznie ekosystem `devcontainers` co tydzień [commit `44e2ac5`, 2024-02-08]. Później dochodzi feature Pythona [commit `a576ccb`, 2024-02-14], rozszerzenia Home Assistant i LDAP Explorer [commit `b148bbb`, `a3cb67c`, 2024-02-27] oraz instalacja `shellcheck` w `postCreateCommand` [commit `1b9fec3`, 2024-03-26].
- Dependabot nie obejmuje obrazów w compose. Wersjami usług zarządzały tagi `:latest` i Watchtower z `--cleanup` [plik `DMZ/Docker/Compose/docker-compose.media.yaml` w `d68bcf6`].

### 2.8. Przerwa od kwietnia do lipca 2024

Po 2024-02-29 są tylko dwa commity, oba 2024-03-26: `shellcheck` w devcontainerze i RAID10 na ZFS [commit `1b9fec3`, `d68bcf6`, 2024-03-26]. Potem do 2024-07-14 nie ma nic, także w innych gałęziach lokalnego klonu. E2 otwiera seria commitów 2024-07-14: workflow CI `deploy.yaml` [commit `9de8f42`, 2024-07-14] i przeniesienie compose do katalogu głównego [commit `7198b20`, 2024-07-14]. Powód przerwy jest [nieznane].

## 3. Decyzje i problemy

| Problem lub decyzja | Rozwiązanie | Dowód | Motyw w repo |
| --- | --- | --- | --- |
| dom za CGNAT, brak publicznego IP | VPS z publicznym IP jako punkt wejścia | [commit `511a120`] | podany („to bypass CGNAT”) |
| jeden certyfikat dla wszystkich subdomen | wildcard z DNS-01 Cloudflare | [commit `a1042ba`] | brak |
| certyfikat potrzebny na dwóch maszynach | `upload_acme.sh` przez `scp` co 30 dni, potem zbędny | [commit `386f12a`], [commit `681a085`] | brak |
| przekazanie ruchu z VPS do domu | najpierw Tailscale + DnsMasq, po tygodniu WireGuard + DNAT | [commit `1a16b19`], [commit `3dc86c2`], [commit `814bff1`] | brak |
| firewall VPS | `ufw allow` usunięte, zostaje iptables (`FORWARD DROP` + DNAT/SNAT) | [commit `814bff1`], [commit `0661a04`], [commit `b946160`] | brak; komentarz o Oracle VCN tłumaczy tylko czyszczenie iptables |
| backend użytkowników | lldap, OpenLDAP, znowu lldap | [commit `4689c1f`], [commit `8cf1bc9`], [commit `731bdac`] | brak |
| Home Assistant za Traefikiem (nagłówki `X-Forwarded-For`) | stały IP Traefika i `trusted_proxies` | [commit `a0770b7`] | podany („as fix for home assistant”) |
| porty DNS AdGuarda (mapowanie `53:53` bez protokołu obejmuje tylko TCP [wniosek]) | osobne mapowanie `53/tcp` i `53/udp` | [commit `52e8c58`] | podany („fix dns ports”) |
| redundancja danych | RAID0/mergerfs, RAID10 mdadm, mirrory ZFS | [commit `386f12a`], [commit `814bff1`], [commit `d68bcf6`] | brak |
| pliki `.env` w repo | wypełnione pliki `envs/.env.*` usunięte z repo i dopisane do `.gitignore` | [commit `d68685f`, 2024-02-26] | brak |

Pliki `envs/.env.*` z wypełnionymi wartościami były w repo przez kilka godzin 2024-02-26, po czym trafiły do `.gitignore` (pytanie 11).

## 4. Stan na koniec E1 (zadeklarowany w `d68bcf6`, 2024-03-26)

### Architektura

```
Internet ──80/443──> VPS (Oracle, Ubuntu, publiczne IP)
                      iptables: DNAT 80/443 -> 192.168.5.2, SNAT -> 192.168.5.1
                      │ WireGuard wg0 (192.168.5.0/24, UDP 51820)
                      v
                     DMZ = serwer domowy (Ubuntu, Docker Compose, projekt "dmz")
                      Traefik 172.21.0.255 :80/:443/:8080
                        ├─ forwardAuth -> Authelia (one_factor) -> lldap
                        └─ routery HostRegexp {nazwa}.{domena} -> kontenery
LAN ──DNS──> AdGuard Home na DMZ: *.nerine.dev -> 192.168.1.10
Administracja: Tailscale na obu maszynach, VS Code tunnel, Portainer
```

[wniosek z plików `VPS/setup_wireguard.sh`, `DMZ/setup_wireguard.sh`, `DMZ/Docker/Compose/*.yaml`, `AdGuardHome.yaml` w `d68bcf6`]

Domyślna reguła Traefika `HostRegexp({subdomain:{{ .ContainerName }}}.{host:.+})` i `exposedbydefault=false` sprawiały, że kontener z `traefik.enable=true` dostawał subdomenę z nazwy kontenera, np. `radarr.<domena>` [plik `DMZ/Docker/Compose/docker-compose.reverse-proxy.yaml` w `d68bcf6`].

### Usługi

| Stos | Usługi | Uwagi |
| --- | --- | --- |
| reverse-proxy | Traefik, Authelia, lldap | Traefik dashboard z `api.insecure`, lldap wystawia port 389 na hoście |
| media | Jellyfin (`/dev/dri`, `watch.`), Jellyseerr (`add.`), Sonarr, Radarr, Prowlarr, Bazarr, qBittorrent, Recyclarr, FlareSolverr, Watchtower | przez Traefik wystawione Jellyfin (bez Authelii) oraz Jellyseerr, Sonarr, Radarr, Prowlarr, Bazarr i qBittorrent (z Authelią); Recyclarr, FlareSolverr i Watchtower bez routera |
| home | Home Assistant (`network_mode: host`, `privileged`, USB), Portainer, httpd (strona na domenie głównej), Homepage (`home.`), AdGuard Home (DNS :53), scanservjs (`scan.`), GPT-Wol (`wol.`), własny bot Discord | |
| game-servers | Minecraft FTB Skies Expert (:25565) | port na hoście, VPS przekazuje tylko 80/443 |
| poza Dockerem | Samba (udziały HDD/SSD z dostępem gościa), Tailscale, WireGuard, VS Code tunnel, usługa wygaszania ekranu | z `DMZ/install.sh` |

[plik `DMZ/Docker/Compose/docker-compose.{reverse-proxy,media,home,game-servers}.yaml`, `DMZ/install.sh` w `d68bcf6`]

Odtwarzanie systemu: `install.sh` w katalogu głównym pyta o rolę (DMZ albo VPS), a skrypty po drodze otwierają `nano` na plikach `.env`, pytają o dyski, hasło i potwierdzenia (`read -r -p`) [plik `install.sh`, `DMZ/install.sh`, `VPS/install.sh` w `d68bcf6`]. Instalacja była więc półautomatyczna i interaktywna, bez CI i bez testów [wniosek].

## 5. Skąd skok aktywności w styczniu i lutym 2024

Liczby z `git log`:

- Styczeń: 151 commitów w 9 dniach (1, 2, 6, 13, 14, 15, 17, 19, 20 stycznia). Sam 2024-01-15 to 54 commity, z czego około 23 mają w temacie jedno ze słów: wireguard, iptables, ufw, firewall, rules, port, ping, forward, exports.
- Luty: 46 commitów w 12 dniach, w tym 8 dnia 2024-02-26 (restrukturyzacja) i 7 dnia 2024-02-27 (Home Assistant).
- Łącznie w E1 dotknięto 97 ścieżek, dodano 5683 i usunięto 4255 linii (`git log --numstat --no-renames` dla ścieżek, linie bez plików binarnych).
- Commity są bardzo drobne: 51 tematów zaczyna się od „Update”, 46 od „Add”, często jedna poprawka ścieżki, uprawnień albo literówki.
- 108 commitów ma strefę `+0000`, 91 `+0100`. W dniu 2024-01-15 obie strefy przeplatają się w ciągu kilku godzin.

Interpretacja [wniosek]: styczeń to przeniesienie istniejącego, ręcznie postawionego serwera do repo i dwukrotna przebudowa ścieżki wejścia (DnsMasq, potem WireGuard). Skrypty instalacyjne były testowane na żywych maszynach metodą prób, a każda próba kończyła się commitem, stąd serie po kilkanaście commitów w godzinę. Dwie strefy czasowe wskazują na commity z dwóch środowisk, np. z laptopa i z sesji na serwerze lub w kontenerze z zegarem UTC; które to były, jest [nieznane]. Podobny schematyczny styl tematów („Update X in Y”) może pochodzić z generatora opisów commitów w edytorze, ale to tylko przypuszczenie. Luty to porządkowanie usług (LDAP, AdGuard, HA, jeden projekt compose) i narzędzi (devcontainer), bez zmian w architekturze.

## 6. Co E1 zostawił otwarte

- Wersje obrazów: wszędzie `:latest` i Watchtower, Dependabot tylko dla devcontainera. W E2 dochodzi Renovate (`renovate.json` od 2024-07-17 według osi czasu projektu).
- Sekrety w plikach `.env` na dysku, bez menedżera sekretów (sekcja 3).
- Instalacja interaktywna (pytania, `nano`), brak CI do 2024-07-14 [commit `9de8f42`].
- Ruch z internetu dociera do Traefika z adresem VPS w tunelu (SNAT), więc aplikacje nie widzą IP klienta [wniosek z `VPS/setup_wireguard.sh`].
- Bezpieczeństwo: `one_factor` jako polityka domyślna, dashboard Traefika `api.insecure=true` na porcie 8080, Samba z zapisem dla gościa, `NOPASSWD` w sudo, `privileged` dla HA i scanservjs [pliki w `d68bcf6`].
- Routing Home Assistanta poza repo, Immich porzucony, skrypt ZFS bez śladu wykonania.
- Reguły `HostRegexp({subdomain:…}.{host:.+})` zostają zastąpione na początku E2 regułą `Host(...)` z subdomeną z etykiety kontenera i domeną ze zmiennej `PUBLIC_HOSTNAME` [commit `f73d558`, 2024-07-16].
- Po 2024-02-26 repo nie deklaruje żadnej usługi kopii zapasowych (Duplicati zniknął razem ze stosem Immich) [plik `DMZ/Docker/Compose/*.yaml` w `d68bcf6`].

## Pytania do autora

1. Czy łącze domowe w 2024 roku faktycznie było za CGNAT? Obecne notatki (2026-08) mówią, że Orange przepuszcza 80/443 na publiczny, zmienny adres. Jeśli w 2024 był CGNAT, kiedy i dlaczego się to zmieniło (inny operator, inna taryfa, prośba o publiczny IP)?
2. Jaki sprzęt był serwerem domowym w 2024 roku (CPU, RAM, GPU/iGPU, liczba i pojemność dysków HDD/SSD)? Czy to był ten sam komputer co dzisiejszy `carbon`?
3. Czy VPS był instancją Oracle Cloud Always Free (ARM Ampere czy x86)? Ile kosztował miesięcznie?
4. Od kiedy działał serwer przed pierwszym commitem 2024-01-01 i jakie usługi już na nim były (media, AdGuard, Samba, Portainer)?
5. Skąd nazwy „Fireword”, „litwave” i „Interstellar” i kiedy zmieniła się domena z `fireword.xyz` na `nerine.dev`?
6. Dlaczego Traefik i Authelia przeniosły się z VPS do domu, a VPS został tylko przekaźnikiem WireGuard? Co nie działało w wariancie Tailscale + DnsMasq?
7. Dlaczego 2024-01-17 domyślna polityka Authelii zmieniła się z `two_factor` na `one_factor`?
8. Po co Authelii był LDAP zamiast pliku użytkowników (wspólne konta dla aplikacji?) i dlaczego zamieniono lldap na OpenLDAP, a po trzech tygodniach wrócono do lldap?
9. Dlaczego zrezygnowano z Immicha w lutym 2024?
10. Co oznaczała nazwa „DMZ” dla serwera domowego? Czy był w osobnej sieci lub VLAN-ie?
11. Czy krótki epizod z wypełnionymi plikami `envs/.env.*` w repo (2024-02-26) zmienił sposób przechowywania sekretów (szablony `.env.example`, później Bitwarden)?
12. Czy pula ZFS (dwa mirrory) ze skryptu z 2024-03-26 rzeczywiście powstała w 2024 roku? Kiedy zastąpiła ją obecna RAIDZ1 z 5 dysków?
13. Skąd przerwa w commitach od kwietnia do połowy lipca 2024? Czy serwer był w tym czasie zmieniany ręcznie poza repo?
14. Z jakich środowisk powstawały commity w styczniu i lutym 2024 (laptop, VS Code tunnel na serwerze, devcontainer, Codespaces)? Czy opisy commitów były generowane automatycznie?

## Do której części pracy

- Wstęp: punkt wyjścia projektu, czyli ręcznie postawiony serwer i potrzeba wejścia zza CGNAT.
- Projekt: pierwsza architektura (dwie maszyny, tunel, reverse proxy, SSO) jako stan bazowy do porównania z obecną.
- Implementacja: historia przejścia od skryptów bash i Docker Compose do IaC; lista problemów E1 (sekrety, `:latest`, interaktywna instalacja) uzasadnia późniejsze wybory.
- Odtwarzanie po awarii: E1 jako przykład odtwarzania półautomatycznego (interaktywne `install.sh`, dane poza repo) w kontraście do dzisiejszego.
- Analiza kosztów: VPS jako koszt zewnętrzny okresu E1 (po odpowiedzi na pytanie 3).

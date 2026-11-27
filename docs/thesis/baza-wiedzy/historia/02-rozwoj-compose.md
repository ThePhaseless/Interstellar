# E2: rozwój na Docker Compose (2024-07-14 → 2025-07-25)

Okres E2 obejmuje 290 commitów na `main` (97 w lipcu 2024, potem 7-29 miesięcznie) **[wniosek: zliczenie `git log main --since=2024-07-14 --until=2025-07-26`]**. Prawie połowa (131) to commity Renovate z aktualizacjami obrazów, a 134 ze 135 PR-ów otwartych w tym okresie pochodzi od `app/renovate`, a jedyny PR autora to #2 „Refactor” z pustym opisem **[PR #2]**. Commity autora prawie nigdy nie mają treści poza tytułem. Dlatego większość odpowiedzi na pytanie „dlaczego” w tym pliku to **[nieznane]** albo pytania do autora.

## 1. Stan na początku E2

- Ostatni commit E1 to `d68bcf6` z 2024-03-26, więc przed przebudową repo stało bez zmian przez prawie 4 miesiące **[commit `d68bcf6`, 2024-03-26]**.
- Pliki compose były już wtedy podzielone według domen, ale leżały w `DMZ/Docker/Compose/`: `game-servers`, `home`, `media`, `reverse-proxy` i nadrzędny `docker-compose.yaml` z `include` oraz własną siecią `172.21.0.0/16` **[plik `DMZ/Docker/Compose/docker-compose.yaml` w `d68bcf6`]**. Uruchamiał je skrypt `start_all.sh`, który wywoływał `docker compose -f` dla każdego pliku po kolei **[plik `DMZ/Docker/start_all.sh` w `d68bcf6`]**.
- Usługi: Traefik + Authelia + LLDAP (reverse-proxy), Home Assistant, Portainer, httpd, Homepage, Renamer, AdGuard Home, scanservjs, gptwol (home), Recyclarr, Bazarr, Radarr, Sonarr, Prowlarr, qBittorrent, Jellyseerr, Jellyfin, Watchtower, FlareSolverr (media) i serwer FTB Skies Expert **[commit `d68bcf6`]**.
- Hosta i VPS stawiały interaktywne skrypty (`install.sh`, `DMZ/install.sh`, `VPS/install.sh`). VPS przekazywał ruch HTTP/HTTPS do serwera domowego tunelem WireGuard („every http and https request will be tunneled to DMZ”) **[plik `VPS/install.sh` w `d68bcf6`]**.

## 2. Przebudowa z 2024-07-14

### Co się zmieniło

Uwaga do osi czasu: rozbicie na pliki per domena **nie** pojawiło się w tym dniu, bo istniało już w E1. 2024-07-14 zmieniły się trzy rzeczy: układ katalogów, sposób wdrażania i zakres repo.

| Zmiana | Dowód |
| --- | --- |
| Usunięto całe drzewa `DMZ/`, `VPS/`, `General/` (37 plików, ok. 1330 linii) razem ze skryptami instalacyjnymi hosta, WireGuard, Samby, ZFS RAID10 i zsh | **[commit `6f7927b`, 2024-07-14]**, **[commit `235506e`, 2024-07-14]** (`install.sh`) |
| Pliki compose przeniesiono do katalogu głównego: `docker-compose.{auth,home,media,game-servers}.yaml` + `docker-compose.yaml` z `include`. `reverse-proxy` przemianowano na `auth` i dodano do niego Postfix (relay SMTP) | **[commit `7198b20`, 2024-07-14]** |
| Puste pliki `compose.arr.yaml`, `compose.auth.yaml`, `compose.yaml` (0 bajtów) dodane jako zaczątek nazewnictwa `compose.*`. `compose.arr.yaml` zniknął jeszcze tego samego dnia | **[commit `6f7927b`, 2024-07-14]**, szkielet osi czasu |
| Konfiguracje usług w `Config/` (AdGuard, Home Assistant, strona httpd); `.gitignore` wpuszcza do repo tylko wybrane pliki konfiguracyjne | **[commit `4b5fdf9`, 2024-07-14]**, **[commit `f998fdf`, 2024-07-14]** |
| `.env` → `.env.example` (w `.env` była tylko ścieżka `CONFIG_PATH`) | **[commit `c67b548`, 2024-07-14]** |
| Pierwszy workflow wdrożeniowy: GitHub Actions → Tailscale (OAuth, `tag:ci`) → `tailscale ssh` na serwer → `git pull && docker compose up -d` | **[commit `9de8f42`, 2024-07-14]**, **[commit `5ebf412`, 2024-07-14]**, **[plik `.github/workflows/deploy.yaml` w `5b4ecc4`]** |

Te same commity przeszły przez PR #2 („Refactor”), utworzony i scalony 2024-07-14 w ciągu 15 sekund **[PR #2]**.

### Kolejne dni lipca

- `scripts/` (2024-07-16): logika wdrożenia przeszła z YAML-a workflow do `scripts/deploy.sh`, a doszedł `scripts/install_hacs.sh` (instalacja HACS do kontenera Home Assistant) **[commit `90f9a2f`, 2024-07-16]**, **[commit `2acd858`, 2024-07-16]**.
- Routing po etykiecie: `defaultRule` Traefika buduje host z etykiety `subdomain` (albo z nazwy kontenera) i domeny ze zmiennej, więc nowa usługa potrzebuje tylko etykiet **[commit `f73d558`, 2024-07-16]**; w ostatecznej postaci `Host({{ or (index .Labels "subdomain") (lower .ContainerName)}}.${PUBLIC_HOSTNAME})` **[plik `compose.auth.yaml` w `b1a441a`]**.
- Przypięte wersje + Renovate: 2024-07-17 obrazy dostały konkretne tagi zamiast `latest` **[commit `b222e39`, 2024-07-17]**, a kilka minut później doszedł `renovate.json` z `config:recommended` **[commit `5b2f015`, 2024-07-17]**. Pierwszy PR Renovate z aktualizacją (Sonarr 4.0.8) scalono 2024-07-18 **[PR #5]**, **[commit `add6c27`, 2024-07-18]**; wcześniejszy był tylko PR onboardingowy „Configure Renovate” z 2024-07-17 **[PR #3]**. Później: grupowanie mniejszych aktualizacji **[commit `720fac2`, 2024-07-22]**, automerge minor/patch **[commit `cbfb327`, 2024-08-21]**, migracja konfiguracji **[commit `882b0f9`, 2024-12-12]**. Stan końcowy: jedna grupa „all non-major dependencies” plus automerge minor/patch z `ignoreTests: true` dla wersji ≥1.0 **[plik `renovate.json` w `b1a441a`]**.
- CrowdSec (2024-07-18): agent czyta logi dostępowe Traefika, a bouncer działa jako plugin Traefika (`maxlerebourg/crowdsec-bouncer-traefik-plugin`) w postaci middleware `crowdsec` **[commit `ac3087c`, 2024-07-18]**, **[commit `84f0ceb`, 2024-07-19]**, **[plik `compose.auth.yaml` w `b1a441a`]**. Od 2024-07-19 każda trasa ma łańcuch middleware `crowdsec,default-headers[,auth]` **[commit `23b199e`, 2024-07-19]**. Powiadomienia e-mail CrowdSec wyłączono 2024-10-08 **[commit `d9ddcc2`, 2024-10-08]**.
- Recyclarr (profile jakości Sonarr/Radarr jako kod) wrócił 2024-07-17 **[commit `f17d368`, 2024-07-17]**. Później ograniczono pobieranie do 1080p bez remuxów **[commit `401b346`, 2024-07-25]**, **[commit `1465ed0`, 2024-07-26]** i dodano filtr języka **[commit `a7909c0`, 2025-04-13]**.
- Decluttarr (sprzątanie zawieszonych i nieudanych pobrań w kolejkach *arr) od **[commit `0d3bbfd`, 2024-07-18]**. W lutym 2025 zmieniło się tylko to, że jego zmienne przeszły do osobnego `.env.decluttarr` **[commit `c8dccdd`, 2025-02-12]**.
- FlareSolverr → Byparr: 2024-07-22 FlareSolverr dostał obraz z gałęzi PR jako „temp fix” **[commit `30f7a17`, 2024-07-22]**. 2024-07-25 serwis przemianowano na `byparr`, z obrazem z rejestru GHCR autora **[commit `7582a93`, 2024-07-25]**. README z 2025-03 opisuje Byparr jako „Cloudflare Turnstile bypass” **[plik `README.md` w `84ea802`]**. **[wniosek]** Autor zastąpił niedziałający FlareSolverr własnym narzędziem; to, że Byparr jest jego projektem, wynika tylko z nazwy rejestru.
- Eksperymenty, które nie weszły na stałe: Open WebUI z Ollamą („possible ai chat ui”) dodany od razu jako zakomentowany **[commit `d663a49`, 2024-07-19]**; `whoami` do testów nagłówków **[commit `a5e01ff`, 2024-07-16]**.

### Dlaczego

Repo tego nie mówi **[nieznane]**. **[wniosek]** Treść zmian wskazuje na przejście z „repo skryptów do ręcznej instalacji” na „repo, którego `main` jest wdrażany automatycznie”: skrypty interaktywne (`read -r -p`) zniknęły, a w ich miejsce przyszły push-to-deploy i Renovate, który bez CD nie miałby sensu.

## 3. Chronologia tematyczna do 2025-07

### 3.1 Wdrażanie i dryf konfiguracji (`scripts/deploy.sh`)

| Data | Zmiana | Dowód |
| --- | --- | --- |
| 2024-07-16 | `git pull && docker compose up -d --remove-orphans`, `sudo git pull` | **[commit `cd74ab3`]**, **[commit `0736b56`]** |
| 2024-08-04 | zawsze `--pull always` + `docker system prune -a -f` | **[commit `5e0ba8c`]** |
| 2024-09-16 | `down` → `pull` → `up` („fix client ip retrival”, patrz 3.4) | **[commit `4c055a4`]** |
| 2024-10-08 | `set -e` w skrypcie | **[commit `693c1ef`]** |
| 2024-12-27 | workflow w środowisku GitHub `server` | **[commit `4c84a73`]** |
| 2025-02-14 | `git pull --rebase` | **[commit `dcfa976`]** |
| 2025-02-18 | z powrotem bez `down` („don't down on update”) | **[commit `bd31092`]** |
| 2025-04-23 | skrypt najpierw robi `git commit -am "[skip ci] Synced latest changes"`, potem `pull --rebase` i `git push` | **[commit `a0ed77e`]**, **[commit `44902bf`]** |

Od 2025-04-23 serwer sam commituje i wypycha zmiany, które powstały na nim lokalnie. Takich commitów „Synced latest changes” jest 8; zmieniają głównie `Config/Home/AdGuard/conf/AdGuardHome.yaml` (AdGuard zapisuje ustawienia z UI do tego pliku), a raz `compose.misc.yaml` **[commit `5493c78`, 2025-05-07]**, **[commit `39db043`, 2025-05-25]**, **[commit `fbc1ef2`, 2025-06-09]**. **[wniosek]** To dwukierunkowa synchronizacja zamiast jednokierunkowego GitOps: źródłem prawdy bywał serwer, a git tylko to rejestrował. Do pracy nadaje się to jako przykład problemu, który rozwiązują później ArgoCD (jednokierunkowo) i konfiguracja aplikacji przez Terraform.

### 3.2 Serwery gier i Minecraft

| Data | Zdarzenie | Dowód |
| --- | --- | --- |
| 2024-07-14 | `docker-compose.game-servers.yaml` (FTB Skies Expert, `eclipse-temurin:17-jre`, port 25565), ale jego `include` od początku zakomentowany; katalog `Servers/` z `.gitkeep` | **[commit `7198b20`]**, **[commit `1562388`]** |
| 2024-07-18 | serwer FTB w pliku zakomentowany („comment out example minecraft server”) | **[commit `d0f7961`]** |
| 2024-07-29 → 2024-08-09 | PufferPanel (panel serwerów gier, z `docker.sock`) dodany, a po 11 dniach wyłączony | **[commit `7b922cd`]**, **[commit `96acad8`]** |
| 2024-08-14 | `docker-compose.mc.yaml` z serwerem DawnCraft uruchamianym przez `start.sh` („use old mc server method”) | **[commit `6461946`]** |
| 2024-12-03 | `include` dla `mc.yaml` zakomentowany, w jego miejsce `docker-compose.dev.yaml` | **[commit `c0d65d8`]** |
| 2025-02-12 | pliki `game-servers`, `mc`, `dev` usunięte w ramach „refactor and migrate to authentik” | **[commit `c8dccdd`]** |

Serwery gier nie zostały więc ani dodane, ani usunięte jednego dnia. W E2 Minecraft działał najwyżej od 2024-08-14 do 2024-12-03; potem pliki leżały nieużywane, a w lutym je skasowano. Powód **[nieznane]**. Pierwszy serwer gry jest jednak starszy niż E2: FTB Skies Expert (port 25565) był włączony w projekcie `dmz` już w E1 **[commit `06b7e79`, 2024-02-26]**, zob. `historia/01-start-docker-compose.md`. README z 2025-03 nadal wymienia „Game server sharing” wśród zastosowań Tailscale **[plik `README.md` w `84ea802`]**, co **[wniosek]** może znaczyć, że serwery gier działały wtedy poza tym repo.

### 3.3 Uwierzytelnianie: Authelia + LLDAP → Authentik (2025-02-12)

- Przed: Authelia (forward-auth Traefika, nagłówki `Remote-User` itd.) z LLDAP jako backendem LDAP **[plik `docker-compose.auth.yaml` w `7198b20`]**. Konfigurację Authelii przeniesiono ze zmiennych środowiskowych do pliku 2024-07-16 **[commit `931521d`, 2024-07-16]**. Home Assistant próbował logowania nagłówkiem z Authelii **[commit `a64d88d`, 2024-07-16]**, wyłączonego 2024-08-04 **[commit `2424d27`, 2024-08-04]**; 2024-08-07 HA w ogóle zdjęto z Authelii **[commit `95ba430`, 2024-08-07]**.
- Zmiana: jeden duży commit **[commit `c8dccdd`, 2025-02-12]**: znika `Config/Auth/Authelia/configuration.yml`, znikają serwisy `authelia` i `lldap`, dochodzą `postgresql`, `redis`, `authentikserver`, `authentikworker` i plik `.env.authentik.example`. Middleware `auth` wskazuje teraz na outpost Authentika (`/outpost.goauthentik.io/auth/traefik`). Tym samym commitem pliki dostały nowe nazwy (`docker-compose.*` → `compose.*`), doszedł pusty `compose.misc.yaml` i zniknęły Samba, Portainer, Watchtower oraz pliki gier i dev.
- Później: outpost LDAP Authentika (`authentik_ldap`, porty 389/636) dla Jellyfina **[commit `f779305`, 2025-03-06]**. README opisuje ręczne kroki: konfigurację Authentika z Traefikiem według zewnętrznego poradnika i ręczny outpost z tokenem w `.env` **[plik `README.md` w `84ea802`]**. Postgres 16 → 17 **[commit `51ffd4a`, 2025-05-04]**.
- Dlaczego: commit podaje tylko „migrate to authentik” **[nieznane]**. Commity pokazują jedno: Jellyfin miał korzystać z LDAP-u, a w nowym układzie LDAP daje outpost Authentika zamiast osobnego LLDAP **[wniosek]**. Porównanie Authelii z Authentikiem należy do pliku technologicznego i wymaga źródeł z sieci.

### 3.4 Prawdziwy IP klienta przez VPS i Tailscale

To najdłuższy techniczny wątek E2. CrowdSec banuje po adresie klienta, więc Traefik musi widzieć prawdziwy IP, choć ruch przychodzi z VPS przez Tailscale.

| Data | Krok | Dowód |
| --- | --- | --- |
| 2024-07-16 | Traefik ufa nagłówkowi PROXY z `100.0.0.0/8` (zakres Tailscale) na `web` i `websecure` | **[commit `d1e481a`]** |
| 2024-08-04 | zostaje sam PROXY protocol, `forwardedHeaders` zakomentowane | **[commit `79def97`]** |
| 2024-09-16 | „fix client ip retrival”: deploy robi pełne `down` przed `up` | **[commit `4c055a4`]** |
| 2025-02-14/18 | porty DNS AdGuarda, a potem 80/443 Traefika publikowane w `mode: host` (bez NAT-u docker-proxy) | **[commit `c319667`]**, **[commit `700b643`]**, **[plik `compose.auth.yaml` w `b1a441a`]** |
| 2025-03-07 | zaufany zakres zawężony do `100.64.0.0/10`, IPv6 w sieci compose „for tailscale ip resolving” | **[commit `b7cb2f9`]** |
| 2025-03-11 → 03-13 | IPv6 dla całego stosu, po dwóch dniach wycofane („fix tailscale ip resolution”) | **[commit `ccf0b9b`]**, **[commit `4f14790`]** |
| 2025-03-13 | README: uruchamiać Tailscale z `--snat-subnet-routes=false` „for docker IP resolving (may break Tailscale subnet routing)” | **[plik `README.md` w `84ea802`]** |

**[wniosek]** Problem tworzyły trzy kolejne warstwy NAT-u: VPS, Tailscale (SNAT dla subnet routes) i docker-proxy. Każdą trzeba było obejść osobno: PROXY protocol, `--snat-subnet-routes=false` i `mode: host`. W E5 cały wątek stracił znaczenie, bo ruch publiczny wchodzi bezpośrednio na MetalLB z `externalTrafficPolicy: Local` **[plik `CLAUDE.md` na `main`, Key Gotchas: Tailscale k8s-operator L3 Services]**.

### 3.5 HAProxy na Oracle VPS

- 2025-03-13 do repo trafiły „vps config files”: `compose.proxy.yaml` (HAProxy `latest` na 80/443 i Watchtower) oraz `haproxy.cfg` w trybie TCP. Na `:80` HAProxy robi redirect 301 na HTTPS, a `:443` przekazuje do `media:443` z `send-proxy-v2` **[commit `0fa08ec`, 2025-03-13]**. TLS nie jest terminowany na VPS; robi to Traefik w domu **[wniosek z `mode tcp`]**.
- README z tego dnia opisuje VPS jako Oracle Cloud free tier (Ampere A1, 4 rdzenie, 20 GB RAM, Ubuntu 24.04 Minimal) z HAProxy „with Proxy Protocol enabled to bypass CGNat”. SSH jest dopuszczony tylko z sieci Tailscale, a VPS działa też jako exit node **[plik `README.md` w `84ea802`]**.
- Data: 2025-03-13 to dzień wgrania konfiguracji do repo, a nie uruchomienia HAProxy. Traefik przyjmował PROXY protocol z adresów Tailscale już od 2024-07-16 **[commit `d1e481a`]**, a VPS z E1 używał WireGuarda **[plik `VPS/install.sh` w `d68bcf6`]**. **[wniosek]** Przejście WireGuard → Tailscale + proxy z PROXY protocol nastąpiło najpóźniej w połowie lipca 2024, ale nie wiadomo, czy od początku był to HAProxy.
- `compose.proxy.yaml` nie jest w `include` `compose.yaml`, więc działał osobno na VPS **[plik `compose.yaml` w `b1a441a`]**.
- CGNAT: README z 2025 twierdzi, że ISP nie daje publicznego IP („bypassing the lack of the public IP from the ISP”) **[plik `README.md` w `84ea802`]**. 2026-08-21 ustalono, że łącze przyjmuje ruch na 80/443, a wcześniejsza diagnoza blokady wynikała ze złego port-forwardu na routerze **[plik `CLAUDE.md` na `main`, Key Gotchas: Orange]**. Nie wiadomo, czy w 2024-2025 łącze było za CGNAT, czy uznano tak z tego samego powodu **[nieznane]**.

### 3.6 DNS: AdGuard Home i split-horizon

- 2024-07-16: rewrite `*.nerine.dev` na adres LAN serwera (wtedy `192.168.1.6`) **[commit `5a81e80`, 2024-07-16]**.
- 2025-01-22 „Fix remote DNS”: rewrite zależny od klienta. Klienci z `100.0.0.0/8` (tailnet) dostają adres Tailscale serwera, klienci z `192.168.0.0/24` dostają adres LAN; dochodzą upstreamy Quad9 (DoT/DoH) **[commit `9561075`, 2025-01-22]**. W E2 klienci tailnetu łączyli się więc z serwerem bezpośrednio, nie przez VPS; dziś dostają publiczny IP jak wszyscy **[plik `CLAUDE.md` na `main`, Key Gotchas: Split-horizon DNS]**.
- Adres LAN serwera w tych regułach zmieniał się kilka razy: `.0.23` → `.0.32` **[commit `c8dccdd`, 2025-02-12]**, → `.0.52` **[commit `700b643`, 2025-02-18]**, → `.0.101` **[commit `39db043`, 2025-05-25]**. Adres Tailscale zmienił się dwa razy 2025-02-12 **[commit `c8dccdd`, 2025-02-12]**, **[commit `7beb0f1`, 2025-02-12]**. **[wniosek]** Serwer dostawał adres z DHCP i był przynajmniej raz stawiany od nowa (nowy węzeł Tailscale) w okolicy migracji na Authentik. To zapowiada problem opisany w E5: pula DHCP routera kolidowała ze statycznymi adresami **[plik `CLAUDE.md` na `main`, Key Gotchas: DHCP pool]**.
- Pozostałe zmiany: listy blokujące (HaGeZi TIF), wyjątki allowlisty, reverse DNS wyłączony i włączony ponownie **[commit `95657be`, 2025-02-14]**, **[commit `581b68a`, 2025-03-03]**, **[commit `ee74218`, 2025-03-31]**.

### 3.7 Inne usługi dodane, zmienione i usunięte

| Usługa | Okres w E2 | Uwagi | Dowód |
| --- | --- | --- | --- |
| Samba | 2024-07-14 → 2025-02-12 | kontener `network_mode: host`; 2024-08-04 przestawiona na dostęp gościnny („make samba public”) | **[commit `8d8ead1`]**, **[commit `c8dccdd`]** |
| Portainer | 2024-07-14 → 2025-02-12 | aktualizowany przez Renovate do 2.26.1, potem usunięty | **[commit `a5ca113`]**, **[commit `c8dccdd`]** |
| Watchtower | dom: 2024-07-14 → 2025-02-12; VPS: od 2025-03-13 | przez 7 miesięcy działał obok Renovate | **[commit `c8dccdd`]**, **[commit `0fa08ec`]** |
| Magnum (projekt deweloperski z zewnętrznej organizacji GitHub, `API_MODE=development`) | 2024-12-03 → 2025-02-12 | jedyny serwis w `docker-compose.dev.yaml` | **[commit `c0d65d8`]**, **[commit `72dec8f`]** |
| scanservjs (skaner przez USB) | w E1 i od 2024-07-14; ponownie dodany 2025-03-05 | po migracji brakowało go od 12.02 do 05.03 | **[commit `52aafff`]** |
| MSSQL 2022 („test mssql”) | 2025-03-03 → 2025-06-09 (zakomentowany przez sync z serwera) | jedyny serwis w `compose.misc.yaml` | **[commit `534fc1f`]**, **[commit `fbc1ef2`]** |
| qBittorrent | hotio → linuxserver + VueTorrent mod | 2025-02-22 | **[commit `180a6a3`]** |
| Wake-on-LAN | port 9 w kontenerze Home Assistant | 2024-08-14 | **[commit `ba0fad5`]** |
| Jellyfin | mod OpenCL Intel, `/dev/dri` (iGPU UHD 770) | przez cały okres | **[plik `compose.media.yaml` w `c8dccdd`]** |

Powody usunięcia Samby, Portainera i Watchtowera na serwerze **[nieznane]**. **[wniosek]** Watchtower (aktualizacje `latest` w czasie działania) i Renovate (aktualizacje przypiętych tagów przez PR) robiły to samo, więc usunięcie Watchtowera z serwera, gdzie wersje są przypięte, jest spójne. Na VPS, gdzie HAProxy ma tag `latest`, Watchtower został.

## 4. Decyzje i problemy w skrócie

| Decyzja / problem | Rozwiązanie w E2 | Motyw w repo? |
| --- | --- | --- |
| Ręczne skrypty instalacyjne | push-to-deploy przez GitHub Actions + Tailscale SSH (2024-07-14) | nie |
| Niekontrolowane `latest` | przypięte tagi + Renovate z automerge minor/patch (2024-07-17, 2024-08-21) | nie |
| Ataki na publiczne usługi | CrowdSec + plugin bouncera w Traefiku (2024-07-18) | nie |
| FlareSolverr przestał działać (przypuszczalnie) | własny Byparr (2024-07-25) | częściowo („temp fix for flaresolverr”) |
| Utrata IP klienta za VPS/Tailscale/Dockerem | PROXY protocol, `mode: host`, `--snat-subnet-routes=false` | częściowo (tytuły commitów) |
| Authelia + LLDAP | Authentik + outpost LDAP (2025-02-12, 2025-03-06) | nie |
| Zmiany z UI (AdGuard) rozjeżdżają się z gitem | serwer sam commituje i pushuje (2025-04-23) | nie |

## 5. Stan na koniec E2 (`b1a441a`, 2025-07-24)

### Architektura

```
Internet → Oracle VPS (HAProxy, TCP, PROXY v2) → Tailscale → serwer domowy:443
                                                           └ Traefik (TLS, Let's Encrypt DNS-01 Cloudflare, wildcard)
                                                              ├ middleware: crowdsec → default-headers → auth (Authentik forward-auth)
                                                              └ kontenery Docker (etykieta subdomain)
LAN / tailnet → AdGuard Home (split-horizon) → serwer bezpośrednio
GitHub push → Actions → Tailscale SSH → scripts/deploy.sh (commit+pull+push, compose up --pull always, prune)
```

Źródła: **[plik `compose.auth.yaml` w `b1a441a`]**, **[plik `haproxy.cfg` w `b1a441a`]**, **[plik `.github/workflows/deploy.yaml` w `b1a441a`]**, **[plik `README.md` w `b1a441a`]**.

### Gdzie co działało

| Maszyna | Rola | Dowód |
| --- | --- | --- |
| Serwer domowy: i5-12600K, 32 GB RAM, NVMe 1 TB + 5× HDD 3 TB (odnowione), Proxmox VE 8, Docker w maszynie wirtualnej | wszystkie usługi z `compose.yaml` | **[plik `README.md` w `84ea802`]** |
| Oracle VPS: Ampere A1 4 rdzenie, 20 GB RAM, Ubuntu 24.04 | HAProxy + Watchtower (`compose.proxy.yaml`), exit node Tailscale | **[plik `README.md` w `84ea802`]**, **[commit `0fa08ec`]** |

Kiedy serwer przeszedł z instalacji bezpośrednio na systemie (skrypty E1 instalowały Ubuntu i ZFS na hoście) na Proxmox z maszyną wirtualną z Dockerem, żaden commit nie mówi **[nieznane]**. **[wniosek]** Mogło to być około 2025-01/02: zmiana podsieci LAN i nowy węzeł Tailscale 2025-02-12.

### Lista usług (`compose.yaml` → `include`)

| Plik | Usługi |
| --- | --- |
| `compose.auth.yaml` (`name: reverse-proxy`) | CrowdSec, Traefik v3.5, whoami, PostgreSQL 17, Redis, Authentik server/worker/LDAP 2025.6, Postfix |
| `compose.home.yaml` | Home Assistant 2025.7 (`/dev/ttyUSB0`), httpd (nginx, strona na domenie głównej), Homepage, Renamer, AdGuard Home, scanservjs |
| `compose.media.yaml` | Bazarr, Radarr, Sonarr, Prowlarr, qBittorrent, Jellyseerr, Jellyfin, Byparr, Decluttarr, Recyclarr |
| `compose.misc.yaml` | pusty (MSSQL zakomentowany) |
| `compose.proxy.yaml` (VPS, poza `include`) | HAProxy, Watchtower |

**[plik `compose*.yaml` w `b1a441a`]**. README wymienia w planach „Implement proper backup solution” i „Expand monitoring capabilities” **[plik `README.md` w `84ea802`]**, czyli kopii zapasowych i monitoringu w E2 nie było.

### Co skłoniło do E3

Repo nie podaje powodu wprost **[nieznane]**. Pierwsze commity E3 (2025-07-26) od razu wyłączają stary workflow i dodają Ansible i Terraform **[commit `fc8269f`, 2025-07-26]**, **[commit `162b32c`, 2025-07-26]**, **[commit `6930efc`, 2025-07-26]**. Następnego dnia pojawia się „prepare for kubernetes” **[commit `a9ff5be`, 2025-07-27]**. Commit „migrate back to terraform” **[commit `75e604b`, 2025-07-26]** sugeruje, że Terraform (albo OpenTofu) był już wcześniej używany gdzie indziej. **[wniosek]** Słabe punkty E2 widoczne w samym repo:

1. Ręczne kroki konfiguracji w README (Authentik, outpost LDAP, klucze API *arr przepisywane do `.env`, drugie `docker compose up`).
2. Dryf konfiguracji obsługiwany commitami z serwera.
3. Brak IaC dla hosta, VM i VPS: Proxmox i VPS stawiane ręcznie, a konfiguracja VPS trafiła do repo dopiero po fakcie.
4. Brak backupu i monitoringu.
5. Jeden host jako pojedynczy punkt awarii.

Każdy z nich ma odpowiednik w E3/E4 (Terraform/Ansible, ArgoCD, borg, observability, 3 węzły Talos), ale motyw trzeba potwierdzić u autora.

## Pytania do autora

1. Dlaczego 2025-02-12 zastąpiłeś Authelię i LLDAP Authentikiem? Chodziło o outpost LDAP dla Jellyfina, o OIDC, o UI czy o coś innego?
2. Dlaczego usunąłeś serwery gier (FTB, DawnCraft, PufferPanel)? Czy działały potem gdzie indziej, skoro README z 2025-03 wymienia „Game server sharing” przez Tailscale?
3. Kiedy serwer domowy przeszedł z Ubuntu na hoście na Proxmox VE 8 z VM dla Dockera i dlaczego?
4. Kiedy VPS przeszedł z tunelu WireGuard (E1) na proxy przez Tailscale z PROXY protocol i czy od początku był to HAProxy na Oracle free tier?
5. Czy w latach 2024-2025 łącze faktycznie było za CGNAT (brak publicznego IP), czy to była ta sama błędna diagnoza co w 2026-08?
6. Co zastąpiło Sambę i Portainera po 2025-02-12 (np. udział na hoście Proxmox)?
7. Do czego służył kontener MSSQL („test mssql”) i projekt Magnum w `docker-compose.dev.yaml`?
8. Czy Byparr powstał dlatego, że FlareSolverr przestał przechodzić wyzwania Cloudflare w lipcu 2024?
9. Co w lipcu 2025 przesądziło o przejściu na Terraform/Ansible/Kubernetes? I co znaczy „migrate back to terraform”: wcześniejsze użycie Terraformu gdzie indziej czy OpenTofu?
10. Czy automatyczne commity „Synced latest changes” z serwera były świadomym wyborem, czy obejściem problemu z UI AdGuarda?

## Do której części pracy

- Wstęp / motywacja: punkt wyjścia przed IaC, z wdrożeniem przez CI, ale z ręcznym hostem i dryfem (sekcje 2, 3.1, 5).
- Projekt: porównanie architektury E2 (VPS + HAProxy + Tailscale + jeden host Docker) z docelową; wątek IP klienta (3.4) i split-horizon DNS (3.6) jako wymagania, które przeszły do nowego projektu.
- Implementacja: tło dla Renovate, CrowdSec, Authentik, Recyclarr i Decluttarr, które przetrwały migrację do Kubernetes.
- Odtwarzanie po awarii: stan wyjściowy bez backupu i z ręcznymi krokami (sekcja 5) jako punkt odniesienia dla testu odtworzenia.
- Analiza kosztów: VPS na Oracle free tier i sprzęt serwera z README (sekcja 5).

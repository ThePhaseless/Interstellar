# Aplikacje użytkowe i repatriacja usług chmurowych

Ten plik dotyczy aplikacji, z których korzystają ludzie: autor, domownicy i znajomi. Warstwa platformy (Kubernetes, Longhorn, Traefik, Authentik) jest opisana w innych plikach. Przy każdej aplikacji podaję, co robi w tym homelabie, od kiedy do kiedy działała, jaką usługę chmurową zastępuje lub mogłaby zastępować i na jakie ograniczenia trafiono. Na końcu jest tabela repatriacji: co przeniesiono z chmury do domu, a co w chmurze zostało.

Daty pochodzą z historii brancha `main`. „Od” to commit, który dodał usługę do pliku compose lub manifestu, „Do” to commit, który ją usunął. Repo zaczyna się 2024-01-01, a serwer działał już wcześniej, więc część usług z ery compose mogła działać dłużej, niż pokazuje historia **[wniosek]**.

Repo pokazuje tylko, że zamiennik działa. Nie pokazuje, że autor miał kiedyś abonament ani że z niego zrezygnował. Dlatego ceny w tym pliku są punktem odniesienia z cenników, a nie kosztami autora. Faktyczne abonamenty to pytania na końcu pliku.

## 1. Oś czasu aplikacji

### 1.1. Era compose (E1-E2, 2024-01 → 2025-09)

Pierwszy commit zawiera tylko proxy (Traefik, Authelia, Watchtower) i skrypty hosta, w tym `general/setup_samba.sh` i `host/run_portainer.sh` **[commit `386f12a`, 2024-01-01]**. Stos aplikacji trafia do repo 2024-01-15 w katalogu `DMZ/`, w commitach „add compose files” **[commit `ba47ea5`, 2024-01-15]** i „Update VSCode extensions and Docker services” **[commit `8f3e37d`, 2024-01-15]**. W lipcu 2024 pliki przechodzą na układ `docker-compose.<grupa>.yaml` w katalogu głównym **[commit `7198b20`, 2024-07-14]**, a w lutym 2025 na `compose.<grupa>.yaml`, razem z przejściem z Authelii na Authentik **[commit `c8dccdd`, 2025-02-12]**. Ostatni zestaw plików compose usuwa commit „remove og compose” **[commit `28fbc9e`, 2025-09-01]**.

| Usługa (obraz) | Rola tutaj | Od | Do | Dalszy los |
|---|---|---|---|---|
| Jellyfin (`linuxserver/jellyfin`) | serwer multimediów, transkodowanie przez `/dev/dri` z modem `linuxserver/mods:jellyfin-opencl-intel` **[plik `compose.media.yaml` w `28fbc9e^`]** | `ba47ea5` 2024-01-15 | `28fbc9e` 2025-09-01 | Kubernetes |
| Sonarr, Radarr, Prowlarr, Bazarr (`linuxserver/*`) | automatyzacja biblioteki seriali i filmów, indeksy, napisy | `ba47ea5` 2024-01-15 | `28fbc9e` 2025-09-01 | Kubernetes |
| Jellyseerr (`fallenbagel/jellyseerr`) | zgłaszanie próśb o filmy i seriale | `ba47ea5` 2024-01-15 | `28fbc9e` 2025-09-01 | Kubernetes, potem Seerr |
| qBittorrent (`hotio/qbittorrent`, od `180a6a3` 2025-02-22 `linuxserver/qbittorrent`) | klient BitTorrent | `ba47ea5` 2024-01-15 | `28fbc9e` 2025-09-01 | Kubernetes |
| Recyclarr | synchronizacja profili jakości do Sonarr i Radarr | `ba47ea5` 2024-01-15; przerwa od `6f7927b` 2024-07-14 do „add recyclar” `f17d368` 2024-07-17 | `28fbc9e` 2025-09-01 | Kubernetes |
| FlareSolverr | rozwiązywanie wyzwań Cloudflare dla indeksów | `ba47ea5` 2024-01-15 | `6c0c661` 2024-07-25 | w tym samym commicie zastąpiony przez Byparr |
| Byparr (`ghcr.io/thephaseless/byparr`) | zamiennik FlareSolverr; obraz z przestrzeni nazw właściciela repo **[wniosek: projekt autora]** | `6c0c661` 2024-07-25 | `28fbc9e` 2025-09-01 | Kubernetes |
| Decluttarr | usuwanie zawieszonych pobrań z kolejek *arr | `0d3bbfd` 2024-07-18 | `28fbc9e` 2025-09-01 | Kubernetes |
| Immich (+ ML, Redis, pgvecto-rs) | biblioteka zdjęć | `8f3e37d` 2024-01-15 | wyłączony „dont use Immich” `334c89d` 2024-02-11, usunięty `06b7e79` 2024-02-26 | wraca w Kubernetes w `6757719` 2026-02-01 |
| Duplicati | kopie zapasowe | `8f3e37d` 2024-01-15 | przeniesiony do stosu Immicha (`8d6dcf4` 2024-02-10) i usunięty razem z nim (`06b7e79` 2024-02-26) | kopie wracają jako BorgBackup w E4 |
| AdGuard Home | DNS z blokowaniem reklam dla sieci domowej | `ba47ea5` 2024-01-15 | `28fbc9e` 2025-09-01 | Kubernetes |
| Home Assistant (`ghcr.io/home-assistant/home-assistant`) | automatyka domowa | `acfb3af` 2024-02-25 | `28fbc9e` 2025-09-01 | chwilę w Kubernetes, potem VM na Proxmoxie |
| scanservjs | webowy interfejs skanera | `ba47ea5` 2024-01-15; przerwa od `c8dccdd` 2025-02-12 do „add scan service” `52aafff` 2025-03-05 | `28fbc9e` 2025-09-01 | Kubernetes do 2026-02-01, od 2026-11 Pagewire |
| gptwol | Wake-on-LAN z przeglądarki | `8f3e37d` 2024-01-15 | `6f7927b` 2024-07-14 | brak następcy |
| Homepage (`gethomepage/homepage`) | strona startowa z kafelkami usług | `8f3e37d` 2024-01-15 | `28fbc9e` 2025-09-01 | Kubernetes, potem statyczna strona, od 2026-08 biblioteka aplikacji Authentika |
| httpd / nginx | statyczna strona WWW z portfolio (`DMZ/Compose/Home/website`, `05b109f` 2024-01-19) | 2024-01-15 | `28fbc9e` 2025-09-01 | Kubernetes `utilities/httpd` do 2026-02-01 |
| sggwbot → Renamer | bot; w `2706f22` (2024-01-19) usługa `sggwbot` zmienia nazwę i obraz na `ghcr.io/thephaseless/renamer` z tokenem `RENAMER_BOT_TOKEN` | `ba47ea5` 2024-01-15 | `28fbc9e` 2025-09-01 | Kubernetes `utilities/renamer` do 2026-02-01 |
| Portainer | GUI do Dockera | skrypt `host/run_portainer.sh` w `386f12a`; w compose od `34a5add` 2024-02-08 | `c8dccdd` 2025-02-12 | powód usunięcia [nieznane] |
| Samba (`servercontainers/samba`) | udział plików w LAN (wcześniej skrypt `general/setup_samba.sh`) | `7198b20` 2024-07-14 | `c8dccdd` 2025-02-12 | funkcję udostępniania plików przejmuje w 2026 copyparty **[wniosek]** |
| FileBrowser, wolweb, `benphelps/homepage` | przeglądarka plików, Wake-on-LAN, stara wersja Homepage | `ba47ea5` 2024-01-15 | `8f3e37d` 2024-01-15 (ten sam dzień) | brak |
| Postfix (`boky/postfix`) | przekaźnik SMTP dla powiadomień, relay przez `smtp.gmail.com:587` **[plik `compose.auth.yaml` w `28fbc9e^`]** | `7198b20` 2024-07-14 | `28fbc9e` 2025-09-01 | Kubernetes, relay przez OCI Email Delivery |
| PufferPanel | panel serwerów gier | `ba47ea5` 2024-01-15, usunięty tego samego dnia w `8f3e37d`; ponownie „add pufferpanel” `7b922cd` 2024-07-29 | „disable puffer panel” `96acad8` 2024-08-09 (zakomentowany do `28fbc9e`) | brak |
| Serwery Minecraft (`eclipse-temurin` + `start.sh` z modpacka): FTB Skies Expert, DawnCraft | modowane serwery gry | `06b7e79` 2024-02-26 (`docker-compose.game-servers.yaml`); DawnCraft `6461946` 2024-08-14 | `c8dccdd` 2025-02-12 | od 2026-04 osobny host z tagiem `tag:minecraft` (pkt 2.8) |
| Magnum (`silvernetgroupsggw/magnum`) | środowisko deweloperskie projektu zespołowego | `c0d65d8` 2024-12-03 | `c8dccdd` 2025-02-12 | brak |
| MS SQL Server | testowa baza danych | `534fc1f` 2025-03-03 | `fbc1ef2` 2025-06-09 | brak |
| whoami (`traefik/whoami`) | test reverse proxy | `370fea4` 2024-01-15; przerwa od `06b7e79` do `a5e01ff` 2024-07-16 | `28fbc9e` 2025-09-01 | Kubernetes do `7158f21` 2026-08-20 |

Daty z tabeli ustalono przez `git log -S"<obraz>" -- '*compose*.y*ml'`, czyli według commitów, które zmieniły liczbę wystąpień nazwy obrazu.

### 1.2. Kubernetes (E3-E5, od 2025-08)

Pliki compose przekonwertowano na manifesty narzędziem kompose w „migrate compose files” **[commit `abcb648`, 2025-08-11]**. Nazwy w rodzaju `claim0-persistentvolumeclaim.yaml` to typowy wynik kompose **[wniosek]**, a commit „remove kompose” **[commit `f2082c1`, 2025-08-13]** usuwa samo narzędzie. Podział na katalogi `Kubernetes/media`, `home`, `utilities`, `infrastructure` przychodzi z „organize” **[commit `328dddf`, 2025-08-15]**. Home Assistant znika z klastra tego samego dnia, w „remove home assistant” **[commit `929e6b4`, 2025-08-15]**. Przebudowa „migrate” wprowadza obecny układ `Kubernetes/apps/*` zarządzany przez ArgoCD **[commit `6757719`, 2026-02-01]**.

| Aplikacja | Rola tutaj | Od | Do / stan na 2026-11-27 |
|---|---|---|---|
| Jellyfin (`jellyfin/jellyfin`, host `watch.nerine.dev`) | strumieniowanie biblioteki z transkodowaniem na GPU | `abcb648` 2025-08-11 | działa |
| Sonarr, Radarr, Prowlarr, Bazarr, Recyclarr, Decluttarr | jak w compose; konfiguracja przez Terraform (`Terraform/apps/servarr.tf`), metryki przez `exportarr`, powiadomienia na Discord i e-mail **[commit `2b33dec`, 2026-02-24]** | `abcb648` 2025-08-11 | działają |
| Jellyseerr → Seerr (`ghcr.io/seerr-team/seerr`) | prośby o filmy i seriale; Jellyseerr z kompose, potem Seerr | Jellyseerr `abcb648` 2025-08-11; obraz Seerr w deploymencie `jellyseerr` od `b9f0bfe` 2026-02-19 (gałąź migracyjna; na `main` od 2026-02-26, `327eff3`), przemianowanie na `seerr` w `6911d9a` 2026-02-26 | Seerr działa |
| qBittorrent | klient BitTorrent; pobrania na puli mergerfs z NVMe jako pierwszą warstwą **[commit `0bdd584`, 2026-09-01]** | `abcb648` 2025-08-11 | działa |
| Byparr | rozwiązywanie wyzwań Cloudflare dla Prowlarr (natywne proxy FlareSolverr, tag 1) | `abcb648` 2025-08-11 | działa |
| byparr-proxy | dwie instancje pośredniczące dla dwóch indeksów | `7855699` 2026-08-08 | usunięte w `c854fe2` 2026-11-05, bo natywne definicje Prowlarr dawały te same lub lepsze wyniki |
| arr-coverage-search | CronJob, który szuka po jednej pozycji i czeka, dopóki Prowlarr zgłasza indeks w backoffie | `f07d1ad` 2026-08-27 | działa |
| Immich (`photos.nerine.dev`) | biblioteka zdjęć z ML na GPU (`immich-machine-learning:*-openvino`) | `6757719` 2026-02-01 | działa |
| copyparty (`ghcr.io/9001/copyparty-ac`) | serwer plików z sekcjami `/private`, `/members`, `/public`, `/media` | `6757719` 2026-02-01 | działa |
| copyparty-dav | druga instancja: WebDAV przez tailnet bez IdP | `3cdfd9b` 2026-08-20 | usunięta w `6e9a4c5` 2026-09-03 |
| clips-sftp | pod `tailscaled` zarejestrowany jako `files`, SFTP tylko do `/personal/public/clips` | `cf24c25` 2026-11-17 | działa |
| AdGuard Home (`dns.nerine.dev`) | DNS dla LAN i tailnetu | `abcb648` 2025-08-11 | działa |
| Postfix | relay SMTP dla powiadomień klastra | `abcb648` 2025-08-11; obecny katalog `16fdd8f` 2026-02-24 | działa |
| Pagewire (`print.nerine.dev`) | drukowanie i skanowanie na Samsung SCX-4300; `scan.nerine.dev` przekierowuje do niego | `e3857f4` 2026-11-25 | działa |
| c-oop (`c-oop.nerine.dev`) | współdzielony edytor C++, publiczny bez logowania | `d9446b8` 2026-11-22 | działa |
| homepage | statyczna strona dla `nerine.dev` | `1d273cf` 2026-02-19 | zastąpiona biblioteką aplikacji Authentika w `3fce217` 2026-08-21 |
| mcpjungle (`mcp.nerine.dev`) | brama serwerów MCP | `6757719` 2026-02-01 | usunięta w `096bd7e` 2026-08-19 |
| whoami | debugowanie sieci, od `096bd7e` publiczne | `fa77451` 2026-02-01 | usunięte w `7158f21` 2026-08-20 |
| MinIO | cel kopii Longhorna (S3) | `145f097` 2026-06-03 | wycofane tego samego dnia w `59a11a8` |
| Home Assistant | VM na Proxmoxie, poza Kubernetes i poza Terraformem | [nieznane] | działa |
| Minecraft | serwer udostępniany znajomym przez Tailscale | `7168368` 2026-04-08 (tag w polityce) | host poza repo [nieznane] |

Dostęp do aplikacji wyznaczają grupy Authentika: `watchers` (Jellyfin), `photos` (Immich, z samodzielną rejestracją), `vips` (usługi prywatne, Grafana, ArgoCD), `writers` (zapis w copyparty) i `admins` **[commit `12b2249`, 2026-08-19]**. Po zmianie strony głównej przypadkowe konto Google widzi tylko copyparty, a członek `watchers` widzi copyparty i Jellyfin **[commit `3fce217`, 2026-08-21]**. Z homelabu korzysta więc więcej osób niż sam autor **[wniosek]**. Ile ich jest, repo nie mówi.

## 2. Aplikacje według funkcji

### 2.1. Media: Jellyfin i automatyzacja (*arr)

**Co robi.** Jellyfin udostępnia bibliotekę filmów i seriali z puli ZFS przez NFS (`media-pvc`) pod `watch.nerine.dev` **[plik `Kubernetes/apps/jellyfin/ingress.yaml`]**. Sonarr (seriale), Radarr (filmy), Prowlarr (indeksy), Bazarr (napisy), Recyclarr (profile jakości), Decluttarr (sprzątanie kolejek) i qBittorrent (pobieranie) automatyzują uzupełnianie biblioteki. Seerr zbiera prośby użytkowników. Konfigurację *arr opisuje Terraform **[plik `Terraform/apps/servarr.tf`]**.

**GPU do transkodowania.** W erze compose Jellyfin dostawał `/dev/dri` i moda OpenCL dla Intela **[plik `compose.media.yaml` w `28fbc9e^`]**. Wskazuje to na zintegrowane GPU Intela, np. procesora i5-12600K z obecnego `README.md`, o ile w 2024 był to ten sam procesor **[wniosek]**. W pierwszym klastrze Jellyfin używał `runtimeClassName: nvidia` **[commit `318ae6d`, 2025-08-16]**, a wtyczka `nvidia-device-plugin` dostawała aktualizacje do 2026-01-23 **[commit `dafd355`, 2026-01-23]**. Od 2026-02-01 w `bootstrap/` jest `intel-gpu-operator`, a 2026-02-18 Jellyfin i Immich ML przechodzą na zasób `gpu.intel.com/xe` (Battlemage, Intel Arc B580) i selektor węzła z NFD **[commit `34c4dbc`, 2026-02-18]**. Jaką kartę NVIDIA autor miał i dlaczego przeszedł na Arc, to pytanie do autora.

**Logowanie.** Jellyfin dostał SSO przez wtyczkę OIDC 9p4 w miejsce wcześniejszego systemu VIP **[commit `16fdd8f`, 2026-02-24]**, a potem przeszedł na wtyczkę JellyfinSecurity **[commit `ccb3005`, 2026-07-28]**. Logowanie hasłem zostało jako droga awaryjna na wypadek awarii Authentika **[commit `12b2249`, 2026-08-19]**. Aplikacje *arr nie mają własnego SSO. Kontener startowy wpisuje do `config.xml` `AuthenticationMethod=External`, a tożsamość przychodzi w nagłówku `Remote-User` z forward-auth Traefika **[plik `AGENTS.md`, wpis od `bf8056e` 2026-03-09]**.

**Ograniczenia napotkane w repo.**
- Karta Arc bez firmware'u DMC nie wchodziła w uśpienie i pobierała ok. 9 W bez przerwy. Pomogło rozszerzenie Talos `i915` **[plik `AGENTS.md`, wpis od `aee76cc` 2026-06-14]**. Okresowe skoki wentylatora usunęła aktualizacja firmware'u karty z LVFS **[plik `AGENTS.md`, wpis od `711d818` 2026-07-27]**.
- Jellyfin pobiera dane OIDC z publicznego adresu `auth.nerine.dev`. Z poda wymaga to `hostAliases` na adres MetalLB Traefika, bo split-horizon DNS działa tylko w LAN **[plik `AGENTS.md`, wpis od `e42d919` 2026-05-14]**.
- Po restarcie wewnątrz procesu (`jellyfin_restart` w Terraformie) `/health` zwraca 200, a interfejs WWW same błędy 500, bo zostaje stary assembly wtyczki **[plik `Kubernetes/AGENTS.md`]**.
- Standardowy scenariusz CrowdSec `http-dos-random-uri` banował zwykłych użytkowników Jellyfina przewijających bibliotekę. Potrzebny był własny parser-wyjątek **[plik `Kubernetes/AGENTS.md`]**.
- qBittorrent przez mergerfs i NFS: zmiana nazwy pliku `X.mkv.!qB` → `X.mkv` zrywała otwarte deskryptory **[plik `AGENTS.md`, wpis od `3804899` 2026-09-02]**. `compression=off` na ZFS wyłączał wykrywanie bloków zerowych i rozdmuchał rzadki plik torrenta z 0,9 do 79 GiB **[plik `AGENTS.md`, wpis od `064f440` 2026-09-02]**. „Mark as failed” w Sonarr/Radarr przy seedowanym torrencie zostawiał pełnowymiarowe sieroty `.nfs*` **[plik `AGENTS.md`, wpis od `957d2a2` 2026-11-19]**.
- Masowe wyszukiwanie Radarra działa równolegle i po cichu gubi indeksy w backoffie. Stąd własny job `arr-coverage-search` **[commit `f07d1ad`, 2026-08-27]**.
- Decluttarr potrafi trwale „zatruć” listę usuniętych pobrań, a Bazarr w kontenerze s6-overlay przy OOM raportuje `Completed`/`0` zamiast `OOMKilled` **[plik `Kubernetes/AGENTS.md`]**.

**Uwaga do opisu w pracy.** Sonarr, Radarr, Prowlarr i qBittorrent to narzędzia ogólnego przeznaczenia. Sonarr opisuje się jako „Smart PVR for newsgroup and bittorrent users” **[źródło: https://github.com/Sonarr/Sonarr, dostęp 2026-11-27]**. O tym, czy ich użycie jest legalne, decyduje źródło treści, a nie samo oprogramowanie **[wniosek]**. W pracy lepiej opisywać je technicznie: kolejki, profile jakości, integracja przez API, obsługa awarii indeksów. Nazwy konkretnych indeksów z repo celowo pominięto w tym pliku. Jak autor chce przedstawić tę część, to pytanie na końcu pliku.

**Co zastępuje.** Biblioteka Jellyfina może zastępować serwisy VOD i płatne serwery multimediów **[wniosek]**. Pełną zamianę daje tylko wtedy, gdy treści pochodzą z legalnego źródła, np. z własnych nośników **[wniosek]**. Ceny serwisów są w sekcji 3. Czy autor płacił za Netflix, Disney+, HBO Max lub Plex Pass, to pytanie do autora.

**Alternatywy self-hosted.**

| Projekt | Licencja | Ostatnie wydanie | Płatne funkcje | Ograniczenia | Źródło |
|---|---|---|---|---|---|
| Jellyfin | GPL-2.0 | v12.4, 2026-10-26 | brak warstw płatnych [nie potwierdzono w dokumentacji] | logowanie i klienty natywne nie sprawdzone | **[źródło: https://github.com/jellyfin/jellyfin, dostęp 2026-11-27]** |
| Plex Media Server | własnościowa [nieznane: nie sprawdzono na stronie Plex, strony zwracały 403] | [nieznane] | zdalne oglądanie wideo wymaga Plex Pass po stronie właściciela serwera albo Plex Pass / Remote Watch Pass po stronie widza (zmiana z 2025) | wymóg Plex Pass dla transkodowania sprzętowego i zależność od konta plex.tv nie sprawdzone | **[źródło: https://9to5mac.com/2026/05/19/plex-increasing-lifetime-plex-pass-cost-to-whopping-750/, dostęp 2026-11-27; artykuł, nie strona Plex]** |
| Emby | własnościowa (stare repo `MediaBrowser/Emby` na GPL-2.0, ostatni push 2024-03-27) | 4.10.2.0, 2026-10-20 | Emby Premiere: transkodowanie sprzętowe na GPU, pełne aplikacje mobilne i na konsole, pobieranie offline | licencja Premiere: jedno gospodarstwo, 30 urządzeń | **[źródło: https://emby.media/premiere.html, https://github.com/MediaBrowser/Emby.Releases, dostęp 2026-11-27]** |

Dla Seerr (MIT, v3.5.2 z 2026-11-12) alternatywą jest Ombi (GPL-2.0, repo aktywne, ostatni push 2026-11-06) **[źródło: https://github.com/seerr-team/seerr, https://github.com/Ombi-app/Ombi, dostęp 2026-11-27]**. Seerr powstał z połączenia zespołów Jellyseerr i Overseerr ogłoszonego 2026-02-10 **[źródło: http://docs.seerr.dev/blog/seerr-release/, dostęp 2026-11-27]**. Pierwszy obraz Seerr pojawia się w repo 9 dni później **[commit `b9f0bfe`, 2026-02-19]**, a pełne przemianowanie po 16 dniach **[commit `6911d9a`, 2026-02-26]**. Licencje pozostałych narzędzi: Sonarr, Radarr, Prowlarr, Bazarr GPL-3.0; Recyclarr i FlareSolverr MIT; qBittorrent GPLv2+ (kod) / GPLv3+ (binaria) z wyjątkiem w pliku COPYING **[źródło: repozytoria GitHub projektów, dostęp 2026-11-27]**.

**Dlaczego Jellyfin.** Repo nie podaje powodu. Jellyfin jest od pierwszego stosu compose **[commit `ba47ea5`, 2024-01-15]**. Brak opłat za transkodowanie sprzętowe [do weryfikacji w dokumentacji Jellyfina] (w Emby to funkcja Premiere) i za zdalny dostęp (w Plex od 2025 płatny) pasuje do tego wyboru **[wniosek]**, ale motyw autora to pytanie.

**Kiedy wybrać coś innego.** Plex, gdy zdalni widzowie są gotowi płacić za Remote Watch Pass, a właściciel przyjmuje zamknięty kod. Emby, gdy ktoś akceptuje opłatę Premiere za transkodowanie na GPU i limit 30 urządzeń **[wniosek, na podstawie tabeli]**. Jakość klientów na telewizory w trzech projektach nie została sprawdzona [do weryfikacji]. Jeśli biblioteka jest mała, a użytkownik ogląda głównie nowości, abonament VOD bywa tańszy niż dyski i prąd. Porównanie kosztów jest w pliku o kosztach.

### 2.2. Zdjęcia: Immich

**Co robi.** Immich (`photos.nerine.dev`) trzyma zdjęcia na NFS `/Storage/Photos` (PV `photos-nfs-pv` → PVC `immich-upload`) **[plik `Kubernetes/apps/common/media-pv.yaml`]**, bazę Postgres na Longhornie (3Gi), a cache modeli ML lokalnie na węźle z GPU **[plik `Kubernetes/apps/immich/pvc.yaml`]**. Statyczne PV dla zdjęć wprowadził `a338df4` **[commit `a338df4`, 2026-02-20]**. Funkcje ML liczy kontener `immich-machine-learning` w wariancie OpenVINO na GPU Intel Arc **[plik `Kubernetes/apps/immich/ml-deployment.yaml`]**. Jakie funkcje ML są włączone (twarze, wyszukiwanie), nie sprawdzono w dokumentacji [do weryfikacji]. Logowanie idzie przez OIDC Authentika z automatycznym przekierowaniem i wyłączonym logowaniem hasłem **[plik `Kubernetes/apps/immich/deployment.yaml`]**. Authentik z kolei loguje wyłącznie kontem Google **[commit `2b33dec`, 2026-02-24]**. Grupa `photos` pozwala na samodzielną rejestrację **[commit `12b2249`, 2026-08-19]**.

**Historia.** Immich był w pierwszym stosie compose **[commit `8f3e37d`, 2024-01-15]**, po niecałym miesiącu został wyłączony („dont use Immich”) **[commit `334c89d`, 2024-02-11]** i usunięty **[commit `06b7e79`, 2024-02-26]**. Wrócił dopiero w klastrze **[commit `6757719`, 2026-02-01]**. Commit z 2024 nie podaje powodu. Czym autor przechowywał zdjęcia przez te dwa lata, to pytanie do autora.

**Co zastępuje.** Zdjęcia Google (miejsce z Google One, wspólne ze Zdjęciami, Dyskiem i Gmailem **[źródło: https://one.google.com/about/plans?hl=pl&gl=PL, dostęp 2026-11-27]**) albo zdjęcia w iCloud+ **[wniosek]**. Logowanie do Authentika nadal idzie przez konto Google, więc repatriowane są same zdjęcia, a tożsamość zostaje w chmurze **[wniosek z `2b33dec`]**.

**Alternatywy self-hosted.**

| Projekt | Licencja | Ostatnie wydanie | Płatne funkcje | Ograniczenia | Źródło |
|---|---|---|---|---|---|
| Immich | AGPL-3.0 | v3.4.2, 2026-11-18 | link „Buy Immich”; czy coś jest zablokowane [nieznane] | (repo: ML na GPU wymaga wariantu obrazu `-openvino`) | **[źródło: https://github.com/immich-app/immich, dostęp 2026-11-27]** |
| PhotoPrism | AGPL-3.0 (plik LICENSE) | 261029-963b58c50, 2026-10-29 | edycje Community (darmowa), Essentials, Plus oraz hostowana PikaPods; zakres Plus nie przypisany na stronie | aplikacja mobilna to PWA + zewnętrzny PhotoSync | **[źródło: https://www.photoprism.app/editions, https://github.com/photoprism/photoprism, dostęp 2026-11-27]** |
| Nextcloud Memories | AGPL-3.0 | v11.1.4, 2026-11-13 | [nieznane] | działa jako aplikacja Nextcloud, więc wymaga całego Nextcloud | **[źródło: https://github.com/pulsejet/memories, dostęp 2026-11-27]** |
| Ente (serwer i klienci) | AGPL-3.0 | photos-v1.3.70, 2026-11-13 | hostowana usługa płatna (sekcja 3) | szyfrowanie end-to-end; brak ML po stronie serwera [wniosek, nie potwierdzono] | **[źródło: https://github.com/ente-io/ente, dostęp 2026-11-27]** |

**Kiedy wybrać coś innego.** Ente, gdy ważniejsze jest szyfrowanie end-to-end, a ten sam projekt oferuje też wersję hostowaną (ceny w sekcji 3). Nextcloud Memories, gdy Nextcloud i tak działa jako dysk plików. PhotoPrism, gdy wystarcza aplikacja PWA z zewnętrznym PhotoSync zamiast natywnej aplikacji do kopii z telefonu **[wniosek, na podstawie tabeli]**. Czy migracja między Ente hostowanym a własnym serwerem jest prosta, nie sprawdzono [do weryfikacji]. Immich z 2024 został wyłączony po niecałym miesiącu („dont use Immich”). Powód to pytanie do autora.

### 2.3. Pliki: copyparty i clips-sftp

**Co robi.** copyparty udostępnia `personal-pvc` w czterech sekcjach: `/private` (tylko `@admins`), `/members` (odczyt dla każdego konta Authentika), `/public` (odczyt dla wszystkich, zapis dla `@writers`) i `/media` **[plik `Kubernetes/apps/copyparty/copyparty.conf`]**. Tożsamość i grupy przychodzą w nagłówkach `X-authentik-username` i `X-authentik-groups` z forward-auth Traefika (`auth-ord: idp`). Konfiguracja zaznacza, że jest to bezpieczne tylko dlatego, że Traefik usuwa takie nagłówki od klienta **[plik `Kubernetes/apps/copyparty/copyparty.conf`]**. Opcja `daw` pozwala nadpisywać pliki przez WebDAV. clips-sftp to osobny pod `tailscaled`, który udostępnia przez Tailscale SSH tylko katalog `/personal/public/clips`, jako nieuprzywilejowany użytkownik bez przekierowań i PTY **[commit `cf24c25`, 2026-11-17]**.

**Historia.** Wcześniej pliki udostępniała Samba: najpierw skrypt hosta **[plik `general/setup_samba.sh` w `386f12a`]**, potem kontener **[commit `7198b20`, 2024-07-14]**, usunięty w lutym 2025 **[commit `c8dccdd`, 2025-02-12]**. copyparty pojawia się w 2026 **[commit `6757719`, 2026-02-01]**. Druga, bezlogowa instancja WebDAV dla tailnetu (`copyparty-dav`) istniała dwa tygodnie i zniknęła, gdy po wyłączeniu proxy na Oracle tailnet przestał być drogą do aplikacji WWW **[commit `6e9a4c5`, 2026-09-03]**.

**Ograniczenia napotkane w repo.** Zaufanie do nagłówków IdP wymaga, by każda droga do copyparty szła przez Traefik. Stąd poprawka „close copyparty IdP header bypass” **[commit `3cdfd9b`, 2026-08-20]** i flaga `xvol`, przez którą dowiązanie symboliczne utworzone przez SFTP nie wyprowadzi anonimowego czytelnika poza `/public` **[commit `cf24c25`, 2026-11-17]**.

**Co zastępuje.** Udostępnianie plików z Google Drive, Dropboxa lub OneDrive, w tym publiczne linki **[wniosek]**. copyparty to serwer plików z WWW (WebDAV, SFTP, FTP, SMB) **[źródło: https://github.com/9001/copyparty, dostęp 2026-11-27]**. Nie jest klientem synchronizacji, więc nie zastępuje automatycznej synchronizacji folderu na laptopie jak klient Dropboxa **[wniosek]**.

**Alternatywy self-hosted.**

| Projekt | Licencja | Ostatnie wydanie | Model | Ograniczenia | Źródło |
|---|---|---|---|---|---|
| copyparty | MIT | v1.20.28, 2026-11-24 | serwer plików WWW + WebDAV/SFTP/FTP/SMB; logowanie nagłówkami IdP zza reverse proxy (`idp-h-usr`, `idp-h-grp`, `xff-src`) | SFTP wolniejszy niż WebDAV/FTP; SMB „unsafe, slow, not recommended for wan”; woluminy IdP domyślnie zapominane po restarcie do pierwszego żądania użytkownika | **[źródło: https://github.com/9001/copyparty, https://github.com/9001/copyparty/blob/hovudstraum/docs/idp.md, dostęp 2026-11-27]** |
| Nextcloud Server | AGPL-3.0 | v35.0.3, 2026-11-12 | groupware + synchronizacja, pełny WebDAV | PHP 8.3-8.6, min. 128 MB RAM na proces (zalecane 512 MB), SQLite tylko do testów | **[źródło: https://github.com/nextcloud/server/releases, https://docs.nextcloud.com/server/latest/admin_manual/installation/system_requirements.html, dostęp 2026-11-27]** |
| Seafile | serwer AGPLv3, Seahub Apache-2.0, klient GPLv2; Pro komercyjna (bez licencji do 3 użytkowników) | Community v14.0.11, 2026-11-21 | synchronizacja i udostępnianie; Pro dodaje m.in. SAML, multi-tenancy, skan AV | przechowywanie w blokach zamiast zwykłych plików [nie potwierdzono] | **[źródło: https://github.com/haiwen/seafile-server, https://www.seafile.com/en/download/, dostęp 2026-11-27]** |
| Syncthing | MPL-2.0 | v2.1.7, 2026-10-21 | synchronizacja P2P bez serwera centralnego | synchronizuje tylko urządzenia online w tym samym czasie; zespół nie planuje aplikacji na iOS; brak udostępniania linkiem [nie potwierdzono wprost] | **[źródło: https://docs.syncthing.net/users/faq.html, dostęp 2026-11-27]** |
| FileBrowser | Apache-2.0 | v2.63.23, 2026-07-27; repo zarchiwizowane 2026-08-31/09-01 | prosty menedżer plików WWW | brak dalszych poprawek bezpieczeństwa, README odradza wystawianie do internetu | **[źródło: https://github.com/filebrowser/filebrowser, dostęp 2026-11-27]** |

FileBrowser został dodany i usunięty tego samego dnia **[commit `ba47ea5` → `8f3e37d`, 2024-01-15]**, więc jego archiwizacja nie dotyczy obecnego stanu.

**Kiedy wybrać coś innego.** Nextcloud, gdy potrzebne są synchronizacja z klientami desktop, kalendarz i kontakty, i jest na to RAM. Syncthing, gdy chodzi tylko o synchronizację kilku własnych urządzeń bez serwera i bez udostępniania. Seafile, gdy potrzebna jest synchronizacja z klientem desktop przy lżejszym serwerze niż Nextcloud [do weryfikacji: wydajności nie porównano]. copyparty pasuje tutaj, bo jest jednym procesem bez bazy danych i czyta tożsamość z nagłówków Authentika **[wniosek z `copyparty.conf`]**.

### 2.4. DNS dla domowników: AdGuard Home

**Co robi.** AdGuard Home jest resolwerem dla LAN i tailnetu (przez usługę `adguard-tailscale`). Blokuje reklamy i przepisuje `*.nerine.dev` na `192.168.1.11` tylko klientom z `192.168.0.0/16` **[plik `Terraform/apps/adguard.tf`]**. Panel `dns.nerine.dev` nie ma własnego logowania. Chronią go middleware Authentika i NetworkPolicy, bo AdGuard nie umie przyjąć nagłówka `Remote-User` **[plik `Kubernetes/AGENTS.md`]**.

**Ograniczenia napotkane w repo.** Kiedy klaster leży, leży też DNS, i `terraform apply` nie rozwiązuje już nazw backendu stanu ani `carbon` **[plik `AGENTS.md`, wpis o `shutdownGracePeriodByPodPriority`]**. To koszt trzymania DNS-u domowników w tym samym klastrze co aplikacje **[wniosek]**.

**Co zastępuje.** NextDNS lub podobny filtr DNS w chmurze **[wniosek]**. NextDNS jest darmowy do 300 000 zapytań miesięcznie (potem rozwiązuje nazwy, ale bez blokowania), a Pro kosztuje 1,99 EUR miesięcznie lub 19,90 EUR rocznie **[źródło: https://nextdns.io/pricing, dostęp 2026-11-27]**. Dla jednego gospodarstwa oszczędność jest więc mała. AdGuard daje też przepisywanie `*.nerine.dev` na adres w LAN, czego publiczny resolwer nie zrobi **[wniosek]**.

| Projekt | Licencja | Ostatnie wydanie | Funkcje | Ograniczenia | Źródło |
|---|---|---|---|---|---|
| AdGuard Home | GPL-3.0 | v1.0.0, 2026-11-19 (repo używa v0.107.80) | reguły per klient, upstream i własny serwer DoH/DoT/DNSCrypt, DHCP | nie blokuje reklam z tej samej domeny co treść (YouTube, Twitch) | **[źródło: https://github.com/AdguardTeam/AdGuardHome, dostęp 2026-11-27]** |
| Pi-hole | EUPL | Core v6.6 / FTL v6.9, 2026-11-11 | sinkhole DNS, DHCP | DoH/DoT tylko przez dodatkowe oprogramowanie (cloudflared, unbound) [wg README AdGuard Home, źródło konkurencyjne] | **[źródło: https://github.com/pi-hole/pi-hole, dostęp 2026-11-27]** |
| Technitium DNS Server | GPL-3.0 | v15.6.2, 2026-10-17 | pełny serwer DNS (rekurencja, strefy, DNSSEC), DoT/DoH/DoQ, listy blokowania per podsieć, klastrowanie | [nieznane] | **[źródło: https://github.com/TechnitiumSoftware/DnsServer, dostęp 2026-11-27]** |

**Kiedy wybrać coś innego.** Technitium, gdy potrzebny jest autorytatywny serwer stref. Pi-hole, gdy działa na małym Raspberry Pi poza klastrem. Ta druga opcja usuwa też zależność DNS-u domowników od działania klastra (pkt wyżej) **[wniosek]**. NextDNS, gdy filtr ma działać także poza domem bez VPN.

### 2.5. Automatyka domowa: Home Assistant

**Co robi.** Home Assistant działa jako VM na Proxmoxie, pod adresem `192.168.1.186:8123` **[plik `AGENTS.md`]**. Koordynator Zigbee (konwerter CH340 `1a86:7523`) jest przekazany do VM przez mapowanie USB `Zigbee` **[plik `Ansible/setup-proxmox.yaml`]**, a integracja Zigbee to ZHA. Sieć to jedna żarówka Tuya `TS0505B` i trzy gniazdka `TS011F` **[plik `AGENTS.md`, wpis od `453a391` 2026-08-03]** oraz przełącznik Aqara E1 w salonie **[plik `AGENTS.md`, wpis od `b91130f` 2026-10-13]**. Urządzenie HA w tailnecie ma tag `tag:homeassistant` **[commit `c729800`, 2026-10-02]**.

**Historia.** Kontener w compose od 2024-02-25 **[commit `acfb3af`, 2024-02-25]**, krótko w Kubernetes po konwersji kompose, usunięty z klastra **[commit `929e6b4`, 2025-08-15]**. Konfiguracja VM (HAOS czy inna instalacja, data utworzenia) nie jest w repo [nieznane].

**Ograniczenia napotkane w repo.**
- Urządzenia Tuya nigdy nie zgłaszają aktualizacji firmware'u, bo domyślni dostawcy OTA nie mają obrazów Tuya **[plik `AGENTS.md`, wpis od `453a391` 2026-08-03]**.
- Aqara E1 wysyła podwójne naciśnięcia tylko po ręcznym zapisie atrybutu klastra `0xFCC0`, a HA nie ma do tego encji **[plik `AGENTS.md`, wpis od `b91130f` 2026-10-13]**.
- Niezalogowane zapytania do `/api/*` HA liczy jako nieudane logowania i przy dodatnim progu banuje IP bez automatycznego zdjęcia bana **[plik `AGENTS.md`, wpis od `453a391` 2026-08-03]**.
- Nie wolno odłączać CH340 w regułach oszczędzania energii, a VM HA nie wystartuje bez podłączonego koordynatora **[plik `AGENTS.md`, wpis od `e8cafa2` 2026-06-20]**.

**Co zastępuje.** Aplikacje producentów (Tuya Smart / Smart Life, Aqara Home) z ich chmurami **[wniosek]**. ZHA steruje urządzeniami Zigbee lokalnie przez własny koordynator **[źródło: https://www.home-assistant.io/integrations/zha/, dostęp 2026-11-27]**. Zdalny dostęp do HA przez tailnet (tag `tag:homeassistant`) zastępuje też płatny Home Assistant Cloud od Nabu Casa, który kosztuje 7,50 EUR miesięcznie lub 75 EUR rocznie bez VAT **[źródło: https://www.nabucasa.com/pricing/, dostęp 2026-11-27]** **[wniosek]**. Czy HA ma inny zdalny dostęp, repo nie mówi.

| Projekt | Licencja | Ostatnie wydanie | Model | Ograniczenia | Źródło |
|---|---|---|---|---|---|
| Home Assistant Core | Apache-2.0 | 2026.11.3, 2026-11-23 | zalecana instalacja to HA OS (z add-onami, czyli „apps”); Zigbee przez ZHA (jeden koordynator, jedna sieć) albo Zigbee2MQTT (osobna usługa + broker MQTT) | instalacja Container nie ma add-onów i wymaga ręcznych aktualizacji; jednego adaptera nie mogą naraz używać ZHA i Zigbee2MQTT | **[źródło: https://github.com/home-assistant/core, https://www.home-assistant.io/installation/, dostęp 2026-11-27]** |
| openHAB | EPL-2.0 | 5.2.5, 2026-11-18 | Java/OSGi; natywny binding Zigbee z koordynatorem USB lub Ethernet | w Dockerze trzeba przekazać port szeregowy | **[źródło: https://github.com/openhab/openhab-distro, https://www.openhab.org/addons/bindings/zigbee/, dostęp 2026-11-27]** |
| Domoticz | GPL-3.0 | 2026.4, 2026-10-01 | ponad 150 typów sprzętu (Z-Wave, Zigbee, MQTT, Hue), skrypty dzVents (Lua), wtyczki Python | sposób obsługi Zigbee [nieznane] | **[źródło: https://github.com/domoticz/domoticz, dostęp 2026-11-27]** |

Kontener HA był w compose do `28fbc9e` (2025-09-01), a z klastra zniknął w `929e6b4` (2025-08-15). Kiedy powstała VM, repo nie mówi [nieznane]. Przejście na VM zgadza się z tym, że add-ony ma tylko instalacja HA OS, a nie Container **[wniosek]**. Czy VM to HA OS, to pytanie do autora.

**Kiedy wybrać coś innego.** openHAB, gdy zespół zna ekosystem Javy i chce natywnego bindingu Zigbee bez osobnej bramki. Domoticz, gdy wystarczą skrypty Lua (dzVents) i wtyczki Python **[wniosek, na podstawie tabeli]**. Zigbee2MQTT zamiast ZHA rozważyć przy kłopotach z urządzeniami jak Aqara E1 opisanym wyżej. Czy Zigbee2MQTT obsługuje te urządzenia lepiej, nie sprawdzono [do weryfikacji].

### 2.6. Druk i skan: scanservjs → Pagewire

**Co robi.** Pagewire (`print.nerine.dev`, obraz `ghcr.io/thephaseless/pagewire`, czyli według przestrzeni nazw projekt autora **[wniosek]**) obsługuje drukarkę i skaner Samsung SCX-4300 podłączony przez USB do talos-2. Ansible przekazuje urządzenie do VM jako surowe `usb0: host=04e8:342e`, żeby VM startowała także przy wyłączonej drukarce. `generic-device-plugin` wystawia je jako zasób `devic.es/printer`. Dostęp mają `admins` **[commit `e3857f4`, 2026-11-25]**, a od `9b1d576` także `vips` **[commit `9b1d576`, 2026-11-25]**. `scan.nerine.dev` przekierowuje do Pagewire.

**Historia.** Wcześniej był scanservjs: od 2024-01-15 w compose, z przerwą w lutym-marcu 2025 **[commit `52aafff`, 2025-03-05]**, potem w `Kubernetes/home/scanservjs` do przebudowy z 2026-02-01 **[wniosek: katalog `Kubernetes/home` znika w `6757719`]**. Od lutego do listopada 2026 skanowania w klastrze nie było [wniosek z braku manifestu].

**Ograniczenia napotkane w repo.** Proxmox pozwala na surowe `host=` tylko kontu root@pam, więc passthrough drukarki robi Ansible, a nie Terraform. Brak drukarki objawia się podem urządzenia w stanie Pending, którego Pagewire nie odróżni od wyłączonej drukarki **[plik `AGENTS.md`, wpis od `e3857f4` 2026-11-25]**.

**Co zastępuje.** Raczej nic z chmury. Zastępuje oprogramowanie producenta i podłączanie drukarki do jednego komputera, a do starej drukarki USB daje dostęp przez przeglądarkę **[wniosek]**.

### 2.7. Poczta: tylko wysyłka powiadomień

**Co robi.** Postfix w klastrze jest wyłącznie przekaźnikiem dla powiadomień (Authentik, Immich, *arr). W compose przekazywał pocztę przez `smtp.gmail.com:587` **[plik `compose.auth.yaml` w `28fbc9e^`]**, od 2026-02-24 przez OCI Email Delivery z domeną, DKIM i SPF w Cloudflare zarządzanymi Terraformem **[commit `2b33dec`, 2026-02-24]**, **[plik `Terraform/email.tf`]**.

**Skrzynki zostają w chmurze.** Dokument `docs/email-provider-research.md` porównuje hostowaną pocztę z własną domeną i zakłada wprost „No self-hosting”. Lista w nim to Zoho, Migadu, Purelymail, Fastmail, Proton, iCloud+, Mailbox.org oraz Google Workspace i Microsoft 365 jako punkt odniesienia, z cenami z 2026-08-01 **[plik `docs/email-provider-research.md`, commit `0bdd584`]**. Odbiór poczty nie został więc repatriowany. Wybór dostawcy to pytanie do autora.

**Dlaczego nie własny serwer pocztowy.** Spamhaus PBL wymienia zakresy adresów klientów końcowych ISP, z których poczta „should never be sent directly to the final destination” **[źródło: https://www.spamhaus.org/blocklists/policy-blocklist/, dostęp 2026-11-27]**. Adres domowy jest dynamiczny (dlatego `cloudflare-ddns`), a to typowy przypadek takiej listy **[wniosek]**. Czy Orange blokuje dziś wychodzący port 25, nie udało się potwierdzić. Są tylko wpisy na forach, w tym o blokadzie w TP od 2009-12-01 **[źródło: https://www.elektroda.pl/rtvforum/topic1507294.html, dostęp 2026-11-27; forum, nie źródło oficjalne]**. Oracle także domyślnie blokuje wychodzący TCP 25 dla tenancy utworzonych po 2021-06-23 **[źródło: https://docs.oracle.com/en-us/iaas/releasenotes/changes/f7e95770-9844-43db-916c-6ccbaf2cfe24, dostęp 2026-11-27]**, więc VPS na Oracle też nie zastąpi przekaźnika. OCI Email Delivery w cenniku ma pierwsze 3000 e-maili miesięcznie bez opłat **[źródło: https://www.oracle.com/cloud/price-list/, dostęp 2026-11-27]**, co wystarcza na powiadomienia homelabu **[wniosek]**.

### 2.8. Pozostałe

- **Minecraft.** W erze compose działały modowane serwery (FTB Skies Expert, DawnCraft) na `eclipse-temurin` i panel PufferPanel (pkt 1.1). Od 2026-04-08 polityka Tailscale daje urządzeniom udostępnionym (`autogroup:shared`) dostęp do `tag:minecraft:25565` i `:8100` **[plik `Tailscale/policy.hujson`]**, **[commit `7168368`, 2026-04-08]**. Serwer udostępnia się więc znajomym przez Tailscale zamiast przez publiczny port **[wniosek]**. Gdzie działa i co jest na porcie 8100, repo nie mówi [nieznane]. Zastępuje płatny hosting serwerów gier lub Minecraft Realms **[wniosek]**.
- **c-oop.** Współdzielony edytor C++ pod `c-oop.nerine.dev`, publiczny bez logowania i bezstanowy. Ma własny limit równoległych żądań na adres, bo otwarte gniazdo sygnalizacji zajmuje slot z globalnej puli 500 **[commit `d9446b8`, 2026-11-22]**. Obraz `ghcr.io/thephaseless/c-oop` **[wniosek: projekt autora]**. Do czego służy (zajęcia, nauka z innymi), to pytanie do autora.
- **Strona startowa.** Homepage (compose) → statyczna strona nginx **[commit `1d273cf`, 2026-02-19]** → biblioteka aplikacji Authentika, która pokazuje tylko kafelki dostępne dla zalogowanego **[commit `3fce217`, 2026-08-21]**.
- **mcpjungle.** Brama MCP pod `mcp.nerine.dev`, usunięta, bo była jedyną prywatną trasą bez sprawdzania tożsamości **[commit `096bd7e`, 2026-08-19]**.
- **whoami.** Usługa testowa, od 2024 do 2026-08-20 **[commit `7158f21`, 2026-08-20]**.
- **Boty (sggwbot, Renamer).** Własne obrazy autora w compose i w `utilities/renamer` do 2026-02-01 **[wniosek: przestrzeń nazw obrazu]**.

## 3. Ceny usług chmurowych jako punkt odniesienia

Ceny są katalogowe, z dnia dostępu. Kolumna „Typ” rozróżnia oficjalną stronę producenta (OF) od artykułu prasowego lub sprzedawcy (ART). Ceny ART mogą być nieaktualne o kilka tygodni. Promocje podano osobno.

| Usługa | Plan | Cena | Typ | Źródło (dostęp 2026-11-27) |
|---|---|---|---|---|
| Google One | 100 GB / 2 TB | 1,99 / 9,99 EUR mies. (strona pokazała EUR, nie PLN) | OF | https://one.google.com/about/plans?hl=pl&gl=PL |
| Google One | 100 GB / 2 TB w PLN | [nieznane]: tylko fragment z wyszukiwarki (8,99 zł / 46,99 zł mies.), strony nie przeczytano | brak | brak |
| iCloud+ | 50 GB / 200 GB / 2 TB / 6 TB / 12 TB | 4,99 / 14,99 / 49,99 / 149,99 / 299,99 zł mies. | OF | https://support.apple.com/pl-pl/108047 |
| Netflix | Podstawowy / Standardowy / Premium | 37 / 55 / 75 zł mies. (od 05.2026; brak planu z reklamami w PL) | ART | https://antyweb.pl/ile-kosztuje-netflix-w-2026-roku |
| Disney+ | Standard z reklamami / Standard / Premium | 24,99 / 34,99 / 59,99 zł mies.; rocznie 349,90 / 599,90 zł | OF | https://www.disneyplus.com/pl-pl |
| HBO Max | Podstawowy z reklamami / Standardowy / Premium | 29,99 / 39,99 / 49,99 zł mies. (promocja −50% do 30.11.2026 dla nowych) | OF | https://www.hbomax.com/pl/pl |
| Amazon Prime | Prime | 15,50 zł mies. lub 69,99 zł rok (od 13.01.2026 dla nowych) | ART | https://www.chip.pl/2026/01/amazon-prime-drozeje-w-polsce-po-raz-pierwszy-od-lat |
| SkyShowtime | z reklamami / Standard / Premium | 24,99 / 34,99 / 49,99 zł mies. (od 24.02.2026) | ART | https://www.instalki.pl/news/rozrywka/tanich-serwisow-streamingowych-juz-nie-ma-skyshowtime-podnosi-ceny/ |
| Plex Pass | miesięczny / roczny / dożywotni | 6,99 / 69,99 / 749,99 USD (dożywotni od 01.07.2026, wcześniej 249,99 USD) | ART | https://9to5mac.com/2026/05/19/plex-increasing-lifetime-plex-pass-cost-to-whopping-750/ |
| Plex Remote Watch Pass | miesięczny / roczny | 1,99 / 19,99 USD | ART | j.w. |
| Emby Premiere | miesięczny / roczny / dożywotni | 4,99 / 54 / 119 USD (99 USD w promocji) | OF | https://emby.media/premiere.html |
| Dropbox | Plus 2 TB | 9,99 EUR mies. lub 7,99 EUR mies. przy płatności rocznej | OF | https://www.dropbox.com/pl/plans |
| Microsoft 365 | Personal / Family | ok. 369,99 / 559,99 zł rok (inne źródła: 349,99 / 489,99 zł); niezweryfikowane | ART (sprzedawca licencji) | https://kluczesoft.pl/wiedza/licencje/cennik-microsoft-365-2026 |
| NextDNS | Free / Pro | 0 (300 000 zapytań mies.) / 1,99 EUR mies. lub 19,90 EUR rok | OF | https://nextdns.io/pricing |
| Ente Photos | 50 GB / 200 GB / 1 TB / 2 TB | 2,49 / 4,99 / 9,99 / 19,99 USD mies. (Free: 10 GB) | OF | https://ente.com/pricing |
| Home Assistant Cloud (Nabu Casa) | brak | 7,50 EUR mies. lub 75 EUR rok, bez VAT | OF | https://www.nabucasa.com/pricing/ |
| Proton Unlimited | 500 GB | 12,99 USD mies. cennikowo (region US) | OF | https://proton.me/pricing |

Czego nie zweryfikowano: oficjalnych cen Google One w PLN, Microsoft 365, Amazon Prime, SkyShowtime, Netflix PL i Plex (strony zwracały EUR, błędy 403/404/503 albo przekroczyły limit czasu). Ceny hostowanej poczty z własną domeną są w `docs/email-provider-research.md` ze stanem na 2026-08-01, np. Google Workspace Starter 31,50 zł za użytkownika miesięcznie przy płatności rocznej **[plik `docs/email-provider-research.md`]**.

## 4. Repatriacja

Tytuł pracy mówi o częściowej repatriacji. Tabele poniżej rozdzielają dwie rzeczy, które repo potwierdza w różnym stopniu. Kolumna „Zamiennik działa” opiera się na repo. Kolumna „Abonament był / zrezygnowano” jest pytaniem do autora, bo repo nie zawiera faktur ani historii kont.

### 4.1. Usługi przeniesione lub z zamiennikiem w domu

| Usługa chmurowa (przykład) | Zamiennik w homelabie | Zamiennik działa [dowód] | Abonament był / zrezygnowano | Status repatriacji |
|---|---|---|---|---|
| Netflix, Disney+, HBO Max, SkyShowtime, Prime Video; Plex Pass | Jellyfin + *arr + Seerr | tak, od `ba47ea5` 2024-01-15 | [pytanie] | częściowo: zależy od źródła treści, nowości dalej są tylko w VOD **[wniosek]** |
| Zdjęcia Google / Google One, iCloud+ | Immich | tak, od `6757719` 2026-02-01 (epizod 2024-01/02) | [pytanie] | [pytanie]: czy telefony robią kopię tylko do Immicha, czy także do Google/Apple |
| Google Drive, Dropbox, OneDrive (udostępnianie) | copyparty, clips-sftp | tak, od `6757719` 2026-02-01; SFTP od `cf24c25` 2026-11-17 | [pytanie] | częściowo: brak klienta synchronizacji **[wniosek]** |
| NextDNS (filtr DNS) | AdGuard Home | tak, od `ba47ea5` 2024-01-15 | [pytanie] | zastąpione dla LAN i tailnetu **[wniosek]** |
| chmury producentów Tuya/Aqara, Nabu Casa | Home Assistant + ZHA, dostęp przez Tailscale | tak (VM, `Ansible/setup-proxmox.yaml`) | [pytanie] | [pytanie]: czy urządzenia nadal są sparowane z aplikacją Tuya |
| hosting serwerów gier / Minecraft Realms | serwery Minecraft (compose 2024-2025, w 2026 host z `tag:minecraft`) | tak w compose; w 2026 tylko polityka Tailscale | [pytanie] | [pytanie] |
| strona/portfolio na hostingu | httpd/nginx z `DMZ/Compose/Home/website` (2024-2026) | tak, do `6757719` 2026-02-01 | [pytanie] | [nieznane]: czy portfolio dalej gdzieś działa |
| aplikacja producenta drukarki, druk z jednego komputera | Pagewire | tak, od `e3857f4` 2026-11-25 | nie dotyczy | nie dotyczy chmury **[wniosek]** |
| Duplicati do chmury [nieznane: cel kopii z 2024 nie jest w repo] | BorgBackup na Hetzner (patrz 4.2) | brak | brak | kopie celowo poza domem |

### 4.2. Co zostało w chmurze i dlaczego

| Usługa | Rola | Dowód w repo | Dlaczego w chmurze |
|---|---|---|---|
| Google (konto Google jako jedyna metoda logowania do Authentika) | tożsamość użytkowników | „Google-only authentication flow” **[commit `2b33dec`, 2026-02-24]** | znajomi i domownicy logują się kontem, które już mają **[wniosek]**; motyw [pytanie] |
| Hostowana poczta (dostawca [pytanie]) | skrzynki z domeną | „No self-hosting” **[plik `docs/email-provider-research.md`]** | reputacja IP domowego (Spamhaus PBL), dynamiczny adres **[wniosek]** |
| OCI Email Delivery | wysyłka powiadomień | **[plik `Terraform/email.tf`]** | wychodzący port 25 i reputacja; 3000 e-maili/mies. bez opłat (sekcja 2.7) |
| OCI: VPS `VM.Standard.A1.Flex` (4 OCPU, 24 GB) i bucket stanu Terraform | VPS `compute`, stan Terraform; wejściem HAProxy do 2026-08-20 była osobna VM `oracle-proxy` (1 OCPU / 6 GB), usunięta w `7158f21`, który podniósł `compute` z 3 OCPU / 18 GB do 4 / 24 | **[plik `Terraform/oracle.tf`]**, **[plik `Terraform/backend.tf`]**, **[commit `7158f21`, 2026-08-20]** | stan Terraform nie może leżeć w infrastrukturze, którą Terraform odtwarza **[wniosek]**; czy VPS jest w Always Free [pytanie] |
| Hetzner Storage Box `bx11` (1 TB) | cel kopii BorgBackup | **[plik `Terraform/hetzner.tf`]**, **[plik `Terraform/variables.tf`]** | kopia poza domem (zasada 3-2-1) **[wniosek]** |
| Cloudflare DNS | publiczne rekordy `nerine.dev`, DKIM/SPF | **[plik `Terraform/cloudflare.tf`]** | domena musi mieć autorytatywny DNS dostępny z internetu **[wniosek]** |
| Tailscale | sieć administracyjna, DNS dla tailnetu, udostępnianie Minecrafta | **[plik `Tailscale/policy.hujson`]** | serwer koordynacji to SaaS; alternatywa self-hosted (np. Headscale) nie jest w repo [pytanie] |
| Bitwarden Secrets Manager | sekrety dla ESO i Terraform | **[plik `Terraform/secrets.tf`]** | sekrety potrzebne do odtworzenia klastra muszą przetrwać jego awarię **[wniosek]** |
| GitHub (repo, Actions, GHCR, Renovate) | źródło prawdy GitOps, CI, obrazy własnych projektów | **[plik `Terraform/github.tf`]** | ArgoCD i CI potrzebują repo poza klastrem **[wniosek]** |
| Discord (webhooki) | powiadomienia *arr i Authentika | **[plik `Terraform/apps/servarr.tf`]**, **[commit `e0eb080`, 2026-08-24]** | [wniosek: darmowy kanał powiadomień na telefon] |

Do domu przeniesiono dane i aplikacje (media, zdjęcia, pliki, DNS, automatykę), a w chmurze zostało to, co musi przeżyć awarię domu (stan Terraform, sekrety, kopie, repo) albo potrzebuje reputacji i adresu, których łącze domowe nie ma (poczta, publiczny DNS) **[wniosek]**. Taki podział można w pracy nazwać częściową repatriacją.

## Pytania do autora

1. Które abonamenty miałeś przed homelabem lub w trakcie (Netflix, Disney+, HBO Max, SkyShowtime, Prime, Spotify, Google One, iCloud+, Dropbox, Microsoft 365, Plex Pass, NextDNS, hosting gier) i ile miesięcznie za nie płaciłeś?
2. Z których z tych abonamentów zrezygnowałeś dzięki homelabowi i kiedy (miesiąc i rok)?
3. Jak chcesz przedstawić w pracy Sonarr, Radarr, Prowlarr i qBittorrent: jako automatyzację legalnych źródeł (np. własnych płyt), opis czysto techniczny bez źródła treści, czy pominąć tę część?
4. Dlaczego 2024-02-11 wyłączyłeś Immicha („dont use Immich”) i czego używałeś do zdjęć do powrotu Immicha w lutym 2026?
5. Czy telefony domowników robią kopię zdjęć tylko do Immicha, czy nadal także do Zdjęć Google lub iCloud?
6. Dlaczego wybrałeś Jellyfina zamiast Plexa lub Emby?
7. Jaką kartę NVIDIA miał klaster w 2025 i dlaczego przeszedłeś na Intel Arc B580?
8. Czy VM Home Assistanta to HA OS, od kiedy działa jako VM i dlaczego przeszła z kontenera na VM?
9. Czy urządzenia Tuya i Aqara są nadal sparowane z aplikacjami producentów, czy działają już tylko lokalnie przez ZHA?
10. Gdzie działa serwer Minecraft z tagiem `tag:minecraft` (Oracle VPS, Proxmox, inny komputer) i co jest na porcie 8100?
11. U jakiego dostawcy są teraz skrzynki pocztowe z domeną i czy migracja z Gmaila opisana w `docs/email-provider-research.md` się odbyła?
12. Ile osób poza Tobą korzysta z homelabu (grupy `watchers`, `photos`, `vips`, `writers`)?
13. Do czego służy c-oop (zajęcia, nauka z innymi) i czy chcesz go opisać w pracy?
14. Dlaczego w lutym 2025 usunąłeś Portainera i Sambę i co zastąpiło Sambę w latach 2025-2026, zanim pojawił się copyparty?
15. Dokąd Duplicati robił kopie w 2024 (dysk lokalny czy chmura)?
16. Czy VPS na Oracle mieści się w darmowym planie Always Free, czy płacisz za niego?
17. Czy portfolio z `DMZ/Compose/Home/website` działa dziś gdzieś indziej?

## Do której części pracy

- **Technologie:** sekcja 2 tego pliku (opis aplikacji, licencje, tabele alternatyw, „kiedy wybrać coś innego”).
- **Projekt:** sekcje 4.1-4.2 (podział: co w domu, co w chmurze i dlaczego) oraz grupy dostępu Authentika z sekcji 1.2.
- **Implementacja:** sekcja 1 (oś czasu compose → kompose → ArgoCD) i ograniczenia napotkane w repo z sekcji 2.
- **Analiza kosztów:** sekcja 3 (ceny odniesienia) razem z odpowiedziami na pytania 1-2 i 16.
- **Wstęp i podsumowanie:** wniosek o częściowej repatriacji z końca sekcji 4.2.

# E5 (2026-08-01 → 2026-11-27): publiczne wystawienie, stabilizacja i stan obecny

Plik opisuje piąty okres historii repozytorium: przejście z wejścia przez Oracle VPS na bezpośrednie wystawienie domowego łącza, przebudowę modelu dostępu (Authentik jako jedyna brama, egzekwowane NetworkPolicies), serię incydentów dyskowych i sieciowych z ich diagnozami oraz nowe aplikacje. Ostatnia część opisuje stan na 2026-11-27 na podstawie plików z brancha `main`.

Tagi: [commit `hash`, data], [PR #N] i [plik `ścieżka`] to dowód z repo, [wniosek] to rozumowanie z tych dowodów, [nieznane] oznacza brak danych w repo. Daty commitów to daty autora z `git log --date=short`. `CLAUDE.md` w katalogu głównym to dowiązanie do `AGENTS.md`, więc cytaty z wpisów Key Gotchas wskazują `AGENTS.md`.

Okres liczy 517 commitów na `main` z 2026-11-27 (tip `e7ae5da`; 516 przy tipie `9b1d576`), licząc datę autora w UTC jak w `historia/04-przebudowa-gitops.md`, z czego około 270 to zmiany inne niż aktualizacje zależności (Renovate) [wniosek: zliczenie `TZ=UTC git log main --date=short-local` od 2026-08-01 z odfiltrowanymi tematami `chore(deps)`/`lock file`].

## 1. Oś czasu okresu (kamienie milowe)

| Data | Zdarzenie | Dowód |
| --- | --- | --- |
| 2026-08-03 | Wyłączenie nieużywanej karty Wi-Fi i Bluetooth na hoście (udev unbind) | [commit `43cb431`, 2026-08-03] |
| 2026-08-08 | CrowdSec: sekret LAPI z Bitwardena zamiast losowego z Helma; byparr-proxy dla 1337x/EZTV | [commit `7c7a702`, 2026-08-08], [commit `7855699`, 2026-08-08] |
| 2026-08-09 | Naprawa backendu HAProxy na Oracle VPS (timer sync-traefik-ip, potem IP wpisywany przy deployu) | [commit `7814f55`, 2026-08-09], [commit `00abc56`, 2026-08-09] |
| 2026-08-13 | Duży przegląd bezpieczeństwa: luka SSO, usunięte poświadczenia z repo, RBAC, CI | [commit `c3bd45f`, 2026-08-13] |
| 2026-08-18 | `compute` (Oracle VPS) staje się urządzeniem osobistym w Tailscale | [commit `4fe6631`, 2026-08-18] |
| 2026-08-19 | Egzekwowanie NetworkPolicy w Talos, default-deny w `media`; awaria wszystkich kubeletów (shutdown bands); talos-3 do 12 GiB | [commit `930e1e8`, 2026-08-19], [commit `a7d5281`, 2026-08-19], [commit `59abe12`, 2026-08-19], [commit `1727f68`, 2026-08-19] |
| 2026-08-20 | Wycofanie VM z HAProxy na podstawie błędnej diagnozy „Orange blokuje 80/443” | [commit `7158f21`, 2026-08-20], [PR #567] |
| 2026-08-21 | Sprostowanie diagnozy; cloudflare-ddns; usunięcie `private-chain`/`tailscale-only`; strona główna zastąpiona biblioteką aplikacji Authentik | [commit `ca9a652`, 2026-08-21], [commit `5d7f26e`, 2026-08-21], [commit `cf4cbd6`, 2026-08-21], [commit `3fce217`, 2026-08-21] |
| 2026-08-31 → 09-02 | Pobieranie torrentów przeniesione na pulę mergerfs NVMe+HDD; seria poprawek ZFS/mergerfs/NFS | [commit `0bdd584`, 2026-09-01], [commit `064f440`, 2026-09-02] |
| 2026-09-03 | Traefik zdjęty z Tailscale, cały ruch www przez publiczny entrypoint | [commit `905ab74`, 2026-09-03] |
| 2026-09-21 → 09-22 | Incydent talos-3: kolizja IP z dekoderem TV (DHCP routera Mercusys); równolegle ZFS txg vs etcd, zawieszony klient NFS, Longhorn livelock | [commit `9903e08`, 2026-09-22], [commit `34899c2`, 2026-09-21] |
| 2026-09-24 | Węzły zarządzane przez `talos_machine`/`talos_cluster` (automatyczne aktualizacje), Talos v1.14.1, Kubernetes 1.37.1 | [commit `b79a68b`, 2026-09-24], [commit `a5a4ddf`, 2026-09-24] |
| 2026-10-02 | Moduł `Terraform/modules/talos-node`, aktualizacje po jednym węźle z bramką zdrowia Longhorn | [commit `feb2ee9`, 2026-10-02] |
| 2026-10-05 → 10-07 | CrowdSec: ban domowego IP, panel `bans.nerine.dev`, pamięć AppSec; HTTP/3 wyłączone | [commit `efac355`, 2026-10-05], [commit `6deeeaf`, 2026-10-06], [commit `e55dcab`, 2026-10-07] |
| 2026-11-02 → 11-04 | Po restarcie hosta: rejestracja agentów CrowdSec, fbcon na talos-1 | [PR #752], [PR #760] |
| 2026-11-17 | clips-sftp (SFTP przez Tailscale SSH), podział Copyparty na public/members/private | [commit `cf24c25`, 2026-11-17], [commit `7b920a7`, 2026-11-17] |
| 2026-11-22 | c-oop: współdzielony edytor C++ bez logowania | [commit `d9446b8`, 2026-11-22] |
| 2026-11-25 | Pagewire (drukowanie/skanowanie przez USB) i generic-device-plugin | [commit `e3857f4`, 2026-11-25] |

## 2. Stan na początku E5 (2026-08-01)

Punkt odniesienia to `28cd19a` z 2026-07-31, ostatni commit przed okresem w czasie warszawskim. Źródła się tu różnią: `historia/04-przebudowa-gitops.md` kończy E4 na `cb3847a` (2026-07-31 22:48 UTC, w Warszawie już 2026-08-01), który dzieli od `28cd19a` tylko aktualizacja `uv` (PR #518).

- Wejście z internetu. README opisywało dostęp publiczny „Only through Oracle VPS → Tailscale → Traefik”, a usługi prywatne jako wymagające uwierzytelnienia w Tailscale [plik `README.md` w `28cd19a`]. W katalogu głównym leżały `compose.proxy.yaml` i `haproxy.cfg`, czyli HAProxy w kontenerze na VM Oracle [plik `compose.proxy.yaml` w `28cd19a`]. Ta ścieżka nie działała już od około 2026-07-26: VPS miał wyłączone MagicDNS (`--accept-dns=false`), więc HAProxy nie rozwiązywał nazwy backendu Traefika i się restartował w pętli [commit `0d9b743`, 2026-08-09].
- Bramki na Traefiku. Istniały middleware `private-chain` (allowlista adresów LAN/Tailscale) i `tailscale-only` [commit `cf4cbd6`, 2026-08-21]. Komentarz w repo przypisywał `private-chain` kontrolę dostępu, której ono nie dawało; była to wyłącznie allowlista IP [commit `096bd7e`, 2026-08-19].
- Aplikacje. W `Kubernetes/apps/` były m.in. homepage, mcpjungle i whoami, później usunięte [plik `Kubernetes/apps/` w `28cd19a`].
- Węzły. talos-3 miał 8 GiB RAM, talos-1 16 GiB, talos-2 12 GiB [plik `Terraform/variables.tf` w `28cd19a`], [commit `1727f68`, 2026-08-19].
- Sieć klastra. Flannel z Talosa ignorował obiekty NetworkPolicy; w klastrze było 13 polityk z chartów ArgoCD, Authentika i Longhorna i żadna nie działała [commit `930e1e8`, 2026-08-19].
- Oszczędzanie prądu odziedziczone z E4. `hd-idle -c ata` [commit `0eb5f62`, 2026-06-18], wpisy o `atime` i `zfs_txg_timeout` [commit `5615611`, 2026-06-18], limit ARC 4 GiB i wyłączony boost CPU [commit `aeca5da`, 2026-07-20]. E5 nie wprowadza tych ustawień, tylko odkrywa ich skutki uboczne (rozdz. 5.3).

## 3. Wystawienie publiczne

### 3.1 Koniec HAProxy na Oracle VPS (2026-08-09 → 2026-08-20)

2026-08-09 autor trzy razy zmieniał sposób, w jaki HAProxy na VPS znajduje Traefika w tailnecie:

1. Przypięcie IP Traefika adnotacją `tailscale.com/tailnet-ip` [commit `0d9b743`, 2026-08-09]. Nie zadziałało: operator Tailscale v1.98.9 nie obsługuje już tej adnotacji [commit `7814f55`, 2026-08-09].
2. Skrypt `sync-traefik-ip.sh` z timerem systemd co 60 s, który czytał IP z `tailscale status`, wpisywał je do `/etc/hosts` i wysyłał HAProxy SIGHUP [commit `7814f55`, 2026-08-09].
3. Tego samego dnia timer zastąpiono rozwiązaniem w momencie deployu: playbook Ansible odczytuje IP i wstawia je do szablonu `haproxy.cfg.j2` [commit `00abc56`, 2026-08-09].

Skrypt i obie jednostki timera (`sync-traefik-ip.sh`, `traefik-ip-sync.{service,timer}`) dodano i usunięto tego samego dnia [commit `7814f55`, 2026-08-09], [commit `00abc56`, 2026-08-09].

2026-08-20 VM `oracle-proxy` zniszczono razem z rekordami A w Cloudflare, regułami ingress, kluczem `tag:oracle` i playbookami [commit `7158f21`, 2026-08-20], [PR #567]. Uzasadnienie w PR brzmiało: Orange odrzuca przychodzące TCP 80/443, więc VPS był jedyną drogą publiczną, a „public access has been dropped in favour of Tailscale + LAN” [PR #567]. Przy okazji z entrypointów Traefika usunięto zaufanie do PROXY protocol i nagłówków forwarded: bez HAProxy każdy host z LAN lub tailnetu mógł podrobić adres klienta i ominąć bany CrowdSec [PR #567]. VM `compute` powiększono do 4 OCPU / 24 GB, czyli całego limitu Always Free, z budżetem w OCI jako zabezpieczeniem [PR #567].

### 3.2 Studium przypadku: „Orange blokuje porty 80/443”

| Etap | Treść | Dowód |
| --- | --- | --- |
| Objaw | Z zewnątrz połączenia na 80/443 domowego IP kończą się `Connection refused` w jednym RTT; `tcpdump` na `vmbr0` nie widzi żadnego pakietu. | [commit `7158f21`, 2026-08-20] (wpis gotcha) |
| Diagnoza (błędna) | Router przyjmuje mapowania UPnP, port 18443 przez „tę samą ścieżkę reguł” działa, więc RST musi przychodzić od operatora. Wniosek zapisany w AGENTS.md: „port-forwarding 80/443 will never work on this line”. | [commit `7158f21`, 2026-08-20] |
| Skutek błędu | Zniszczona VM proxy, publiczny dostęp porzucony na jeden dzień. | [PR #567], [wniosek: odstęp między `7158f21` a `5d7f26e`] |
| Przyczyna | Źle skonfigurowane przekierowanie portów na routerze. Operator nigdy nie blokował 80/443. | [commit `ca9a652`, 2026-08-21] |
| Weryfikacja | 2026-08-21 z Oracle VPS (spoza sieci Orange): `:80` zwraca 301 Traefika, `:443` ważny certyfikat Let's Encrypt, aplikacje 302 do Authentika. | [plik `AGENTS.md`], [commit `ca9a652`, 2026-08-21] |
| Lekcja | Brak pakietów na `vmbr0` znaczył, że router ich nie przekazywał, a nie że nie dotarły. Pojedynczy RST nie odróżnia filtra operatora od RST samego routera; rozstrzyga porównanie TTL z RST dla nieprzekierowanego portu. | [plik `AGENTS.md`] |

Drugi błąd z tej samej serii wyszedł miesiąc później: wpis nazywał router „Orange Funbox”. To konsumencki Mercusys (certyfikat `CN=mwlogin.net`), a pomyłka kosztowała czas w incydencie z 2026-09-21, bo szukano urządzenia, którego nie ma [commit `ef00f2c`, 2026-09-22].

Co dokładnie było źle w regule przekierowania, repo nie podaje [nieznane].

### 3.3 Publiczny DNS i jedna brama (2026-08-21 → 2026-09-03)

- cloudflare-ddns. Rekordy A `nerine.dev` i `*.nerine.dev` zakłada Terraform z `ignore_changes = [content]`, a aktualizuje je Deployment `favonia/cloudflare-ddns` w `utilities`, bo domowy IP jest dynamiczny [commit `5d7f26e`, 2026-08-21], [plik `Terraform/cloudflare.tf`]. Rekordy są `proxied = false`, ponieważ proxy Cloudflare podmieniłoby adres klienta, na którym opiera się CrowdSec [commit `5d7f26e`, 2026-08-21].
- Koniec bramek sieciowych. Wszystkie trasy z `private-chain` (qBittorrent, ArgoCD, Longhorn, Grafana, dashboard Traefika) przeszły na `public-chain`; o dostępie decyduje już tylko Authentik (forward-auth albo OIDC aplikacji). `private-chain` i `tailscale-only` usunięto. ArgoCD dostał dodatkowo forward-auth, co zepsuło `argocd login` z CLI; teraz trzeba port-forwardu [commit `cf4cbd6`, 2026-08-21].
- Biblioteka aplikacji zamiast homepage. `nerine.dev` odpowiada 302 do biblioteki aplikacji Authentika, która pokazuje każdemu tylko kafelki aplikacji, do których przechodzi jego polityka. Przykład z commita: losowe konto Google widzi tylko Copyparty, członek `watchers` widzi Copyparty i Jellyfin [commit `3fce217`, 2026-08-21]. 302 zamiast 301 wybrano, żeby cache przeglądarek nie przeszkodził w ewentualnym powrocie strony głównej [commit `cf4cbd6`, 2026-08-21].
- AdGuard bez własnego logowania. Port www AdGuarda zniknął z tailnetu (był tam bez forward-auth i na dodatek serwował zwykłe HTTP na 443), a hasło AdGuarda usunięto, bo i tak nie przyjmuje nagłówka `Remote-User` i stanowiło drugi, niezintegrowany login [commit `4a956f1`, 2026-08-22].
- Traefik zdjęty z Tailscale. Proxy L3 operatora Tailscale kończyło WireGuard w podzie, w przestrzeni użytkownika; jeden strumień osiągał około 57 MB/s wobec 276 MB/s prosto na IP MetalLB. Płacili za to także klienci z LAN, bo AdGuard dawał członkom tailnetu adres proxy [commit `905ab74`, 2026-09-03]. Za tym poszły: usunięcie przepisań DNS dla tailnetu i tagu `tag:web` [commit `72459bb`, 2026-09-03] oraz instancji `copyparty-dav` [commit `6e9a4c5`, 2026-09-03]. README poprawiono tego samego dnia: Tailscale niesie już tylko DNS i administrację klastrem [commit `28ba73b`, 2026-09-03].

### 3.4 HTTP/3: włączone, niedziałające, wyłączone

| Data | Krok | Dowód |
| --- | --- | --- |
| 2026-08-20 | HTTP/3 włączone na `websecure` przy okazji wycofania HAProxy | [PR #567] |
| 2026-09-03 | Alt-Svc ogłaszał wewnętrzny port `:8443`; 21 z 21 próbek to HTTP/2 | [commit `affbc29`, 2026-09-03] |
| 2026-09-03 | Odkrycie: przy client-side apply port UDP 8443 kolidował z TCP 8443 i znikał z Deploymentu; najpierw wyłączono ogłaszanie h3 | [commit `4345078`, 2026-09-03] |
| 2026-09-03 | Revert tego wyłączenia (bez uzasadnienia w treści) i przejście na server-side apply Deploymentu i Service | [commit `ecd4a61`, 2026-09-03], [commit `d59c775`, 2026-09-03], [commit `2fb8cbd`, 2026-09-03] |
| 2026-10-06 | Ostateczne wyłączenie: uploady przez QUIC z domowego Wi-Fi 69-76 Mbit/s wobec 181 Mbit/s przez HTTP/2; QUIC kosztował Traefika ~15x więcej CPU na bajt | [commit `6deeeaf`, 2026-10-06], [PR #681] |

Lekcja [wniosek]: domyślnie „szybszy” protokół okazał się wolniejszy dla obciążenia, które tu dominuje (duże uploady w LAN), a sprawdzono to dopiero pomiarem.

### 3.5 CrowdSec po wystawieniu

- Chart generował `crowdsec-lapi-secrets` losowo przy każdym renderze, więc ArgoCD nigdy nie osiągał zgodności. Sekret przeniesiono do ExternalSecret z Bitwardena, zasiany wartościami z działającego klastra [commit `7c7a702`, 2026-08-08]; potem Terraform zaczął go generować (wymaga ≥ 64 znaków) [commit `62687ef`, 2026-08-08], [commit `1f6c9ca`, 2026-08-08].
- Ban domowego IP. Klienci z LAN, którzy rozwiązują `*.nerine.dev` publicznie, trafiają na Traefika przez hairpin NAT jako domowy IP publiczny, więc whitelist `192.168.1.0/24` ich nie obejmowała. Ładowanie strony Jellyfin wyzwoliło `http-crawl-non_statics` i zablokowało cały dom. Poprawka: whitelist po rozwiązaniu `nerine.dev` (dynamiczny IP nie trafia do repo) i panel `bans.nerine.dev` (crowdsec-web-ui za Authentikiem, tylko admins) [commit `efac355`, 2026-10-05]. Dzień później podobny fałszywy alarm: Jellyfin Enhanced pyta o każdy plakat po numerycznym ID TMDB, co spełnia test „random URI” [commit `a442e19`, 2026-10-06].
- AppSec OOM = 403 dla wszystkich. Bouncer przekazuje do AppSec do 10 MB ciała każdego żądania; 4 równoległe uploady zabiły kontener (limit 256Mi), a w czasie restartu bouncer odrzucał cały ruch z zewnątrz. Limity podniesiono do 2 CPU / 1536Mi [commit `e55dcab`, 2026-10-07], a wyjaśnienie zużycia pamięci poprawiono po teście obciążeniowym (pierwsze ciało podnosi AppSec z 42 do ~230 MiB, każde kolejne +15-40 MiB) [commit `e156975`, 2026-10-07].
- Rejestracja po restarcie węzła. Pody agentów zachowują nazwę po restarcie węzła, LAPI zwraca `403 user already exist` i agenci nie startują; 2026-11-02 stanęły wszystkie trzy. Patch pomija rejestrację, gdy poświadczenia już są [PR #752].

## 4. Model dostępu i bezpieczeństwo

### 4.1 Studium przypadku: luka SSO (2026-08-13)

| Etap | Treść |
| --- | --- |
| Objaw | Brak widocznego objawu; luka wyszła przy przeglądzie bezpieczeństwa. |
| Przyczyna | Oba proxy providery Authentika (`public-proxy`, `private-proxy`) działały w trybie `forward_domain` z tym samym `external_host`. Outpost nie umiał ich rozróżnić i `public-proxy`, którego aplikacja nie miała żadnych powiązań polityk, wygrywał dla każdego hosta. W efekcie każda usługa była dostępna dla „dowolnego konta Google”, a wiązanie `admins_only` nigdy nie działało. |
| Poprawka | `public-proxy` przestawiony na `forward_single` dla `files.nerine.dev`; sprawdzono, że sonarr/radarr/dns trafiają do `private-proxy`. |
| Dodatkowo | Usunięto `docs/superpowers` z danymi uwierzytelniającymi, dosłowne hasło AdGuarda i middleware, które je wstrzykiwało na publicznej trasie; zawężono RBAC `arr-configurator`; Pod Security Standards (enforce baseline) na 7 namespace'ach; uprawnienia `contents: read` w workflowach; zastąpienie `tj-actions/changed-files` (skompromitowany łańcuch dostaw) zwykłym `git diff`. |
| Dowód | [commit `c3bd45f`, 2026-08-13] |
| Lekcja [wniosek] | Poprawne zaaplikowanie konfiguracji nie dowodzi, że polityka działa; sprawdza to dopiero test z konta bez uprawnień. |

Pokrewna pułapka, z niewyjaśnioną sprzecznością: 2026-08-13 aplikacja `public-proxy` bez wiązań polityk wpuszczała każde konto Google [commit `c3bd45f`, 2026-08-13], a 2026-09-03 aplikacja Copyparty bez wiązań odmawiała wszystkim, łącznie z adminami, bo flaga tenanta `core_default_app_access` jest `False` (nie zarządza nią repo) [commit `47f966a`, 2026-09-03]. Zachowanie odwróciło się więc między tymi datami; dlaczego, repo nie mówi [nieznane]. Poprawka to jawne wiązanie „allow all”.

### 4.2 Grupy i polityki Authentika (2026-08-19)

Wprowadzono grupy `vips` i `photos`. Każda polityka przyjmująca `vips` przyjmuje też `admins`, bo claim `groups` wysyłany do Grafany, ArgoCD i Jellyfin zawiera tylko członkostwa bezpośrednie i zagnieżdżanie grup by do nich nie dotarło [commit `12b2249`, 2026-08-19]. RBAC ArgoCD stał się domyślnie odmowny (wcześniej `role:readonly` dla każdego zalogowanego konta Google) [commit `12b2249`, 2026-08-19]. Seerr dostał własny provider `forward_single` z polityką `watchers-vips-or-admins`, żeby nie poszerzać polityki chroniącej stos *arr, Longhorna i Traefika [commit `7db9f35`, 2026-08-24]. Jellyfin zachował logowanie hasłem jako ścieżkę awaryjną na wypadek niedostępności Authentika [commit `12b2249`, 2026-08-19], [commit `0be1bd5`, 2026-08-11].

Powiadomienia: Authentik wysyła na Discord zdarzenia utworzenia konta, usunięcia konta, zmiany hasła, nieudanego logowania i własnych błędów [commit `e0eb080`, 2026-08-24], [commit `4b97a5b`, 2026-08-25], [commit `4fa154b`, 2026-08-25].

### 4.3 Studium przypadku: NetworkPolicies (2026-08-19 → 2026-08-24)

| Etap | Treść | Dowód |
| --- | --- | --- |
| Problem | Płaska sieć podów. qBittorrent miał `AuthSubnetWhitelist=0.0.0.0/0`, a jego API pozwala ustawić program uruchamiany po pobraniu, czyli RCE w dowolnym podzie dawało wykonanie poleceń w kontenerze z NFS. Sonarr/Radarr/Prowlarr z `AuthenticationMethod=External` ufały każdemu żądaniu z ClusterIP. Copyparty ufało nagłówkom `X-authentik-*` z dowolnego prywatnego adresu, więc pod mógł wysłać `X-authentik-groups: admins`. | [commit `a7d5281`, 2026-08-19], [commit `d390292`, 2026-08-20] |
| Warunek wstępny | Włączenie `cni.flannel.kubeNetworkPoliciesEnabled` (sidecar kube-network-policies); egzekwowanie sprawdzone testem A/B. | [commit `930e1e8`, 2026-08-19] |
| Poprawka | Default-deny tylko dla ruchu przychodzącego w `media`, `utilities`, `home`. Egress celowo pominięty, bo zepsułby DNS, indeksery i pobieranie obrazów. Reguły zezwalające wyprowadzono z obserwowanego ruchu. | [commit `a7d5281`, 2026-08-19], [commit `d390292`, 2026-08-20] |
| Uboczne | Wyłączenie montowania tokenów ServiceAccount w tych namespace'ach. | [commit `093862e`, 2026-08-19] |
| Regresje | `photos.nerine.dev` zwracało 504, bo reguła wskazywała port Service (3001), a NetworkPolicy dopasowuje port poda (2283). Jellyfin nie mógł wołać API Seerr. Sonarr/Radarr nie mogły odświeżać bibliotek Jellyfin. | [commit `3b84dab`, 2026-08-20], [commit `1613369`, 2026-08-24], [commit `c36a283`, 2026-09-03] |
| Koszt uboczny | kube-network-policies loguje na `--v=2` każdy pakiet: wpis z 2026-08-30 podaje ~8,4 GiB/dzień i 97% ingestu Lokiego, a późniejszy pomiar przy poprawce ~11 GB/dzień i 98% (loki-data zapełnione w 85%). Od 2026-10-13 Promtail odrzuca te linie. | [commit `12996b0`, 2026-08-30], [commit `ee96fc0`, 2026-10-13] |
| Lekcja | Polityka bez egzekwującego CNI aplikuje się bez błędu i nic nie robi; porty w regułach to porty kontenera. | [commit `930e1e8`, 2026-08-19], [commit `3b84dab`, 2026-08-20] |

Równolegle z NetworkPolicies zaostrzono qBittorrent: zawężenie `AuthSubnetWhitelist` do CIDR podów zepsuło integrację z *arr (401 dla 10.244.0.34), więc przywrócono `0.0.0.0/0`, a ochronę zostawiono warstwie sieci i `CSRFProtection` [commit `32951f5`, 2026-08-20], [commit `7a732f8`, 2026-08-20].

### 4.4 Tailscale: tagi, nazwy hostów, urządzenie osobiste

- ACL. Usunięto wszystkie nazwane grupy (były puste) i reguły `tag:cluster`; `autogroup:admin/member` zastąpiono `autogroup:owner` [commit `527da49`, 2026-08-19]. Później doszły tagi `tag:secured`, `tag:untrusted` (laptopy znajomych do zdalnej pomocy), `tag:homeassistant` [commit `c729800`, 2026-10-02] z wyłączonym wygasaniem klucza [commit `90117eb`, 2026-10-02] oraz `tag:files` dla clips-sftp [commit `a8e3b26`, 2026-11-17]. Reguła `tag:secured → compute:22` została dodana i tego samego dnia wycofana bez opisu powodu [commit `8575c0b`, 2026-11-10], [commit `c958239`, 2026-11-10], [nieznane].
- Przyrostek `-1`. Tailscale dopisuje `-1`, gdy nazwa jest zajęta przez inny rekord, także dawno offline; urządzenia infrastrukturalne mają wyłączone wygasanie klucza, więc stare rekordy nie znikają same. Wartość hostname operatora była w chartcie pod złym kluczem (`operator` zamiast `operatorConfig`), Helm ją po cichu zignorował i operator zarejestrował się jako `tailscale-operator-1`, co zepsuło TLS do proxy API [commit `15c1ae1`, 2026-08-20]. Powstał skrypt `scripts/tailscale-release-hostname.sh` (domyślnie dry-run), który usuwa stary rekord przed ponowną rejestracją; po rejestracji jest już za późno, bo Tailscale używa ponownie ID węzła [commit `34d7f55`, 2026-08-20].
- `compute` jako urządzenie osobiste. Oracle VPS `compute` jest nieotagowany i należy do właściciela, więc zachowuje się jak laptop. Wymagało to reguły SSH `autogroup:self`, bo wszystkie reguły były otagowane, a rejestracja odbywa się przez logowanie w przeglądarce, ponieważ klucze z OAuth zawsze mają tag [commit `4fe6631`, 2026-08-18], [plik `AGENTS.md`]. CI ma dostęp tylko do `tag:oracle`, więc `compute` przeniesiono z grupy `oracle` w Ansible do osobnej grupy `personal` [commit `b97b0d0`, 2026-08-18]. Przy tej okazji wyszło, że wygasł klucz węzła `carbon` (host Proxmox), co odcięło NFS i exit node; atrybut w `nodeAttrs` nie wyłączał wygasania, robi to dopiero `tailscale_device_key.infra` [commit `4fe6631`, 2026-08-18].

## 5. Dyski, prąd i stabilność węzłów

### 5.1 Oszczędzanie prądu w E5

| Data | Zmiana | Dowód |
| --- | --- | --- |
| 2026-08-03 | Odpięcie Intel AC 3168 od `iwlwifi` (runtime PM może uśpić kartę) i radia BT; naprawa reguły udev z `$DEVPATH` zamiast `$devpath` | [commit `43cb431`, 2026-08-03] |
| 2026-10-12 | Artwork, NFO i trickplay Jellyfin na SSD zamiast obok mediów (przeglądanie budziło dyski HDD) | [commit `59314da`, 2026-10-12] |
| 2026-10-12 | Dane tymczasowe Firefoksa w Byparr w RAM (~4 GB/dzień zapisów na SSD) | [commit `d6f26be`, 2026-10-12] |
| 2026-10-26 | TLP dawał `sda` 15-sekundowy autosuspend: ~36 tys. cykli start/stop wobec ~2,2 tys. na pozostałych dyskach | [commit `73d06cc`, 2026-10-26] |
| 2026-11-19 | Jak czytać log smartd, żeby wiedzieć, czy dyski spały | [commit `957d2a2`, 2026-11-19] |

Pomiarów poboru mocy w watach repo w tym okresie nie zawiera [nieznane]; to dane potrzebne do rozdziału kosztów.

### 5.2 Studium przypadku: pula pobierania NVMe + HDD (2026-08-31 → 2026-11-19)

Najdłuższy łańcuch przyczyn w E5: kolejną usterkę zwykle odsłaniała poprawka poprzedniej.

| Krok | Objaw | Przyczyna | Poprawka | Dowód |
| --- | --- | --- | --- | --- |
| 1 | Pobieranie spada z 128 MB/s do < 2 MB/s | Próg „wolnego torrenta” 1 MB/s zwalniał prawie wszystkie z limitu; 91 zapisywało naraz na RAIDZ1 z 5 HDD, zapisy ~52 KiB losowo przy 35 ms await | Limit aktywnych pobrań faktycznie wiążący | [commit `f7ad39e`, 2026-08-31] |
| 2 | Dyski w połowie bezczynne, a zapis dławiony | Kolejka async ZFS rosła od zapełnienia bufora, a przy `txg_timeout=30` próg opóźnień zapadał, zanim kolejka urosła powyżej 2 | `zfs_vdev_async_write_active_min_dirty_percent=10`; latencja 32-37 ms → 0,7-3,7 ms | [commit `61c109d`, 2026-08-31] |
| 3 | Niekompletne torrenty piszą losowo po dziesiątkach plików | Taki wzorzec zapisu nie pasuje do RAIDZ1 | Osobna pula NVMe 238 GiB na dane w trakcie pobierania | [commit `b4744b4`, 2026-08-31] |
| 4 | Włączenie `TempPath` przeniosłoby 472 GiB na pulę 231 GiB; pod wisiał w Terminating ponad godzinę | Przenoszenie storage blokuje zamknięcie qBittorrenta | `TempPathEnabled=false` | [commit `914e906`, 2026-08-31], [commit `99b59af`, 2026-08-31] |
| 5 | Projekt docelowy | Unia mergerfs: NVMe (RW) → HDD (RW, przelew) → stary katalog (NC, tylko do opróżnienia); `sync=disabled` lokalnie tylko na dwóch datasetach z danymi do ponownego pobrania | Wdrożone po testach na zbędnych datasetach; `write_cache_overload` 44% → 0% | [commit `0bdd584`, 2026-09-01], [plik `docs/ssd-download-pool.md`] |
| 6 | ESTALE, zawieszony klient NFS, talos-3 do `reboot --mode force` | qBittorrent zmieniał nazwę `X.!qB` → `X`; `inodecalc=path-hash` zmienia inode przy rename, a uchwyt NFS zostaje | Wyłączenie sufiksu `.!qB` | [commit `bfeb1c6`, 2026-09-01], [commit `3804899`, 2026-09-02] |
| 7 | Quota 2 TiB `Storage/dl` pełna, 25 torrentów w błędzie | mergerfs przenosi plik `sendfile()`, który zamienia dziury plików rzadkich w prawdziwe zera, a `compression=off` wyłącza w ZFS wykrywanie bloków zerowych | `compression=zle` (8 GiB pliku z 410 MiB danych: 8,0G pod `off`, 400M pod `zle`) | [commit `064f440`, 2026-09-02] |
| 8 | NVMe wielokrotnie do 0 B wolnego | Pliki rzadkie: 79 GiB torrent zajmuje 0,9 GiB przy tworzeniu, więc globalne `minfreespace=25G` nigdy nie zadziała; 609 GiB pozornego rozmiaru na 238 GiB | `minfreespace` 75G per gałąź | [commit `0258e6e`, 2026-09-02] |
| 9 | Torrent w błędzie po odznaczeniu plików | Przeniesienie do `.unwanted` to rename przy otwartych plikach (jak krok 6) | `UseUnwantedFolder` przypięty na wyłączony | [commit `3a97171`, 2026-11-12] |
| 10 | 95 GB osieroconych plików `.nfs*` | Usunięcie pliku otwartego przez NFS daje „silly rename”, a ten zmienia fileid; przy zamknięciu jądro pomija unlink. Wyzwala to „Mark as failed” w Sonarr/Radarr na wciąż seedowanym torrencie | Wpis z poleceniem wyszukiwania | [commit `957d2a2`, 2026-11-19] |

Decluttarr faktycznie kasował pobrania: trzy dobre wydania 50 GiB po 30 minutach spowolnienia [commit `87062e4`, 2026-08-29] i pięć pobrań w jednej sekundzie po jednym błędnym odczycie kolejki [commit `6d7b5de`, 2026-08-30]. Przy incydentach storage z 2026-09-02 skasowałby m.in. dwa sezony pobrane w 49% i 57%, więc progi wydłużono do trzech godzin [commit `a4590af`, 2026-09-02].

Lekcja [wniosek]: przyjęte w projekcie założenie („średni torrent 24 GiB < 25G wolnego miejsca”) było złą statystyką, co dokument sam przyznaje: ryzyko wyznacza ogon rozkładu (79 GiB), a nie średnia [plik `docs/ssd-download-pool.md`].

### 5.3 Studium przypadku: ustawienia ZFS pod uśpienie dysków a etcd (2026-09-21)

| Etap | Treść |
| --- | --- |
| Objaw | Logi etcd `apply request took too long: 7.0s`, `leader is overloaded likely from slow disk`, wybory lidera (term 214); jednocześnie kończą się z exit 1 kube-scheduler, kube-controller-manager, sidecary CSI i Authentik. Wygląda to na awarię węzła albo storage. |
| Przyczyna | `zfs_txg_timeout=30` i `zfs_dirty_data_max=12GiB` ustawiono dla puli HDD (uśpienie dysków), ale to globalne parametry modułu, bez wersji per pula. `rpool` (NVMe z etcd i dyskami VM) brudził ~1,8 GiB w 30 s, poniżej progu 2,4 GiB, więc zawsze wygrywał timeout i każdy txg zapisywał całość w jednym 6-25-sekundowym syncu. |
| Poprawka | Najpierw 1 GiB [commit `34899c2`, 2026-09-21], potem 256 MiB, bo przy odbudowie Longhorna 1 GiB dawał sync 3,9 s, a 256 MiB daje 0,4 s [commit `d795946`, 2026-09-21]. |
| Korekta uzasadnienia | `d795946` przypisywał flapowanie węzła tej przyczynie; okazało się, że flapy dawała kolizja IP (5.4). Wartość 256 MiB została, bo reguła „sync dużo poniżej sekundy” nadal obowiązuje [commit `cca052c`, 2026-09-22]. |
| Lekcja | Strojenie pod jeden cel (prąd) ma skutki dla innych pul, bo parametry są globalne; bezczynna pula i tak nie zapisuje txg, więc uśpienie dysków na mniejszym buforze nie cierpi [plik `AGENTS.md`]. |

### 5.4 Studium przypadku: talos-3 i kolizja IP (2026-09-21 → 2026-09-22)

Przez dwa dni sprawdzano trzy hipotezy. Każdą wspierał częściowy pomiar i każdą potem wycofano.

| Etap | Treść | Dowód |
| --- | --- | --- |
| Objaw | Na talos-3: 70-100% utraty odpowiedzi DNS (na `.110`/`.111` 0%), brak wychodzącego TCP, timeouty etcd, błędy dzierżaw kubeleta, flapy `Ready` mniej więcej co godzinę (42 przejścia NotReady w jeden dzień bez alertu), burze odbudów Longhorna. LAN i sam router osiągalne. | [commit `1988d0a`, 2026-09-21], [commit `9903e08`, 2026-09-22] |
| Hipoteza 1 | Trzy tailscaled za jednym NAT na porcie 41641 wyczerpują mapowania UDP routera → przypięcie osobnych portów. Po zmianie utrata DNS wróciła do 77%. | [commit `2ba9039`, 2026-09-21], [commit `ee812e0`, 2026-09-21], [commit `0b25106`, 2026-09-22] |
| Hipoteza 2 | Repliki Longhorna „nie przeciążone, tylko wolne” → `engine-replica-timeout` 8 → 30 s. Odbudowy oscylowały dalej. | [commit `7c1a8e3`, 2026-09-21], [commit `5fd7f56`, 2026-09-22] |
| Hipoteza 3 | Odbudowy nasycają NVMe dzielone z etcd → limit odbudów 2 → 1 → 0 (pauza) → 1. Pauza faktycznie uspokoiła pulę. | [commit `7447c19`, 2026-09-21], [commit `a3383c1`, 2026-09-21], [commit `f75a932`, 2026-09-22], [commit `89b6d49`, 2026-09-22] |
| Przyczyna | Pula DHCP routera Mercusys obejmowała `192.168.1.2-253`; po zaplanowanym poniedziałkowym restarcie routera o 03:00 dekoder TV dostał `192.168.1.112`, statyczny adres talos-3. Na ARP odpowiadały dwa urządzenia, odpowiedź dekodera przychodziła ~1 ms później i wygrywała w cache routera, więc ruch powrotny z internetu do talos-3 trafiał do dekodera. | [commit `9903e08`, 2026-09-22] |
| Poprawka | Pula DHCP zawężona do `192.168.1.180-253`; potrzebny był drugi restart routera, bo zawężenie nie unieważnia istniejącej dzierżawy. Weryfikacja: jedna odpowiedź ARP, utrata DNS 100% → 0%, TCP 0/5 → 5/5. | [commit `67466a5`, 2026-09-22] |
| Sprzątanie | Wycofanie przypięcia portów i ograniczenia odbudów; usunięcie błędnego wpisu z AGENTS.md („a confidently wrong gotcha is worse than none”); `engineReplicaTimeout` jawnie zadeklarowany jako 8, bo samo usunięcie klucza nie resetuje ustawienia Longhorna. | [commit `0b25106`, 2026-09-22], [commit `b11c5b1`, 2026-09-22], [commit `d10f74a`, 2026-09-22] |
| Lekcja | Diagnoza jednym poleceniem: `tcpdump -i vmbr0 -nn 'arp and host <ip>'`; dwie odpowiedzi `is-at` to konflikt. Problem przetrwał restart VM i restart routera, i właśnie dlatego wyglądał na usterkę węzła. | [plik `AGENTS.md`] |

Nie wszystko z tych dwóch dni wynikało z kolizji IP. Rozróżnienie:

| Zmiana | Status po wyjaśnieniu przyczyny | Dowód |
| --- | --- | --- |
| Przypięcie portów WireGuard | wycofane | [commit `0b25106`, 2026-09-22] |
| `engine-replica-timeout` 30 s | wycofane | [commit `5fd7f56`, 2026-09-22], [commit `b11c5b1`, 2026-09-22] |
| Ograniczanie odbudów Longhorna | wycofane do 2 | [commit `0b25106`, 2026-09-22] |
| Bufor ZFS 256 MiB | zachowany, uzasadnienie poprawione | [commit `cca052c`, 2026-09-22] |
| Wpis o livelocku odbudów | zachowany, poprawiony | [commit `d10f74a`, 2026-09-22] |
| ZFS txg vs etcd | realny, osobny problem | [commit `34899c2`, 2026-09-21] |
| Zawieszony klient NFS (rozdz. 5.5) | realny, osobny problem | [commit `034599f`, 2026-09-21] |
| Authentik: 92 restarty w 3 dni 7 h | poprawki zachowane (`single-request-reopen`, `ndots:2`, pełna nazwa bazy); mechanizm opisany jako wyścig conntrack przy równoległych A/AAAA, ale pod stał na talos-3, więc czy problem był niezależny od kolizji IP, repo nie rozstrzyga [nieznane] | [commit `3b9c9e3`, 2026-09-21], [commit `b19b91f`, 2026-09-21] |
| Alerty: flapy węzłów, kopie, NoData Mimira | zachowane, bo wtedy wyszły luki w monitoringu | [commit `1988d0a`, 2026-09-21], [commit `6046838`, 2026-09-21], [commit `c37bf8b`, 2026-09-22] |

### 5.5 Zawieszony klient NFSv4

Dwa osobne wyzwalacze tego samego stanu:

- 2026-09-01: rename przez mergerfs (krok 6 w 5.2) zostawił klienta tak zawieszonego, że węzeł nie mógł odmontować NFS i nie dało się go zrestartować [commit `bfeb1c6`, 2026-09-01], [commit `36e6157`, 2026-09-01].
- 2026-09-21: przestoje VM z powodu syncu ZFS zostawiły talos-3 z 36 zadaniami w stanie D, load 55 i ~90% iowait przy bezczynnych dyskach. `talosctl processes` pokazywał wszystkie 282 zadania jako `S`, więc problem był niewidoczny; widać go w `procs_blocked` z `/proc/stat` [commit `034599f`, 2026-09-21]. Serwer nadal widział klienta jako `confirmed`. Wygaszenie stanu klienta po stronie serwera NFS naprawiło węzeł w kilka sekund bez restartu (36 → 0 zablokowanych, load 55 → 1,2) [commit `1b7ad54`, 2026-09-21].

### 5.6 Pamięć węzłów i OOMController Talosa (2026-08-19)

| Etap | Treść | Dowód |
| --- | --- | --- |
| Objaw | Kontenery giną z exit 137 i powodem `Error`, nie `OOMKilled`; metallb-frr-k8s 605 restartów, longhorn-manager 207, authentik-server 127, argocd-application-controller 117; SSO i synchronizacja GitOps leżały godzinami. | [commit `1727f68`, 2026-08-19] |
| Przyczyna | Userspace'owy `runtime.OOMController` Talosa zabija przy presji PSI całe cgroupy QoS, BestEffort jako pierwsze. Prawie wszystkie workloady nie mają requestów, więc są BestEffort; kontenery restartują się w miejscu zamiast przenieść się na inny węzeł. talos-3 miał 8 GiB, a uruchamiał kube-apiserver, Loki, Mimir, Grafanę, ArgoCD, Authentika i control plane Longhorna; scheduler widział 47% zajętości przy faktycznych 82%. | [commit `1727f68`, 2026-08-19], [commit `f72ba59`, 2026-08-19] |
| Poprawka | talos-3 do 12 GiB. LimitRange z domyślnym requestem pamięci został przygotowany i wycofany: „Owner's call: no default memory requests”. | [commit `1727f68`, 2026-08-19], [commit `787476f`, 2026-08-19] |
| Lekcja | Dyskusyjna decyzja projektowa: mniej deklaracji w manifestach kosztem zapasu RAM na węzłach. | [wniosek] |

Podobnie mylący objaw: OOM w kontenerze s6-overlay (linuxserver.io) raportuje `Completed`, exit 0; Bazarr restartował się 6 razy w 36 h przez ffprobe [commit `5ec1ee0`, 2026-08-21].

### 5.7 Wyłączanie węzłów: pasma priorytetów kubeleta (2026-08-19)

| Etap | Treść | Dowód |
| --- | --- | --- |
| Objaw | Wyłączenie niedrenowanego węzła wisi ~12 minut na każdym montowaniu Longhorn RWX (`nfs: server ... not responding`). | [commit `692af2c`, 2026-08-19] |
| Przyczyna | Kubelet dawał zwykłym podom 20 s (30 s − 10 s), Grafana deklaruje 90 s; Talos zatrzymywał kube-proxy i CNI, zanim pody zwolniły montowania. Share-managery Longhorna (priorytet 10^9) kończyły się w tej samej fazie co ich klienci. | [commit `ed3641f`, 2026-08-19] |
| Poprawka | `shutdownGracePeriodByPodPriority` z dwoma pasmami (120 s). | [commit `ed3641f`, 2026-08-19] |
| Awaria wywołana poprawką | Kubelet odrzuca tę opcję, gdy któryś z dwóch skalarnych okresów jest > 0, a Talos ustawia je domyślnie na 30 s i 10 s; kubelet padł na wszystkich trzech węzłach. Obecny wpis gotcha dodaje zastrzeżenie: wprowadzony później (2026-10-02) łańcuch modułów `talos-node` też by przed tym nie chronił, bo apply wraca przed restartem kubeleta. Gdy klaster leży, leży też AdGuard, więc `terraform apply` nie rozwiązuje nazwy backendu stanu. | [commit `59abe12`, 2026-08-19], [commit `40f9ca2`, 2026-08-19], [plik `AGENTS.md`] |
| Uzupełnienia | Wolumeny obserwowalności z RWX na RWO (RWX to share-manager NFS na każdy wolumen) i reguła „drenuj przed każdym planowanym restartem”. | [commit `fb226ed`, 2026-08-19], [commit `692af2c`, 2026-08-19] |

### 5.8 Ukryte pułapki przy restarcie hosta (2026-08-31)

Dwie usterki leżały ukryte tygodniami i wyszły dopiero przy restarcie [commit `c939f49`, 2026-08-31]:

- `lifecycle.ignore_changes` na `cdrom` VM: nazwa pliku ISO zawiera `talos_version`, a pobranie nowej wersji zastępuje plik, więc VM wskazywały nieistniejące ISO. Proxmox odrzuca to dopiero przy starcie, więc cały klaster nie wstał [commit `3c111c6`, 2026-08-31]. Później odwrócono podejście: ISO świadomie nie śledzi wersji Talosa, bo aktualizacje idą przez obraz instalatora [commit `80990c3`, 2026-09-24].
- Dodanie dysku NVMe przenumerowało grupy IOMMU, a mapowanie PCI w Proxmoxie przypinało grupę, więc passthrough GPU nie działał [commit `c939f49`, 2026-08-31].

Podobne zjawisko po aktualizacji OVMF/QEMU 2026-11-02: fbcon na talos-1 zajmował cpu0 w 100%, etcd padał na health checku około 4 razy na godzinę (221 razy w 58 h); poprawka `fbcon=map:9` w schemacie GPU [PR #760].

### 5.9 Automatyczne aktualizacje Talosa i moduł `talos-node` (2026-09-24 → 2026-10-27)

- `talos_machine` i `talos_cluster` z providera 0.12 zastąpiły dotychczasowe zasoby: aktualizacja OS przy zmianie obrazu instalatora (cordon, drain, reboot, uncordon) i `upgrade-k8s` przy zmianie wersji Kubernetes. Stan przejęto bez restartu węzłów [commit `b79a68b`, 2026-09-24]. Pierwsza aktualizacja przez ten mechanizm: Talos v1.14.1, Kubernetes 1.37.1 [commit `a5a4ddf`, 2026-09-24].
- Problemy wdrożeniowe: provider zgłaszał każdą udaną aktualizację jako błąd po 15 minutach, bo strumień przez Tailscale zostawał półotwarty (naprawa: krótszy TCP keepalive w CI) [commit `32270cd`, 2026-09-24]; Renovate zdejmował prefiks `v` z wersji i obraz instalatora nie istniał [commit `d07a43b`, 2026-10-02].
- Studium przypadku 2026-10-02. Apply bez łańcucha zrestartował talos-1, gdy repliki talos-3 jeszcze się odbudowywały; talos-2 został ostatnią zdrową kopią każdego wolumenu, jego drain utknął na PDB Longhorna, a dwa wolumeny z niezgodnym licznikiem rewizji przeszły w fault. Odpowiedź: moduł `Terraform/modules/talos-node` wywoływany osobno dla każdego węzła i łączony `depends_on` (bo `for_each` nie umie łańcuchować instancji) oraz bramka `restful_operation`, która co 10 s sprawdza, czy żaden podpięty wolumen Longhorna nie jest zdegradowany [commit `feb2ee9`, 2026-10-02]. Bramka sama musiała dostać ponawianie, bo API server po restarcie odpowiadał 429 [commit `8f6c950`, 2026-10-27].

## 6. Kopie zapasowe i monitoring

### 6.1 Kopie (borg → Hetzner Storage Box)

| Data | Zmiana | Dowód |
| --- | --- | --- |
| 2026-08-09 | Wykluczenia (cache, logi, dane odtwarzalne); `BORG_PATTERNS` dla reguł `+`, których `--exclude-from` nie obsługuje | [commit `54e0586`, 2026-08-09], [commit `2ca87ba`, 2026-08-09] |
| 2026-08-20 | Snapshoty Storage Boxa co tydzień, 10 sztuk (~10 tygodni). Cel 6 miesięcy wymagałby BX31. Snapshoty chronią przed skompromitowanym klientem z kluczem zapisu | [commit `b6b0e81`, 2026-08-20] |
| 2026-08-31 | Kod wyjścia 1 (plik zmienił się w trakcie) nie oznacza już porażki | [commit `782e2fa`, 2026-08-31] |
| 2026-09-21 | Kopie wolumenów Traefika (`acme.json`) i CrowdSec, wcześniej bez żadnej kopii | [commit `771beb5`, 2026-09-21] |
| 2026-09-22 | Limity czasu jobów, bo `concurrencyPolicy: Forbid` plus zawieszony job blokuje kolejne bez końca; alert „backup CronJob stopped succeeding” | [commit `7780f83`, 2026-09-22], [commit `c37bf8b`, 2026-09-22] |
| 2026-11-09 | `--lock-wait`: poprzednia poprawka (`BORG_LOCK_WAIT`) nie działała, bo borg 1.4 nie ma takiej zmiennej; 2026-11-08 pięć jobów nie zapisało archiwum | [commit `aa8466b`, 2026-09-21], [commit `db85464`, 2026-11-09] |

Wątek „Degraded app-of-apps bez widocznej przyczyny = nieudany CronJob” kosztował prawie cały dzień 2026-09-22 [commit `0652a8b`, 2026-09-22]; osobno health check ArgoCD blokował prune osieroconych zasobów, co naprawiono dopiero 2026-11-05 [commit `7a0e7c3`, 2026-11-05].

### 6.2 Monitoring i alerty

- Reguły crash-loop przepisane, bo dawna (`> 5 restartów w 10 min`) milkła akurat wtedy, gdy backoff kubeleta się wydłużał [commit `bf6f565`, 2026-08-20]; potem tolerancja jednego restartu [commit `a6de5ff`, 2026-09-29].
- Nowe reguły: flapy węzłów szybsze niż `for: 5m` [commit `1988d0a`, 2026-09-21] (poprawka „zatrzaskiwania” na 12 h [commit `7d0cb3b`, 2026-09-22]); kopie; Mimir i Loki dostały dłuższe timeouty sond, bo restart Mimira dawał burzę alertów NoData [commit `6046838`, 2026-09-21].
- smartd i ZED na hoście wysyłają alerty prosto na Discord; Postfix na `carbon` był wyłączony i poczta do roota ginęła od czerwca [commit `dc32b4e`, 2026-10-26].
- Loki: WAL > 90% powoduje odrzucanie wszystkich pushy, PVC 1Gi → 10Gi [commit `2874089`, 2026-08-08], [commit `62cdbd0`, 2026-08-08].

## 7. Nowe i usunięte aplikacje

| Aplikacja | Okres | Cel i uwagi | Dowód |
| --- | --- | --- | --- |
| byparr-proxy | 2026-08-08 → 2026-11-05 | Proxy w Pythonie (stdlib, z ConfigMap) przed Byparr, żeby Prowlarr dostawał gotowy HTML 1337x/EZTV zamiast odtwarzać ciasteczka Cloudflare. Usunięte, gdy natywne proxy FlareSolverr w Prowlarr okazało się wystarczające. Przy okazji załatana luka SSRF (`@evil.tld/x`) | [commit `7855699`, 2026-08-08], [commit `3cdfd9b`, 2026-08-20], [commit `c854fe2`, 2026-11-05] |
| copyparty-dav | 2026-08-20 → 2026-09-03 | Druga instancja Copyparty bez IdP dla WebDAV przez Tailscale, bo proxy L3 operatora nie przepisuje nagłówków i klient tailnetu mógł podrobić `X-authentik-*`. Usunięta, gdy tailnet przestał być ścieżką do www | [commit `3cdfd9b`, 2026-08-20], [commit `6e9a4c5`, 2026-09-03] |
| cloudflare-ddns | od 2026-08-21 | Aktualizacja rekordów A na dynamiczny IP | [commit `5d7f26e`, 2026-08-21] |
| arr-coverage-search | od 2026-08-27 | CronJob w Pythonie: wyszukiwanie w Radarr/Sonarr po jednej pozycji, wstrzymane, gdy Prowlarr zgłasza indekser w backoffie (masowe wyszukiwanie Radarr robi to równolegle i bez raportu) | [commit `f07d1ad`, 2026-08-27], [commit `13a0d2f`, 2026-08-31] |
| crowdsec-web-ui | od 2026-10-05 | Panel banów `bans.nerine.dev`, tylko admins | [commit `efac355`, 2026-10-05] |
| clips-sftp | od 2026-11-17 | Pod z tailscaled jako `files`, SFTP przez Tailscale SSH jako nieuprzywilejowany użytkownik, tylko katalog `public/clips` | [commit `cf24c25`, 2026-11-17] |
| c-oop | od 2026-11-22 | Współdzielony edytor C++ pod `c-oop.nerine.dev`, publiczny bez logowania, bezstanowy (relay sygnalizacji w pamięci), własny limit żądań na adres; obraz z GHCR autora | [commit `d9446b8`, 2026-11-22], [plik `Kubernetes/apps/c-oop/`] |
| Pagewire + generic-device-plugin | od 2026-11-25 | Drukowanie i skanowanie na Samsungu SCX-4300 przez USB, namespace `printing` (privileged), `print.nerine.dev` za Authentikiem (najpierw admins, tego samego dnia vips); drukarka przekazywana do talos-2 przez Ansible jako `usb0: host=`, by VM startowała bez włączonej drukarki | [commit `8d53436`, 2026-11-25], [commit `e3857f4`, 2026-11-25], [commit `9b1d576`, 2026-11-25] |
| homepage | usunięta 2026-08-21 | Zastąpiona biblioteką aplikacji Authentika | [commit `3fce217`, 2026-08-21] |
| mcpjungle | usunięta 2026-08-19 | Jedyna prywatna trasa z bramką sieciową i bez sprawdzenia tożsamości | [commit `096bd7e`, 2026-08-19] |
| whoami | usunięta 2026-08-20 | Debug ścieżki ingress, zbędny po wycofaniu VPS | [commit `7158f21`, 2026-08-20] |

Copyparty zmienił w tym czasie układ: anonimowy odczyt `/personal/public` [commit `1e67b18`, 2026-11-17], podział na private/members/public [commit `7b920a7`, 2026-11-17] i przeniesienie sekcji na najwyższy poziom URL [commit `a0c250d`, 2026-11-18]. Przy okazji powstał wpis o `skip_path_regex` w Authentiku: końcowy znak nowej linii dodaje pusty regex, który wyłącza forward-auth dla całej strony [commit `1e67b18`, 2026-11-17].

Poczta e-mail. `docs/email-provider-research.md` porównuje hostingi poczty dla własnej domeny (obserwacja cen 2026-08-01) i rekomenduje Zoho Mail Lite, potem Purelymail i Migadu [plik `docs/email-provider-research.md`]. Plik trafił do repo w commicie o puli pobierania [commit `0bdd584`, 2026-09-01]. Żaden inny plik na `main` nie wspomina tych dostawców; wysyłka nadal idzie przez Postfix i OCI Email Delivery [plik `Terraform/email.tf`]. Czy migracja skrzynek się odbyła, repo nie mówi [nieznane]. Wygląda na to, że poczty autor nie przenosi do domu, tylko wybiera dostawcę [wniosek]; przyda się to w rozdziale o repatriacji.

Strojenie stosu mediów (Recyclarr, qBittorrent, Decluttarr) zajmuje kilkadziesiąt commitów; zbiorczo:

| Obszar | Przykład | Dowód |
| --- | --- | --- |
| Recyclarr | kolejność jakości wg TRaSH, ujemny `min_format_score`, ban upscali, paczki sezonów nad pojedynczymi odcinkami (obejście Sonarr v4) | [commit `2dda8d1`, 2026-08-08], [commit `4586b26`, 2026-08-21], [commit `10d28d8`, 2026-11-12] |
| qBittorrent | kolejka dysku, limity aktywnych pobrań, wyłączenie sufiksu `.!qB` | [commit `4a50f3f`, 2026-08-31], [commit `bfeb1c6`, 2026-09-01] |
| Decluttarr | dłuższe progi usuwania, bufor ostrzeżeń dla `remove_orphans` | [commit `87062e4`, 2026-08-29], [commit `a4590af`, 2026-09-02] |
| Prowlarr | odrzucanie zablokowanych hashy (ten sam pakiet wracał do 26 razy) | [commit `7cd283d`, 2026-08-26] |

## 8. Wzorce przekrojowe okresu

- Diagnozy poprawiane w dokumentacji. Co najmniej cztery wpisy gotcha okazały się błędne i zostały publicznie sprostowane: Orange 80/443, „Funbox”, przypięcie portów Tailscale, rozmiar bufora ZFS [commit `ca9a652`, 2026-08-21], [commit `ef00f2c`, 2026-09-22], [commit `0b25106`, 2026-09-22], [commit `cca052c`, 2026-09-22]. Repo traktuje sekcję Key Gotchas jako pamięć operacyjną i usuwa z niej wpisy, które okazały się nieprawdziwe [wniosek].
- Dwa twierdzenia z E4, które obalono w E5. Po pierwsze, „publiczny DNS wskazuje tylko IP Oracle VPS” [commit `bf8056e`, 2026-03-09] przestało obowiązywać, gdy rekordy A zaczęły wskazywać domowe IP [commit `5d7f26e`, 2026-08-21]. Po drugie, wpis o tym, że Longhorn w ciągu sekund usuwa snapshoty tworzone przez użytkownika [commit `1ff0808`, 2026-06-03], obalił pomiar: snapshot przetrwał 30 minut, a grupa recurring-job jest tu pusta [commit `2924c95`, 2026-09-22]. Początek E4 opisuje `historia/04-przebudowa-gitops.md`.
- Lokalny plan przed pushem. CI aplikuje Terraform automatycznie na `main`, więc wprowadzono regułę lokalnego `plan`/`apply` przed pushem; CI ma tylko potwierdzać [commit `111db10`, 2026-08-19].
- Praca z agentem AI. Część commitów ma trailer `Claude-Session`, a 2026-08-18 pliki AGENTS.md podlinkowano jako CLAUDE.md, żeby Claude Code je czytał [commit `300b202`, 2026-08-18]. Wiele komunikatów to szczegółowe raporty z pomiarami [wniosek]. Skala udziału agenta w pracy jest [nieznane].
- Odwracalność. Kilka zmian wycofano tego samego dnia (LimitRange, HTTP/3, reguła SSH, tini subreaper) [commit `787476f`, 2026-08-19], [commit `ecd4a61`, 2026-09-03], [commit `c958239`, 2026-11-10], [commit `fda93a8`, 2026-11-05].

## 9. Stan obecny (2026-11-27, branch `main`)

### 9.1 Sprzęt

| Element | Według plików | Uwagi |
| --- | --- | --- |
| Host Proxmox `carbon` | README: Intel Core i5-12600K, 32 GB DDR4, 1 TB NVMe + pula ZFS 5×3 TB, Intel Arc B580 [plik `README.md`] | Sprzeczności, patrz niżej |
| Pule ZFS | `rpool` (lustro NVMe, dyski VM i etcd), `Storage` (RAIDZ1 z 5 HDD), `ssdstage` (NVMe 238 GiB, pobieranie) | [commit `a3383c1`, 2026-09-21], [commit `b4744b4`, 2026-08-31], [plik `docs/ssd-download-pool.md`] |
| Kontrolery SATA | ASMedia ASM1062 (sda, sdb) i FCH (sdc-sde) | [plik `AGENTS.md`] |
| GPU | Intel Arc B580 przekazany do talos-1 | [plik `Terraform/variables.tf`] |
| VM Home Assistant | `192.168.1.186`, koordynator Zigbee przez mapowanie USB `Zigbee`; poza Terraformem | [plik `AGENTS.md`], [plik `Ansible/vars/proxmox.yaml`: `serial_logger_vmids: [110, 111, 112]`] |
| Oracle VPS `compute` | VM.Standard.A1.Flex, 4 OCPU, 24 GB, urządzenie osobiste w tailnecie | [plik `README.md`], [PR #567] |

Sprzeczności do wyjaśnienia (rozdział kosztów potrzebuje poprawnych danych):

1. README podaje dla każdego węzła 8 vCPU / 16 GB, a `Terraform/variables.tf` 4 vCPU / 16 GiB (talos-1) oraz 6 vCPU / 12 GiB (talos-2, talos-3) [plik `README.md`], [plik `Terraform/variables.tf`].
2. Same VM Talosa mają 40 GiB, do tego ARC do 4 GiB i VM Home Assistant, a README podaje 32 GB na hoście [wniosek].
3. README podaje procesor Intel, a repo mówi o kontrolerach FCH, czyli nazwie hubu chipsetów AMD [plik `AGENTS.md`], [wniosek].
4. README opisuje jeszcze `nfs-csi` StorageClass, usuniętą w E4 [plik `README.md`], [commit `a338df4`, 2026-02-20].

### 9.2 Węzły i klaster

| Węzeł | VMID | vCPU | RAM | Rola |
| --- | --- | --- | --- | --- |
| talos-1 | 110 | 4 | 16 GiB | control plane + worker, GPU |
| talos-2 | 111 | 6 | 12 GiB | control plane + worker, drukarka USB |
| talos-3 | 112 | 6 | 12 GiB | control plane + worker |

[plik `Terraform/variables.tf`], [plik `AGENTS.md`]. VIP API: `192.168.1.100` [plik `Terraform/variables.tf`]. Talos i Kubernetes aktualizowane przez `talos_machine`/`talos_cluster` w module `talos-node`, po jednym węźle, z bramką zdrowia Longhorna [commit `feb2ee9`, 2026-10-02]. Wersje na `main`: Talos `v1.14.6`, Kubernetes `1.37.2`, kontrakt konfiguracji maszyn przypięty do `v1.13.9` [plik `Terraform/variables.tf`].

### 9.3 Sieć i wystawienie

- Internet → router Mercusys (przekierowanie 80/443) → Traefik na IP MetalLB `192.168.1.11` (`externalTrafficPolicy: Local`, więc CrowdSec widzi prawdziwe IP) [plik `AGENTS.md`].
- DNS publiczny: Cloudflare, `nerine.dev` i `*.nerine.dev`, bez proxy, aktualizowane przez cloudflare-ddns [plik `Terraform/cloudflare.tf`].
- DNS w LAN: AdGuard przepisuje `*.nerine.dev` na `192.168.1.11` tylko dla `192.168.0.0/16`; klienci tailnetu dostają IP publiczny [plik `AGENTS.md`].
- Tailscale: DNS (AdGuard przez Service operatora), administracja klastrem, exit node na Proxmoxie, SSH; tagi `tag:node`, `tag:proxmox`, `tag:service`, `tag:ci`, `tag:files`, `tag:secured`, `tag:untrusted`, `tag:homeassistant`, `tag:minecraft`, `tag:k8s-operator` [plik `Tailscale/policy.hujson`].
- Pula DHCP routera `192.168.1.180-253`; adresy statyczne muszą być poniżej `.180` [plik `AGENTS.md`].
- HTTP/3 wyłączone [commit `6deeeaf`, 2026-10-06].

### 9.4 Uwierzytelnianie

- Authentik jest jedyną bramą: forward-auth (`private-proxy` w trybie `forward_domain` dla stosu *arr, Longhorna, Traefika itd.; osobne `forward_single` dla Seerr, panelu banów, Pagewire i Copyparty) albo OIDC aplikacji (Jellyfin, Immich, Grafana, ArgoCD) [plik `Terraform/apps/authentik.tf`], [plik `README.md`].
- Brand Authentika używa flow `google-only-authentication`, czyli logowania przez źródło OAuth Google [plik `Terraform/apps/authentik.tf`].
- Grupy: `admins`, `vips`, `watchers`, `writers`, `photos`; polityki `vips-or-admins`, `watchers-vips-or-admins`, `photos-or-admins` [plik `Terraform/apps/authentik.tf`].
- Strona główna to biblioteka aplikacji Authentika [commit `3fce217`, 2026-08-21]. Bez middleware Authentika w IngressRoute są c-oop (publiczny, bez logowania) oraz Jellyfin i Immich (własne OIDC); Copyparty pomija forward-auth dla `/public` [plik `Kubernetes/apps/c-oop/ingress.yaml`], [plik `Kubernetes/apps/jellyfin/ingress.yaml`], [plik `Kubernetes/apps/immich/ingress.yaml`], [commit `a0c250d`, 2026-11-18].
- Warstwy dodatkowe: CrowdSec (bouncer + AppSec w Traefiku), default-deny ingress w namespace'ach aplikacji, Pod Security `baseline` (`privileged` tylko w `printing`), brak tokenów SA w podach aplikacji [plik `Kubernetes/apps/namespaces.yaml`], [commit `093862e`, 2026-08-19].

### 9.5 Storage

| Warstwa | Zastosowanie | Dowód |
| --- | --- | --- |
| NFS v4.2 z hosta | `media-pvc` (`/Storage/Media`), `downloads-pvc` (`/Storage/Media/Downloads`), `downloads-pool-pvc` (mergerfs `/srv/downloads`), `downloads-ssd-pvc` (`/ssdstage/downloads`, wg dokumentu do wycofania), `personal-pvc` (`/SSDStorage`), `immich-upload` (`/Storage/Photos`) | [plik `Kubernetes/apps/common/media-pv.yaml`], [plik `docs/ssd-download-pool.md`] |
| Longhorn | konfiguracja i bazy aplikacji; klasy `longhorn` (zarządzana przez longhorn-manager), `longhorn-rwx`, `longhorn-static`, `longhorn-cache` (1 replika) | [commit `81609a2`, 2026-08-19] |
| Lokalny PV | cache modeli Immich ML na węźle GPU | [commit `e690d6b`, 2026-09-24] |

Strojenie hosta: `atime=off` na `Storage`, `zfs_txg_timeout=30`, `zfs_arc_max=4 GiB`, `zfs_dirty_data_max=256 MiB`, `zfs_vdev_async_write_active_min_dirty_percent=10`, `hd-idle -i 600 -c ata`, quota `Storage/dl` 2T, `minfreespace` NVMe 75G [plik `Ansible/setup-proxmox.yaml`], [plik `Ansible/vars/proxmox.yaml`].

### 9.6 Kopie zapasowe

- Borg do Hetzner Storage Box (`interstellar-backups`, z dostępem SSH, snapshoty raz w tygodniu, `day_of_week = 0`, `hour = 6`, maks. 10) [plik `Terraform/hetzner.tf`].
- CronJoby między 03:00 a 04:30: `borgbackup` (m.in. pg_dump Immicha), `media-backup` (orkiestrator jobów per PVC), `home-backup`, kopie obserwowalności, Traefika i CrowdSec z wspólnym patchem `backup=borg` [plik `Kubernetes/apps/borgbackup/cronjob.yaml`], [plik `Kubernetes/bootstrap/observability/backup-cronjob.yaml`], [commit `771beb5`, 2026-09-21].
- Recurring jobs Longhorna nie są zdefiniowane [plik `AGENTS.md`].

### 9.7 Sekrety

Bitwarden Secrets Manager + External Secrets Operator, magazyny `bitwarden-store` (ręczne) i `bitwarden-store-generated` (tworzone przez Terraform z `random_password` i `ignore_changes = [value]`) [plik `AGENTS.md`], [plik `Terraform/AGENTS.md`]. Sekret OIDC Jellyfin od 2026-11-05 jest atrybutem write-only i nie trafia do stanu Terraform [commit `09017c8`, 2026-11-05].

### 9.8 CI/CD i GitOps

| Workflow | Wyzwalacz | Rola |
| --- | --- | --- |
| `terraform.yaml` | push/PR na `main` w `Terraform/**` (bez `apps/`) i `Tailscale/**`, ręcznie | plan, auto-apply na `main` |
| `terraform-apps.yaml` | `Terraform/apps/**` | konfiguracja aplikacji przez port-forwardy |
| `terraform-destroy.yaml` | tylko ręcznie | zniszczenie |
| `ansible.yaml` | push w playbookach Proxmoxa i ich zmiennych, ręcznie | konfiguracja hosta |
| `ansible-lint.yaml`, `kubernetes-lint.yaml` | push/PR | lint |

[plik `.github/workflows/`]. Stan Terraform: OCI Object Storage (główny), Secret Kubernetes (`apps`) [plik `Terraform/AGENTS.md`]. Manifesty Kubernetes dostarcza ArgoCD (app-of-apps) z automatyczną synchronizacją [plik `AGENTS.md`]. Reloader restartuje każdy workload po zmianie ConfigMap/Secret (wyjątki: qBittorrent, Jellyfin) [commit `700a268`, 2026-11-12]. Renovate korzysta ze współdzielonego presetu [commit `42d311f`, 2026-11-04].

### 9.9 Monitoring

Grafana, Loki, Mimir, Promtail, Alloy, kube-state-metrics, node-exporter, shipper `/dev/kmsg` do Lokiego; kontakty alertów Discord i e-mail; dashboardy klastra, Traefika, mediów, logów, geolokalizacji, IP i Longhorna [plik `Kubernetes/bootstrap/observability/kustomization.yaml`]. Host wysyła alerty smartd i ZED na Discord niezależnie od klastra [commit `dc32b4e`, 2026-10-26].

### 9.10 Aplikacje według namespace

| Namespace | Aplikacje (host) |
| --- | --- |
| `media` | Jellyfin (`watch`), Seerr (`add`), Sonarr, Radarr, Prowlarr, Bazarr, qBittorrent, Decluttarr, Recyclarr, arr-coverage-search, Byparr, media-backup |
| `utilities` | Copyparty (`files`), Immich (`photos`), Postfix, clips-sftp, cloudflare-ddns, c-oop (`c-oop`), borgbackup |
| `home` | AdGuard (`dns`), home-backup |
| `printing` | Pagewire (`print`, `scan` → przekierowanie) |
| `kube-system` | descheduler, generic-device-plugin, metrics-server |
| infrastruktura | `argocd` (`argocd`), `authentik` (`auth`, apex), `crowdsec` (`bans`), `external-secrets`, `longhorn-system` (`longhorn`), `metallb-system`, `observability` (`grafana`), `reloader`, `tailscale`, `traefik` (`traefik`); dodatkowo coredns-override i intel-gpu-operator |

Hosty to subdomeny `nerine.dev` [plik `Kubernetes/apps/kustomization.yaml`], [plik `Kubernetes/bootstrap/kustomization.yaml`], [wniosek: przypisanie namespace z plików `kustomization.yaml` poszczególnych katalogów]. NetworkPolicies leżą w osobnym katalogu i obejmują kilka namespace'ów [plik `Kubernetes/apps/networkpolicies/`].

## Pytania do autora

1. Co dokładnie było źle w przekierowaniu portów 80/443 na routerze, poprawionym 2026-08-21?
2. Jaki procesor i ile RAM ma host `carbon`? README podaje Intel i5-12600K i 32 GB, a repo wspomina kontrolery FCH (AMD), a VM mają łącznie 40 GiB.
3. Czy README z węzłami po 8 vCPU / 16 GB jest nieaktualne, a obowiązują wartości z `Terraform/variables.tf` (4/16, 6/12, 6/12)?
4. Czy dla rozdziału kosztów istnieją pomiary poboru mocy (W) hosta przed i po zmianach z E4/E5 (hd-idle, atime, Wi-Fi, TLP)?
5. Czy migracja poczty do zewnętrznego dostawcy (np. Zoho Mail Lite z `docs/email-provider-research.md`) się odbyła, a jeśli tak, to do kogo i za ile?
6. Dlaczego reguła Tailscale `tag:secured → compute:22` została wycofana tego samego dnia (2026-11-10)?
7. Dlaczego zdecydowano „no default memory requests” (2026-08-19) zamiast LimitRange?
8. Do czego służy c-oop: czy to projekt na zajęcia z programowania obiektowego w C++?
9. Kto korzysta z usług publicznie (poza autorem): ile kont jest w grupach `vips`, `watchers`, `photos`, w przybliżeniu?
10. Jak duży był udział agenta AI (trailer `Claude-Session`) w diagnozach i zmianach z E5? Czy praca ma to opisać?
11. Czy jakiś koszt dał wycofanie Oracle `oracle-proxy` (VM była w Always Free, czy płatna)?
12. Dlaczego aplikacja Authentika bez wiązań polityk 2026-08-13 wpuszczała każde konto Google, a 2026-09-03 odmawiała wszystkim? Czy flaga `core_default_app_access` była zmieniana ręcznie?
13. Czy restarty authentik-server (92 w 3 dni 7 h, do 2026-09-21) zaczęły się przed poniedziałkowym restartem routera o 03:00, czy dopiero po nim?
14. Jakie VM poza Talosem działają na `carbon` (Home Assistant, inne) i ile mają RAM?

## Do której części pracy

- Projekt: model dostępu (Authentik jako jedyna brama, grupy, NetworkPolicies), wystawienie publiczne i DNS split-horizon (3.3, 4.2-4.4, 9.3-9.4).
- Implementacja: pula mergerfs, moduł `talos-node`, automatyczne aktualizacje, kopie zapasowe (5.2, 5.9, 6.1, rozdz. 9).
- Technologie: porównania z uzasadnieniem z repo, np. Tailscale proxy vs MetalLB, HTTP/3 vs HTTP/2, `forward_single` vs `forward_domain` (3.3, 3.4, 4.1).
- Odtwarzanie po awarii: studia przypadków 5.4-5.8 i 5.9 (kolizja IP, awaria kubeletów, ukryte ISO/IOMMU, rolling upgrade), zasady drenowania i lokalnego planu.
- Analiza kosztów: Oracle Always Free (4 OCPU / 24 GB), Hetzner BX11 vs BX31, oszczędzanie prądu (5.1), poczta (rozdz. 7); wymaga odpowiedzi na pytania 2, 4, 5, 11.
- Podsumowanie: wzorce przekrojowe (rozdz. 8).

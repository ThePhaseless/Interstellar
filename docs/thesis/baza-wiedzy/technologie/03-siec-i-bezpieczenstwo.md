# Sieć, wystawianie usług, uwierzytelnianie i bezpieczeństwo

Zakres: jak żądanie z internetu, z sieci domowej i z tailnetu trafia do aplikacji, kto je wpuszcza i co chroni klaster. Stan obecny odczytany z brancha `main` (2026-11-27). Okresy E1-E5 jak we wspólnym briefie.

Oznaczenia dowodów: [commit `hash`, data], [plik `ścieżka`] (stan na `main`), [PR #N], [wniosek], [źródło: URL, dostęp 2026-11-27], [nieznane].

---

## 1. Oś czasu w skrócie

| Data | Zdarzenie | Dowód |
| --- | --- | --- |
| 2024-01-01 | Pierwszy commit: osobna maszyna „proxy” z Traefikiem i Authelią (docker-compose), certyfikaty Let's Encrypt przez DNS-01 w Cloudflare, Tailscale instalowany skryptem | [commit `386f12a`, 2024-01-01] |
| 2024-01-02 | README: usługi „connected to an internal and external reverse proxy to bypass CGNAT”, wymagana „Machine with public IP address” | [commit `511a120`, 2024-01-02] |
| 2024-01-06 | DnsMasq zamiast systemd-resolved na hoście | [commit `c5cb2ca`, 2024-01-06], [commit `65c85aa`, 2024-01-06] |
| 2024-01-14/15 | Katalogi `DMZ/` i `VPS/`: tunel WireGuard VPS → DMZ, „every http and https request will be tunneled to DMZ” | [commit `1d51611`, 2024-01-14], [commit `2aefed4`, 2024-01-15] |
| 2024-07-14 | „setup repo”: usunięcie `DMZ/`, `VPS/`, `General/`, przejście na `compose.*.yaml` | [commit `6f7927b`, 2024-07-14] |
| 2024-07-16/18 | Authelia 4.38 z backendem LLDAP (pliki `.env.ldap` są już w `06b7e79`, 2024-02-26) i Postfixem; CrowdSec z wtyczką bouncera w Traefiku | [commit `931521d`, 2024-07-16], [commit `d7136fb`, 2024-07-16], [commit `ac3087c`, 2024-07-18] |
| 2025-02-12 | Authelia + LLDAP → Authentik (compose) | [commit `c8dccdd`, 2025-02-12] |
| 2025-03-13 | Do repo trafia konfiguracja HAProxy na VPS (TCP passthrough z PROXY protocol v2) | [commit `0fa08ec`, 2025-03-13] |
| 2025-08 → 2026-01 | Pierwszy Kubernetes (k3s): wbudowany Traefik (`HelmChartConfig`, `hostNetwork`), IngressRoute bez middleware uwierzytelniania | [plik `Kubernetes/infrastructure/traefik/config.yaml` w `6b94576`] |
| 2026-02-01 | Przebudowa (gałąź migracyjna; na `main` od 2026-02-26, `327eff3`): Traefik, MetalLB, Tailscale operator, CrowdSec, AdGuard w `Kubernetes/bootstrap` i `apps`; oauth2-proxy z Google OAuth | [commit `6757719`, 2026-02-01], [commit `fdd5bf3`, 2026-02-01] |
| 2026-02-18 | Certyfikat wildcard `*.nerine.dev` na entrypoincie; 2026-02-19 dodatkowo `certResolver` w każdej trasie | [commit `b85f139`, 2026-02-18], [commit `d42247e`, 2026-02-19] |
| 2026-02-19 | Split-horizon DNS w AdGuard | [commit `7866a37`, 2026-02-19] |
| 2026-02-20 | oauth2-proxy → Authentik w Kubernetes, konfiguracja w Terraformie | [commit `e2a3a1b`], [commit `bee6057`], [commit `84135e7`], [commit `0242d78`], wszystkie 2026-02-20 |
| 2026-02-24 | Nadpisanie CoreDNS (hairpin NAT); Postfix jako relay do OCI Email Delivery | [commit `197d3cf`, 2026-02-24], [commit `16fdd8f`, 2026-02-24], [commit `2b33dec`, 2026-02-24] |
| 2026-03-23 | Włączenie przekazywania pakietów dla exit node Tailscale na Proxmoxie (od kiedy carbon jest exit node: [nieznane]) | [commit `55e61c1`, 2026-03-23] |
| 2026-05-14 | Nadpisanie CoreDNS usunięte, zamiast niego `hostAliases` w Jellyfinie | [commit `e42d919`, 2026-05-14], [commit `7876eb3`, 2026-05-14] |
| 2026-07-24 | CrowdSec przeniesiony na chart Helm; wcześniej w k8s nie analizował żadnych logów | [commit `b0099ce`, 2026-07-24] |
| 2026-07-27 | CrowdSec AppSec (WAF) | [commit `38dcd4e`, 2026-07-27] |
| 2026-08-19/20 | Egzekwowanie NetworkPolicy, default-deny ingress w `media`, `utilities`, `home` (`printing` doszło 2026-11-25, [commit `e3857f4`]), uproszczenie ACL Tailscale | [PR #563], [commit `930e1e8`, 2026-08-19] |
| 2026-08-20 | Wyłączenie HAProxy i VM proxy w Oracle (błędna diagnoza, że Orange blokuje 80/443) | [commit `7158f21`, 2026-08-20], [PR #567] |
| 2026-08-21 | Korekta diagnozy; publiczne rekordy A + `cloudflare-ddns`; usunięcie `private-chain`, wszystko za Authentikiem | [commit `ca9a652`], [commit `5d7f26e`], [commit `cf4cbd6`], wszystkie 2026-08-21 |
| 2026-09-03 | Traefik zdjęty z tailnetu (proxy L3 operatora było wąskim gardłem) | [commit `905ab74`, 2026-09-03], [commit `72459bb`, 2026-09-03] |
| 2026-10-05/06 | Whitelist domowego IP w CrowdSec, panel banów; HTTP/3 wyłączone | [commit `efac355`, 2026-10-05], [commit `6deeeaf`, 2026-10-06] |

---

## 2. Traefik (reverse proxy, ingress)

**Rola.** Jedyny punkt wejścia HTTP(S): terminacja TLS, routing po nazwie hosta, łańcuchy middleware (nagłówki bezpieczeństwa, bouncer CrowdSec, forward-auth Authentika). Aplikacje mówią wewnątrz klastra zwykłym HTTP [plik `CLAUDE.md`, Key Gotchas „TLS terminates at Traefik”].

**Od kiedy.** Od pierwszego commita, czyli od 2024-01-01 [commit `386f12a`, 2024-01-01], więc był też przed repozytorium [wniosek]. Kolejne wcielenia:
- E1-E2: kontener docker-compose, routing przez etykiety Dockera, certyfikat przez DNS-01 w Cloudflare [commit `386f12a`]; od 2024 wildcard i `HostRegexp` [commit `a1042ba`, 2024-01-02].
- E3: Traefik wbudowany w k3s, skonfigurowany przez `HelmChartConfig` z `hostNetwork: true`, bez Service; zaufanie do PROXY protocol z `100.0.0.0/8` (tailnet) [plik `Kubernetes/infrastructure/traefik/config.yaml` w `6b94576`].
- E4: własny Deployment w `Kubernetes/bootstrap/traefik` [commit `6757719`, 2026-02-01], od 2026-02-25 chart Helm [commit `edebb5c`, 2026-02-25].
- E5: chart 42.4.0, Service `LoadBalancer` na `192.168.1.11` z `externalTrafficPolicy: Local`, TLSOption tylko z szyframi AEAD i `sniStrict` [plik `Kubernetes/bootstrap/traefik/kustomization.yaml`], [plik `Kubernetes/bootstrap/traefik/tls-options.yaml`], [commit `46ae919`, 2026-07-24].

**Konwencja.** Wyłącznie CRD `IngressRoute` (`traefik.io/v1alpha1`), nigdy standardowe `Ingress` [plik `CLAUDE.md`, Conventions]. Już w E3 trasy były IngressRoute [plik `Kubernetes/media/jellyfin/ingress.yaml` w `6b94576`].

**Co zastąpił.** Nic: Traefik jest od początku. Motyw pierwotnego wyboru nie jest zapisany [nieznane]. [wniosek] Za Traefikiem w compose przemawiało automatyczne wykrywanie kontenerów po etykietach (`providers.docker`), z którego repo korzystało od początku; w k3s był domyślnym ingressem, więc przejście do Kubernetesa nie wymagało zmiany narzędzia.

**Ograniczenia napotkane w repo.**
- HTTP/3 (QUIC) wyłączone: wysyłanie przez QUIC z domowego Wi-Fi osiągało 69-76 Mbit/s wobec 181 Mbit/s po HTTP/2, a Traefik zużywał ok. 15 razy więcej CPU na bajt [commit `6deeeaf`, 2026-10-06], [PR #681].
- Zaufanie do PROXY protocol z tailnetu i LAN pozwalało podrobić IP klienta przed CrowdSec, więc zdjęto je razem z HAProxy [commit `7158f21`, 2026-08-20].
- Trasa bez backendu (przekierowanie apeksu) i tak wymaga `services`; użyto `noop@internal` [plik `Kubernetes/bootstrap/authentik/ingress.yaml`].
- Rate limiting w samym Traefiku dodano i usunięto tego samego dnia, ograniczanie ruchu przejął CrowdSec [commit `4a66842`, 2026-03-10], [commit `0429288`, 2026-03-10], [plik `Kubernetes/bootstrap/traefik/middlewares.yaml`, komentarz „Rate limiting comes from the CrowdSec bouncer”].

**Alternatywy.**

Wszystkie wiersze: [źródło: podane URL, dostęp 2026-11-27].

| Narzędzie | Licencja | Stan utrzymania | Ograniczenia, cechy | Źródło |
| --- | --- | --- | --- | --- |
| Traefik Proxy (wybrany) | MIT; WAF, OIDC/JWT, OPA i rozproszony rate limit tylko w płatnym Traefik Hub | v3.8.0, 2026-11-23 | dostawcy K8s: Gateway API, IngressRoute, Ingress; wbudowany ACME nie obsługuje wielu instancji z Let's Encrypt (HA przez Enterprise albo cert-manager) | https://github.com/traefik/traefik, https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/acme/ |
| ingress-nginx | Apache-2.0 | wycofany: ogłoszenie 2025-11-11, utrzymanie best-effort do marca 2026, repo zarchiwizowane, ostatnie wydanie v1.15.1 (2026-03-19) | brak dalszych poprawek bezpieczeństwa; zalecana migracja na Gateway API | https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/ |
| Caddy | Apache-2.0 | v2.11.9, 2026-11-05 | kontroler Ingress (`caddyserver/ingress`) oznaczony jako WIP, ostatnie wydanie z 2023-11-20 | https://github.com/caddyserver/caddy, https://github.com/caddyserver/ingress |
| HAProxy / HAProxy Kubernetes Ingress | HAProxy: GPLv2 z wyjątkiem OpenSSL; kontroler: Apache-2.0 | 3.4 LTS (2026-06-03, EOL 2031-Q2); kontroler v3.4.1, 2026-11-19 | w tym repo używany jako L4 passthrough na VPS (sekcja 4); ograniczenia kontrolera: niezweryfikowane | https://www.haproxy.org/, https://github.com/haproxytech/kubernetes-ingress |
| Gateway API | Apache-2.0 | GA od v1.0 (2023-10-31), v1.7.0 z 2026-10-29 | API `Ingress` jest zamrożone (GA, bez rozwoju), Kubernetes zaleca Gateway | https://kubernetes.io/blog/2023/10/31/gateway-api-ga/, https://kubernetes.io/docs/concepts/services-networking/ingress/ |

[wniosek] Wycofanie ingress-nginx wzmacnia wybór Traefika, ale IngressRoute to CRD jednego dostawcy; Traefik obsługuje też Gateway API, więc migracja byłaby możliwa bez zmiany kontrolera.

**Kiedy wybrać coś innego** [wniosek]: Gateway API, jeśli konfiguracja ma być przenośna między kontrolerami, bo IngressRoute wiąże manifesty z Traefikiem, a Kubernetes zamroził API `Ingress` i zaleca Gateway (tabela). Caddy jako kontroler ingress odpada przy stanie WIP i wydaniu z 2023 roku. HAProxy pasował do roli, którą pełnił tu na VPS: prosty forwarder TCP z PROXY protocol. Szersze porównanie wydajności i funkcji: niezweryfikowane.

---

## 3. Certyfikaty: Let's Encrypt przez DNS-01 w Cloudflare

**Rola.** Jeden certyfikat wildcard `nerine.dev` + `*.nerine.dev` na entrypoincie `websecure`; Traefik rozwiązuje wyzwanie DNS-01 tokenem API Cloudflare [plik `Kubernetes/bootstrap/traefik/kustomization.yaml`]. Rekord CAA zezwala tylko na `letsencrypt.org` [plik `Terraform/cloudflare.tf`].

**Od kiedy.** DNS-01 przez Cloudflare od pierwszego commita [commit `386f12a`, 2024-01-01]. W E1 certyfikat z maszyny proxy był kopiowany na hosta skryptem `upload_acme.sh` z crona, co 30 dni [plik `proxy/upload_acme.sh` w `386f12a`]. W k8s najpierw jeden wildcard na entrypoincie, a trasy dostały `tls: {}` [commit `b85f139`, 2026-02-18]; dzień później wszystkie IngressRoute dostały z powrotem `certResolver: letsencrypt` z tymi samymi domenami [commit `d42247e`, 2026-02-19] i tak jest do dziś [plik `Kubernetes/apps/sonarr/ingress.yaml`]. Powód tego kroku: [nieznane].

DNS-01 jest tu konieczny, bo certyfikat jest wildcardem, a Let's Encrypt wydaje wildcard tylko przez DNS-01 [źródło: https://letsencrypt.org/docs/faq/, dostęp 2026-11-27]. [wniosek] Przy okazji DNS-01 nie zależy od tego, którą drogą (VPS czy bezpośrednio) ruch z internetu dociera do Traefika, więc zmiany w sekcji 4 nie dotykały odnawiania certyfikatów.

---

## 4. Droga z internetu do domu: WireGuard/VPS → HAProxy na Oracle → bezpośrednie wystawienie

Ruch publiczny szedł do domu przez VPS w 2024 (WireGuard) i od 2025-03 do sierpnia 2026 (HAProxy); co działo się pomiędzy, repo nie pokazuje (4.1). HAProxy nie musiał jednak działać bez przerwy: od 2025-08-31 do scalenia gałęzi migracyjnej (2026-02-26) security list OCI w Terraformie ma port 443 zakomentowany [commit `2ef3d50`, 2025-08-31], [plik `Terraform/variables.tf` w `f50bd66`], więc w tym oknie WWW było najpewniej dostępne tylko przez Tailscale i LAN [wniosek] (zob. `historia/03-iac-i-pierwszy-kubernetes.md`). Pierwsza próba wystawienia bezpośredniego (2026-08-20) skończyła się błędną diagnozą, że operator blokuje porty, a dzień później okazało się, że wystarczyło poprawić router.

### 4.1 E1: tunel WireGuard VPS → DMZ (2024-01 → 2024-07)
- README z 2024-01-02: celem jest „bypass CGNAT”, wymagana maszyna z publicznym IP [commit `511a120`, 2024-01-02].
- Skrypty `VPS/setup_wireguard.sh` i `DMZ/setup_wireguard.sh` zestawiały tunel WireGuard i reguły iptables; komunikat końcowy: „every http and https request will be tunneled to DMZ” [commit `2aefed4`, 2024-01-15], [plik `VPS/install.sh` w `06b7e79`].
- Usunięte 2024-07-14 [commit `6f7927b`, 2024-07-14]. Co je zastąpiło w okresie 2024-07 → 2025-03, repo nie pokazuje wprost. W compose Traefik ufał PROXY protocol z `100.0.0.0/8` (adresy Tailscale) [plik `docker-compose.auth.yaml` w `c8dccdd^`], więc [wniosek] już wtedy jakiś pośrednik w tailnecie przekazywał ruch z PROXY protocol, prawdopodobnie HAProxy na VPS przed jego dodaniem do repo.

### 4.2 E2-E5: HAProxy na VPS Oracle (w repo 2025-03-13 → 2026-08-20)
- Konfiguracja: `mode tcp`, port 443 przekazywany bez terminacji TLS do domowego Traefika przez Tailscale, z `send-proxy-v2`, żeby Traefik i CrowdSec widziały prawdziwe IP klienta [plik `haproxy.cfg` w `0fa08ec`].
- Później szablon Ansible z wpisanym na sztywno IP Traefika w tailnecie, bo VPS działa z `--accept-dns=false` i nie rozwiąże MagicDNS [plik `haproxy.cfg.j2` w `7158f21^`], [commit `00abc56`, 2026-08-09], [commit `46ae919`, 2026-07-24].
- Krótkotrwale publiczne DNS miało podwójne rekordy A (Tailscale + VPS) [commit `59015bc`, 2026-02-01] (gałąź migracyjna; na `main` od 2026-02-26, `327eff3`), potem tylko VPS [commit `bf8056e`, 2026-03-09].

### 4.3 Wyłączenie i odwrócenie diagnozy (2026-08-20/21)
1. 2026-08-20: PR #567 usuwa VM proxy, HAProxy i rekordy A z uzasadnieniem „Orange refuses inbound TCP 80/443 on this residential line, so the homelab cannot be exposed directly”; dostęp publiczny zostaje porzucony na rzecz Tailscale + LAN [commit `7158f21`, 2026-08-20].
2. 2026-08-21: „Inbound 80/443 were never blocked upstream; the port-forward on the router was wrong” [commit `ca9a652`, 2026-08-21]. Sprawdzono z VPS spoza sieci Orange: `:80` zwraca 301 Traefika, `:443` ważny certyfikat [plik `CLAUDE.md`, Key Gotchas „Orange … does not block”].
3. Tego samego dnia publiczne rekordy A `nerine.dev` i `*.nerine.dev` plus `cloudflare-ddns` [commit `5d7f26e`, 2026-08-21].

Lekcja zapisana w repo: brak pakietów w `tcpdump` na `vmbr0` świadczył o tym, że router nie przekazywał ruchu, a nie o filtrze u operatora; `Connection refused` w jednym RTT nie odróżnia filtra operatora od RST routera (trzeba porównać TTL) [plik `CLAUDE.md`, Key Gotchas].

**Co zyskano** [wniosek, z dowodami w commitach]: o jedną VM mniej, koniec z zależnością od IP Traefika w tailnecie, brak PROXY protocol (czyli brak możliwości podrobienia IP), cały przydział Oracle Free Tier dla VM `compute` [commit `7158f21`, 2026-08-20].

**Otwarta sprzeczność.** W 2024 README mówi o CGNAT, w 2026 okazuje się, że łącze ma publiczne IP i porty są otwarte. Czy w 2024 był inny operator lub naprawdę CGNAT, repo nie mówi [nieznane] → pytanie do autora.

Alternatywy dla wystawiania (Cloudflare Tunnel, VPS z WireGuardem) są w tabeli w sekcji 7.

---

## 5. DNS: Cloudflare, cloudflare-ddns, AdGuard Home, CoreDNS, DnsMasq

### 5.1 Cloudflare (DNS publiczne)
- Strefa `nerine.dev` w Cloudflare, rekordy w Terraformie [plik `Terraform/cloudflare.tf`]. Rekordy A apeksu i wildcard mają `proxied = false` i `lifecycle { ignore_changes = [content] }`: Terraform tylko je zakłada, wartość utrzymuje `cloudflare-ddns`, bo IP domowe jest dynamiczne [plik `Terraform/cloudflare.tf`], [commit `5d7f26e`, 2026-08-21].
- `proxied = false` z powodu: „the Cloudflare proxy would replace the client IP that CrowdSec and the private-chain allowlists match on” [commit `5d7f26e`, 2026-08-21]. Skutek uboczny [wniosek]: nie da się użyć Cloudflare WAF ani ukryć domowego IP.
- Cloudflare dostarcza też DNS-01 (sekcja 3) i rekordy SPF/DKIM poczty (sekcja 11).
- `cloudflare-ddns` (obraz `favonia/cloudflare-ddns`) jako Deployment w `utilities`, tylko IPv4 (`IP6_PROVIDER=none`) [plik `Kubernetes/apps/cloudflare-ddns/deployment.yaml`].

### 5.2 AdGuard Home (DNS w LAN i tailnecie, split-horizon)
- **Rola.** Filtrujący resolver (listy blokujące, upstream DoH do 1.1.1.1/1.0.0.1). Serwer DHCP AdGuarda jest opisany w konfiguracji, ale wyłączony (`enabled = false`); adresy rozdaje router [plik `Terraform/apps/adguard.tf`], [plik `CLAUDE.md`, Key Gotchas o puli DHCP]. Jedyny resolver tailnetu (`override_local_dns = true`) [plik `Terraform/tailscale.tf`]. Wystawiony w tailnecie przez Service `loadBalancerClass: tailscale` [plik `Kubernetes/apps/adguard/service-tailscale.yaml`].
- **Od kiedy.** Usługa w compose od 2024-01-15 [commit `ba47ea5`, 2024-01-15], plik konfiguracji w repo od 2024-02-21 [commit `775a8a8`, 2024-02-21]; w Kubernetesie (pierwszy klaster k3s) od 2025-08-11 [commit `abcb648`, 2025-08-11], w obecnym klastrze od 2026-02-01 [commit `6757719`, 2026-02-01] (na `main` od 2026-02-26); konfiguracja przeniesiona do Terraformu (provider `gmichels/adguard`) [commit `81c3675`, 2026-02-25].
- **Split-horizon.** Reguły `$dnsrewrite` kierują `nerine.dev` i `*.nerine.dev` na `192.168.1.11` (MetalLB) tylko dla `client=192.168.0.0/16`; reszta dostaje publiczny rekord A [plik `Terraform/apps/adguard.tf`]. Pierwsza wersja (2026-02-19) dawała klientom tailnetu adres Traefika w Tailscale [commit `7866a37`, 2026-02-19]; te przepisania usunięto, gdy Traefik zszedł z tailnetu [commit `72459bb`, 2026-09-03].
- **Bez własnego logowania.** Panel AdGuard nie ma użytkownika; dostępu pilnuje Authentik i NetworkPolicy wpuszczająca tylko Traefika na port 3000 [commit `4a956f1`, 2026-08-22]. Wcześniej w repo był literał `admin:admin123` i middleware wstrzykujący go na publicznej trasie, usunięte w [commit `c3bd45f`, 2026-08-13].

### 5.3 CoreDNS i split-horizon w podach
- Pody nie korzystają z AdGuard, więc `*.nerine.dev` rozwiązują publicznie i zależą od hairpin NAT routera [plik `CLAUDE.md`, Key Gotchas].
- 2026-02-24 dodano nadpisanie CoreDNS (`hosts { 192.168.1.11 auth.nerine.dev }`) [commit `197d3cf`, 2026-02-24].
- 2026-05-14 je usunięto i zastąpiono `hostAliases` tylko w podzie Jellyfina [commit `e42d919`, 2026-05-14], [plik `Kubernetes/apps/jellyfin/deployment.yaml`]. Katalog `coredns-override` został, ale zawiera standardowy Corefile, tylko po to, żeby ArgoCD nie usunął ConfigMapy `kube-system/coredns` [commit `7876eb3`, 2026-05-14], [plik `Kubernetes/bootstrap/coredns-override/kustomization.yaml`].
- Zasada w repo: dla pojedynczego workloadu `hostAliases` zamiast zmiany DNS w całym klastrze [plik `CLAUDE.md`, Key Gotchas].

### 5.4 DnsMasq (E1)
Na hoście w styczniu 2024 wyłączono systemd-resolved i zainstalowano DnsMasq jako lokalny resolver [commit `c5cb2ca`, 2024-01-06], [commit `65c85aa`, 2024-01-06]. Skrypty zniknęły w porządkach 2024-01-13 [commit `3dc86c2`, 2024-01-13]. Funkcję resolvera w sieci przejął AdGuard, w compose od 2024-01-15 [commit `ba47ea5`, 2024-01-15] [wniosek].

**Alternatywy dla AdGuard Home.**

Wszystkie wiersze: [źródło: podane URL, dostęp 2026-11-27].

| Narzędzie | Licencja | Stan utrzymania | Cechy | Źródło |
| --- | --- | --- | --- | --- |
| AdGuard Home (wybrany) | GPL-3.0 | v1.0.0, 2026-11-19 | DNS sinkhole, DHCP, upstream DoH/DoT/DNSCrypt, ustawienia per klient (na tym opiera się split-horizon `client=`) | https://github.com/AdguardTeam/AdGuardHome |
| Pi-hole | EUPL-1.2 | v6.6, 2026-11-11 | panel WWW, opcjonalny DHCP, FTLDNS z API | https://github.com/pi-hole/pi-hole |
| Technitium DNS Server | GPL-3.0 | v15.6.2, 2026-10-17 | serwer autorytatywny i rekursywny, DoT/DoH/DoQ, DNSSEC, wbudowany clustering | https://github.com/TechnitiumSoftware/DnsServer |
| Unbound | BSD-3-Clause | 1.26.2, 2026-10-21 | walidujący rekursywny resolver; brak panelu i list blokujących [wniosek] | https://github.com/NLnetLabs/unbound |

**Kiedy wybrać coś innego** [wniosek]: Technitium, gdy potrzebna jest własna strefa autorytatywna albo wbudowany clustering resolverów (tabela); Unbound, gdy upstream ma być własną rekursją zamiast DoH do Cloudflare. Motyw wyboru AdGuarda zamiast Pi-hole repo nie podaje [nieznane].

---

## 6. MetalLB (adresy LoadBalancer w sieci domowej)

- **Rola.** Daje Service `LoadBalancer` adresy z puli `192.168.1.11-192.168.1.20` w trybie L2 (ARP) [plik `Kubernetes/bootstrap/metallb/ipaddresspool.yaml`], [plik `Kubernetes/bootstrap/metallb/l2advertisement.yaml`]. Traefik ma stały `192.168.1.11`, na który wskazuje przekierowanie portów routera i split-horizon [plik `CLAUDE.md`, Key Gotchas].
- **Od kiedy.** 2026-02-01 [commit `6757719`, 2026-02-01] (na `main` od 2026-02-26). Wcześniej (k3s) Traefik siedział na `hostNetwork` bez Service [plik `Kubernetes/infrastructure/traefik/config.yaml` w `6b94576`]. Wszystkie trzy węzły są control-plane, więc potrzebne było `ignoreExcludeLB` [commit `9b810a8`, 2026-02-25].
- **Ograniczenia napotkane.** Tryb L2 opiera się na ARP i dzieli podsieć z urządzeniami domowymi. Incydent z ARP dotyczył adresu węzła, nie puli MetalLB: router Mercusys miał pulę DHCP na całą podsieć i wydał `.112` (statyczny adres talos-3) dekoderowi TV. Pula DHCP jest teraz `192.168.1.180-253`, więc nie obejmuje też puli MetalLB `.11-.20`, a nowe adresy statyczne muszą być poniżej `.180` [plik `CLAUDE.md`, Key Gotchas „The router's DHCP pool spanned the whole subnet”].
- `externalTrafficPolicy: Local` zachowuje IP klienta dla CrowdSec [plik `Kubernetes/bootstrap/traefik/kustomization.yaml`], [plik `CLAUDE.md`, Key Gotchas o Tailscale DNAT].

**Alternatywy.**

Wszystkie wiersze: [źródło: podane URL, dostęp 2026-11-27].

| Narzędzie | Licencja | Stan utrzymania | Ograniczenia | Źródło |
| --- | --- | --- | --- | --- |
| MetalLB (wybrany) | Apache-2.0 | v0.16.2, 2026-11-04 | L2: cały ruch danego IP obsługuje jeden węzeł (dokumentacja nazywa to podstawowym ograniczeniem ARP/NDP); failover kilka sekund przy gratuitous ARP | https://metallb.io/concepts/layer2/ |
| kube-vip | Apache-2.0 | v1.3.2, 2026-11-20 | VIP dla control plane i Service LoadBalancer, ARP lub BGP; bez gratuitous ARP stare wpisy wygasają zwykle do 30 s | https://kube-vip.io/docs/about/architecture/ |
| Cilium LB IPAM + L2 Announcements | Apache-2.0 | v1.20.5, 2026-11-17 | L2 Announcements w becie; failover 10-20 s domyślnie; elekcja lidera obciąża API server | https://docs.cilium.io/en/stable/network/l2-announcements/ |

**Kiedy wybrać coś innego** [wniosek]: kube-vip, gdy jednym narzędziem chce się dać też wirtualny IP dla API Kubernetesa (tabela; tu przez dwa dni istniał katalog `kube-api-lb`, 2026-02-16 → 2026-02-18, wg szkieletu osi czasu); Cilium LB IPAM, gdy klaster i tak działa na Cilium. Repo nie konfiguruje BGP na routerze domowym, więc zostaje tryb L2/ARP.

---

## 7. Tailscale (dostęp administracyjny, DNS, CI)

**Rola dziś.** Administracja i DNS; aplikacje webowe idą drogą publiczną (sekcja 12):
- `kubectl` przez API-proxy operatora z podszyciem pod `system:masters` dla właściciela tailnetu (grant `tailscale.com/cap/kubernetes`) [plik `Tailscale/policy.hujson`], [plik `Kubernetes/bootstrap/tailscale-operator/kustomization.yaml`];
- CI (`tag:ci`) dostaje tylko porty 22/8006 Proxmoxa i 6443/50000 węzłów [plik `Tailscale/policy.hujson`];
- Tailscale SSH na urządzenia infrastruktury; SFTP-only dla użytkownika `clips` na `tag:files` [plik `Tailscale/policy.hujson`], [commit `a8e3b26`, 2026-11-17], [commit `cf24c25`, 2026-11-17];
- AdGuard jako DNS tailnetu (sekcja 5.2);
- exit node na Proxmoxie; przekazywanie pakietów (`ip_forward`) włączone w Ansible [commit `55e61c1`, 2026-03-23], [plik `Ansible/setup-proxmox.yaml`];
- gościnny dostęp (`autogroup:shared`) tylko do serwera Minecraft i DNS [plik `Tailscale/policy.hujson`].

**Historia.**
- Skrypt instalacyjny w pierwszym commicie [commit `386f12a`, 2024-01-01], Tailscale SSH od 2024-07 [commit `5ebf412`, 2024-07-14].
- E3: Ansible i k3s komunikowały się po IP Tailscale [commit `70b47e0`, 2025-08-03], [commit `01a7a88`, 2025-08-04].
- E4: operator w klastrze [commit `6757719`, 2026-02-01], OAuth clients, klucze i ACL zarządzane Terraformem [commit `2486270`, 2026-02-18], [commit `7ca938d`, 2026-02-26], dynamiczne inventory Ansible z `tailscale status` [commit `ecfff6f`, 2026-02-19].
- E5: ACL zredukowane do `autogroup:owner`, `autogroup:shared` i tagów, bo nazwane grupy były puste, a `group:vips` dawało pełny dostęp i root SSH pod tą samą nazwą co grupa w Authentiku [commit `527da49`, 2026-08-19], [PR #563].
- 2026-09-03: Traefik zdjęty z tailnetu. Proxy L3 operatora terminowało WireGuard w podzie w przestrzeni użytkownika i ograniczało pojedynczy strumień do ok. 57 MB/s wobec 276 MB/s bezpośrednio do IP MetalLB [commit `905ab74`, 2026-09-03].

**Ograniczenia napotkane w repo.**
- Usługi wystawione przez operatora (L3, DNAT) nie przekazują IP klienta, co psuje CrowdSec (tailscale/tailscale#11024) [plik `CLAUDE.md`, Key Gotchas].
- Dopisek `-1` do nazwy hosta po przebudowie węzła; skrypt `scripts/tailscale-release-hostname.sh` [plik `CLAUDE.md`, Key Gotchas], [commit `34d7f55`, 2026-08-20].
- Wartość Helm `operatorConfig.hostname`, nie `operator.hostname`; zły klucz przechodzi bez błędu [plik `CLAUDE.md`, Key Gotchas], [commit `15c1ae1`, 2026-08-20].
- Urządzenie osobiste (nieotagowane) potrzebuje osobnej reguły SSH i nie da się go zapisać kluczem z Terraformu [plik `CLAUDE.md`, Key Gotchas], [commit `4fe6631`, 2026-08-18].
- Wygasły klucz węzła carbon odciął NFS i exit node; wygasanie wyłączono przez `tailscale_device_key.infra` [commit `4fe6631`, 2026-08-18], [plik `Terraform/tailscale.tf`].
- VPS w Oracle potrzebował UDP 3478 (STUN), inaczej ruch szedł przez przekaźniki DERP [commit `0a9af08`, 2026-03-09].

**Dlaczego Tailscale, a nie goły WireGuard.** W E1 autor sam zestawiał WireGuard skryptami z ręczną wymianą kluczy i interaktywnymi `read -r -p` [plik `VPS/setup_wireguard.sh` w `06b7e79`], a Tailscale był instalowany równolegle. Motywu porzucenia własnego WireGuarda repo nie podaje [nieznane]. [wniosek] W obecnym układzie przesądzają: ACL, klucze i DNS jako kod w Terraformie, API-proxy do Kubernetesa i Tailscale SSH bez zarządzania kluczami.

**Alternatywy (dostęp zdalny i wystawianie).**

Wszystkie wiersze: [źródło: podane URL, dostęp 2026-11-27].

| Narzędzie | Licencja | Stan utrzymania | Ograniczenia, cechy | Źródło |
| --- | --- | --- | --- | --- |
| Tailscale (wybrany) | klient BSD-3-Clause; serwer koordynacyjny i GUI zamknięte | v1.104.7, 2026-11-12 | plan Personal: do 6 użytkowników, 50 zasobów z tagami (kolejne płatne), 3 grupy ACL, Tailscale SSH na 5 hostach, tylko użytek prywatny | https://tailscale.com/opensource, https://tailscale.com/pricing |
| WireGuard (używany w E1) | GPLv2 (moduł jądra, wireguard-tools) | wireguard-tools v1.0.20260223 | dystrybucja kluczy i konfiguracji poza zakresem: ręczna wymiana kluczy, statyczni peerzy | https://www.wireguard.com/ |
| Headscale | BSD-3-Clause | v0.29.8, 2026-11-26 | własny serwer koordynacyjny Tailscale, celowo jeden tailnet, projekt społecznościowy | https://headscale.net/stable/ |
| NetBird | BSD-3-Clause; serwer (management, signal, relay) AGPL-3.0 | v0.83.2, 2026-11-20 | self-hosting: VM 1 CPU/2 GB, publiczna domena, TCP 443 + UDP 3478; wbudowany IdP | https://docs.netbird.io/selfhosted/selfhosted-quickstart |
| ZeroTier | od 1.16.0 (2025-08-21) rdzeń MPL-2.0, kontroler sieci source-available tylko niekomercyjnie | 1.16.2, 2026-05-28 | plan darmowy: 10 urządzeń, 1 sieć, 1 admin | https://github.com/zerotier/ZeroTierOne/blob/dev/RELEASE-NOTES.md, https://www.zerotier.com/pricing/ |
| Cloudflare Tunnel (alternatywa dla VPS z HAProxy) | cloudflared Apache-2.0, usługa zamknięta | cloudflared 2026.11.2, 2026-11-23 | tylko połączenia wychodzące, bez publicznego IP; domena w Cloudflare; regulamin CDN: wideo i duże pliki wymagają płatnych usług; czy Tunnel jest darmowy: niezweryfikowane | https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/, https://www.cloudflare.com/service-specific-terms-application-services/ |

[wniosek] Limit 50 zasobów z tagami w darmowym planie ma tu znaczenie, bo infrastruktura jest otagowana (`tag:node`, `tag:proxmox`, `tag:service`, …) [plik `Tailscale/policy.hujson`]. Liczby urządzeń w tailnecie repo nie podaje [nieznane]. Zapis regulaminu Cloudflare o wideo jest istotny dla tego homelaba, bo publicznie wystawiony jest Jellyfin [plik `Kubernetes/apps/jellyfin/ingress.yaml`].

**Kiedy wybrać coś innego** [wniosek]: Headscale lub self-hosted NetBird, gdy serwer koordynacyjny nie może być cudzą usługą (Headscale obsługuje jeden tailnet); Cloudflare Tunnel, gdy łącze nie ma publicznego IP i nie ma się VPS, z zastrzeżeniem regulaminu dla wideo i z utratą IP klienta po stronie lokalnego CrowdSec; goły WireGuard dla stałego tunelu między dwoma znanymi hostami, jak w E1.

---

## 8. Authelia → oauth2-proxy → Authentik (uwierzytelnianie)

### 8.1 Authelia (E1-E2, 2024-01 → 2025-02)
- W pierwszym commicie: forward-auth dla dashboardu Traefika, użytkownicy w pliku YAML, powiadomienia SMTP przez Gmail [plik `proxy/docker-compose.yml` w `386f12a`].
- 2024-02 → 2024-07: Authelia z LLDAP (`DMZ/Docker/Compose/envs/.env.ldap` w [commit `06b7e79`, 2024-02-26]); w 2024-07 Authelia 4.38 z LLDAP, Postfixem i nagłówkami `Remote-User/Remote-Groups` [plik `docker-compose.auth.yaml` w `c8dccdd^`], [commit `931521d`, 2024-07-16], [commit `a64d88d`, 2024-07-16].

### 8.2 Authentik w compose (2025-02-12 → 2025-09-01)
- „refactor and migrate to authentik”, bez opisu [commit `c8dccdd`, 2025-02-12]. Authentik 2024.12 z Postgresem i Redisem, forward-auth przez wbudowany outpost [plik `compose.auth.yaml` w `c8dccdd`].
- README z tego commita: „Create LDAP outpost … configure LDAP Authentik with Jellyfin” [commit `c8dccdd`, 2025-02-12]. [wniosek] Ta instrukcja sugeruje, że integracja z Jellyfinem była częścią migracji, ale motywu zmiany IdP commit nie podaje → pytanie.
- Plik compose zniknął z końcem compose 2025-09-01. W k8s w E3 żadna IngressRoute nie miała middleware uwierzytelniania [plik `Kubernetes/` w `6b94576`, brak `middlewares`/`forwardAuth`] → pytanie, jak w tym okresie chroniono usługi.

### 8.3 oauth2-proxy (2026-02-01 → 2026-02-20)
- Wspólny oauth2-proxy z Google OAuth jako middleware [commit `fdd5bf3`, 2026-02-01], [commit `3ef219e`, 2026-02-01]. Po 19 dniach zastąpiony Authentikiem we wszystkich trasach [commit `84135e7`, 2026-02-20], usunięty [commit `0242d78`, 2026-02-20]. Powodu powrotu do Authentika commity nie podają [nieznane]. Ten sam dzień przyniósł w Terraformie providery OIDC dla Grafany i Immich oraz politykę dostępu VIP [commit `bee6057`, 2026-02-20]; czy to był powód, nie wiadomo.

### 8.4 Authentik w Kubernetes (od 2026-02-20)
- Chart Helm z Postgresem na Longhornie [commit `e2a3a1b`, 2026-02-20]; cała konfiguracja (źródła, przepływy, providery, aplikacje, polityki, powiadomienia) w Terraformie [plik `Terraform/apps/authentik.tf`].
- Logowanie wyłącznie przez Google (źródło OAuth `google`, przepływ `google-only-authentication`) [plik `Terraform/apps/authentik.tf`], [commit `2b33dec`, 2026-02-24]; etap identyfikacji ma puste `user_fields`, więc formularza loginu i hasła nie ma. Przywrócone 2026-08-11 logowanie hasłem dotyczy Jellyfina, nie Authentika [commit `0be1bd5`, 2026-08-11].
- Dwa sposoby ochrony aplikacji:
  - forward-auth (provider proxy): `private-proxy` w trybie `forward_domain` dla stosu *arr, narzędzi klastra i AdGuard, dostępny dla grup `vips` i `admins`; osobne `forward_single` dla `files`, `add`, `bans`, `print` [plik `Terraform/apps/authentik.tf`], [plik `Kubernetes/bootstrap/traefik/middlewares.yaml`];
  - natywne OIDC: Grafana, Immich, Jellyfin, ArgoCD [plik `Terraform/apps/authentik.tf`]. Jellyfin i Immich nie mają middleware `authentik`, tylko łańcuch CrowdSec [plik `Kubernetes/apps/jellyfin/ingress.yaml`], [plik `Kubernetes/apps/immich/ingress.yaml`].
- Grupy `admins`, `vips`, `watchers`, `writers`, `photos`; to, które kafelki widzi użytkownik, wynika wyłącznie z powiązań polityk [commit `e78ea0b`, 2026-02-25], [commit `12b2249`, 2026-08-19], [commit `3fce217`, 2026-08-21]. Apeks `nerine.dev` przekierowuje (302) do biblioteki aplikacji Authentika [commit `3fce217`, 2026-08-21].

**Ograniczenia i błędy znalezione w repo.**
- Dwa providery `forward_domain` z tym samym `external_host`: outpost ich nie rozróżniał i wygrywał `public-proxy`, więc każda usługa wpuszczała dowolne konto Google [commit `c3bd45f`, 2026-08-13]. Dlatego `public` musi zostać `forward_single` [plik `Terraform/apps/authentik.tf`, komentarz].
- copyparty ufał nagłówkom `X-authentik-groups` z dowolnego prywatnego adresu, więc każdy pod mógł podać się za admina; zamknięte NetworkPolicy i poprawką [PR #563], [commit `3cdfd9b`, 2026-08-20].
- Usługi z `AuthenticationMethod=External` (Sonarr/Radarr/Prowlarr) ufają proxy w całości, więc bez NetworkPolicy wystarczało zapytanie po ClusterIP [PR #563].
- Liveness probe zabijał zdrowy serwer, serwer zapętlał się na nieudanym zapytaniu do bazy [commit `e0f1e41`, 2026-09-21], [commit `3b9c9e3`, 2026-09-21].

**Alternatywy.**

Wszystkie wiersze: [źródło: podane URL, dostęp 2026-11-27].

| Narzędzie | Licencja | Stan utrzymania | Ograniczenia, cechy | Źródło |
| --- | --- | --- | --- | --- |
| Authentik (wybrany) | MIT poza katalogiem `authentik/enterprise/` (licencja EE, w produkcji wymaga subskrypcji) | 2026.8.7, 2026-11-25 | darmowo: OIDC, SAML, LDAP, SCIM, RADIUS, Proxy, RAC; tylko Enterprise: m.in. integracje Google Workspace i Entra ID, mTLS, device trust | https://github.com/goauthentik/authentik/blob/main/LICENSE, https://goauthentik.io/pricing/ |
| Authelia (używana 2024-2025) | Apache-2.0 | v4.39.28, 2026-09-17 | działa obok reverse proxy (ForwardAuth); użytkownicy w pliku YAML albo LDAP, bez UI do zarządzania; OIDC na roadmapie wciąż oznaczone jako beta | https://www.authelia.com/configuration/first-factor/introduction/ |
| Keycloak | Apache-2.0 | 26.8.2, 2026-11-05 | OIDC, OAuth 2.0, SAML, projekt CNCF; wymagania zasobowe: niezweryfikowane | https://www.keycloak.org/ |
| Zitadel | AGPL-3.0 od v3.0 (zmiana z Apache-2.0 ogłoszona 2025-03-13); API, SDK, chart i provider Terraform zostają na Apache-2.0 | v4.20.6, 2026-11-25 | płatne plany chmurowe, darmowa chmura do 100 DAU | https://zitadel.com/blog/apache-to-agpl |
| Pocket ID | BSD-2-Clause | v2.19.3, 2026-11-15 | tylko OIDC i tylko logowanie bez hasła (passkey); aplikacje bez OIDC wymagają osobnego auth proxy | https://pocket-id.org/docs/ |

[wniosek] W tym repo przydaje się to, czego Authelia i Pocket ID nie dają naraz: forward-auth (outpost proxy) i OIDC z jednego serwera, grupy i polityki per aplikacja, biblioteka aplikacji oraz provider Terraform (`goauthentik/authentik`) [plik `Terraform/apps/authentik.tf`]. Logowanie przez Google działa tu jako zwykłe źródło OAuth (`authentik_source_oauth.google`); czy pozycja cennika „Google Workspace” go dotyczy: niezweryfikowane.

**Kiedy wybrać coś innego** [wniosek, na podstawie tabeli]: Authelia, gdy wystarczy forward-auth i użytkownicy w pliku YAML albo LDAP; Pocket ID, gdy wszystkie aplikacje mówią OIDC, a logowanie ma być tylko passkeyem. Kiedy lepszy byłby Keycloak lub Zitadel: niezweryfikowane; przy Zitadel trzeba uwzględnić AGPL-3.0 od v3.

---

## 9. CrowdSec (wykrywanie i blokowanie, WAF)

- **Rola.** Agent (DaemonSet) czyta logi kontenerów Traefika i Jellyfina z `/var/log/containers`, LAPI podejmuje decyzje, wtyczka bouncera w Traefiku blokuje adresy w trybie `stream`, AppSec (WAF) dostaje treść żądań do inspekcji [plik `Kubernetes/bootstrap/crowdsec/values.yaml`], [plik `Kubernetes/bootstrap/traefik/crowdsec-middleware.yaml`]. Kolekcje: `traefik`, `http-cve`, `linux`, `LePresidente/jellyfin`, `http-dos`, `appsec-virtual-patching`, `appsec-generic-rules` [plik `Kubernetes/bootstrap/crowdsec/values.yaml`].
- **Od kiedy.** Compose od 2024-07-18 [commit `ac3087c`, 2024-07-18]; w k8s od 2026-02-01 [commit `6757719`, 2026-02-01], ale do 2026-07-24 „blind — 0 alerts, 0 decisions, no log ingestion”, bo `DISABLE_AGENT=true` pomijało instalację kolekcji [commit `b0099ce`, 2026-07-24]. Wtyczkę `maxlerebourg/crowdsec-bouncer-traefik-plugin` zadeklarowano w Traefiku już 2026-02-01, a dokument migracji podaje powody: stary bouncer „unmaintained”, oszczędność ok. 200 MB [commit `6757719`, 2026-02-01], [plik `.github/MIGRATION-CROWDSEC.md` w `6757719`]. Middleware nadal wskazywał jednak bouncer przez ForwardAuth, który nie działał; przełączono go na wtyczkę 2026-02-19 [commit `37f4e5e`, 2026-02-19]. AppSec od [commit `38dcd4e`, 2026-07-27].
- **Ograniczenia napotkane w repo** (wszystkie w [plik `CLAUDE.md`] lub [plik `Kubernetes/AGENTS.md`], Key Gotchas):
  - chart losuje `crowdsec-lapi-secrets` przy każdym renderze, więc ArgoCD nigdy nie jest w synchronizacji; sekret z Bitwardena przez ExternalSecret [commit `62687ef`, 2026-08-08];
  - chart nie ustawia `metadata.namespace` [commit `2f331b6`, 2026-07-24]; przestrzeń nazw wymaga `privileged` przez hostPath [commit `5bdb861`, 2026-07-26]; klucz bouncera musi się nazywać `BOUNCER_KEY_traefik` [commit `8144b27`, 2026-07-26];
  - whitelist `ip:` nie przyjmuje CIDR [commit `8347e9c`, 2026-07-27];
  - ban domowego IP: urządzenie w LAN, które rozwiązało publiczny rekord, wraca przez hairpin NAT jako domowe IP; jedno ładowanie strony Jellyfina wyzwoliło scenariusz i zablokowało cały dom. Whitelist przez `LookupHost("nerine.dev")` [commit `efac355`, 2026-10-05];
  - scenariusz `http-dos-random-uri` banuje zwykłych użytkowników Jellyfina (numeryczne ID wyglądają jak losowe URI) [commit `a442e19`, 2026-10-06];
  - OOM AppSec przy równoległych uploadach zamienia się w 403 dla wszystkich z zewnątrz [commit `e55dcab`, 2026-10-07], [PR #682];
  - pody po restarcie węzła nie mogły się ponownie zarejestrować [commit `ffcbdac`, 2026-11-02], [PR #752].
- **Zaufane sieci.** `clientTrustedIPs` (LAN `192.168.1.0/24` i pody `10.244.0.0/16`) omijają wszystkie sprawdzenia, łącznie z WAF [plik `Kubernetes/bootstrap/traefik/crowdsec-middleware.yaml`, komentarz].

**Alternatywy.**

Wszystkie wiersze: [źródło: podane URL, dostęp 2026-11-27].

| Narzędzie | Licencja | Stan utrzymania | Ograniczenia, cechy | Źródło |
| --- | --- | --- | --- | --- |
| CrowdSec (wybrany) | MIT (silnik) | v1.8.2, 2026-10-26 | plan Community: łącznie 3 blocklisty; pełna Community Blocklist tylko dla silników, które regularnie wysyłają sygnały z niezmodyfikowanych scenariuszy, pozostali dostają wersję Lite (do 3 tys. IP) | https://docs.crowdsec.net/docs/central_api/community_blocklist/, https://www.crowdsec.net/pricing |
| fail2ban | GPLv2 | 1.1.1, 2026-08-15 | skanuje logi i blokuje IP firewallem hosta; działa per host, bez wspólnej reputacji | https://github.com/fail2ban/fail2ban |
| Cloudflare WAF (Free) | usługa zamknięta | brak danych | tylko Free Managed Ruleset, 1 reguła rate limiting; rekordy DNS-only nie są chronione i ujawniają IP originu, więc WAF wymaga rekordów proxied | https://developers.cloudflare.com/waf/, https://developers.cloudflare.com/dns/proxy-status/ |

[wniosek] Repo dodaje własne whitelisty (domowe IP, Jellyfin Enhanced). Czy silnik dostaje pełną czy okrojoną (Lite) Community Blocklist, repo nie pokazuje [nieznane].

**Kiedy wybrać coś innego** [wniosek, na podstawie tabeli]: fail2ban, gdy chroni się pojedynczy host (działa per host, bez wspólnej reputacji); Cloudflare WAF, gdy można przełączyć rekordy na proxied (tu wykluczone przez `proxied = false`, sekcja 5.1).

---

## 10. NetworkPolicy (segmentacja wewnątrz klastra)

- **Rola.** Default-deny dla ruchu przychodzącego w przestrzeniach nazw `media`, `utilities`, `home`, `printing` plus reguły „allow-traefik” i wyjątki dla konkretnych par usług [plik `Kubernetes/apps/networkpolicies/kustomization.yaml`], [plik `Kubernetes/apps/networkpolicies/media.yaml`]. Polityk egress w tych plikach nie ma (brak `egress` w `Kubernetes/apps/networkpolicies`). Inne przestrzenie nazw mają tylko polityki z chartów (ArgoCD, Authentik, Longhorn) i pojedyncze polityki aplikacji, np. panelu CrowdSec [PR #563], [plik `Kubernetes/bootstrap/crowdsec/web-ui/networkpolicy.yaml`].
- **Od kiedy.** `media` 2026-08-19 [commit `a7d5281`], `utilities` i `home` 2026-08-20 [commit `d390292`], `printing` 2026-11-25 [commit `e3857f4`]. Wcześniej Flannel w Talosie ignorował NetworkPolicy, więc 13 polityk z chartów nic nie robiło; włączenie `kubeNetworkPoliciesEnabled` wdraża `kube-network-policies` obok Flannela, potwierdzone testem A/B [commit `930e1e8`, 2026-08-19], [PR #563].
- **Dlaczego.** Przegląd bezpieczeństwa znalazł ścieżki ruchu bocznego: qBittorrent z `AuthSubnetWhitelist=0.0.0.0/0`, *arr z uwierzytelnianiem `External`, copyparty ufający nagłówkom; reguły „allow” wyprowadzono z obserwowanego ruchu, nie z manifestów [PR #563].
- **Ograniczenie.** `kube-network-policies` loguje dwie linie na pakiet przy `--v=2` (ok. 8,4 GiB dziennie, 97% danych w Loki) [plik `Kubernetes/AGENTS.md`, Key Gotchas].
- CNI z własnym egzekwowaniem NetworkPolicy zamiast Flannela z dodatkiem: nie rozważane w repo; Talos dostarcza Flannela [commit `930e1e8`, 2026-08-19] → pytanie do autora.

---

## 11. Poczta wychodząca: Postfix i OCI Email Delivery

- **Rola.** Postfix (`boky/postfix`) w klastrze jako relay SMTP dla Authentika, Grafany, Immich i *arr; wysyła przez OCI Email Delivery [commit `16fdd8f`, 2026-02-24], [commit `2b33dec`, 2026-02-24]. Domena, DKIM, nadawca i poświadczenia SMTP w Terraformie, rekordy DKIM (CNAME) i SPF w Cloudflare [plik `Terraform/email.tf`]. Dostęp do Postfixa tylko z wybranych przestrzeni nazw [plik `Kubernetes/apps/networkpolicies/utilities.yaml`, `allow-postfix-senders`].
- **Historia.** E1: Authelia wysyłała przez SMTP Gmaila [plik `proxy/docker-compose.yml` w `386f12a`]. 2024-07: Postfix w compose [commit `d7136fb`, 2024-07-16]. E3: Postfix w `Kubernetes/infrastructure` [plik `Kubernetes/infrastructure/postfix/deployment.yaml` w `6b94576`]. E4: relay do OCI.
- **Skrzynki odbiorcze.** Nie są hostowane w domu: `docs/email-provider-research.md` (obserwacje z 2026-08-01) porównuje płatnych dostawców (Zoho, Migadu, Purelymail, Fastmail, Proton, iCloud+, Mailbox.org, Google Workspace, Microsoft 365, Cloudflare Email Routing) i zakłada „No self-hosting” [plik `docs/email-provider-research.md`]. [wniosek] Poczta przychodząca to świadomie niezrepatriowana część, ważna dla rozdziału o kosztach.

---

## 12. Model bezpieczeństwa

### 12.1 Droga żądania z internetu

| Krok | Element | Co robi | Dowód |
| --- | --- | --- | --- |
| 1 | DNS publiczne (Cloudflare) | `*.nerine.dev` → domowe IP, bez proxy Cloudflare, aktualizowane przez `cloudflare-ddns` | [plik `Terraform/cloudflare.tf`], [plik `Kubernetes/apps/cloudflare-ddns/deployment.yaml`] |
| 2 | Router Mercusys `192.168.1.1` | przekierowanie TCP 80/443 na `192.168.1.11`; konfiguracja tylko w opisie, nie w kodzie | [plik `CLAUDE.md`, Key Gotchas] |
| 3 | MetalLB L2 | ogłasza `192.168.1.11` przez ARP; `externalTrafficPolicy: Local` zachowuje IP klienta | [plik `Kubernetes/bootstrap/metallb/ipaddresspool.yaml`], [plik `Kubernetes/bootstrap/traefik/kustomization.yaml`] |
| 4 | Traefik, entrypoint `web` | 301 na HTTPS | [plik `Kubernetes/bootstrap/traefik/kustomization.yaml`] |
| 5 | Traefik, entrypoint `websecure` | TLS 1.2+ tylko AEAD, `sniStrict`, wildcard LE; middleware `security-headers` (HSTS, nosniff, frame options) na całym entrypoincie | [plik `Kubernetes/bootstrap/traefik/tls-options.yaml`], [plik `Kubernetes/bootstrap/traefik/middlewares.yaml`] |
| 6 | `public-chain` / `streaming-chain` | bouncer CrowdSec (decyzje z LAPI) + AppSec WAF, limit 500 równoczesnych żądań | [plik `Kubernetes/bootstrap/traefik/middlewares.yaml`], [plik `Kubernetes/bootstrap/traefik/crowdsec-middleware.yaml`] |
| 7 | middleware `authentik` (forward-auth) lub OIDC w aplikacji | brak sesji → przekierowanie do `auth.nerine.dev`, logowanie Google, sprawdzenie polityki grupy; Traefik przekazuje nagłówki `X-authentik-*` | [plik `Kubernetes/bootstrap/traefik/middlewares.yaml`], [plik `Terraform/apps/authentik.tf`] |
| 8 | NetworkPolicy | w `media`, `utilities`, `home`, `printing` do podu aplikacji wpuszczany tylko Traefik (i wymienione pody), więc z wnętrza klastra nie da się tam obejść kroków 5-7; panele w innych przestrzeniach nazw (ArgoCD, Longhorn, Grafana) mają tylko polityki z chartów lub żadne [wniosek] | [plik `Kubernetes/apps/networkpolicies/media.yaml`], [PR #563] |
| 9 | Aplikacja | zwykły HTTP; *arr ufa nagłówkowi (`External`); AdGuard i qBittorrent nie mają własnego logowania; Jellyfin, Immich, Grafana i ArgoCD logują przez OIDC | [plik `CLAUDE.md`, Key Gotchas „Sonarr/Radarr external auth”], [commit `4a956f1`, 2026-08-22], [commit `5abd814`, 2026-02-25], [plik `Terraform/apps/authentik.tf`] |

Kolejność na przykładzie Sonarr: entrypoint (`security-headers`) → `public-chain` → `authentik` → usługa `sonarr:8989` [plik `Kubernetes/apps/sonarr/ingress.yaml`].

### 12.2 Wyjątki i obejścia (świadome)
- LAN i pody (`192.168.1.0/24`, `10.244.0.0/16`) omijają CrowdSec i WAF (`clientTrustedIPs`) [plik `Kubernetes/bootstrap/traefik/crowdsec-middleware.yaml`]. Klienci w LAN docierają do Traefika bezpośrednio dzięki przepisaniu DNS w AdGuard [plik `Terraform/apps/adguard.tf`]. Uwierzytelnianie Authentikiem obowiązuje ich tak samo [wniosek z IngressRoute].
- `auth.nerine.dev` i apeks nie mają forward-auth (z definicji) [plik `Kubernetes/bootstrap/authentik/ingress.yaml`].
- Anonimowy odczyt `/public` w copyparty przez `skip_path_regex` [plik `Terraform/apps/authentik.tf`].
- Jellyfin i Immich są chronione tylko przez własne OIDC (bez forward-auth) [plik `Kubernetes/apps/jellyfin/ingress.yaml`], [plik `Kubernetes/apps/immich/ingress.yaml`].
- Od 2026-08-21 nie ma już ograniczeń po adresie źródłowym (`private-chain`, `tailscale-only` usunięte); dostęp zależy wyłącznie od tożsamości [commit `cf4cbd6`, 2026-08-21]. Skutek uboczny: `argocd login` z CLI wymaga port-forward [commit `cf4cbd6`, 2026-08-21].

### 12.3 Dostęp administracyjny
- Panele (ArgoCD, Longhorn, Grafana, Traefik, AdGuard, panel banów) idą tą samą publiczną drogą co aplikacje, za Authentikiem: wspólny `private-proxy` wpuszcza grupy `vips` i `admins` (polityka `vips_or_admins` na `authentik_application.private`), a panel banów CrowdSec ma osobny provider tylko dla `admins` [commit `cf4cbd6`, 2026-08-21], [plik `Terraform/apps/authentik.tf`].
- Przez Tailscale idą tylko: API Kubernetesa (API-proxy operatora), API Talosa (50000), Proxmox (22, 8006), SSH na hosty i DNS [plik `Tailscale/policy.hujson`].
- Proxmox: SSH tylko z kluczem, `MaxAuthTries 3`, bez przekierowań [commit `46ae919`, 2026-07-24].
- CI (GitHub Actions) wchodzi do tailnetu jako `tag:ci` z kluczem OAuth zarządzanym w Terraformie [plik `Terraform/tailscale.tf`], [plik `Tailscale/policy.hujson`].

### 12.4 Inne warstwy (skrótem, szczegóły w innych plikach bazy)
- Sekrety w Bitwarden SM + ESO, losowane w Terraformie [plik `CLAUDE.md`, Conventions].
- Pod Security Standards (enforce baseline) w 7 przestrzeniach nazw, zawężone RBAC, przypięte digesty obrazów, `permissions: contents: read` w CI [commit `c3bd45f`, 2026-08-13].

### 12.5 Ewolucja modelu (do opisu w pracy)
1. E1: VPS + tunel WireGuard, Authelia na dashboardach [commit `386f12a`], [commit `2aefed4`].
2. E2-E4: VPS z HAProxy (PROXY protocol przez Tailscale), Authelia/Authentik w compose, potem Authentik w k8s; równolegle dostęp tylko z LAN/Tailscale (`private-chain`) dla wrażliwych usług [commit `0fa08ec`], [commit `099e42d`, 2026-02-25].
3. E5: bezpośrednie wystawienie, model oparty na tożsamości (Authentik), CrowdSec + WAF, egzekwowane NetworkPolicy, Tailscale tylko do administracji i DNS [commit `5d7f26e`], [commit `cf4cbd6`], [commit `905ab74`], [PR #563].

---

## 13. Ograniczenia sieci domowej (studia przypadków z Key Gotchas)

| Problem | Objaw | Przyczyna | Dowód |
| --- | --- | --- | --- |
| „Orange blokuje 80/443” | brak ruchu z zewnątrz | źle ustawione przekierowanie portów na routerze; po poprawce oba porty działają | [commit `ca9a652`, 2026-08-21], [plik `CLAUDE.md`] |
| Router gubi odpowiedzi UDP | 70-90% utraty odpowiedzi DNS dla `.112` (2026-09-21) | wpis przypisuje to routerowi; czy to ten sam problem co konflikt ARP niżej, jest [wniosek] | [plik `CLAUDE.md`, wpis o Mercusys], [commit `ef00f2c`, 2026-09-22] |
| Konflikt adresu z pulą DHCP | 100% utraty odpowiedzi dla talos-3, flapy `Ready`, przebudowy Longhorna | router wydał `.112` dekoderowi TV; pula zawężona do `.180-.253` | [plik `CLAUDE.md`, wpis o puli DHCP] |
| Hairpin NAT | pody i klienci LAN z publicznym DNS wracają przez router jako domowe IP | brak split-horizon poza AdGuard | [plik `CLAUDE.md`], [commit `efac355`, 2026-10-05] |
| Tailscale L3 proxy | utrata IP klienta, ok. 4,8 razy wolniejszy upload | DNAT i WireGuard w przestrzeni użytkownika | [plik `CLAUDE.md`], [commit `905ab74`, 2026-09-03] |
| QUIC przez router | uploady 2,5 razy wolniejsze | router gubi UDP, koszt CPU QUIC w Traefiku | [commit `6deeeaf`, 2026-10-06] |

---

## 14. Źródła zewnętrzne

Wszystkie: dostęp 2026-11-27. Licencje i daty wydań sprawdzone przez stronę projektu lub GitHub API; licencje ingress-nginx (zarchiwizowane), Zitadel (AGPL-3.0), AdGuard Home (GPL-3.0) i CrowdSec (MIT) sprawdzone dodatkowo przez `gh api repos/<repo>`.

- Let's Encrypt: certyfikat wildcard wymaga DNS-01 (FAQ i strona typów wyzwań, parafraza): https://letsencrypt.org/docs/faq/, https://letsencrypt.org/docs/challenge-types/
- tailscale/tailscale#11024, „FR: Forwarding Tailscale user IP addresses to cluster backends exposed via Tailscale Kubernetes Services”, otwarte od 2024-02-02, stan OPEN: https://github.com/tailscale/tailscale/issues/11024
- Wycofanie ingress-nginx: https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/
- Gateway API GA: https://kubernetes.io/blog/2023/10/31/gateway-api-ga/
- MetalLB L2: https://metallb.io/concepts/layer2/
- Cennik Tailscale: https://tailscale.com/pricing
- Cennik Authentik: https://goauthentik.io/pricing/
- Zmiana licencji Zitadel: https://zitadel.com/blog/apache-to-agpl
- Community Blocklist CrowdSec: https://docs.crowdsec.net/docs/central_api/community_blocklist/
- Status proxy w Cloudflare DNS: https://developers.cloudflare.com/dns/proxy-status/
- Regulamin usług aplikacyjnych Cloudflare: https://www.cloudflare.com/service-specific-terms-application-services/

---

## Pytania do autora

1. Czy w 2024 łącze domowe było naprawdę za CGNAT (README z 2024-01-02 mówi „bypass CGNAT”), czy był to inny operator lub inna umowa niż obecna z Orange z publicznym IP?
2. Czym w okresie 2024-07 → 2025-03 ruch publiczny trafiał do domu, skoro katalog `VPS/` z WireGuardem usunięto 2024-07-14, a HAProxy pojawił się w repo dopiero 2025-03-13? Czy HAProxy na VPS działał wcześniej poza repo?
3. Dlaczego w lutym 2025 Authelię z LLDAP zastąpił Authentik (commit `c8dccdd` nie ma opisu)? Czy chodziło o OIDC/LDAP dla Jellyfina, interfejs, czy coś innego?
4. Dlaczego 2026-02-01 w nowym klastrze najpierw postawiono oauth2-proxy, a po 19 dniach wrócono do Authentika?
5. Jak były chronione usługi w pierwszym Kubernetesie (2025-09 → 2026-02), skoro IngressRoute nie miały middleware uwierzytelniania, a Authentik z compose zniknął 2025-09-01? Czy usługi były wtedy publiczne?
6. Dlaczego pierwotnie wybrano Traefika (2024 lub wcześniej), a nie nginx/Caddy?
7. Dlaczego zrezygnowano z własnego tunelu WireGuard na rzecz Tailscale?
8. Czy rozważano Cloudflare Tunnel jako zamiennik VPS z HAProxy, a jeśli tak, dlaczego odrzucono?
9. Czy rozważano zmianę CNI na Cilium/Calico zamiast `kube-network-policies` obok Flannela?
10. Dlaczego dzień po przejściu na wildcard na entrypoincie (`b85f139`) przywrócono `certResolver` w każdej IngressRoute (`d42247e`)?
11. Jak długo trwało szukanie przyczyny „blokady 80/443” i ile kosztował VPS proxy w tym czasie (do rozdziału o kosztach)?

## Do której części pracy

- **Technologie**: sekcje 2-3 i 5-11 (rola, alternatywy, licencje).
- **Projekt**: sekcja 12 (model bezpieczeństwa, droga żądania), 5.2 (split-horizon), 7 (podział: aplikacje publicznie, administracja przez Tailscale).
- **Implementacja**: sekcje 2, 8.4, 9, 10 (konkretne pliki, kolejność middleware, ograniczenia chartów).
- **Odtwarzanie po awarii**: 5.1 (rekordy DNS z Terraformu + DDNS), 7 (sufiks `-1` nazw Tailscale po przebudowie węzła), 9 (sekrety CrowdSec z Bitwardena).
- **Analiza kosztów**: sekcja 4 (VPS proxy wycofany), 11 (poczta przychodząca u zewnętrznego dostawcy), darmowe plany Tailscale/Cloudflare (sekcja 14).
- **Wstęp/podsumowanie**: sekcja 4 jako przykład błędnej diagnozy i wartości zapisywania gotchas.

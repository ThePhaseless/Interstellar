# Baza wiedzy do pracy inżynierskiej

Materiał źródłowy do pracy „Projekt i implementacja zautomatyzowanego środowiska Homelab z wykorzystaniem Infrastructure as Code w procesie częściowej repatriacji usług chmurowych”. Opisuje, jak homelab wyglądał na początku, jak się zmieniał i dlaczego. Przy technologiach podaje alternatywy, ograniczenia i sytuacje, w których lepiej wybrać coś innego.

Stan na 2026-11-27: gałąź `main` w commicie `9b1d576`, a w części plików już `e7ae5da` (z 2026-11-27: skany Pagewire na NFS). Repo zaczyna się 2024-01-01, ale serwer działał już wcześniej. To, co było przed pierwszym commitem, da się tylko wywnioskować, a resztę zebrano jako pytania do autora.

## Pliki

| Plik | Zawartość | Rozdziały pracy |
| --- | --- | --- |
| [os-czasu.md](os-czasu.md) | Okresy E1-E5, kamienie milowe, technologie i sprzęt w czasie, aktywność w repo | 1, 3, 4 |
| [historia/01-start-docker-compose.md](historia/01-start-docker-compose.md) | E1, 2024-01 → 2024-07: stan sprzed repo, docker-compose, Traefik i Authelia, przeniesienie proxy z VPS do domu | 1, 3, 4 |
| [historia/02-rozwoj-compose.md](historia/02-rozwoj-compose.md) | E2, 2024-07 → 2025-07: push-to-deploy, Renovate, Authelia → Authentik, HAProxy na Oracle | 3, 4 |
| [historia/03-iac-i-pierwszy-kubernetes.md](historia/03-iac-i-pierwszy-kubernetes.md) | E3, 2025-07 → 2026-01: Terraform, Ansible, k3s w LXC, koniec compose | 3, 4 |
| [historia/04-przebudowa-gitops.md](historia/04-przebudowa-gitops.md) | E4, 2026-02 → 2026-07: Talos, ArgoCD, Longhorn, Bitwarden + ESO, incydenty | 3, 4, 5 |
| [historia/05-publiczne-wystawienie-i-stan-obecny.md](historia/05-publiczne-wystawienie-i-stan-obecny.md) | E5, 2026-08 → dziś: wystawienie bez VPS, NetworkPolicies, dyski i prąd, opis stanu obecnego | 3, 4, 5, 6 |
| [technologie/01-platforma-i-orkiestracja.md](technologie/01-platforma-i-orkiestracja.md) | Proxmox, Talos, Kubernetes, compose, Oracle VPS, GPU | 2, 3 |
| [technologie/02-iac-gitops-ci.md](technologie/02-iac-gitops-ci.md) | Terraform/OpenTofu, Ansible, Kustomize/Helm, ArgoCD, GitHub Actions, Renovate, mise | 2, 3, 4 |
| [technologie/03-siec-i-bezpieczenstwo.md](technologie/03-siec-i-bezpieczenstwo.md) | Traefik, Authentik, Tailscale, Cloudflare, MetalLB, AdGuard, CrowdSec, model bezpieczeństwa | 2, 3, 4 |
| [technologie/04-dane-kopie-sekrety-monitoring.md](technologie/04-dane-kopie-sekrety-monitoring.md) | ZFS, NFS, mergerfs, Longhorn, Borg + Hetzner, Bitwarden SM + ESO, Grafana/Loki/Mimir, strategia kopii | 2, 3, 5 |
| [technologie/05-aplikacje-i-repatriacja.md](technologie/05-aplikacje-i-repatriacja.md) | Aplikacje, usługi chmurowe, które zastępują, ceny abonamentów, tabela repatriacji | 1, 2, 6 |
| [odtwarzanie-i-koszty.md](odtwarzanie-i-koszty.md) | Sprzęt, co da się odtworzyć z gita, scenariusze testu odtworzenia, pomiary mocy, cena prądu G11, koszty stałe | 5, 6 |
| [pytania-do-autora.md](pytania-do-autora.md) | Pytania, na które repo nie odpowiada, do uzupełnienia przez autora | wszystkie |

Numery rozdziałów: 1 wstęp, 2 technologie, 3 projekt, 4 implementacja, 5 odtwarzanie po awarii, 6 analiza kosztów, 7 podsumowanie. Podsumowanie korzysta ze wszystkich plików.

## Jak czytać oznaczenia

- [commit `abc1234`, RRRR-MM-DD], [plik `ścieżka`], [PR #N]: fakt sprawdzony w repo. Wszystkie cytowane commity istnieją na `main`, a daty zgadzają się z `git log`.
- [źródło: URL, dostęp 2026-11-27]: fakt ze strony internetowej. Licencje, ceny i status projektów zmieniają się, więc przed oddaniem pracy trzeba je sprawdzić jeszcze raz. Oznaczenie „ART” przy cenie znaczy, że pochodzi z artykułu, a nie ze strony producenta.
- [wniosek]: rozumowanie autora pliku na podstawie dowodów. Motywu autora projektu nie należy z tego wyprowadzać.
- [nieznane]: repo tego nie mówi. Zwykle jest do tego pytanie w [pytania-do-autora.md](pytania-do-autora.md).

Motywy decyzji („dlaczego wybrałem X”) są podane tylko wtedy, gdy zapisano je w commicie, PR-ze albo dokumentacji. Pozostałe trzeba uzupełnić z odpowiedzi na pytania.

## Znane rozbieżności z dokumentacją repo

- `README.md` na `main` podaje nieaktualny sprzęt (i5-12600K, 32 GB) i tabelę węzłów. Aktualne dane są w [odtwarzanie-i-koszty.md](odtwarzanie-i-koszty.md), a rozmiary węzłów w `Terraform/variables.tf`.
- `Terraform/AGENTS.md` podaje backend `kubernetes` dla `Terraform/apps`, a stan od 2026-06-23 leży w OCI.
- Część wpisów „Key Gotchas” obalono później. Lista jest w sekcji o obalonych twierdzeniach w [historia/04-przebudowa-gitops.md](historia/04-przebudowa-gitops.md).

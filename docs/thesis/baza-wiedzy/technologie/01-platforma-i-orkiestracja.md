# Technologie platformy: sprzęt, wirtualizacja, system węzłów, orkiestracja

Zakres: warstwa, na której działają wszystkie usługi homelaba, czyli fizyczny host `carbon` z Proxmox VE, trzy maszyny wirtualne z Talos Linux tworzące klaster Kubernetes, VPS w Oracle Cloud i dodatki klastra związane ze sprzętem (GPU, rozkład obciążenia, metryki). Do tego technologie, które ta warstwa zastąpiła: docker-compose (2024-2025, najpierw na Linuksie bez hypervisora, od 2025-03 najpóźniej w VM na Proxmox VE 8) i k3s w kontenerach LXC (2025).

Oznaczenia: [commit `abc1234`, data], [plik `ścieżka`] (stan na `main`), [PR #N], [wniosek], [źródło: URL, dostęp 2026-11-27], [nieznane].

## 1. Oś czasu platformy

| Okres | Gdzie działały usługi | Orkiestracja | Dowód |
| --- | --- | --- | --- |
| przed 2024-01-01 | serwer istniał przed repo, sprzęt i system nieznane | [nieznane] | nie dotyczy |
| 2024-01 → ? | Linux z `apt` (Debian lub Ubuntu) wprost na sprzęcie, Docker, Portainer, mergerfs albo RAID0; VPS w Oracle jako brama przez WireGuard | docker-compose | [commit `386f12a`, 2024-01-01], [commit `b946160`, 2024-01-15] |
| najpóźniej 2025-03 | Proxmox VE 8 na i5-12600K / 32 GB (iGPU UHD 770), usługi Dockera w VM; proxy na Oracle A1 | docker-compose | [commit `84ea802`, 2025-03-13] |
| 2025-07-26 | pierwszy ślad Proxmox VE w repo: kontener LXC `nickel` (Ubuntu 24.04) zakładany przez Terraform (OpenTofu, provider Telmate) | compose (do 2025-09) |  [commit `6930efc`, 2025-07-26] |
| 2025-08-02 → 2026-02 (na `main` do 2026-02-26) | k3s instalowany Ansible'em w uprzywilejowanym LXC, Flannel po `tailscale0`, GPU NVIDIA | k3s | [commit `5765311`, 2025-08-02], [commit `bc91666`, 2025-12-17], [commit `327eff3`, 2026-02-26] |
| 2025-08-11 → 2025-09-01 | pliki compose przepisane na manifesty (kompose 1.34.0), główny compose usunięty | k3s | [commit `abcb648`, 2025-08-11], [commit `28fbc9e`, 2025-09-01] |
| 2025-12-17 | plan migracji k3s/LXC → Talos/VM na gałęzi migracyjnej, gdzie usunięto kod k3s, LXC i NVIDIA; na `main` ten kod zostaje do scalenia 2026-02-26 | k3s (stan faktyczny [nieznane]) | [commit `bc91666`, 2025-12-17], [plik `Ansible/k3s.yaml` w `f50bd66`], [commit `327eff3`, 2026-02-26] |
| 2026-02-01 → dziś | 3 VM z Talos Linux na Proxmox, Intel Arc B580 przekazany do talos-1 (gałąź migracyjna; na `main` od 2026-02-26, `327eff3`) | Kubernetes (Talos) + ArgoCD | [commit `6757719`, 2026-02-01] |
| 2026-08-20 | koniec ostatniego compose (`compose.proxy.yaml` z HAProxy na Oracle) | Kubernetes (Talos) | [PR #567], [commit `7158f21`, 2026-08-20] |

Dwie pułapki przy czytaniu historii:

- Commit „disable k3s” [commit `aff4c61`, 2025-08-31] tylko komentuje zadanie CI, które instalowało k3s. Kolejne commity jesienią 2025 nadal wdrażają manifesty na klaster (np. „apply kubernetes” [commit `06ecf16`, 2025-09-12]), więc k3s najpewniej działał dalej [wniosek]. Kod k3s i LXC znika na gałęzi migracyjnej w [commit `bc91666`, 2025-12-17], a Terraform dla Talosa pojawia się tam w [commit `6757719`, 2026-02-01]. Na `main` stary kod zostaje do scalenia [commit `327eff3`, 2026-02-26] [plik `Terraform/proxmox.tf` w `f50bd66`], więc do lutego 2026 `main` nadal opisuje k3s w LXC. Kiedy nowy klaster faktycznie przejął pracę, repo nie pokazuje [nieznane]; zob. `historia/04-przebudowa-gitops.md`.
- Compose nie skończył się 2025-09-01. Brama HAProxy na Oracle działała z `compose.proxy.yaml` do 2026-08-20 [PR #567].

## 2. Sprzęt: host `carbon`

### Co mówi repo (dowody są sprzeczne)

| Źródło | CPU | RAM | Dyski | GPU |
| --- | --- | --- | --- | --- |
| README z 2025-03 [commit `84ea802`, 2025-03-13] | Intel Core i5-12600K (16 wątków) | 32 GB DDR4 | 1 TB NVMe + 5×3 TB HDD | Intel UHD Graphics 770 (iGPU); OS: Proxmox VE 8 |
| README na `main` (CPU i RAM bez zmian od 2025-03; GPU zmienione na B580 w [commit `6757719`, 2026-02-01]) | Intel Core i5-12600K | 32 GB DDR4 | 1 TB NVMe + pula ZFS 5×3 TB | Intel Arc B580 [plik `README.md`] |
| plan migracji Talos [commit `bc91666`, 2025-12-17] | AMD Ryzen 9 3950X (32 wątki) | 62,71 GiB | / 94 GiB + /Storage 10,77 TiB ZFS | Intel Arc B580 |
| specyfikacja oszczędzania energii [commit `4367315`, 2026-06-18] | AMD Ryzen 9 3950X (16c/32t, TDP 105 W) | 64 GB DDR4 | 5×3 TB HDD 7200 rpm (RAIDZ1), 2×1 TB NVMe (mirror) | nie podano |

Na rzecz Ryzena przemawia [wniosek]: obecne VM zajmują razem 16 vCPU i 40 GiB RAM (16+12+12) [plik `Terraform/variables.tf`], czego nie zmieściłby host z 32 GB. Tabela węzłów w README (3×8 vCPU, 3×16 GB) też nie zgadza się z `variables.tf`, więc README jest najpewniej nieaktualne: przy migracji 2026-02-01 poprawiono w nim tylko GPU. Najprostsze wyjaśnienie to wymiana płyty i CPU (i5-12600K → Ryzen 9 3950X) między 2025-03 a 2025-12 [wniosek; pytanie 4]. Pliki z [commit `4367315`] usunięto później z repo [commit `c3bd45f`, 2026-08-13]; cytuję z nich wyłącznie dane sprzętowe.

Wersja Proxmox VE: spec z 2026-06-14 podaje 9.2.3, spec z 2026-06-18 podaje „7.0.6-2 on Debian 13 trixie” (to raczej wersja jądra niż PVE) [commit `4367315`], a `SETUP.md` wymaga „Proxmox VE 8+ (IOMMU)” [plik `SETUP.md`]. PVE 9.x działa na Debianie 13, a PVE 8 stracił wsparcie w 2026-08 [źródło: https://pve.proxmox.com/wiki/FAQ, dostęp 2026-11-27]. „Trixie” w specyfikacji wskazuje więc na PVE 9 [wniosek], a wymóg „8+” w `SETUP.md` dopuszcza już nieutrzymywaną wersję.

### Inne fakty sprzętowe ważne dla platformy

- Kontroler SATA ASMedia ASM1062 obsługuje 2 z 5 dysków puli `Storage`; nie wolno go odpinać w regułach oszczędzania energii [plik `CLAUDE.md`, Key Gotchas].
- Konwerter CH340 (`1a86:7523`) to koordynator Zigbee przekazany do VM Home Assistanta [plik `CLAUDE.md`].
- Wtyczka pomiarowa w HA pokazała średnio 147,4 W przed pierwszą fazą oszczędzania i 130,2 W po niej [commit `4367315`, 2026-06-18]; resztę danych o energii zawiera plik o kosztach.

## 3. Proxmox VE (hypervisor)

### Rola w tym homelabie

- Host `carbon` uruchamia trzy VM Talosa (VMID 110-112), VM Home Assistanta (poza Terraformem; VMID 102 według [commit `4367315`]) i serwer NFS dla mediów na ZFS [plik `Terraform/proxmox.tf`], [plik `Ansible/setup-proxmox.yaml`], [plik `CLAUDE.md`].
- Terraform (provider `bpg/proxmox`) zakłada VM: q35, OVMF, CPU `host`, dysk systemowy i osobny dysk danych Longhorna na `local-zfs`, przekazanie GPU przez `hostpci` z mapowaniem `gpu`, agent QEMU, port szeregowy [plik `Terraform/proxmox.tf`].
- Ansible konfiguruje sam host: NFS, forwarding dla exit node Tailscale, oszczędzanie energii (TLP, powertop, hd-idle, ASPM), ZFS (atime, txg, ARC), logowanie konsol szeregowych, przekazanie drukarki USB do talos-2 [plik `Ansible/setup-proxmox.yaml`].
- Instalację samego Proxmoxa i mapowanie PCI GPU (`/etc/pve/mapping/pci.cfg`) robi się ręcznie, poza kodem [plik `SETUP.md`], [plik `Terraform/AGENTS.md`].

### Od kiedy i co zastąpił

- W 2024 skrypt `host/install.sh` instaluje usługi bezpośrednio na Linuksie przez `apt`, z Dockerem i Portainerem [commit `386f12a`, 2024-01-01]. README z 2025-03-13 podaje już „Proxmox VE 8” i „VM containing various docker containers” [commit `84ea802`, 2025-03-13]. Proxmox zastąpił więc instalację bez hypervisora między 2024-01 a 2025-03 [wniosek]. Dokładna data i powód: [nieznane].
- Pierwszy kod dla Proxmoxa: [commit `6930efc`, 2025-07-26], czyli kontener LXC `nickel` zakładany przez Terraform.
- 2025-07 → 2026-02 (na gałęzi migracyjnej usunięty 2025-12-17, na `main` 2026-02-26): Proxmox z kontenerem LXC (uprzywilejowanym: `unprivileged = false`, `lxc.apparmor.profile: unconfined`, `lxc.cgroup2.devices.allow: a`, przekazane `/dev/nvidia*`) [commit `bc91666`^, pliki `Terraform/proxmox.tf`, `Ansible/vars/containers.yaml`].
- Od 2026-02-01: Proxmox z pełnymi VM dla Talosa [commit `6757719`, 2026-02-01].

### Alternatywy

| Rozwiązanie | Licencja / koszt | Wymagania | Mocne strony | Ograniczenia |
| --- | --- | --- | --- | --- |
| Proxmox VE 9.2 (wybrany) | AGPLv3; subskrypcja opcjonalna, za gniazdo CPU rocznie: Community 120 €, Basic 370 €, Standard 550 €, Premium 1100 €, „all features available at every level” [źródło: https://pve.proxmox.com/wiki/FAQ; https://www.proxmox.com/en/products/proxmox-virtual-environment/pricing, dostęp 2026-11-27] | min. 64-bit CPU z VT/AMD-V, 1 GB RAM (tylko do testów); zalecane 2 GB dla systemu plus RAM gości i ok. 1 GB RAM na TB dla ZFS/Ceph [źródło: https://www.proxmox.com/en/products/proxmox-virtual-environment/requirements, dostęp 2026-11-27] | KVM i LXC w jednym narzędziu, ZFS, Ceph, HA; 9.2 z 2026-05-21 (Debian 13.5, jądro 7.0, QEMU 11.0) [źródło: https://www.proxmox.com/en/about/press-releases/proxmox-virtual-environment-9-2, dostęp 2026-11-27] | repozytorium enterprise i wsparcie tylko w subskrypcji; RAID sprzętowy nieobsługiwany pod ZFS/Ceph [źródło: requirements, jw.] |
| XCP-ng 8.3 LTS + Xen Orchestra | XCP-ng GPL-2.0, wszystkie funkcje darmowe; XO AGPL3 (Vates); płatne wsparcie Vates od 2000/rok do 3 hostów [źródło: https://github.com/xcp-ng/xcp; https://github.com/vatesfr/xen-orchestra; https://vates.tech/en/pricing-and-support/, dostęp 2026-11-27] | CPU x86-64 ≥1,5 GHz z VT-x/AMD-V i SLAT, RAM min. 2 GB (zal. 8 GB+), dysk min. 46 GB [źródło: https://docs.xcp-ng.org/installation/requirements/, dostęp 2026-11-27] | hypervisor typu 1 (Xen), w pełni otwarty; 8.3 jest LTS od 2025-06-16 [źródło: https://xcp-ng.org/blog/2025/06/16/xcp-ng-8-3-is-now-lts/, dostęp 2026-11-27] | interfejs przez XO osobno; brak kontenerów LXC [wniosek]; XO budowane ze źródeł nie ma wsparcia producenta (tylko wynik wyszukiwania: https://docs.xen-orchestra.com/install-from-sources) |
| VMware ESXi / vSphere (Broadcom) | od 2023-12-11 koniec sprzedaży licencji wieczystych i odnowień SnS, wyłącznie subskrypcje lub licencje terminowe (komunikat Broadcom, znany z wyniku wyszukiwania, strona nie pobrana: https://news.broadcom.com/news/vmware-by-broadcom-business-transformation; także https://www.theregister.com/2023/12/12/vmware_broadcom_licensing_changes/); darmowy ESXi wycofany w lutym 2024 [źródło: https://www.servethehome.com/broadcom-vmware-ends-free-vmware-vsphere-hypervisor-closing-an-era/, dostęp 2026-11-27]; w kwietniu 2025 wrócił darmowy ESXi 8.0U3e do labów domowych [źródło: https://knowledge.broadcom.com/external/article/399823, dostęp 2026-11-27]; dla 9.0 darmowej wersji brak („Free ESX versions up to release 8.0U3”) [źródło: https://www.vmware.com/docs/vsphere9-faq, dostęp 2026-11-27] | darmowa 8.0U3e: maks. 8 vCPU na VM, do 2 fizycznych CPU, bez vCenter [źródło: KB 399823, jw.]; w płatnych minimum 16 rdzeni na CPU, od 2025-04-10 minimum 72 rdzenie na zamówienie [źródło: https://heise.de/-10335733, dostęp 2026-11-27] | dojrzały ekosystem korporacyjny [wniosek] | koszt i minima rdzeniowe; wersja darmowa bez API do backupu, bez klastrowania, bez aktualizacji przez LCM [źródło: KB 399823, jw.] |
| Microsoft Hyper-V | ostatnim darmowym samodzielnym produktem był Hyper-V Server 2019 (tylko wynik wyszukiwania: https://techcommunity.microsoft.com/t5/windows-server-insiders/hyper-v-server-2022/m-p/3266289), wsparcie do 2029-01-10 [źródło: https://learn.microsoft.com/en-us/lifecycle/products/hyperv-server-2019, dostęp 2026-11-27]; dziś rola Windows Server 2025: Standard 1176 $, Datacenter 6771 $ za 16 rdzeni [źródło: https://www.microsoft.com/en-us/windows-server/pricing, dostęp 2026-11-27] | [nieznane] (nie sprawdzono) | integracja z Windows i AD [wniosek] | płatne licencje Windows Server; darmowy produkt zatrzymany na 2019 [źródło: jw.] |
| Bez hypervisora (bare metal) | brak kosztu hypervisora | brak | brak narzutu wirtualizacji, prostsze GPU | brak snapshotów i izolacji; kilka węzłów k8s wymaga kilku maszyn; odbudowa = reinstalacja hosta [wniosek] |

Rynek a wybór: zmiany Broadcomu (koniec licencji wieczystych, okresowy brak darmowego ESXi, minima rdzeni) zbiegają się z popularnością Proxmoxa w homelabach, ale repo nie mówi, czy miały wpływ na decyzję autora [wniosek; pytanie 1].

### Ograniczenia napotkane w tym repo

- Dodanie lub usunięcie urządzenia PCIe zmienia numery grup IOMMU i psuje przekazanie GPU przy kolejnym starcie (`'iommugroup' does not match`). Zainstalowanie jednego NVMe przesunęło GPU z grupy 32 do 34 [plik `Terraform/AGENTS.md`].
- Podmiana ISO dopisuje oczekującą zmianę kolejności bootowania. Provider `bpg` z domyślnym `reboot_after_update = true` może wtedy zrestartować wszystkie trzy węzły naraz bez drenażu [plik `Terraform/AGENTS.md`], [plik `Terraform/proxmox.tf`].
- Parametry ZFS (`zfs_txg_timeout`, `zfs_dirty_data_max`) są globalne. Strojenie pod usypianie HDD spowalniało też pulę NVMe z etcd: zrzuty txg trwały 6-25 s, co dawało wybory lidera etcd i padanie kontrolerów [plik `CLAUDE.md`].
- Przestoje VM przez hypervisor potrafią na stałe zawiesić klienta NFSv4 w Talosie (montowanie `hard`) [plik `CLAUDE.md`].
- Zmiany w `/etc/modprobe.d/zfs.conf` wymagają `update-initramfs -u`. Pakiety aktualizuje się `pveupdate`/`pveupgrade`, nie gołym `apt` [plik `CLAUDE.md`].
- Surowe przekazanie USB (`host=`) może ustawić tylko `root@pam`. Token API Terraformu tego nie zrobi, więc drukarkę przekazuje Ansible [plik `CLAUDE.md`].
- Serwer NFS musi startować przed `pve-guests.service` [plik `CLAUDE.md`].
- Wszystkie trzy „węzły HA” stoją na jednym fizycznym hoście. Awaria `carbon` wyłącza cały klaster, więc wysoka dostępność chroni tylko przed awarią VM lub restartem węzła, nie sprzętu [wniosek].

### Kiedy lepiej wybrać coś innego

- Jedna usługa lub kilka kontenerów, bez potrzeby VM: Docker na zwykłym Debianie jest prostszy [wniosek].
- Organizacja ze wsparciem i istniejącymi kompetencjami VMware lub Windows: ESXi/vSphere albo Hyper-V, jeśli koszt licencji jest akceptowalny [wniosek].
- Wymóg czystego Xena lub zarządzania wieloma hostami przez jedno web UI z płatnym wsparciem dostawcy: XCP-ng + Xen Orchestra [wniosek].
- Tylko klaster k8s na kilku fizycznych maszynach: Talos bezpośrednio na sprzęcie, bez hypervisora [wniosek].

## 4. Talos Linux (system węzłów)

### Rola

- System trzech VM `talos-1..3`, każda pełni rolę control-plane i worker. Wirtualny IP API `192.168.1.100` jest obsługiwany przez Talosa [plik `Terraform/talos.tf`], [plik `Terraform/variables.tf`].
- Obrazy budowane przez Image Factory z rozszerzeniami: `iscsi-tools`, `qemu-guest-agent`, `util-linux-tools`, `tailscale` na wszystkich węzłach; `mei`, `xe`, `i915` tylko na węźle GPU [plik `Terraform/variables.tf`].
- Węzły (stan `main`): talos-1 4 vCPU / 16 GiB / GPU; talos-2 i talos-3 6 vCPU / 12 GiB; każdy ma dysk danych 120 GB dla Longhorna [plik `Terraform/variables.tf`].
- Wersje: Talos `v1.14.6`, konfiguracja generowana dla `v1.13.9`, Kubernetes `1.37.2`, aktualizowane przez Renovate [plik `Terraform/variables.tf`].
- Aktualizacje OS idą przez `talos_machine`, węzeł po węźle (moduł `talos-node`), z bramką czekającą, aż wszystkie wolumeny Longhorna będą zdrowe [commit `feb2ee9`, 2026-10-02].

### Od kiedy i co zastąpił

- W repo od [commit `6757719`, 2026-02-01] (Talos v1.10.0, Kubernetes 1.32.0 w domyślnych zmiennych) na gałęzi migracyjnej, na `main` od 2026-02-26; zastąpił k3s w LXC. Kiedy dokładnie nowy klaster przejął ruch (2026-02-01 czy po 2026-02-26), repo nie pokazuje [nieznane], zob. `historia/04-przebudowa-gitops.md`.
- Jedyny zapis motywacji to plan migracji: „Current State: K3s running on Proxmox LXC containers; Manual configuration and deployments” i „Target State: TalosOS on Proxmox VMs (immutable, API-driven Kubernetes OS)” [commit `bc91666`, 2025-12-17, plik `.github/prompts/plan-k3sToTalosOsMigration.prompt.md`]. Plan wymienia też, co usuwa: Ansible do LXC i sterowniki NVIDIA „for containers (not VMs)” [tamże].
- Moje odczytanie [wniosek, do potwierdzenia]: uprzywilejowany LXC z wyłączonym AppArmorem i dostępem do wszystkich urządzeń dawał słabą izolację od hosta, a k3s i system w nim trzeba było utrzymywać ręcznie. VM z niezmiennym systemem konfigurowanym przez API da się w całości opisać w Terraformie, a LXC z ręcznie utrzymywanym Ubuntu nie.
- Następstwa: kube-api-lb zastąpiony natywnym VIP Talosa [commit `066701e`, 2026-02-18]; bump do Talos v1.12.4 / k8s 1.35.0 [commit `8dcd6e1`, 2026-02-16].

### Alternatywy

| Rozwiązanie | Licencja | Wymagania (min.) | Mocne strony | Ograniczenia |
| --- | --- | --- | --- | --- |
| Talos Linux (wybrany) | MPL-2.0 [źródło: https://github.com/siderolabs/talos, dostęp 2026-11-27] | control plane 2 GiB RAM, 2 rdzenie, 10 GiB dysku (zal. 4 GiB/4/100 GiB); worker 1 GiB/1/10 GiB; amd64 wymaga x86-64-v2 [źródło: https://docs.siderolabs.com/talos/v1.14/getting-started/system-requirements, dostęp 2026-11-27] | system z SquashFS, „We have no shell. We have no SSH.”, całe zarządzanie przez API [źródło: https://docs.siderolabs.com/talos/v1.14/learn-more/philosophy, dostęp 2026-11-27]; Talos 1.14 wspiera Kubernetes 1.33-1.37, więc używana para Talos v1.14.6 + Kubernetes 1.37.2 mieści się w macierzy (data wydania 1.14 podana na stronie jako „2026-08-27 (TBD)”) [źródło: https://docs.siderolabs.com/talos/v1.14/getting-started/support-matrix, dostęp 2026-11-27] | brak powłoki, debugowanie tylko przez `talosctl`; sprzęt specjalny (GPU) tylko przez rozszerzenia systemowe [wniosek; przykład w §8] |
| k3s | Apache-2.0, projekt CNCF Sandbox [źródło: https://github.com/k3s-io/k3s; https://www.cncf.io/projects/k3s/, dostęp 2026-11-27] | serwer 2 rdzenie / 2 GB, agent 1 rdzeń / 512 MB [źródło: https://docs.k3s.io/installation/requirements, dostęp 2026-11-27] | jeden plik binarny poniżej 100 MB, pełna zgodność z Kubernetes [źródło: https://github.com/k3s-io/k3s, dostęp 2026-11-27] | system pod spodem trzeba utrzymywać samemu [wniosek] |
| kubeadm na Ubuntu/Debian | [nieznane] (licencji nie sprawdzono w tej sesji) | 2 GB RAM, 2 CPU dla control plane; swap wyłączony lub tolerowany [źródło: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/, dostęp 2026-11-27] | referencyjny instalator upstream [źródło: jw.] | OS, aktualizacje i hardening po stronie administratora [wniosek] |
| Flatcar Container Linux | Apache 2.0, CNCF Incubating od 2024-08-02 [źródło: https://github.com/flatcar/Flatcar; https://www.cncf.io/projects/flatcar/, dostęp 2026-11-27] | nie opublikowano na sprawdzonych stronach | niezmienny, root tylko do odczytu, automatyczne aktualizacje, następca CoreOS | to tylko OS: Kubernetesa trzeba doinstalować (np. kubeadm) |
| RKE2 (SUSE) | Apache-2.0 [źródło: https://github.com/rancher/rke2, dostęp 2026-11-27] | 4 GB RAM (zal. 8), 2 rdzenie (zal. 4) [źródło: https://docs.rke2.io/install/requirements, dostęp 2026-11-27] | domyślnie zgodny z CIS, FIPS 140-2, SELinux | wyższe minimum RAM; OS pod spodem do utrzymania |
| MicroK8s (Canonical) | Apache-2.0 [źródło: https://github.com/canonical/microk8s, dostęp 2026-11-27] | od 540 MB, do pracy zal. 4 GB RAM i 20 GB dysku [źródło: https://canonical.com/microk8s/docs/getting-started, dostęp 2026-11-27] | instalacja jednym `snap install` | zależność od snapd |

Rynek: we wrześniu 2026 Sidero Labs (twórcę Talosa) przejęła firma Yardi Systems [źródło: https://www.cooley.com/news/coverage/2026/2026-09-15-cooley-advised-yardi-on-acquisition-of-sidero-labs, dostęp 2026-11-27]. Zapowiedź, że Talos zostaje na MPL-2.0, znam tylko z wyników wyszukiwania, więc zmianę właściciela trzeba w pracy opisać jako ryzyko dostawcy.

### Ograniczenia napotkane w tym repo

- Dodanie `shutdownGracePeriodByPodPriority` bez wyzerowania `shutdownGracePeriod` i `shutdownGracePeriodCriticalPods` położyło kubelet na wszystkich węzłach naraz [commit `59abe12`, 2026-08-19], [plik `CLAUDE.md`]. Przy `talosctl upgrade` kubelet i tak chwilowo crash-loopuje, zanim konfiguracja się zbiegnie [plik `Terraform/AGENTS.md`].
- Talosowy `runtime.OOMController` zabija całe grupy cgroup QoS (BestEffort w pierwszej kolejności) przy presji PSI. Objaw: exit 137 bez `OOMKilled`. Pomaga zapas RAM na węzłach [plik `CLAUDE.md`]: talos-3 dostał z powrotem 12 GiB [commit `1727f68`, 2026-08-19], po tym jak „rebalance node memory” zwiększył talos-1 z 10 do 16 GB, ale talos-2 i talos-3 zmniejszył z 12 do 8 GB [commit `7707c14`, 2026-06-24].
- etcd leży w partycji `EPHEMERAL`, nie w osobnej `ETCD`, więc `talosctl reset --system-labels-to-wipe ETCD` nie działa [plik `CLAUDE.md`].
- Uszkodzone snapshoty overlay containerd dawały `exec format error` z plikiem 0 bajtów. Pewnym wyjściem okazało się odtworzenie dysku VM od zera [plik `CLAUDE.md`].
- `talosctl processes` pokazuje każdy proces jako `S` i nie widać w nim zawieszonego NFS; trzeba czytać `/proc/stat` [plik `CLAUDE.md`].
- Terraform nie zmieni `cluster.network.*` (np. ustawień Flannela) na żywym klastrze; potrzebny jest `talosctl upgrade-k8s` [plik `Terraform/AGENTS.md`].
- Provider `talos` przy aktualizacji OS czekał 15 minut i zgłaszał błąd mimo udanej aktualizacji (błąd w Talos v1.14.0) [plik `Terraform/AGENTS.md`].
- Dysku danych Longhorna nie da się wybrać po numerze seryjnym. Talos 1.13 go nie pokazuje, więc używa się dowiązania `/dev/disk/by-id/...-scsi1` [plik `Terraform/AGENTS.md`].
- Na węźle GPU fbcon potrafił zająć 100% jednego vCPU i zagłodzić etcd, stąd `fbcon=map:9` w parametrach jądra [plik `Terraform/talos.tf`], [plik `Terraform/AGENTS.md`].

### Kiedy lepiej wybrać coś innego

- Jeden mały węzeł, mało RAM (np. Raspberry Pi albo VPS 1-2 GB): k3s lub MicroK8s, bo nie potrzeba trzech control plane'ów, a minimum k3s to 512 MB dla agenta [wniosek ze źródeł wyżej].
- Na tej samej maszynie muszą działać też inne usługi niż Kubernetes (Samba, skrypty, agenci): zwykła dystrybucja (Ubuntu + k3s/kubeadm), bo Talos nie uruchomi niczego spoza k8s i rozszerzeń [wniosek].
- Zespół zna tylko SSH i klasyczną administrację, a nie ma czasu uczyć się `talosctl`: Ubuntu + kubeadm lub RKE2 [wniosek].
- Wymogi zgodności (CIS, FIPS) w organizacji: RKE2 [wniosek ze źródła RKE2].
- Sprzęt bez gotowego rozszerzenia Talosa (nietypowe sterowniki): system z menedżerem pakietów [wniosek; przykład z repo: brak `bmg_dmc.bin` w rozszerzeniu `xe`, patrz §8].

## 5. Kubernetes (orkiestracja)

### Rola

Kubernetes uruchamia wszystkie aplikacje (media, narzędzia, dom, drukowanie) i komponenty infrastruktury (Traefik, Authentik, Longhorn, ArgoCD, ESO, CrowdSec, MetalLB) [plik `README.md`], [plik `CLAUDE.md`]. Klaster ma 3 węzły, każdy jest control-plane i workerem [plik `Terraform/talos.tf`]. Węzeł talos-1 ma GPU dla Jellyfina i aplikacji z akceleracją sprzętową [plik `Kubernetes/AGENTS.md`]. Dostarczanie manifestów opisuje plik o IaC i GitOps.

### Historia

1. k3s w LXC, instalowany rolą `k3s.orchestration` z Ansible, z najnowszą wersją pobieraną z GitHuba, Flannel po `tailscale0` i domyślnym runtime `nvidia` na agentach [commit `5765311`, 2025-08-02], [commit `01a7a88`, 2025-08-04], [commit `bc91666`^, plik `Ansible/k3s.yaml`].
2. Konwersja compose przez kompose 1.34.0 [commit `abcb648`, 2025-08-11]; binarkę kompose usunięto z repo dwa dni później [commit `f2082c1`, 2025-08-13].
3. GPU NVIDIA: device plugin, GFD i współdzielenie (time-slicing) [commit `1b4af72`, 2025-08-16], [commit `af0260f`, 2025-08-16]; instalacja sterownika NVIDIA na hoście i przekazanie urządzeń do LXC [commit `fcd329a`, 2025-08-15]; ostatnia przypięta wersja 580.82.09 [commit `bc91666`^, plik `Ansible/vars/nvidia.yaml`].
4. Talos + Kubernetes 1.32 → 1.37 [commit `6757719`, 2026-02-01], [plik `Terraform/variables.tf`].

Motyw przejścia z compose na Kubernetes nie jest zapisany w żadnym commicie [nieznane; pytanie 2]. Commit „prepare for kubernetes” nie ma opisu i zmienia tylko devcontainer [commit `a9ff5be`, 2025-07-27]. W PR-ach też nie znalazłem uzasadnienia: PR-y wspominające Talos, k3s lub Proxmox pochodzą z 2026-08 i później i dotyczą bieżących poprawek.

### Alternatywy

| Rozwiązanie | Licencja / właściciel | Wymagania | Mocne strony | Ograniczenia |
| --- | --- | --- | --- | --- |
| Kubernetes (wybrany) | licencji nie sprawdzono w tej sesji [nieznane]; każda gałąź ma ok. 14 miesięcy wsparcia, 1.37 do 2027-10-28 [źródło: https://kubernetes.io/releases/, dostęp 2026-11-27] | zależnie od dystrybucji (§4) | deklaratywność, samonaprawianie, duży ekosystem (Helm, operatory, CSI) [wniosek] | złożoność, narzut zasobów, szybki cykl wydań wymusza regularne aktualizacje [wniosek] |
| Docker Compose (poprzednik) | Apache-2.0 [źródło: https://github.com/docker/compose, dostęp 2026-11-27] | Docker Engine | jeden plik YAML i `docker compose up` [źródło: https://docs.docker.com/compose/, dostęp 2026-11-27] | jeden host; brak rozmieszczania między węzłami i samonaprawiania na poziomie klastra [wniosek] |
| Docker Swarm (tryb swarm) | SwarmKit Apache-2.0, wbudowany w Docker Engine; klasyczny Swarm nie jest rozwijany [źródło: https://github.com/moby/swarmkit; https://docs.docker.com/engine/swarm/, dostęp 2026-11-27]; Mirantis przedłużył wsparcie Swarm o 5 lat (2025-07-01) [źródło: https://www.mirantis.com/company/press-center/company-news/mirantis-extends-swarm-support-another-five-years/, dostęp 2026-11-27] | Docker Engine | format Compose, tryb wbudowany w Docker Engine [źródło: https://docs.docker.com/engine/swarm/, dostęp 2026-11-27] | mały ekosystem [wniosek]; przejęcie Mirantis przez IREN (2026-08) znane tylko z wyniku wyszukiwania: https://globenewswire.com/news-release/2026/08/04/3338169/0/en/IREN-Completes-Acquisition-of-Mirantis.html |
| HashiCorp Nomad | BSL 1.1 od v1.7.0 (zmiana z MPL ogłoszona 2023-08-10), licencjodawca IBM [źródło: https://github.com/hashicorp/nomad/blob/main/LICENSE; https://www.hashicorp.com/en/blog/hashicorp-adopts-business-source-license, dostęp 2026-11-27]; IBM zamknął przejęcie HashiCorp 2025-02-27 [źródło: https://newsroom.ibm.com/2025-02-27-ibm-completes-acquisition-of-hashicorp,-creates-comprehensive,-end-to-end-hybrid-cloud-platform, dostęp 2026-11-27] | produkcyjnie 3-5 serwerów po 4-8+ rdzeni i 16-32 GB+ RAM [źródło: https://developer.hashicorp.com/nomad/docs/deploy/production/requirements, dostęp 2026-11-27] | jeden plik binarny, uruchamia też procesy bez kontenerów [wniosek, nie sprawdzono w źródle] | licencja BSL nie jest licencją open source [źródło: LICENSE, jw.]; mniejszy ekosystem niż k8s [wniosek] |

### Ograniczenia napotkane w tym repo (wybór)

- Bez domyślnych requestów i limitów większość podów jest BestEffort, więc pierwsza ginie przy presji pamięci (§4). Próbę z LimitRange wycofano tego samego dnia [commit `787476f`, 2026-08-19].
- Drenaż przed planowanym restartem jest obowiązkowy. Bez niego każdy montaż RWX Longhorna wisi ok. 12 minut [plik `CLAUDE.md`, Workflow].
- Zasoby zarządzane przez ArgoCD wolno tylko poprawiać na miejscu; odtworzenie app-of-apps kiedyś skończyło się utratą danych [plik `CLAUDE.md`].

### Kiedy lepiej wybrać coś innego

- Jeden host i garść usług bez wymagań HA: docker-compose. Mniej warstw, łatwiejsze odtworzenie z jednego pliku [wniosek].
- Kilka hostów, mały zespół znający Compose, brak potrzeby operatorów i CSI: Docker Swarm [wniosek].
- Mieszanka kontenerów i zwykłych binarek albo istniejący stos HashiCorp (Consul, Vault): Nomad, jeśli licencja BSL nie przeszkadza [wniosek].
- Celem jest nauka Kubernetesa i GitOps (jak w tej pracy) albo potrzebny jest ekosystem Helm/operatorów: Kubernetes [wniosek].

## 6. docker-compose (era 2024-2025, usunięty)

- 2024-01: `proxy/docker-compose.yml` (Traefik) i skrypty instalacyjne dla hosta i proxy [commit `386f12a`, 2024-01-01]; pliki compose dla usług od [commit `ba47ea5`, 2024-01-15].
- Stary README opisuje cel: „linux server setup that uses docker-compose … connected to an internal and external reverse proxy to bypass CGNAT” [commit `84ea802`^, plik `readme.md`].
- Koniec: główny compose usunięty po migracji na k3s [commit `28fbc9e`, 2025-09-01]; ostatni, `compose.proxy.yaml` na Oracle, zniknął razem z VM proxy [PR #567].
- Szczegóły etapów E1-E2 są w plikach historii.

## 7. Oracle Cloud VPS (`compute`)

### Rola i historia

| Okres | Instancja | Rola | Dowód |
| --- | --- | --- | --- |
| 2024-01 → 2025-03 | VPS w Oracle (kształt nieznany) | brama z publicznym IP: WireGuard do domowego „DMZ”, firewall w Oracle VCN; omijanie CGNAT | [commit `b946160`, 2024-01-15] (skrypt `VPS/setup_wireguard.sh`), [commit `84ea802`^] |
| 2025-03 | „Proxy VPS”: Ampere A1 Flex 4 rdzenie, 20 GB RAM, Ubuntu 24.04 Minimal | proxy | [commit `84ea802`, 2025-03-13] |
| 2025-07-26 | `argon`, VM.Standard.A1.Flex 4 OCPU / 24 GB / 200 GB, Ubuntu 22.04 | serwer ogólny (komentarz: „Free limits are 200 GB / 24 GB / 4 cores”) | [commit `6930efc`, 2025-07-26] |
| 2026-02-01 → 2026-08-20 | `oracle-proxy` 1 OCPU / 6 GB (HAProxy z PROXY protocol, wejście publiczne) + `oracle-compute` 3 OCPU / 18 GB | proxy + maszyna ogólna | [commit `6757719`, 2026-02-01] |
| 2026-08-20 → dziś | `oracle-compute` 4 OCPU / 24 GB / 150 GB, Ubuntu 24.04, unattended-upgrades z restartem o 04:00, budżet-strażnik 1 (alert przy wydatkach) | „General compute / build host”; urządzenie osobiste w tailnecie, nie infrastruktura | [plik `Terraform/oracle.tf`], [plik `README.md`], [commit `4fe6631`, 2026-08-18], [PR #567] |

Uwaga do [PR #567]: jego uzasadnienie („Orange refuses inbound TCP 80/443”) okazało się błędne. Przyczyną było złe przekierowanie portów na routerze, co sprawdzono 2026-08-21 [plik `CLAUDE.md`, Key Gotchas]. PR słusznie dokumentuje usunięcie `oracle-proxy` i zmianę rozmiaru `compute`, ale nie jest dowodem na blokadę u ISP. Ta pomyłka nadaje się na studium przypadku błędnej diagnozy w rozdziale o implementacji.

### Cięcie limitu Always Free w 2026

Dokumentacja Oracle (strona pobrana 2026-11-27, HTTP 200) podaje dla Ampere A1 „1,500 OCPU hours and 9,000 GB hours” miesięcznie, „equivalent to 2 OCPUs and 12 GB of memory”, i nie wyłącza z tego kont Pay As You Go (mówi o wszystkich tenancy) [źródło: https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm, dostęp 2026-11-27]. InfoQ i Linuxiac podają, że cięcie z 4/24 weszło 2026-06-15 bez ogłoszenia [źródło: https://infoq.com/news/2026/07/oracle-cloud-free-tier-limits/; https://linuxiac.com/oracle-quietly-cuts-free-tier-ampere-a1-resources-in-half/, dostęp 2026-11-27]. Konta tylko darmowe powyżej limitu były wyłączane do czasu zmniejszenia, a konta Pay As You Go mogą zachować 4/24. To ostatnie InfoQ podaje z drugiej ręki (maile od wsparcia udostępnione przez użytkowników) i kłóci się to z dokumentacją [źródło: https://infoq.com/news/2026/07/oracle-cloud-free-tier-limits/, dostęp 2026-11-27].

Tymczasem [PR #567] (2026-08-20) mówi, że `compute` powiększono do 4 OCPU / 24 GB, „the whole Always Free allowance, verified 0.00 PLN”, a Terraform ma alert budżetowy przy 1 jednostce waluty [plik `Terraform/oracle.tf`]. Według dokumentacji 4/24 przekracza dziś darmowy limit niezależnie od typu konta. Wyjaśnienie „konto PAYG dostaje 4/24 za darmo” opiera się tylko na relacji z drugiej ręki. Możliwe, że po 2026-06-15 część zasobów `compute` jest płatna albo że Oracle nie egzekwuje jeszcze limitu [wniosek; pytanie 5]. Rozdział kosztów musi to wyjaśnić.

### Alternatywy

| Oferta | Koszt | Zasoby | Ograniczenia |
| --- | --- | --- | --- |
| Oracle Always Free (wybrany) | 0, bez limitu czasu | A1.Flex: 2 OCPU / 12 GB (dokumentacja, strona zweryfikowana 2026-11-27), od 2026-06-15, wcześniej 4/24 [źródło: InfoQ, jw.]; 200 GB block storage; 10 TB transferu miesięcznie [źródło: https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm; https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm, dostęp 2026-11-27] | bezczynne instancje mogą zostać odebrane (7 dni: 95. percentyl CPU < 20%, sieć < 20%, pamięć < 20% dla A1) [źródło: resourceref, jw.]; ARM (aarch64); warunki zmieniane jednostronnie (cięcie 2026-06) |
| Hetzner Cloud | najtańsze CX23 (2 vCPU / 4 GB / 40 GB) 5,99 € i CAX11 (ARM) 6,49 €, obecnie niedostępne; CPX02 (1 vCPU / 1 GB) od 5,49 € [źródło: https://www.hetzner.com/cloud/cost-optimized/; https://www.hetzner.com/cloud/regular-performance/, dostęp 2026-11-27] | 20 TB transferu w Cost-Optimized | podwyżki 2026-04-01 i 2026-06-15 [źródło: https://heise.de/-11333037, dostęp 2026-11-27] |
| AWS Free Tier | od lipca 2025 nowe konta: 100 $ kredytów + do 100 $ więcej, plan darmowy na 6 miesięcy lub do wyczerpania kredytów [źródło: https://aws.amazon.com/about-aws/whats-new/2025/07/aws-free-tier-credits-month-free-plan, dostęp 2026-11-27] | m.in. t3/t4g micro/small [źródło: https://docs.aws.amazon.com/us_en/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html, dostęp 2026-11-27] | czasowy, nie „na zawsze” |
| Google Cloud Free Tier | stale darmowe 1× e2-micro w us-west1/us-central1/us-east1 [źródło: https://docs.cloud.google.com/free/docs/free-cloud-features, dostęp 2026-11-27] | 30 GB dysku, 1 GB transferu z Ameryki Płn. miesięcznie | tylko regiony USA, bardzo małe zasoby |

### Kiedy lepiej wybrać coś innego

- Usługa musi działać stale i przewidywalnie (np. publiczne wejście): płatny VPS (Hetzner) zamiast darmowego planu, który dostawca może zmienić lub odebrać przy bezczynności [wniosek ze źródeł wyżej].
- Potrzebny jest x86 (obrazy bez wersji ARM): Hetzner CX/CPX albo AWS, nie A1 [wniosek].
- Repatriacja: jeśli łącze domowe pozwala na publiczne porty (jak tu od 2026-08-21), VPS przestaje być potrzebny jako brama, co pokazuje usunięcie `oracle-proxy` [PR #567], [plik `CLAUDE.md`].

## 8. Dodatki klastra związane z platformą

### Intel GPU (device plugin + NFD)

- Mimo nazwy katalogu `Kubernetes/bootstrap/intel-gpu-operator` nie ma tam operatora Intela. Jest zwykły DaemonSet `intel/intel-gpu-plugin:0.37.1` z `-shared-dev-num=5` i `-allocation-policy=balanced`, chart Node Feature Discovery 0.20.1 i reguła NFD oznaczająca węzły z GPU [plik `Kubernetes/bootstrap/intel-gpu-operator/gpu-plugin.yaml`], [plik `Kubernetes/bootstrap/intel-gpu-operator/kustomization.yaml`].
- Pody GPU używają `nodeSelector: intel.feature.node.kubernetes.io/gpu: "true"` i zasobu `gpu.intel.com/xe` [plik `Kubernetes/AGENTS.md`].
- Od [commit `6757719`, 2026-02-01]. Zastąpił `nvidia-device-plugin` z ery k3s [commit `1b4af72`, 2025-08-16]. Dlaczego zmieniono kartę z NVIDIA na Intel Arc B580: [nieznane; pytanie 3]. Współdzielenie GPU podniesiono z 2 do 5 [commit `bbc4bf9`, 2026-02-24].
- Projekt: Apache-2.0; `xe` to „the official upstream kernel driver for the latest (Xe2 or newer)”, obejmuje „discrete Battlemage” [źródło: https://github.com/intel/intel-device-plugins-for-kubernetes/blob/main/cmd/gpu_plugin/README.md, dostęp 2026-11-27].
- Ograniczenia z repo: rozszerzenie Talosa `xe` nie zawierało firmware DMC, więc GPU nie wchodziło w uśpienie (ok. 9 W w spoczynku); obejście to rozszerzenie `i915` [commit `08b837f`, 2026-06-18], [plik `CLAUDE.md`]. Odczyty sysfs przez eksportery metryk budzą GPU (7-8 W), dlatego eksporterów GPU nie ma [plik `CLAUDE.md`]. Na węźle GPU trzeba było wyłączyć wyświetlanie (`xe.disable_display=1`) [commit `a218da8`, 2026-06-14]. Aktualizacja firmware karty (krzywe wentylatora) wymagała ręcznego `fwupdtool` z uprzywilejowanego poda [plik `CLAUDE.md`].
- Alternatywy: operator Intel Device Plugins (OperatorHub) zamiast surowego DaemonSetu [źródło: https://github.com/intel/intel-device-plugins-for-kubernetes, dostęp 2026-11-27]; NVIDIA device plugin (używany tu wcześniej). Kiedy co innego: karta NVIDIA → plugin/operator NVIDIA; brak GPU → transkodowanie na CPU [wniosek].

### Descheduler

- CronJob w `kube-system` co 4 godziny, profil `LowNodeUtilization` na rzeczywistym zużyciu (`KubernetesMetrics`), progi 50% / 80% [plik `Kubernetes/apps/descheduler/policy-configmap.yaml`], [plik `Kubernetes/apps/descheduler/cronjob.yaml`].
- Od [commit `1fffc31`, 2026-06-27]; przejście na metryki zamiast requestów [commit `ae206b4`, 2026-06-28]. Wcześniej nic nie wyrównywało obciążenia [wniosek].
- Projekt SIG Scheduling, Apache-2.0; „finds pods that can be moved and evicts them”, a nowe miejsce wybiera domyślny scheduler [źródło: https://github.com/kubernetes-sigs/descheduler, dostęp 2026-11-27].
- Ograniczenie: tylko wyrzuca pody, a przy trzech węzłach i podach `Recreate` z wolumenami RWO każda eksmisja to przerwa w usłudze [wniosek].

### metrics-server

- Chart 3.14.0, 2 repliki, `--kubelet-insecure-tls` i preferowane adresy InternalIP („Talos-friendly kubelet args”) [plik `Kubernetes/bootstrap/metrics-server/kustomization.yaml`], [commit `fe74ed3`, 2026-02-28].
- Służy do `kubectl top` i jako źródło danych dla descheduler'a [commit `fe74ed3`], [plik `Kubernetes/apps/descheduler/policy-configmap.yaml`].
- Ograniczenie z dokumentacji: „meant only for autoscaling purposes”, a nie jako dokładne źródło zużycia zasobów; do monitoringu służy scrapowanie kubeleta [źródło: https://github.com/kubernetes-sigs/metrics-server, dostęp 2026-11-27]. W tym repo monitoring robi osobny stos (Mimir/Loki) [plik `README.md`].

## 9. Najważniejsze wnioski do rozdziału „Technologie”

1. Platforma przeszła pięć stadiów: Linux bez hypervisora + compose → Proxmox VE 8 z Dockerem w VM (najpóźniej 2025-03) → Proxmox + LXC + k3s → Proxmox + VM + Talos → to samo bez publicznej bramy w chmurze [§1].
2. Jedyny zapisany motyw zmiany systemu węzłów to „immutable, API-driven” w miejsce „manual configuration” [commit `bc91666`]. Resztę motywów trzeba potwierdzić u autora.
3. Trzy control plane'y na jednym hoście chronią przed awarią VM, ale awaria sprzętu wyłącza cały klaster, co rozdział o odtwarzaniu po awarii musi uwzględnić [wniosek].
4. Większość opisanych ograniczeń powstała na stykach warstw: hypervisor i etcd (ZFS txg), hypervisor i NFS, IOMMU i GPU, Talos i kubelet [wniosek z Key Gotchas].
5. Dostawcy zmieniają warunki jednostronnie: Oracle obciął darmowy limit (2026-06), Broadcom zmienił licencje VMware (2023-2025), HashiCorp przeszedł na BSL (2023). Praca może to wykorzystać jako argument za repatriacją i otwartymi licencjami [wniosek ze źródeł].

## Pytania do autora

1. Kiedy dokładnie (między 2024-01 a 2025-03) i dlaczego serwer przeszedł z Linuksa bez hypervisora na Proxmox VE? Czy zmiany licencyjne VMware/Broadcom albo inne hypervisory (XCP-ng, ESXi) brały udział w decyzji?
2. Dlaczego w 2025-08 przeniosłeś usługi z docker-compose na Kubernetes (k3s)? Nauka, praca inżynierska, HA, GitOps?
3. Kiedy i dlaczego wymieniłeś GPU z NVIDIA na Intel Arc B580? Jaka to była karta NVIDIA?
4. Czy `carbon` przeszedł z i5-12600K / 32 GB (README z 2025-03) na Ryzen 9 3950X / 64 GB (plan migracji z 2025-12, spec energii z 2026-06)? Kiedy i dlaczego? README na `main` nadal podaje i5. Jaka jest dokładna wersja Proxmox VE (PVE 8 ma EOL od 2026-08)?
5. `compute` ma w `oracle.tf` 4 OCPU / 24 GB, a dokumentacja Oracle podaje od 2026-06-15 darmowy limit A1 2 OCPU / 12 GB dla wszystkich kont. Jakiego typu jest konto (Always Free czy PAYG), co pokazuje rozliczenie od czerwca i czy alert budżetowy się uruchomił?
6. Co działało między 2025-12-17 (usunięcie kodu k3s) a 2026-02-01 (Talos w Terraformie)? Czy stary k3s działał dalej bez kodu w repo?
7. Czy w erze k3s VPS Oracle był agentem klastra (Flannel po `tailscale0`, grupa `agent`), czy klaster był tylko w LXC `nickel`?
8. Dlaczego wybrałeś Talosa, a nie np. k3s w VM z Ubuntu, Flatcar lub RKE2? Czy porównywałeś je przed migracją?
9. Dlaczego trzy węzły control-plane na jednym hoście, a nie jeden węzeł? Rolling upgrade, nauka HA, Longhorn z replikami?

## Do której części pracy

- Technologie: §3-§8 (opisy, tabele alternatyw, licencje, ograniczenia).
- Projekt: §2 (sprzęt), §4-§5 (podział na węzły, VIP, GPU), §9 punkt 3 (granice HA).
- Implementacja: §1 (oś czasu), §3-§4 (Terraform/Ansible dla Proxmoxa i Talosa, bramki aktualizacji), ograniczenia z repo jako studia przypadków.
- Odtwarzanie po awarii: §3 (ręczne kroki poza kodem: instalacja PVE, mapowanie PCI), §4 (bramka Longhorna, `talos_upgrade_gates=false` przy budowie od zera), §9 punkt 3.
- Analiza kosztów: §2 (pobór mocy), §3 (koszt subskrypcji i licencji alternatyw), §7 (zmiana Always Free, ceny VPS).

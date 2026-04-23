# Benchmark Services & Outils — RP-01 IRIS Nice

**Objectif :** Justification technique des choix technologiques par comparaison avec les alternatives

---

## 1. Serveur d'authentification RADIUS

### Choix retenu : **Microsoft NPS (Network Policy Server)**

| Critère | **NPS** ✅ | FreeRADIUS | Cisco ISE |
|---|---|---|---|
| Intégration AD | Native — aucune config LDAP | LDAP externe requis | Native (mais Cisco-only) |
| Installation | Rôle Windows inclus (NPAS) | Paquet Linux à installer | Appliance dédiée |
| Interface de gestion | GUI MMC + PowerShell | Fichiers de config texte | Web GUI complète |
| Logs | Event Viewer Windows (standard) | /var/log/freeradius/ | Dashboard complet |
| Coût | Inclus dans Windows Server | Gratuit (open source) | 15 000–50 000 € |
| Compétences requises | Administrateur Windows | Linux + RADIUS avancé | Ingénieur Cisco certifié |
| Haute disponibilité | NPS proxy + NPS secondaire | Redondance manuelle | Intégrée |
| Support 802.1X | ✅ EAP-MSCHAPv2, PEAP | ✅ EAP complet | ✅ EAP complet |
| Attributs VLAN (RFC 3580) | ✅ Tunnel Attributes | ✅ | ✅ |
| **Score projet** | **9/10** | 7/10 | 8/10 |

**Justification** : NPS est natif à Windows Server 2022, s'intègre directement avec l'AD sans configuration LDAP supplémentaire. Tous les logs sont dans l'Event Viewer, standard pour un SI Windows. Cisco ISE est trop coûteux pour un établissement scolaire. FreeRADIUS nécessiterait une VM Linux dédiée et une configuration LDAP complexe.

---

## 2. Annuaire d'identités

### Choix retenu : **Microsoft Active Directory Domain Services (AD DS)**

| Critère | **AD DS** ✅ | OpenLDAP | FreeIPA | Azure AD |
|---|---|---|---|---|
| Intégration Windows | Native | Via SSSD/Winbind | Via Samba | Native |
| Intégration NPS/RADIUS | Native | Configuration LDAP | Configuration RADIUS | Azure NPS Extension |
| Interface de gestion | ADUC, ADAC, PowerShell | ldapvi, Apache DS | Web UI | Portail Azure |
| GPO (Group Policies) | ✅ Complet | ❌ | Partiel | ✅ Intune |
| Fine-Grained Password | ✅ PSO | ❌ | ✅ | ✅ |
| Coût | Inclus dans Windows Server | Gratuit | Gratuit | Abonnement mensuel |
| Complexité déploiement | Moyenne (wizards) | Élevée (LDIF) | Moyenne | Faible (cloud) |
| Applicable en lab Vagrant | ✅ | ✅ | ✅ | ❌ (cloud) |
| **Score projet** | **10/10** | 6/10 | 7/10 | 5/10 |

**Justification** : AD DS est le standard en entreprise. Le projet répond à un besoin réel de l'école IRIS — une infrastructure 100% compatible avec les équipements Cisco existants et les outils Windows. NPS ne peut pas s'intégrer nativement avec OpenLDAP sans une couche de configuration supplémentaire.

---

## 3. Automatisation / Infrastructure as Code

### Choix retenu : **Vagrant + VirtualBox**

| Critère | **Vagrant + VirtualBox** ✅ | Ansible seul | Terraform | Docker (VMs) |
|---|---|---|---|---|
| Provisionne VMs | ✅ | ✅ (via cloud/VMware) | ✅ (cloud) | ❌ (conteneurs) |
| Scripts PowerShell natifs | ✅ | Via WinRM | ❌ | ❌ |
| Reproductibilité | ✅ `vagrant destroy && up` | Partielle | ✅ | ✅ |
| Courbe d'apprentissage | Faible (Vagrantfile Ruby DSL) | Moyenne (YAML) | Élevée (HCL) | Faible |
| Adapté lab local | ✅ | ✅ | ❌ (cloud-oriented) | ❌ |
| Windows Server support | ✅ | Partiel | Via providers | ❌ |
| Coût | Gratuit | Gratuit | Gratuit / Cloud payant | Gratuit |
| Gestion réseau VMs | ✅ NAT + host-only + intnet | Dépend du provider | Dépend du provider | Bridge/overlay |
| **Score projet** | **9/10** | 6/10 | 4/10 | 3/10 |

**Justification** : Vagrant permet de décrire l'infrastructure complète (2 VMs, réseau, provisioners) dans un seul fichier. La commande `vagrant up` recrée l'environnement entier de zéro. Essentiel pour la reproductibilité du PoC et la démonstration à l'oral.

---

## 4. Helpdesk / Gestion de parc

### Choix retenu : **GLPI** (Gestionnaire Libre de Parc Informatique)

| Critère | **GLPI** ✅ | OTRS/ZNUNY | ServiceNow | iTop |
|---|---|---|---|---|
| Licence | GPL (gratuit) | GPL (gratuit) | Commercial (très coûteux) | AGPL (gratuit) |
| Gestion d'inventaire | ✅ Complète (FusionInventory) | ❌ | ✅ | ✅ |
| Ticketing ITIL | ✅ | ✅ | ✅ | ✅ |
| Intégration LDAP/AD | ✅ | ✅ | ✅ | ✅ |
| Image Docker disponible | ✅ diouxx/glpi | Limitée | ❌ | ✅ |
| Langue française | ✅ | ✅ | ✅ | ✅ |
| Communauté francophone | ✅ Très active | Faible | — | Moyenne |
| Adapté PME/école | ✅ | ✅ | ❌ (enterprise) | ✅ |
| **Score projet** | **9/10** | 6/10 | 3/10 | 7/10 |

**Justification** : GLPI est le standard de facto en France pour la gestion de parc scolaire/PME. Gratuit, en français, avec une forte communauté. L'intégration LDAP avec AD permet aux utilisateurs de se connecter avec leurs comptes mediaschool.local.

> **Note** : L'image Docker officielle GLPI n'existait pas au moment de la conception. L'image `diouxx/glpi` est la plus utilisée et maintenue par la communauté. En production, une installation native sur Debian serait recommandée.

---

## 5. Stockage collaboratif

### Choix retenu : **Nextcloud**

| Critère | **Nextcloud** ✅ | OwnCloud | SharePoint | Google Drive |
|---|---|---|---|---|
| Hébergement | ✅ On-premise | ✅ On-premise | On-premise/cloud | Cloud uniquement |
| Licence | AGPL (gratuit) | AGPL / Commercial | Commercial | Freemium |
| Intégration LDAP/AD | ✅ | ✅ | ✅ Native | ❌ |
| Applications mobiles | ✅ | ✅ | ✅ | ✅ |
| Collaboration documents | ✅ OnlyOffice/Collabora | Limitée | ✅ Office 365 | ✅ Google Docs |
| Image Docker | ✅ Officielle | ✅ | ❌ | ❌ |
| Confidentialité RGPD | ✅ | ✅ | Risques cloud | ❌ |
| Coût annuel 100 users | 0 € | 0 € / 3 600 € | ~6 000 € | ~1 200 € |
| **Score projet** | **9/10** | 7/10 | 6/10 | 4/10 |

**Justification** : Nextcloud est la solution de référence open source pour le stockage on-premise. La protection des données pédagogiques (RGPD) impose un hébergement sur site. L'image Docker officielle est maintenue et stable. L'authentification LDAP permet aux étudiants d'accéder avec leur compte AD.

---

## 6. Supervision / Monitoring

### Choix retenu : **Prometheus + Grafana**

| Critère | **Prometheus + Grafana** ✅ | Zabbix | Nagios | Datadog |
|---|---|---|---|---|
| Architecture | Pull (scraping) | Pull/Push | Pull | Agent |
| Alerting | AlertManager | Intégré | Intégré | Intégré |
| Visualisation | Grafana (dashboards riches) | Intégrée (basique) | Plugins payants | Intégrée |
| Métriques Docker | ✅ cAdvisor | ✅ | Plugins | ✅ |
| Métriques système | ✅ Node Exporter | ✅ Agent | ✅ NRPE | ✅ Agent |
| Image Docker | ✅ Officielles | ✅ | ✅ | Agent seulement |
| Coût | Gratuit | Gratuit / Enterprise | Gratuit / XI payant | 15$/host/mois |
| Scalabilité | ✅ Horizontal | Moyenne | Limitée | ✅ |
| **Score projet** | **9/10** | 8/10 | 6/10 | 5/10 |

**Justification** : Le duo Prometheus/Grafana est devenu le standard de l'industrie pour la supervision cloud-native et conteneurisée. cAdvisor expose les métriques de chaque conteneur Docker. Node Exporter expose les métriques de l'OS Ubuntu. Grafana permet de créer des dashboards visuels sans agent supplémentaire.

---

## 7. VPN Administration

### Choix retenu : **WireGuard**

| Critère | **WireGuard** ✅ | OpenVPN | IPSec/IKEv2 | Cisco AnyConnect |
|---|---|---|---|---|
| Performances | ✅ Excellent (kernel) | Moyen | Bon | Bon |
| Configuration | Simple (clés publiques) | Complexe | Très complexe | Simple (client) |
| Protocole | UDP uniquement | TCP/UDP | UDP | SSL/TLS |
| Image Docker | ✅ linuxserver/wireguard | ✅ | ❌ | ❌ |
| Interface Web (wg-easy) | ✅ :51821 | ❌ natif | ❌ natif | ✅ |
| Coût | Gratuit | Gratuit | Gratuit | Licence Cisco |
| Clients | Windows, Linux, macOS, Android, iOS | Tous | Tous | Tous |
| Audit sécurité | ✅ Code minimaliste audité | Complexe | Standard | Propriétaire |
| **Score projet** | **9/10** | 7/10 | 6/10 | 4/10 |

**Justification** : WireGuard offre les meilleures performances avec une base de code minimaliste (4 000 lignes vs 600 000 pour OpenVPN). L'interface wg-easy permet une gestion graphique des peers VPN. Idéal pour l'accès administrateur distant au VLAN 50 Management.

---

## 8. Antivirus

### Choix retenu : **ClamAV**

| Critère | **ClamAV** ✅ | Sophos | Malwarebytes | Windows Defender |
|---|---|---|---|---|
| Plateforme | Linux | Linux/Windows | Windows | Windows |
| Licence | GPL (gratuit) | Commercial | Commercial | Inclus Windows |
| Image Docker | ✅ clamav/clamav | ❌ | ❌ | ❌ |
| Intégration Nextcloud | ✅ Plugin ICAP | Possible | ❌ | ❌ |
| Mise à jour signatures | Automatique (freshclam) | Automatique | Automatique | Automatique |
| RAM requise | ⚠️ ~1.5–2 GB min | ~512 MB | ~512 MB | Inclus OS |
| Détection | Correcte (open source) | Excellente | Excellente | Bonne |
| **Score projet** | **7/10** | 8/10 | 7/10 | N/A (Linux) |

> ⚠️ **Limite lab** : ClamAV nécessite ~1.5 GB RAM minimum. La VM srv-linux n'a que 2 GB total → le conteneur ClamAV redémarre (exit code 11). En production, srv-linux doit avoir ≥ 4 GB RAM.

**Justification** : ClamAV est la seule solution antivirus open source avec image Docker officielle. Son plugin ICAP permet d'analyser les fichiers uploadés sur Nextcloud en temps réel. Pour un environnement de production, Sophos Intercept X for Linux serait plus efficace.

---

## 9. Orchestration de conteneurs

### Choix retenu : **Docker Compose**

| Critère | **Docker Compose** ✅ | Kubernetes (K8s) | Docker Swarm | Podman Compose |
|---|---|---|---|---|
| Complexité | Faible (YAML simple) | Très élevée | Moyenne | Faible |
| Adapté à 1 serveur | ✅ | ❌ (multi-nodes) | ✅ | ✅ |
| Haute disponibilité | ❌ | ✅ | ✅ | ❌ |
| Orchestration avancée | ❌ | ✅ | Partielle | ❌ |
| Courbe d'apprentissage | Faible | Très élevée | Moyenne | Faible |
| Ressources requises | Minimales | CPU/RAM important | Faibles | Minimales |
| Adapté lab PoC | ✅ | ❌ | ✅ | ✅ |
| **Score projet** | **10/10** | 4/10 | 7/10 | 8/10 |

**Justification** : Pour un PoC sur un seul serveur, Docker Compose est la solution optimale. La configuration complète de 10 services tient dans un seul fichier `docker-compose.yml`. Un `docker compose up -d` recrée toute l'infrastructure applicative. Kubernetes serait surdimensionné et nécessiterait plusieurs nœuds.

---

## 10. Récapitulatif des scores

| Technologie retenue | Score | Alternative principale | Score alt. | Économie |
|---|---|---|---|---|
| NPS (RADIUS) | 9/10 | FreeRADIUS | 7/10 | Intégration native AD |
| AD DS | 10/10 | OpenLDAP | 6/10 | GPO + NPS natif |
| Vagrant + VirtualBox | 9/10 | Ansible seul | 6/10 | Reproductibilité totale |
| GLPI | 9/10 | iTop | 7/10 | 0 € vs 0 € |
| Nextcloud | 9/10 | OwnCloud | 7/10 | RGPD compliant |
| Prometheus + Grafana | 9/10 | Zabbix | 8/10 | Docker-natif |
| WireGuard | 9/10 | OpenVPN | 7/10 | Perf + simplicité |
| ClamAV | 7/10 | Sophos | 8/10 | 0 € (lab) |
| Docker Compose | 10/10 | Kubernetes | 4/10 | Adapté 1-serveur PoC |

**Budget solution retenue : 0 € logiciel** (hors licences Windows Server incluses dans l'environnement scolaire)

---

## 11. Ressources consommées (lab Vagrant)

| VM | RAM allouée | RAM utilisée | CPU | Disque |
|---|---|---|---|---|
| DC-IRIS-01 (Windows Server 2022) | 4 096 MB | ~2 500 MB | 2 vCPU | 50 GB |
| SRV-LINUX-IRIS (Ubuntu 22.04) | 2 048 MB | ~1 800 MB | 2 vCPU | 20 GB |
| **Total lab** | **6 144 MB** | ~4 300 MB | 4 vCPU | 70 GB |

### Consommation par service Docker

| Service | RAM typique | CPU typique | Notes |
|---|---|---|---|
| GLPI | ~256 MB | < 5% | Pic au démarrage |
| Nextcloud | ~300 MB | < 5% | Pic sur upload |
| Grafana | ~150 MB | < 2% | Léger |
| Prometheus | ~200 MB | < 3% | Dépend des métriques |
| MariaDB (GLPI) | ~150 MB | < 2% | — |
| MariaDB (NC) | ~150 MB | < 2% | — |
| Node Exporter | ~20 MB | < 1% | Très léger |
| cAdvisor | ~80 MB | < 2% | — |
| WireGuard | ~30 MB | < 1% | — |
| ClamAV | ~1 500 MB | Variable | ⚠️ Trop lourd en lab |
| **Total (sans ClamAV)** | **~1 336 MB** | ~20% | Correct pour 2 GB VM |

---


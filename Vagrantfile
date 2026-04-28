# -*- mode: ruby -*-
# Vagrantfile — IRIS Nice RP01 — Infrastructure Windows Server 2022 + Ubuntu Docker
# Référence : IRIS-NICE-2024-RP01 — BTS SIO SISR — Épreuve E5
# Auteur : Nedjmeddine Belloum
#
# ARCHITECTURE RÉSEAU :
#   PC (USB Ethernet) ──── SW2-IRIS Gi0/1 (trunk, native VLAN 50)
#   Toutes les VMs utilisent un NIC bridgé sur cet adaptateur :
#   - vm-routeur  : 192.168.50.1 + SVIs VLANs 10/20/30/40/99 (remplace RT2-IRIS)
#   - dc-iris     : 192.168.50.10 (AD DS / DHCP / NPS)
#   - srv-linux   : 192.168.50.20 (GLPI, Nextcloud, monitoring)
#
# PRÉREQUIS : Câble RJ45 PC → SW2-IRIS Gi0/1 (port trunk)

BRIDGED_ADAPTER = "USB2.0 Ethernet Adapter"

Vagrant.configure("2") do |config|

  # Timeout SSH étendu pour les provisioners longs (apt upgrade, Docker install)
  config.ssh.insert_key  = true
  config.vm.boot_timeout = 600
  # ────────────────────────────────────────────────────
  # VM 1 : Windows Server 2022 — Contrôleur de domaine
  # Rôles : AD DS, DNS, DHCP, NPS
  # IP fixe : 192.168.50.10 (VLAN 50 Management)
  # ────────────────────────────────────────────────────
  config.vm.define "dc-iris" do |dc|
    dc.vm.box      = "gusztavvargadr/windows-server-2022-standard"
    dc.vm.hostname = "DC-IRIS-01"

    # WinRM — après promotion AD, vagrant devient compte domaine MEDIASCHOOL\vagrant
    dc.vm.communicator      = "winssh"  if false  # désactivé, on garde winrm
    dc.winrm.username       = "vagrant"
    dc.winrm.password       = "vagrant"
    dc.winrm.transport      = :negotiate
    dc.winrm.basic_auth_only = false
    dc.vm.boot_timeout      = 600

    # RDP accessible depuis l'hôte sur localhost:13389
    dc.vm.network "forwarded_port", guest: 3389, host: 13389, id: "rdp"

    dc.vm.provider "virtualbox" do |vb|
      vb.name   = "DC-IRIS-01"
      vb.memory = 4096
      vb.cpus   = 2
      vb.gui    = true
      vb.customize ["modifyvm", :id, "--vram",        "128"]
      vb.customize ["modifyvm", :id, "--clipboard",   "bidirectional"]
      vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
      # NIC2 bridgé sur USB Ethernet (réseau physique IRIS, VLAN 50 natif)
      # IP 192.168.50.10 configurée dans Windows — visible depuis SW2-IRIS
      vb.customize ["modifyvm", :id, "--nic2", "bridged",
                    "--bridgeadapter2", BRIDGED_ADAPTER]
    end

    # ── Provisioning séquentiel ──
    # run: "always"  = exécuté à chaque `vagrant up`
    # run: "never"   = manuel via `vagrant provision --provision-with <name>`
    #                  (nécessaire après redémarrages induits par les scripts)

    # Étape 1 : Installation des rôles + redémarrage automatique
    dc.vm.provision "01_install_roles",
      type: "shell",
      path: "scripts/01_install_roles.ps1"

    # Étape 2 : Promotion AD DS + redémarrage automatique
    dc.vm.provision "02_configure_ad",
      type: "shell",
      path: "scripts/02_configure_ad.ps1",
      run: "never"

    # Étape 3 : Configuration DHCP (après promotion AD)
    dc.vm.provision "03_configure_dhcp",
      type: "shell",
      path: "scripts/03_configure_dhcp.ps1",
      run: "never"

    # Étape 4 : Configuration NPS/RADIUS
    dc.vm.provision "04_configure_nps",
      type: "shell",
      path: "scripts/04_configure_nps.ps1",
      run: "never"

    # Étape 5 : Création OUs, groupes et utilisateurs AD
    dc.vm.provision "05_create_users",
      type: "shell",
      path: "scripts/05_create_users.ps1",
      run: "never"

    # Étape 6 : Application des GPO de sécurité
    dc.vm.provision "06_configure_gpo",
      type: "shell",
      path: "scripts/06_configure_gpo.ps1",
      run: "never"
  end

  # ────────────────────────────────────────────────────
  # VM 3 : Windows 11 Enterprise — Poste client test
  # Rôle  : Jonction domaine mediaschool.local + tests utilisateurs
  # IP fixe : 192.168.50.30 (VLAN 50 Management lab)
  # Comptes test : étudiant / professeur / admin
  # Fix automatique : scripts/00_fix_win11_box.ps1 corrige l'incompatibilité
  #   OVF ResourceType 32768 (NVMe) avec VirtualBox 7.1.x avant import
  # ────────────────────────────────────────────────────
  config.vm.define "client-win11", autostart: false do |client|
    client.vm.box         = "gusztavvargadr/windows-11-23h2-enterprise"
    client.vm.box_version = "2509.0.0"
    client.vm.hostname    = "PC-CLIENT-IRIS"

    client.winrm.username        = "vagrant"
    client.winrm.password        = "vagrant"
    client.winrm.transport       = :negotiate
    client.winrm.basic_auth_only = false
    client.vm.boot_timeout       = 600

    # RDP accessible depuis l'hôte sur localhost:13389 (partagé avec dc-iris si les deux tournent)
    client.vm.network "forwarded_port",
      guest: 3389,
      host:  13389,
      id:    "rdp"

    client.vm.provider "virtualbox" do |vb|
      vb.name   = "PC-CLIENT-IRIS"
      vb.memory = 4096
      vb.cpus   = 2
      vb.gui    = true
      vb.customize ["modifyvm", :id, "--vram",        "128"]
      vb.customize ["modifyvm", :id, "--clipboard",   "bidirectional"]
      vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
      # NIC2 bridgé sur USB Ethernet — visible depuis SW2-IRIS
      # IP 192.168.50.30 configurée dans Windows lors du provisioning initial
      vb.customize ["modifyvm", :id, "--nic2", "bridged",
                    "--bridgeadapter2", BRIDGED_ADAPTER]
    end

    # ── Trigger : télécharge et patche le box avant import ──────────────────
    # Corrige l'erreur VBoxManage "Unknown resource type 32768" (NVMe OVF)
    # incompatible avec VirtualBox 7.1.x — exécuté une seule fois automatiquement
    client.trigger.before :up do |t|
      t.name = "Fix Win11 OVF — VirtualBox 7.1 compatibility"
      t.run  = {
        inline: "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\00_fix_win11_box.ps1"
      }
    end

    # Étape 1 : Préparation + DNS + jonction domaine + redémarrage
    client.vm.provision "07_join_domain",
      type: "shell",
      path: "scripts/07_configure_client.ps1"

    # Étape 2 : Post-jonction — raccourcis, navigateur configuré (run: never = après reboot manuel)
    client.vm.provision "08_post_join",
      type: "shell",
      path: "scripts/08_post_join_client.ps1",
      run: "never"
  end

  # ────────────────────────────────────────────────────
  # VM 2 : Ubuntu 22.04 LTS — Services applicatifs Docker
  # Services : GLPI, Nextcloud, WireGuard, Grafana, Prometheus, ClamAV
  # IP fixe : 192.168.50.20 (VLAN 50 Management)
  # ────────────────────────────────────────────────────
  config.vm.define "srv-linux" do |linux|
    linux.vm.box      = "ubuntu/jammy64"
    linux.vm.hostname = "SRV-LINUX-IRIS"

    linux.vm.provider "virtualbox" do |vb|
      vb.name   = "SRV-LINUX-IRIS"
      vb.memory = 2048
      vb.cpus   = 2
      # NIC2 bridgé sur USB Ethernet (réseau physique IRIS, VLAN 50 natif)
      # IP 192.168.50.20 configurée dans Ubuntu — visible depuis SW2-IRIS
      vb.customize ["modifyvm", :id, "--nic2", "bridged",
                    "--bridgeadapter2", BRIDGED_ADAPTER]
    end

    linux.vm.provision "shell",
      path: "scripts/linux_docker_services.sh"
  end

  # ────────────────────────────────────────────────────
  # VM ROUTEUR : Ubuntu 22.04 — Remplace RT2-IRIS
  # Rôle  : Routage inter-VLAN (Router-on-a-Stick via Gi0/1 trunk)
  # IP    : 192.168.50.1 (VLAN 50 natif) + 192.168.x.1 (VLANs 10/20/30/40/99)
  # ────────────────────────────────────────────────────
  config.vm.define "vm-routeur" do |router|
    router.vm.box      = "ubuntu/jammy64"
    router.vm.hostname = "VM-ROUTEUR-IRIS"

    router.vm.provider "virtualbox" do |vb|
      vb.name   = "VM-ROUTEUR-IRIS"
      vb.memory = 512
      vb.cpus   = 1
      vb.gui    = false
      # NIC2 bridgé : reçoit le trunk Gi0/1 (native VLAN 50 + tagged 10/20/30/40/99)
      vb.customize ["modifyvm", :id, "--nic2", "bridged",
                    "--bridgeadapter2", BRIDGED_ADAPTER]
      # Promiscuous mode pour traiter les trames VLAN taggées
      vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    end

    router.vm.provision "shell", path: "scripts/router_vlan.sh"
  end

end

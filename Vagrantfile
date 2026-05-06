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

    # Étape préparatoire : prépare DC-IRIS-01 pour accueillir DC-IRIS-02 (PCRA)
    # run: "never" — à exécuter AVANT de lancer dc-iris-backup
    dc.vm.provision "dc1_prepare_pcra",
      type: "shell",
      path: "DC-backup/scripts/dc1_prepare_pcra.ps1",
      run: "never"

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
  # VM 2 : Ubuntu 22.04 LTS— Services applicatifs Docker
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

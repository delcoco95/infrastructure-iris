# -*- mode: ruby -*-
# Vagrantfile — IRIS Nice RP01 — Infrastructure Windows Server 2022 + Ubuntu Docker
# Référence : IRIS-NICE-2024-RP01 — BTS SIO SISR — Épreuve E5
# Auteur : Nedjmeddine Belloum

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

    dc.vm.network "private_network",
      ip: "192.168.50.10",
      netmask: "255.255.255.0",
      virtualbox__intnet: "vlan_management"

    dc.vm.provider "virtualbox" do |vb|
      vb.name   = "DC-IRIS-01"
      vb.memory = 4096
      vb.cpus   = 2
      vb.gui    = true
      vb.customize ["modifyvm", :id, "--vram",      "128"]
      vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
      vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
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
  # VM 2 : Ubuntu 22.04 LTS — Services applicatifs Docker
  # Services : GLPI, Nextcloud, WireGuard, Grafana, Prometheus, ClamAV
  # IP fixe : 192.168.50.20 (VLAN 50 Management)
  # ────────────────────────────────────────────────────
  config.vm.define "srv-linux" do |linux|
    linux.vm.box      = "ubuntu/jammy64"
    linux.vm.hostname = "SRV-LINUX-IRIS"

    linux.vm.network "private_network",
      ip: "192.168.50.20",
      netmask: "255.255.255.0",
      virtualbox__intnet: "vlan_management"

    linux.vm.provider "virtualbox" do |vb|
      vb.name   = "SRV-LINUX-IRIS"
      vb.memory = 2048
      vb.cpus   = 2
    end

    linux.vm.provision "shell",
      path: "scripts/linux_docker_services.sh"
  end

end

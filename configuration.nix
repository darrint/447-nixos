# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.hostName = "nixbox";
  networking.domain = "teamroboto.lan";
  networking.nameservers = [ "172.16.0.5" ];
  # AD needs DC DNS only: DHCP hands out public resolvers that NXDOMAIN SRV lookups for .lan
  networking.networkmanager.dns = "none";
  networking.search = [ "teamroboto.lan" ];

  # Static IP (replaces DHCP on ens3)
  networking.networkmanager.ensureProfiles.profiles."static-ens3" = {
    connection = {
      id = "static-ens3";
      type = "ethernet";
      interface-name = "ens3";
      autoconnect-priority = 100;
    };
    ipv4 = {
      method = "manual";
      address1 = "172.16.0.6/24,172.16.0.1";
      dns = "172.16.0.5;";
      dns-search = "teamroboto.lan;";
    };
    ipv6.method = "auto";
  };

  # Kerberos
  security.krb5 = {
    enable = true;
    settings = {
      libdefaults = {
        default_realm = "TEAMROBOTO.LAN";
        dns_lookup_realm = false;
        dns_lookup_kdc = true;
        rdns = false;
      };
      realms."TEAMROBOTO.LAN" = {
        kdc = [ "dc1.teamroboto.lan" ];
        admin_server = "dc1.teamroboto.lan";
      };
      domain_realm = {
        ".teamroboto.lan" = "TEAMROBOTO.LAN";
        "teamroboto.lan" = "TEAMROBOTO.LAN";
      };
    };
  };

  # SSSD
  services.sssd = {
    enable = true;
    config = ''
      [sssd]
      services = nss, pam
      config_file_version = 2
      domains = teamroboto.lan

      [domain/teamroboto.lan]
      id_provider = ad
      auth_provider = ad
      access_provider = ad
      chpass_provider = ad
      ad_domain = teamroboto.lan
      ad_server = dc1.teamroboto.lan
      ad_hostname = nixbox.teamroboto.lan
      krb5_realm = TEAMROBOTO.LAN
      ad_gpo_access_control = permissive
      ldap_id_mapping = true
      cache_credentials = true
      use_fully_qualified_names = false
      fallback_homedir = /home/%u
      default_shell = /run/current-system/sw/bin/bash
    '';
  };

  # Create home folders on first login
  security.pam.services.login.makeHomeDir = true;
  security.pam.services.sshd.makeHomeDir = true;
  security.pam.services.sddm.makeHomeDir = true;

  # sssd's AD backend can miss its start-up window at boot ("Providers did not start in time").
  # The module's default Restart=on-abnormal doesn't cover that exit (status 1), so force on-failure.
  systemd.services.sssd.serviceConfig = {
    Restart = pkgs.lib.mkForce "on-failure";
    RestartSec = "10s";
  };

  # AD "Domain Admins" get sudo (matched by GID; the name has a space and the GID is SID-derived, so stable)
  security.sudo.extraRules = [
    {
      groups = [ 1769200512 ]; # TEAMROBOTO\Domain Admins
      commands = [ { command = "ALL"; options = [ "SETENV" ]; } ];
    }
  ];

  environment.systemPackages = with pkgs; [ adcli krb5 sssd ];

  # Set your time zone.
  time.timeZone = "America/Indiana/Indianapolis";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."admin" = {
    isNormalUser = true;
    description = "admin";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?
  services.openssh = {
  	enable = true;
	settings = {
		PasswordAuthentication = true;
		PermitRootLogin = "no";
	};
  };
}


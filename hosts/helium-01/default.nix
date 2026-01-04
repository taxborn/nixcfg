{ self, pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.btrfs-helium-01
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "helium-01";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  services.caddy = {
    enable = true;
  };

  services.paperless = {
    enable = true;
    consumptionDirIsPublic = true;
    address = "0.0.0.0";
    settings = {
      PAPERLESS_CONSUMER_IGNORE_PATTERN = [
        ".DS_STORE/*"
        "desktop.ini"
      ];
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_OCR_USER_ARGS = {
        optimize = 1;
        pdfa_image_compression = "lossless";
      };
      PAPERLESS_URL = "https://docs.mischief.town";
    };
    domain = "docs.mischief.town";
    port = 21594;
  };

  environment.systemPackages = with pkgs; [
    jdk21_headless
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  myNixOS = {
    base.enable = true;
    profiles.btrfs.enable = true;
    programs = {
      nix.enable = true;
      # lanzaboote.enable = true;
      yubikey.enable = true;
    };
    services = {
      tailscale = {
        enable = true;
        operator = "taxborn";
      };
      backups = {
        enable = true;
        repository = "ssh://de4388@de4388.rsync.net/./borg-repos/helium-01";
      };
    };
  };

  myHardware = {
    intel.cpu.enable = true;
    profiles.ssd.enable = true;
  };

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}

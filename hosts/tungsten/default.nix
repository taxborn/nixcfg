{
  config,
  self,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./backup.nix
    ./hardware-configuration.nix
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.luks-btrfs-tungsten
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.11";

  myHardware = {
    intel.cpu.enable = true;
    nvidia.gpu.enable = true;
    profiles.ssd.enable = true;
  };

  # TODO: move to yubikey module
  services.udev = {
    packages = [ pkgs.yubikey-personalization ];
  };

  services.pcscd.enable = true;

  myNixOS = {
    base.enable = true;
    desktop = {
      enable = true;
      hyprland = {
        enable = true;
        laptopMonitor = "eDP-1,3456x2160@60,0x0,2";
      };
    };
    profiles = {
      btrfs.enable = true;
    };
    programs = {
      firefox.enable = true;
      nix.enable = true;
      lanzaboote.enable = true;
    };
    services = {
      sddm.enable = true;
      tailscale = {
        enable = true;
        operator = "taxborn";
      };
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.libinput.enable = true;

  environment.systemPackages = with pkgs; [
    brightnessctl
    pavucontrol
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}

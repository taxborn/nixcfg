{ config, lib, ... }:

let
  cfg = config.homelab.ovh;
in
{
  options.homelab.ovh = {
    ipv6 = {
      address = lib.mkOption {
        type = lib.types.nonEmptyStr;
        example = "2604:2dc0:202:300::236a";
        description = ''
          Public IPv6 address, without a prefix length. OVH assigns a single
          /128 whose gateway sits outside it, so the gateway is reached through
          an explicit on-link route rather than by sharing a subnet.

          Read the instance's own allocation back with:
            curl -s http://169.254.169.254/openstack/latest/network_data.json
        '';
      };

      gateway = lib.mkOption {
        type = lib.types.nonEmptyStr;
        example = "2604:2dc0:202:300::1";
        description = "IPv6 gateway, per the instance's `network_data.json`.";
      };

      interface = lib.mkOption {
        type = lib.types.str;
        default = "ens3";
        description = "Interface carrying the public address.";
      };

      ipv4Method = lib.mkOption {
        type = lib.types.enum [
          "auto"
          "disabled"
        ];
        default = "auto";
        description = ''
          `ipv4.method` for the profile below. Some OVH instances put IPv6 on a
          dedicated second NIC (argon: ens3 carries IPv4, ens4 carries IPv6),
          where this must be "disabled" so the profile does not chase a DHCP
          lease that will never arrive on a v6-only link.
        '';
      };
    };
  };

  config = lib.mkMerge [
    {
      boot.initrd.availableKernelModules = [
        "ata_piix"
        "uhci_hcd"
        "virtio_pci"
        "virtio_scsi"
      ];

      boot.kernelModules = [
        "tcp_bbr"
        "sch_fq"
      ];

      boot.kernel.sysctl = {
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.default_qdisc" = "fq";
      };

      boot.loader.grub = {
        enable = true;
        efiSupport = true;

        efiInstallAsRemovable = true;
      };
      services.smartd.enable = false;
    }

    {
      networking.networkmanager.settings.main.no-auto-default = cfg.ipv6.interface;
      networking.networkmanager.ensureProfiles.profiles.${cfg.ipv6.interface} = {
        connection = {
          id = cfg.ipv6.interface;
          type = "ethernet";
          interface-name = cfg.ipv6.interface;
          autoconnect = true;
        };

        ipv4.method = cfg.ipv6.ipv4Method;

        ipv6 = {
          method = "manual";
          address1 = "${cfg.ipv6.address}/128";
          route1 = "${cfg.ipv6.gateway}/128";
          route2 = "::/0,${cfg.ipv6.gateway}";
          may-fail = true;
        };
      };
    }
  ];
}

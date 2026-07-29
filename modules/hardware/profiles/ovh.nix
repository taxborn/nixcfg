{ config, lib, ... }:

let
  cfg = config.myHardware.profiles.ovh;
in
{
  options.myHardware.profiles.ovh = {
    enable = lib.mkEnableOption "OVH server modules";

    ipv6 = {
      enable = lib.mkEnableOption "static IPv6 addressing on an OVH instance";

      address = lib.mkOption {
        type = lib.types.str;
        default = "";
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
        type = lib.types.str;
        default = "";
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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        boot.initrd.availableKernelModules = [
          "ata_piix"
          "uhci_hcd"
          "virtio_pci"
          "virtio_scsi"
        ];

        # How these instances boot is a property of the instance, not of the
        # host running on it — both OVH hosts were setting this identically.
        # `efiInstallAsRemovable` is the part that matters: OVH's firmware does
        # not persist EFI variables across a rebuild, so the loader has to be
        # findable at the removable media path.
        myNixOS.programs.grub.enable = lib.mkDefault true;

        # No SMART behind virtio. smartd is on by default in `nixos/base`, and
        # with nothing to register it fails to start rather than idling.
        services.smartd.enable = false;
      }

      (lib.mkIf cfg.ipv6.enable {
        assertions = [
          {
            assertion = cfg.ipv6.address != "" && cfg.ipv6.gateway != "";
            message = "myHardware.profiles.ovh.ipv6 needs both `address` and `gateway`.";
          }
        ];

        # Without this, NetworkManager auto-creates a "Wired connection N" for
        # the device and activates it before `ensure-profiles` has written the
        # profile below — reloading does not move an already-active device, so
        # the declarative profile ends up loaded but idle. Suppressing the
        # auto-default leaves the device free until the profile lands.
        #
        # Scoped to this interface rather than "*": on a host whose IPv4 lives
        # on a separate NIC, blanket suppression would strip that NIC of its
        # auto-default too and take the host off the network entirely.
        networking.networkmanager.settings.main.no-auto-default = cfg.ipv6.interface;

        # NetworkManager owns this interface, so the address is declared as a
        # profile rather than through `networking.interfaces` — the two would
        # otherwise both try to configure ens3. IPv4 stays on DHCP exactly as
        # before and `may-fail` keeps a broken v6 from blocking activation, so
        # a broken v6 config costs IPv6 rather than the host.
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
            # The gateway sits outside the /128: pin it on-link first, then
            # route the default through it.
            route1 = "${cfg.ipv6.gateway}/128";
            route2 = "::/0,${cfg.ipv6.gateway}";
            may-fail = true;
          };
        };
      })
    ]
  );
}

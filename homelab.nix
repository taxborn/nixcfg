# Homelab-wide settings. Plain data, so secrets/secrets.nix can import it
# outside the module system. modules/options.nix types it as `homelab.*`.
let
  domain = "biscuits.at";
  tailnet = "tucuxi-hexatonic.ts.net";
  owner = {
    name = "Braxton Fair";
    email = "hello@taxborn.com";
    username = "taxborn";
    gpgKey = "F22AFD6CFD66B874";
    did = "did:plc:2grdruc2p6fjhksrfpt366yl";
  };
in
{
  inherit domain owner;

  # Outgoing mail for every service that sends any. 465 is implicit TLS.
  mail = {
    host = "smtp.fastmail.com";
    port = 465;
    from = "infra@${domain}";
    atproto = "atproto@${domain}";
  };

  # The ACLs in secrets/ntfy.age grant the publisher token these topics.
  ntfy.topics = {
    backups = "backups";
    alerts = "alerts";
  };

  rsyncNet = {
    user = "de4388";
    host = "de4388.rsync.net";
  };

  # Every host in the fleet, mapped to its tailnet address.
  hosts = {
    argon = "100.64.2.1";
    carbon = "100.64.2.0";
    helium = "100.64.1.0";
    tungsten = "100.64.0.1";
    uranium = "100.64.0.0";
  };

  # Tailnet devices that are not NixOS hosts.
  devices = {
    ipad = "100.64.3.1";
    phone = "100.64.3.0";
  };

  tailnet = {
    name = tailnet;
    ranges = [
      "100.64.0.0/10"
      "fd7a:115c:a1e0::/48"
    ];
  };

  # Public name and loopback port of every proxied service.
  services = {
    albedo = {
      domain = "albedo.${domain}";
      port = 4317;
    };
    atuin = {
      domain = "atuin.${domain}";
      port = 3008;
    };
    braxton-is = {
      domain = "braxton.is";
      port = 3006;
    };
    glance = {
      domain = "www.${domain}";
      port = 3000;
    };
    grafana = {
      domain = "grafana.${domain}";
      port = 3009;
    };
    knot = {
      domain = "knot.${domain}";
      port = 3011;
      sshDomain = "argon.${tailnet}";
      sshPort = 2222;
    };
    ntfy = {
      domain = "ntfy.${domain}";
      port = 3007;
    };
    paperless = {
      domain = "docs.${domain}";
      port = 3004;
    };
    pds = {
      domain = "pds.${domain}";
      port = 3003;
    };
    piper = {
      domain = "piper.${domain}";
      port = 3005;
    };
    spindle = {
      domain = "spindle.${domain}";
      port = 3012;
    };
    vaultwarden = {
      domain = "vw.${domain}";
      port = 3001;
    };
  };

  # Holds the second copy of every host's borg archives, on its external drive.
  backupServer = {
    host = "helium";
    user = owner.username;
    basePath = "/mnt/hdd/borg";
    port = 2200;
  };

  monitoring = {
    server = "helium";
    alwaysOn = [
      "argon"
      "carbon"
      "helium"
    ];
    physicalDisks = [
      "helium"
      "tungsten"
      "uranium"
    ];
    minecraftHosts = [
      "argon"
      "carbon"
    ];
    ports = {
      minecraftExporter = 9150;
      processExporter = 9256;
      nodeExporter = 9100;
      smartctlExporter = 9633;
      prometheus = 9090;
      alertmanager = 9093;
      alertmanagerNtfy = 8111;
      loki = 3100;
      lokiGrpc = 9096;
    };
  };
}

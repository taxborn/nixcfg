{
  config,
  pkgs,
  self,
  ...
}:
let
  networkMap = config.homelab.services;

  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  homelab.backups.postgresqlDumpAll = true;

  age.secrets.tranquilPds.file = "${self}/secrets/tranquil-pds.age";

  services.tranquil-pds = {
    enable = true;
    package = packages.tranquil-pds;

    # The embedded store is experimental, and nothing migrates between the two.
    database.createLocally = true;

    # MASTER_KEY encrypts every account's signing key.
    environmentFiles = [ config.age.secrets.tranquilPds.path ];

    settings = {
      frontend.dir = packages.tranquil-pds-frontend;

      server = {
        hostname = networkMap.pds.domain;
        port = networkMap.pds.port;

        user_handle_domains = [ networkMap.pds.domain ];

        # Keeps the PDS personal.
        invite_code_required = true;

        trusted_proxy_count = 1;
      };

      email = {
        from_address = config.homelab.mail.from;
        from_name = "biscuits.at PDS";
        smarthost = {
          host = config.homelab.mail.host;
          port = config.homelab.mail.port;
          tls = "implicit";
        };
      };
    };
  };
}

{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.loki.enable = lib.mkEnableOption "loki log aggregation";

  config = lib.mkIf config.myNixOS.services.loki.enable {
    services.loki = {
      enable = true;

      configuration = {
        auth_enabled = false;

        server.http_listen_port = config.mySnippets.mischief-town.networkMap.loki.port;
        server.http_listen_address = "0.0.0.0";

        common = {
          path_prefix = config.services.loki.dataDir;
          replication_factor = 1;

          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
        };

        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        storage_config.filesystem.directory = "${config.services.loki.dataDir}/chunks";

        limits_config = {
          retention_period = "30d";
          allow_structured_metadata = false;
        };

        compactor = {
          working_directory = "${config.services.loki.dataDir}/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
        };
      };
    };
  };
}

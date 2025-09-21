{
  inputs,
  pkgs,
  config,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  environment.systemPackages = with pkgs; [
    sops
  ];

  sops = {
    defaultSopsFile = ../../secrets.yaml;
    validateSopsFiles = false;

    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
  };

  sops.secrets."cloudflare-api-key" = { };
  environment.variables.CLOUDFLARE_API_KEY = "$(cat ${
    config.sops.secrets."cloudflare-api-key".path
  })";
}

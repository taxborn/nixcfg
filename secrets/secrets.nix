let
  hosts = [
    "argon"
    "carbon"
  ];
  extras = [
    "yubikey"
  ];

  systemKeys = builtins.map (host: builtins.readFile ../keys/root_${host}.pub) hosts;
  extraKeys = builtins.map (key: builtins.readFile ../keys/${key}.pub) extras;
  keys = systemKeys ++ extraKeys;

  hostKey = host: [ (builtins.readFile ../keys/root_${host}.pub) ] ++ extraKeys;
in
{
  "tailscale/auth.age".publicKeys = keys;
}

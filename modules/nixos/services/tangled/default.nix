{ lib, ... }:

{
  # Shared by the knot on Argon and the spindle on Carbon, so the two cannot
  # disagree about who runs them.
  options.myNixOS.services.tangled.owner = lib.mkOption {
    type = lib.types.strMatching "^did:[a-z]+:.+";
    default = "did:plc:2grdruc2p6fjhksrfpt366yl";
    description = ''
      atproto DID that administers the knot and owns the spindle. Both
      services stay closed to anyone else: the knot lets only admins create
      repositories, and the spindle runs CI only for its owner and allow-list.
    '';
  };
}

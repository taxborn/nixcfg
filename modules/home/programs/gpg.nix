{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myHome.programs.gpg = {
    enable = lib.mkEnableOption "gpg config";

    agent.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run a gpg-agent on this host.

        On where the yubikey is physically plugged in, off everywhere else —
        and off is what makes forwarding work. `S.gpg-agent` is a fixed path,
        so an agent here and a forwarded socket from a session both want the
        same one; a local agent on a host with no card would win that fight
        while being unable to sign anything.

        The rest of the gpg configuration, `keys/pgp.asc` included, is
        unconditional: the far end of a forward still needs the public key to
        know what the agent is holding.
      '';
    };
  };

  config = lib.mkIf config.myHome.programs.gpg.enable {
    programs.gpg = {
      enable = true;
      scdaemonSettings.disable-ccid = true;
      publicKeys = [
        { source = ../../../keys/pgp.asc; }
      ];
      # https://github.com/drduh/YubiKey-Guide/blob/master/config/gpg.conf
      # https://www.gnupg.org/documentation/manuals/gnupg/GPG-Options.html
      settings = {
        # Use AES256, 192, or 128 as cipher
        personal-cipher-preferences = "AES256 AES192 AES";
        # Use SHA512, 384, or 256 as digest
        personal-digest-preferences = "SHA512 SHA384 SHA256";
        # Use ZLIB, BZIP2, ZIP, or no compression
        personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
        # Default preferences for new keys
        default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
        # SHA512 as digest to sign keys
        cert-digest-algo = "SHA512";
        # SHA512 as digest for symmetric ops
        s2k-digest-algo = "SHA512";
        # AES256 as cipher for symmetric ops
        s2k-cipher-algo = "AES256";
        # UTF-8 support for compatibility
        charset = "utf-8";
        # No comments in messages
        no-comments = true;
        # No version in output
        no-emit-version = true;
        # Disable banner
        no-greeting = true;
        # Long key id format
        keyid-format = "0xlong";
        # Display UID validity
        list-options = "show-uid-validity";
        verify-options = "show-uid-validity";
        # Display all keys and their fingerprints
        with-fingerprint = true;
        # Display key origins and updates
        with-key-origin = true;
        # Cross-certify subkeys are present and valid
        require-cross-certification = true;
        # Enforce memory locking to avoid accidentally swapping GPG memory to disk
        require-secmem = true;
        # Disable caching of passphrase for symmetrical ops
        no-symkey-cache = true;
        # Output ASCII instead of binary
        armor = true;
        # Enable smartcard
        use-agent = true;
        # Disable recipient key ID in messages (WARNING: breaks Mailvelope)
        throw-keyids = true;
      };
    };

    # https://github.com/drduh/YubiKey-Guide/blob/master/config/gpg-agent.conf
    # https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html
    services.gpg-agent = lib.mkIf config.myHome.programs.gpg.agent.enable {
      enable = true;
      enableSshSupport = true;

      # The socket a forwarded session connects to on this end. Restricted by
      # design: it refuses key management and passphrase changes, so a remote
      # host can use the card without being able to reconfigure it.
      enableExtraSocket = true;

      extraConfig = ''
        ttyname $GPG_TTY
      '';
      defaultCacheTtl = 60;
      maxCacheTtl = 120;

      pinentry.package = pkgs.pinentry-gnome3;
    };
  };
}

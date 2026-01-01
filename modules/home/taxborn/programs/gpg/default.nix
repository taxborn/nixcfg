{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.myHome.taxborn.programs.gpg.enable = lib.mkEnableOption "gpg config";

  config = lib.mkIf config.myHome.taxborn.programs.gpg.enable {
    programs.gpg = {
      enable = true;
      scdaemonSettings.disable-ccid = true;
      publicKeys = [
        { source = ./gpg.asc; } # TODO: add to secrets repo
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
    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
      extraConfig = ''
        ttyname $GPG_TTY
      '';
      defaultCacheTtl = 60;
      maxCacheTtl = 120;

      pinentry.package = pkgs.pinentry-gnome3;
    };
  };
}

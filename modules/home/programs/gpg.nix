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

        Only meaningful where the yubikey is physically plugged in — a
        gpg-agent elsewhere has no card to talk to.
      '';
    };
  };

  config = lib.mkIf config.myHome.programs.gpg.enable {
    programs.gpg = {
      enable = true;

      # scdaemon's built-in CCID driver claims the USB device outright and
      # holds it, which shuts out everything that reaches the card through
      # pcscd: ykman, and age-plugin-yubikey, which is how every secret in this
      # repo gets decrypted. Disabled, scdaemon goes through pcscd like they do
      # and the three take turns. pcscd comes from myNixOS.services.yubikey.
      scdaemonSettings.disable-ccid = true;

      publicKeys = [
        { source = ../../../keys/pgp.asc; }
      ];

      # Hardened defaults lifted from drduh's YubiKey guide. Each option is
      # named in the GnuPG manual; only the ones with a consequence worth
      # knowing are annotated below.
      # https://github.com/drduh/YubiKey-Guide/blob/master/config/gpg.conf
      # https://www.gnupg.org/documentation/manuals/gnupg/GPG-Options.html
      settings = {
        personal-cipher-preferences = "AES256 AES192 AES";
        personal-digest-preferences = "SHA512 SHA384 SHA256";
        personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
        default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
        cert-digest-algo = "SHA512";
        s2k-digest-algo = "SHA512";
        s2k-cipher-algo = "AES256";
        charset = "utf-8";
        no-comments = true;
        no-emit-version = true;
        no-greeting = true;
        keyid-format = "0xlong";
        list-options = "show-uid-validity";
        verify-options = "show-uid-validity";
        with-fingerprint = true;
        with-key-origin = true;
        require-cross-certification = true;
        # Refuse to run at all rather than fall back to unlocked memory, so a
        # passphrase or a session key cannot reach swap.
        require-secmem = true;
        no-symkey-cache = true;
        armor = true;
        use-agent = true;
        # Strips the recipient key id from the packet, so a message does not
        # name who can open it. The cost is that a client which cannot try
        # every private key it holds gives up instead: Mailvelope is the one
        # that bit here.
        throw-keyids = true;
      };
    };

    # https://github.com/drduh/YubiKey-Guide/blob/master/config/gpg-agent.conf
    # https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html
    services.gpg-agent = lib.mkIf config.myHome.programs.gpg.agent.enable {
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

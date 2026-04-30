{
  networking.networkmanager.ensureProfiles.profiles = {
    ens3 = {
      connection = {
        id = "ens3";
        type = "ethernet";
        interface-name = "ens3";
        autoconnect = true;
        autoconnect-priority = 100;
      };
      ipv4.method = "auto";
      ipv6 = {
        method = "auto";
        may-fail = "true";
        address1 = "2604:2dc0:101:200::2cc6/128";
        route1 = "::/0,2604:2dc0:101:200::1";
        route1_options = "onlink=true";
        route2 = "2604:2dc0:101:200::1/128";
      };
    };
  };
}

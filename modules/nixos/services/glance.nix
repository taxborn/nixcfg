{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.glance;
  networkMap = config.homelab.services;

  # Probes run from Argon, against the public names rather than loopback, so a
  # red tile means the whole path is broken (DNS, Cloudflare, Caddy, the app)
  # and not just the process. Tailnet-only names resolve to Helium's tailnet
  # address, which Argon reaches because it is a peer.
  site =
    {
      title,
      domain,
      icon,
      path ? "",
    }:
    {
      inherit title icon;
      url = "https://${domain}";
      check-url = "https://${domain}${path}";
    };

  serviceSites = [
    (site {
      title = "Vaultwarden";
      domain = networkMap.vaultwarden.domain;
      icon = "di:vaultwarden";
    })
    (site {
      title = "Paperless";
      domain = networkMap.paperless.domain;
      icon = "di:paperless-ngx";
    })
    (site {
      title = "Grafana";
      domain = networkMap.grafana.domain;
      path = "/api/health";
      icon = "di:grafana";
    })
    (site {
      title = "ntfy";
      domain = networkMap.ntfy.domain;
      path = "/v1/health";
      icon = "di:ntfy";
    })
    (site {
      title = "PDS";
      domain = networkMap.pds.domain;
      path = "/xrpc/_health";
      icon = "si:bluesky";
    })
    (site {
      title = "Knot";
      domain = networkMap.knot.domain;
      icon = "mdi:git";
    })
    (site {
      title = "Spindle";
      domain = networkMap.spindle.domain;
      icon = "mdi:cog-sync";
    })
    (site {
      title = "Piper";
      domain = networkMap.piper.domain;
      icon = "mdi:music";
    })
    (site {
      title = "Atuin";
      domain = networkMap.atuin.domain;
      icon = "mdi:console";
    })
    (site {
      title = "braxton.is";
      domain = networkMap.braxton-is.domain;
      icon = "mdi:web";
    })
  ];

  # Liveness of a host is whether its node_exporter answers on the tailnet,
  # the same signal Prometheus scrapes. Workstations are expected to be red
  # when asleep, which is why they sit in their own widget and not beside the
  # servers.
  roster = config.homelab.hosts;
  nodePort = toString config.homelab.monitoring.ports.nodeExporter;
  alwaysOn = config.homelab.monitoring.alwaysOn;
  workstations = lib.filter (h: !(lib.elem h alwaysOn)) (lib.attrNames roster);
  nodeSites = map (host: {
    title = lib.toUpper (lib.substring 0 1 host) + lib.substring 1 (-1) host;
    url = "https://login.tailscale.com/admin/machines";
    check-url = "http://${roster.${host}}:${nodePort}/metrics";
    icon = "mdi:server";
  });
in
{
  options.myNixOS.services.glance.enable = lib.mkEnableOption "glance dashboard";

  config = lib.mkIf cfg.enable {
    age.secrets.glance.file = "${self}/secrets/glance.age";

    services.glance = {
      environmentFile = config.age.secrets.glance.path;
      enable = true;
      settings = {
        # The `\${...}` escape keeps Nix from interpolating, so the literal
        # reaches Glance, which expands it from the EnvironmentFile at runtime.
        # Written any other way the values land in the settings JSON the module
        # renders into the nix store.
        auth = {
          secret-key = "\${GLANCE_SECRET_KEY}";
          users.taxborn.password = "\${GLANCE_USER_PASSWORD}";
        };
        server = {
          port = config.homelab.services.glance.port;
        };
        # Catppuccin Mocha with the Mauve accent, typed out rather than
        # inherited. This option takes raw HSL triples, and there is no
        # `catppuccin.glance` module for the tree-wide `autoEnable` to find, so
        # this is the one place the palette is written by hand. The bookmark
        # group colours below are Blue and Pink out of the same palette.
        theme = {
          background-color = "240 21 15";
          contrast-multiplier = 1.2;
          primary-color = "267 84 81";
          positive-color = "115 54 76";
          negative-color = "343 81 75";
        };
        pages = [
          {
            name = "Home";
            head-widgets = [
              {
                type = "search";
                search-engine = "kagi";
                autofocus = true;
                bangs = [
                  {
                    title = "Nix options";
                    shortcut = "!no";
                    url = "https://search.nixos.org/options?query={QUERY}";
                  }
                  {
                    title = "Nix packages";
                    shortcut = "!np";
                    url = "https://search.nixos.org/packages?query={QUERY}";
                  }
                  {
                    title = "GitHub";
                    shortcut = "!gh";
                    url = "https://github.com/search?q={QUERY}";
                  }
                  {
                    title = "Paperless";
                    shortcut = "!doc";
                    url = "https://${networkMap.paperless.domain}/documents?query={QUERY}";
                  }
                ];
              }
            ];
            columns = [
              {
                size = "small";
                widgets = [
                  {
                    type = "clock";
                    hour-format = "12h";
                  }
                  {
                    type = "weather";
                    location = "Saint Paul, Minnesota, United States";
                    units = "imperial";
                    hour-format = "12h";
                  }
                  {
                    type = "calendar";
                    first-day-of-week = "sunday";
                  }
                  {
                    type = "markets";
                    hide-header = true;
                    markets = [
                      {
                        name = "S&P 500";
                        symbol = "SPY";
                      }
                    ];
                  }
                ];
              }
              {
                size = "full";
                widgets = [
                  {
                    type = "monitor";
                    title = "Services";
                    cache = "1m";
                    sites = serviceSites;
                  }
                  {
                    type = "bookmarks";
                    groups = [
                      {
                        name = "Homelab";
                        color = "316 72 86";
                        links = [
                          {
                            title = "Grafana";
                            url = "https://${networkMap.grafana.domain}";
                          }
                          {
                            title = "Paperless";
                            url = "https://${networkMap.paperless.domain}";
                          }
                          {
                            title = "Vaultwarden";
                            url = "https://${networkMap.vaultwarden.domain}";
                          }
                          {
                            title = "ntfy";
                            url = "https://${networkMap.ntfy.domain}";
                          }
                          {
                            title = "Knot";
                            url = "https://${networkMap.knot.domain}";
                          }
                          {
                            title = "braxton.is";
                            url = "https://${networkMap.braxton-is.domain}";
                          }
                        ];
                      }
                      {
                        name = "Infrastructure";
                        color = "170 57 73";
                        links = [
                          {
                            title = "Cloudflare";
                            url = "https://dash.cloudflare.com/";
                          }
                          {
                            title = "OVHcloud";
                            url = "https://manager.eu.ovhcloud.com/";
                          }
                          {
                            title = "Tailscale";
                            url = "https://login.tailscale.com/admin/machines";
                          }
                          {
                            title = "Fastmail";
                            url = "https://app.fastmail.com/";
                          }
                          {
                            title = "Tangled";
                            url = "https://tangled.org/";
                          }
                          {
                            title = "GitHub";
                            url = "https://github.com/";
                          }
                        ];
                      }
                      {
                        name = "Entertainment";
                        color = "217 92 76";
                        links = [
                          {
                            title = "Netflix";
                            url = "https://www.netflix.com/";
                          }
                          {
                            title = "HBO Max";
                            url = "https://www.hbomax.com/";
                          }
                          {
                            title = "Peacock";
                            url = "https://www.peacocktv.com/";
                          }
                          {
                            title = "YouTube";
                            url = "https://www.youtube.com/";
                          }
                          {
                            title = "YouTube TV";
                            url = "https://tv.youtube.com/";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    type = "group";
                    widgets = [
                      { type = "hacker-news"; }
                      { type = "lobsters"; }
                    ];
                  }
                ];
              }
              {
                size = "small";
                widgets = [
                  {
                    type = "releases";
                    title = "Upstream releases";
                    cache = "6h";
                    repositories = [
                      "NixOS/nixpkgs"
                      "paperless-ngx/paperless-ngx"
                      "dani-garcia/vaultwarden"
                      "caddyserver/caddy"
                      "tailscale/tailscale"
                      "glanceapp/glance"
                      "grafana/grafana"
                      "binwiederhier/ntfy"
                    ];
                  }
                ];
              }
            ];
          }
          {
            name = "Fleet";
            columns = [
              {
                size = "small";
                widgets = [
                  {
                    # The local server only. Glance reads this host's own
                    # /proc, so this is Argon and says nothing of the others,
                    # which the node checks beside it cover.
                    type = "server-stats";
                    servers = [
                      {
                        type = "local";
                        name = "Argon";
                      }
                    ];
                  }
                ];
              }
              {
                size = "full";
                widgets = [
                  {
                    type = "monitor";
                    title = "Servers";
                    cache = "1m";
                    sites = nodeSites alwaysOn;
                  }
                  {
                    type = "monitor";
                    title = "Workstations";
                    cache = "1m";
                    sites = nodeSites workstations;
                  }
                  {
                    type = "bookmarks";
                    groups = [
                      {
                        name = "Observability";
                        color = "217 92 76";
                        links = [
                          {
                            title = "Grafana";
                            url = "https://${networkMap.grafana.domain}";
                          }
                          {
                            title = "Fleet overview";
                            url = "https://${networkMap.grafana.domain}/dashboards?query=Fleet";
                          }
                          {
                            title = "Explore logs";
                            url = "https://${networkMap.grafana.domain}/explore";
                          }
                          {
                            title = "Alerting";
                            url = "https://${networkMap.grafana.domain}/alerting/list";
                          }
                        ];
                      }
                    ];
                  }
                ];
              }
              {
                size = "small";
                widgets = [
                  {
                    type = "rss";
                    title = "NixOS";
                    limit = 8;
                    cache = "3h";
                    feeds = [
                      {
                        url = "https://discourse.nixos.org/c/announcements/8.rss";
                        title = "Announcements";
                      }
                      {
                        url = "https://github.com/NixOS/nixpkgs/releases.atom";
                        title = "nixpkgs";
                      }
                    ];
                  }
                ];
              }
            ];
          }
          {
            name = "Reading";
            columns = [
              {
                size = "full";
                widgets = [
                  {
                    type = "reddit";
                    subreddit = "selfhosted";
                  }
                  {
                    type = "reddit";
                    subreddit = "NixOS";
                  }
                ];
              }
              {
                size = "small";
                widgets = [
                  {
                    type = "lobsters";
                    sort-by = "hot";
                    limit = 15;
                  }
                  {
                    type = "hacker-news";
                    limit = 15;
                  }
                ];
              }
            ];
          }
        ];
      };
    };
  };
}

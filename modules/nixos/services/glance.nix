{
  config,
  lib,
  self,
  ...
}:
let
  networkMap = config.homelab.services;

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
  age.secrets.glance.file = "${self}/secrets/glance.age";

  services.glance = {
    environmentFile = config.age.secrets.glance.path;
    enable = true;
    settings = {
      # Escaped so Glance expands these at runtime and they stay out of the store.
      auth = {
        secret-key = "\${GLANCE_SECRET_KEY}";
        users.taxborn.password = "\${GLANCE_USER_PASSWORD}";
      };
      server = {
        port = config.homelab.services.glance.port;
      };
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
}

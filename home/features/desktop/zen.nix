{
  inputs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.features.desktop.zen;
in
{
  options.features.desktop.zen.enable = mkEnableOption "enable zen browser";

  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  config = mkIf cfg.enable {
    programs.zen-browser = {
      enable = true;

      profiles = {
        personal = {
          name = "Personal";
          isDefault = true;
          settings = {
            # --- Core Functionality ---
            "browser.shell.checkDefaultBrowser" = false;
            "browser.shell.didSkipDefaultBrowserCheckOnFirstRun" = true;
            "browser.aboutConfig.showWarning" = false;
            "browser.tabs.warnOnOpen" = false;

            # --- Privacy Settings ---
            "dom.security.https_only_mode" = true;
            "dom.security.https_only_mode_ever_enabled" = true;
            "privacy.donottrackheader.enabled" = true;
            "privacy.globalprivacycontrol.was_ever_enabled" = true;
            "network.dns.disablePrefetch" = true;
            "network.http.speculative-parallel-limit" = 0;
            "network.predictor.enabled" = false;
            "network.prefetch-next" = false;

            # --- Telemetry/tracking Disable ---
            "app.shield.optoutstudies.enabled" = false;
            "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 2;
            "toolkit.telemetry.reportingpolicy.firstRun" = false;

            # --- Zen Specific ---
            "zen.welcome-screen.seen" = true;
            "zen.themes.updated-value-observer" = true;
          };
          userChrome = "";
          extensions = [ ];
        };
      };

      policies = {
        DisableAppUpdate = true;
        DisableTelemetry = true;
      };
    };
  };
}

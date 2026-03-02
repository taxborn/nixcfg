{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.services.ollama.enable = lib.mkEnableOption "Ollama LLM service with ROCm GPU acceleration";

  config = lib.mkIf config.myNixOS.services.ollama.enable {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-rocm;

      # Listens on localhost only. To expose over Tailscale:
      #   1. Set host = "0.0.0.0"; (or your tailscale IP)
      #   2. Add: networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 11434 ];
      host = "127.0.0.1";
      port = 11434;
    };

    # RX 7900 XT is RDNA3 (gfx1100), required for ROCm to recognize the GPU.
    systemd.services.ollama.environment.HSA_OVERRIDE_GFX_VERSION = "11.0.0";
  };
}

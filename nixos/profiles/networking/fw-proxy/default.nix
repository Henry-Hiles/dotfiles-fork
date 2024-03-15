{
  config,
  options,
  lib,
  ...
}:
let
  cfg = config.networking.fw-proxy;
  inherit (config.networking) hostName;
  profiles = [
    "main"
    "exclusive"
    "alternative"
  ];
in
lib.mkMerge [
  {
    networking.fw-proxy = {
      enable = true;
      ports = {
        http = config.ports.proxy-http;
        socks = config.ports.proxy-socks;
        mixed = config.ports.proxy-mixed;
        tproxy = config.ports.proxy-tproxy;
        controller = config.ports.clash-controller;
      };
      noProxyPattern = options.networking.fw-proxy.noProxyPattern.default ++ [
        "*.ts.li7g.com"
        "*.zt.li7g.com"
        "*.dn42.li7g.com"
      ];
      tproxy = {
        enable = lib.mkDefault true;
        routingTable = config.routingTables.fw-proxy;
        rulePriority = config.routingPolicyPriorities.fw-proxy;
      };
      downloadedConfigPreprocessing = ''
        # nothing
      '';
      configPreprocessing = ''
        # nothing
      '';
      mixinConfig = {
        log = {
          level = "info";
          timestamp = false; # added by journald
        };
      };
      profiles = lib.listToAttrs (
        lib.lists.map (
          p: lib.nameValuePair p { urlFile = config.sops.secrets."fw-proxy/${p}".path; }
        ) profiles
      );
      externalController = {
        expose = true;
        virtualHost = "${hostName}.*";
        location = "/clash/";
        secretFile = config.sops.secrets."fw_proxy_external_controller_secret".path;
      };
    };

    sops.secrets."fw_proxy_external_controller_secret" = {
      terraformOutput.enable = true;
      restartUnits = [ "fw-proxy.service" ];
    };

    networking.fw-proxy.auto-update = {
      enable = true;
      service = "main";
    };

    systemd.services.nix-daemon.environment = cfg.environment;
  }
  {
    sops.secrets = lib.listToAttrs (
      lib.lists.map (
        p:
        lib.nameValuePair "fw-proxy/${p}" {
          sopsFile = config.sops-file.get "common.yaml";
          restartUnits = [ "fw-proxy-auto-update.service" ];
        }
      ) profiles
    );
  }
]

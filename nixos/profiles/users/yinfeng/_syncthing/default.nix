{ config, lib, ... }:
let
  simpleDeviceNames = [
    "framework"
    "xps8930"
    "nuc"
  ];
  simpleDevices = lib.listToAttrs (
    map (
      h:
      lib.nameValuePair h {
        id = config.lib.self.data.hosts.${h}.syncthing_device_id;
        addresses =
          [ "dynamic" ]
          ++ lib.flatten (
            lib.lists.map
              (
                middle:
                lib.lists.map
                  (
                    protocol: "${protocol}://${h}.${middle}li7g.com:${toString config.ports.syncthing-transfer-yinfeng}"
                  )
                  [
                    "tcp"
                    "tcp6"
                    "udp"
                    "udp6"
                  ]
              )
              [
                ""
                "ts."
                "zt."
              ]
          );
      }
    ) simpleDeviceNames
  );
  devices = lib.recursiveUpdate simpleDevices {
    shiba = {
      id = "IQHYQR7-XD4GDX7-U6VGMGJ-GRQTGLF-NGZCNNL-Z5RPMJV-UMAJQVH-6T77HQU";
    };
    sailfish = {
      id = "WJCWZOM-A3DSD2V-NHKMH4K-KMTQZAP-WAQLJH5-WWBR7QL-WYX53FR-DGC7TQL";
    };
  };
  hostName = config.networking.hostName;
  others = lib.filterAttrs (h: _: h != hostName) devices;
  defaultOtherNames = lib.remove "sailfish" (lib.attrNames others);

  user = "yinfeng";
  group = config.users.users.yinfeng.group;
  uid = config.users.users.${user}.uid;
  gid = config.users.groups.${group}.gid;
in
lib.mkIf (devices ? ${hostName}) {
  containers.syncthing-yinfeng = {
    autoStart = true;
    ephemeral = true;
    privateNetwork = false;
    bindMounts = {
      "/var/lib/syncthing" = {
        hostPath = "/home/yinfeng/Syncthing";
        isReadOnly = false;
      };
      "/run/secrets/syncthing_cert_pem" = {
        hostPath = config.sops.secrets."syncthing_cert_pem".path;
        isReadOnly = true;
      };
      "/run/secrets/syncthing_key_pem" = {
        hostPath = config.sops.secrets."syncthing_key_pem".path;
        isReadOnly = true;
      };
    };
    config = {
      users.users.${user} = {
        inherit uid group;
        isNormalUser = true;
      };
      users.groups.${group} = {
        inherit gid;
      };
      services.syncthing = {
        enable = true;
        guiAddress = "127.0.0.1:${toString config.ports.syncthing-yinfeng}";
        openDefaultPorts = true;
        inherit user group;
        cert = "/run/secrets/syncthing_cert_pem";
        key = "/run/secrets/syncthing_key_pem";
        settings = {
          devices = others;
          folders = {
            "main" = {
              path = "/var/lib/syncthing/Main";
              devices = defaultOtherNames;
              ignoreDelete = false;
              ignorePerms = false;
            };
            "music" = {
              path = "/var/lib/syncthing/Music";
              devices = defaultOtherNames;
              ignoreDelete = false;
              ignorePerms = false;
            };
            "camera" = {
              path = "/var/lib/syncthing/Camera";
              devices = [ "sailfish" ] ++ defaultOtherNames;
              ignoreDelete = false;
              ignorePerms = false;
            };
          };
        };
      };
      system.stateVersion = config.system.stateVersion;
    };
  };
  sops.secrets."syncthing_cert_pem" = {
    terraformOutput = {
      enable = true;
      perHost = true;
    };
    restartUnits = [ "container@syncthing-yinfeng.service" ];
  };
  sops.secrets."syncthing_key_pem" = {
    terraformOutput = {
      enable = true;
      perHost = true;
    };
    restartUnits = [ "container@syncthing-yinfeng.service" ];
  };
  home-manager.users.yinfeng.home.global-persistence.directories = [ "Syncthing" ];
  networking.firewall.allowedTCPPorts = with config.ports; [
    syncthing-transfer-yinfeng
    syncthing-discovery-yinfeng
  ];
}

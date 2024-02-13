{
  config,
  pkgs,
  lib,
  suites,
  profiles,
  ...
}: let
  btrfsSubvol = device: subvol: extraConfig:
    lib.mkMerge [
      {
        inherit device;
        fsType = "btrfs";
        options = ["subvol=${subvol}" "compress=zstd"];
      }
      extraConfig
    ];

  btrfsSubvolMain = btrfsSubvol "/dev/disk/by-uuid/8b982fe4-1521-4a4d-aafc-af22c3961093";
  btrfsSubvolMobile = btrfsSubvol "/dev/mapper/crypt-mobile";
in {
  imports =
    suites.server
    ++ suites.development
    ++ suites.virtualization
    ++ (with profiles; [
      nix.access-tokens
      nix.hydra-builder-server
      nix.hydra-builder-client
      nix.nixbuild
      security.tpm
      networking.network-manager
      networking.behind-fw
      networking.fw-proxy
      services.transmission
      services.jellyfin
      services.samba
      services.nextcloud
      services.vlmcsd
      services.godns
      services.nginx
      services.acme
      services.smartd
      services.postgresql
      services.hydra
      programs.service-mail
      programs.tg-send
      programs.ccache
      users.yinfeng
      users.nianyi
    ])
    ++ [
      ./_minecraft
      ./_steam
    ];

  config = lib.mkMerge [
    {
      boot.loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot.enable = true;
      };
      # TODO broken with 6.7.1
      boot.kernelPackages = pkgs.linuxPackages;
      hardware.enableRedistributableFirmware = true;
      services.fwupd.enable = true;

      services.thermald.enable = true;

      environment.global-persistence.enable = true;
      environment.global-persistence.root = "/persist";

      boot.binfmt.emulatedSystems = [
        "aarch64-linux"
      ];

      systemd.watchdog.runtimeTime = "60s";

      services.fstrim.enable = true;
      services.btrfs.autoScrub = {
        enable = true;
        fileSystems = [
          "/dev/disk/by-uuid/8b982fe4-1521-4a4d-aafc-af22c3961093"
          "/dev/mapper/crypt-mobile"
        ];
      };

      home-manager.users.yinfeng = {suites, ...}: {imports = suites.nonGraphical;};

      boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "vmd" "ahci" "nvme" "usbhid" "uas" "sd_mod"];
      boot.kernelModules = ["kvm-intel"];
      boot.initrd.luks.devices = {
        crypt-mobile = {
          device = "/dev/disk/by-uuid/b456f27c-b0a1-4b1e-8f2b-91f1826ae51c";
          allowDiscards = true;
        };
      };
      fileSystems."/" = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = ["defaults" "size=2G" "mode=755"];
      };
      boot.tmp = {
        useTmpfs = true;
        # reasonable because of swap
        tmpfsSize = "100%";
      };
      fileSystems."/nix" = btrfsSubvolMain "@nix" {neededForBoot = true;};
      fileSystems."/persist" = btrfsSubvolMain "@persist" {neededForBoot = true;};
      fileSystems."/var/log" = btrfsSubvolMain "@var-log" {neededForBoot = true;};
      fileSystems."/swap" = btrfsSubvolMain "@swap" {};
      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/C9A4-3DE6";
        fsType = "vfat";
        options = ["dmask=077" "fmask=177"];
      };
      services.zswap.enable = true;
      swapDevices = [
        {
          device = "/swap/swapfile";
        }
      ];
      fileSystems."/var/lib/transmission" = btrfsSubvolMobile "@bittorrent" {};
      fileSystems."/media/data" = btrfsSubvolMobile "@data" {};
    }

    # godns
    {
      services.godns = {
        ipv4.settings = {
          domains = [
            {
              domain_name = "li7g.com";
              sub_domains = ["nuc"];
            }
          ];
          ip_type = "IPv4";
          ip_urls = [
            "https://api.ipify.org"
            "https://myip.biturl.top"
            "https://api-ipv4.ip.sb/ip"
          ];
        };
        ipv6.settings = {
          domains = [
            {
              domain_name = "li7g.com";
              sub_domains = ["nuc"];
            }
          ];
          ip_type = "IPv6";
          ip_interface = "enp88s0";
        };
      };
    }

    # nginx
    {
      services.nginx = {
        defaultListen = [
          {
            addr = "0.0.0.0";
            port = config.ports.http;
            ssl = false;
          }
          {
            addr = "0.0.0.0";
            port = config.ports.https;
            ssl = true;
          }
          {
            addr = "0.0.0.0";
            port = config.ports.http-alternative;
            ssl = false;
          }
          {
            addr = "0.0.0.0";
            port = config.ports.https-alternative;
            ssl = true;
          }
          {
            addr = "[::]";
            port = config.ports.http;
            ssl = false;
          }
          {
            addr = "[::]";
            port = config.ports.https;
            ssl = true;
          }
          {
            addr = "[::]";
            port = config.ports.http-alternative;
            ssl = false;
          }
          {
            addr = "[::]";
            port = config.ports.https-alternative;
            ssl = true;
          }
        ];
        virtualHosts."nuc.*" = {
          serverAliases = [
            "nuc-proxy.*"
          ];
          locations."/" = {
            root = ./_www;
          };
        };
      };
      networking.firewall.allowedTCPPorts = with config.ports; [
        http-alternative
        https-alternative
      ];
      networking.firewall.allowedUDPPorts = with config.ports; [
        https-alternative
      ];
    }

    # stateVersion
    {
      system.stateVersion = "23.11";
    }
  ];
}

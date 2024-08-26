{ pkgs, lib, ... }:
let
  tag = "sdm845-6.11.0_rc2-r2";
  sha256 = "sha256-v48UfKESS7SQhLmgsRT6b1IoEcjuhnXBANGUVYz7WSs=";
  # version = lib.elemAt (lib.strings.match "sdm845-([0-9\\.]+)(-r[0-9]+)?" tag) 0;
  version = "6.11.0";
  major = lib.versions.major version;
  minor = lib.versions.minor version;
  structuredExtraConfig = { };
in
{
  boot = {
    kernelPackages =
      let
        linux_sdm845_fn =
          {
            buildLinux,
            ccacheStdenv,
            lib,
            ...
          }@args:
          buildLinux (
            args
            // {
              # build with ccacheStdenv
              stdenv = ccacheStdenv;
              inherit version;
              modDirVersion = "${lib.versions.pad 3 version}-sdm845";
              extraMeta.branch = lib.versions.majorMinor version;
              src = pkgs.fetchFromGitLab {
                owner = "sdm845-mainline";
                repo = "linux";
                rev = tag;
                inherit sha256;
              };
              defconfig = "defconfig sdm845.config";
              inherit structuredExtraConfig;
            }
            // (args.argsOverride or { })
          );
        linux_sdm845' = pkgs.callPackage linux_sdm845_fn {
          kernelPatches = lib.filter (p: !(lib.elem p.name [ ])) (
            pkgs."linuxPackages_${major}_${minor}".kernel.kernelPatches or [ ]
          );
        };
        linux_sdm845 = linux_sdm845'.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.hexdump ];
          buildFlags = old.buildFlags ++ [ "all" ];
          installTargets = [
            "install"
            "zinstall"
          ];
        });
      in
      pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux_sdm845);
    kernelPatches = [
      # currently nothing
    ];
  };
}

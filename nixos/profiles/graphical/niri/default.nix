{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkMerge [
  {
    programs.niri = {
      enable = true;
      # TODO broken
      # package = pkgs.niri-unstable;
      package = pkgs.niri;
    };
    niri-flake.cache.enable = false;
    environment.systemPackages = with pkgs; [
      swaylock
    ];
    security.pam.services.swaylock.text = ''
      account required pam_unix.so

      # check passwork before fprintd
      auth sufficient pam_unix.so try_first_pass likeauth
      auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so
      auth required pam_deny.so

      password sufficient pam_unix.so nullok yescrypt

      session required pam_env.so conffile=/etc/pam/environment readenv=0
      session required pam_unix.so
    '';
  }
  (lib.mkIf (!config.services.xserver.desktopManager.gnome.enable) {
    services.gnome.gnome-keyring.enable = true;
    environment.global-persistence.user.directories = [ ".local/share/keyrings" ];
  })
]

{ ... }:

{
  programs.chromium = {
    enable = true;
  };

  home.global-persistence.directories = [
    ".config/chromium"
  ];

  home.sessionVariables = {
    GOOGLE_DEFAULT_CLIENT_ID = "77185425430.apps.googleusercontent.com";
    GOOGLE_DEFAULT_CLIENT_SECRET = "OTJgUOQcT7lO7GsGZq2G4IlT";
  };
}

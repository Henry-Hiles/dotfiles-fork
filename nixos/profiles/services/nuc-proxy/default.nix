{config, ...}: {
  services.nginx.upstreams."nuc".servers = {
    "nuc.ts.li7g.com:${toString config.ports.https}" = {};
    "nuc.li7g.com:${toString config.ports.https-alternative}" = {backup = true;};
  };
  services.nginx.virtualHosts."nuc-proxy.*" = {
    forceSSL = true;
    inherit (config.security.acme.tfCerts."li7g_com".nginxSettings) sslCertificate sslCertificateKey;
    locations."/" = {
      proxyPass = "https://nuc";
    };
  };
}

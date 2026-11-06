{
  pkgs,
  lib,
  config,
  confData,
  ...
}:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ../../../../configs/mx2.nix
  ];

  networking = {
    nameservers = lib.mkForce [ "1.1.1.1" ];
    firewall = {
      enable = true;
      allowedTCPPorts = lib.mkForce [
        22
        25
        80
      ];
    };
  };

  security.acme.certs."mx2.vpsfree.cz" = {
    listenHTTP = ":80";
    group = config.services.postfix.group;
    reloadServices = [ "postfix.service" ];
  };

  services.postfix.settings.main = {
    myhostname = "mx2.vpsfree.cz";
    smtpd_tls_chain_files = [
      "${config.security.acme.certs."mx2.vpsfree.cz".directory}/key.pem"
      "${config.security.acme.certs."mx2.vpsfree.cz".directory}/fullchain.pem"
    ];
    smtpd_tls_security_level = "may";
  };

  systemd.services.postfix = {
    requires = [ "acme-mx2.vpsfree.cz.service" ];
    after = [ "acme-mx2.vpsfree.cz.service" ];
  };

  users.users.root.openssh.authorizedKeys.keys = with confData.sshKeys; [
    toms
  ];

  system.stateVersion = "25.05";
}

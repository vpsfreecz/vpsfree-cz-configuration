{ config, pkgs, lib, confLib, confMachine, ... }:
with lib;
let
  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking.firewall.allowedTCPPorts = [ 25 80 443 ];

  services.postgresql.package = pkgs.postgresql_13;

  services.discourse = {
    enable = true;
    enableACME = true;
    hostname = "discourse.vpsfree.cz";

    admin = {
      email = "podpora@vpsfree.cz";
      username = "admin";
      fullName = "Administrator";
      passwordFile = "/private/discourse/admin.passwd";
    };

    secretKeyBaseFile = "/private/discourse/secret_key_base_file";

    mail = {
      notificationEmailAddress = "discourse@vpsfree.cz";

      contactEmailAddress = "support@vpsfree.org";

      outgoing = {
        serverAddress = "prasiatko.int.vpsfree.cz";
        port = 25;
        opensslVerifyMode = "none";
      };

      incoming.enable = true;
    };

    siteSettings = {
      required = {
        title = "vpsFree.cz Discourse";
        site_description = "Discussion board for vpsFree.cz members";
      };

      basic = {
        allow_user_locale = true;
      };

      email = {
        email_in = true;
      };
    };
  };

  system.stateVersion = "23.05";
}

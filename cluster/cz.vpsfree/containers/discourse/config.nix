{ config, pkgs, lib, confLib, confMachine, ... }:
with lib;
let
  proxyPrg = confLib.findMetaConfig {
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

    plugins = with config.services.discourse.package.plugins; [
      discourse-oauth2-basic
    ];

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

      login = {
        oauth2_enabled = true;
        oauth2_client_id = "discourse.vpsfree.cz";
        # oauth2_client_secret = "set using web UI";
        oauth2_authorize_url = "https://auth.vpsfree.cz/_auth/oauth2/authorize";
        oauth2_token_url = "https://auth.vpsfree.cz/_auth/oauth2/token";
        oauth2_fetch_user_details = true;
        oauth2_user_json_url = "https://api.vpsfree.cz/users/current";
        oauth2_json_user_id_path = "response.user.id";
        oauth2_json_username_path = "response.user.login";
        oauth2_json_name_path = "response.user.full_name";
        oauth2_json_email_path = "response.user.email";
        oauth2_email_verified = true;
        oauth2_button_title = "with vpsAdmin";
        oauth2_allow_association_change = true;
      };
    };
  };

  system.stateVersion = "23.05";
}

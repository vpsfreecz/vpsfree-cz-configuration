{ pkgs, lib, config, confData, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  services.postfix = {
    enable = true;

    config = {
      smtpd_recipient_restrictions = [
        "permit_mynetworks"
        "permit_sasl_authenticated"
        "reject_unauth_pipelining"
        "reject_non_fqdn_recipient"
        "reject_unknown_recipient_domain"
        "reject_unauth_destination"
        "reject_unlisted_recipient"
        "check_policy_service unix:${config.services.postgrey.socket.path}"
        "reject_rbl_client zen.spamhaus.org=127.0.0.[2..11]"
        "reject_rbl_client b.barracudacentral.org=127.0.0.2"
      ];

      smtpd_milters = "inet:localhost:11332";

      milter_default_action = "accept";
    };

    transport = ''
      vpsfree.cz              smtp:prasiatko-mail.vpsfree.cz
      lists.vpsfree.cz        smtp:prasiatko-mail.vpsfree.cz
      vpsfree.org             smtp:prasiatko-mail.vpsfree.cz
    '';
  };

  services.postgrey.enable = true;

  users.users.root.openssh.authorizedKeys.keys = with confData.sshKeys; [ toms ];

  system.stateVersion = "25.05";
}

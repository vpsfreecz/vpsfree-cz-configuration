{ config, ... }:
{
  networking.firewall.allowedTCPPorts = [ 25 ];

  services.postfix = {
    enable = true;
    settings.main = {
      relay_domains = [
        "vpsfree.cz"
        "lists.vpsfree.cz"
        "vpsfree.org"
      ];
      # Keep Postfix defaults except implicit relay permission for subdomains.
      parent_domain_matches_subdomains = [
        "debug_peer_list"
        "fast_flush_domains"
        "mynetworks"
        "permit_mx_backup_networks"
        "qmqpd_authorized_clients"
        "smtpd_access_maps"
      ];
      smtpd_relay_restrictions = [
        "permit_mynetworks"
        "permit_sasl_authenticated"
        "reject_unauth_destination"
      ];
      smtpd_recipient_restrictions = [
        "permit_mynetworks"
        "permit_sasl_authenticated"
        "reject_unauth_pipelining"
        "reject_non_fqdn_recipient"
        "reject_unknown_recipient_domain"
        "reject_unlisted_recipient"
        "check_policy_service unix:${config.services.postgrey.socket.path}"
        "reject_rbl_client zen.spamhaus.org=127.0.0.[2..11]"
        "reject_rbl_client b.barracudacentral.org=127.0.0.2"
      ];
      # Match the primary's advertised 100 MiB limit before accepting a queue item.
      message_size_limit = 104857600;
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
}

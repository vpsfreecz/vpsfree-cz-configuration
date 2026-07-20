{ lib, ... }:
let
  # Verified from the account-ID-2 vpsfreectl result and its active address
  # relation recorded in the migration execution ledger.
  liveVpsId = 29942;
  livePrivateIPv4 = "172.16.8.4";

  privateIPv4Octets =
    if builtins.isString livePrivateIPv4 then lib.splitString "." livePrivateIPv4 else [ ];
  isCanonicalIPv4Octet =
    octet:
    builtins.match "(0|[1-9][0-9]{0,2})" octet != null
    && (
      let
        value = lib.toInt octet;
      in
      value >= 0 && value <= 255
    );
  isExpectedPrivateIPv4 =
    builtins.length privateIPv4Octets == 4
    && lib.all isCanonicalIPv4Octet privateIPv4Octets
    && builtins.elemAt privateIPv4Octets 0 == "172"
    && (
      let
        secondOctet = lib.toInt (builtins.elemAt privateIPv4Octets 1);
      in
      secondOctet >= 16 && secondOctet <= 31
    );

  verifiedVpsId =
    assert lib.assertMsg (builtins.isInt liveVpsId && liveVpsId > 0) ''
      int.blog requires the positive vpsAdmin VPS ID verified for
      blog.int.vpsfree.cz under account ID 2; recheck the exact live object
      relation before every promotion
    '';
    liveVpsId;

  verifiedPrivateIPv4 =
    assert lib.assertMsg (builtins.isString livePrivateIPv4 && isExpectedPrivateIPv4) ''
      int.blog requires the canonical 172.16.0.0/12 private /32 assigned to
      the same verified vpsAdmin VPS; recheck the exact VPS/address relation
      before every promotion
    '';
    livePrivateIPv4;
in
{
  cluster."cz.vpsfree/containers/int.blog" = {
    spin = "nixos";
    inputs.channels = [
      "nixos-stable"
      "os-staging"
    ];

    container.id = verifiedVpsId;

    host = {
      name = "blog";
      location = "int";
      domain = "vpsfree.cz";
      target = verifiedPrivateIPv4;
    };

    addresses.v4 = [
      {
        address = verifiedPrivateIPv4;
        prefix = 32;
      }
    ];

    # Keep shared monitoring, alerting, and logging consumers unchanged until
    # those integrations are reviewed and activated as a separate transition.
    monitoring = {
      enable = false;
      target = verifiedPrivateIPv4;
    };
    logging.enable = false;

    services.node-exporter = { };

    # Keep the candidate out of both broad deployment selectors until the
    # separately reviewed post-cutover tag change.
    tags = [ "blog-migration" ];

    healthChecks = {
      systemd.unitProperties = {
        "nginx.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "mysql.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "phpfpm-wordpress-blog.vpsfree.cz.service" = [
          {
            property = "ActiveState";
            value = "active";
          }
        ];

        "wordpress-init-blog.vpsfree.cz.service" = [
          {
            property = "Result";
            value = "success";
          }
          {
            property = "ExecMainStatus";
            value = "0";
          }
        ];

        "wordpress-blog-secret-health-check.service" = [
          {
            property = "Result";
            value = "success";
          }
          {
            property = "ExecMainStatus";
            value = "0";
          }
        ];
      };

      machineCommands = [
        {
          description = "Revalidate persistent WordPress secret metadata and structure";
          command = [
            "systemctl"
            "start"
            "wordpress-blog-secret-health-check.service"
          ];
          standardOutput.match = "";
        }
      ];

      # The initial empty-database deployment deliberately omits the full local
      # WordPress check. In the first reviewed post-import commit, add a start
      # of wordpress-blog-local-health-check.service here; it checks the local
      # homepage, feed, denial paths, core/database versions, and policy state.
      #
      # The accepted recovery timer and marker check are also absent from this
      # initial metadata. Add both the timer ActiveState property and a start
      # of wordpress-recovery-export-health-check.service in the same reviewed
      # commit that enables the accepted timer after the live 01:00 managed-
      # snapshot schedule and monitoring path are verified.
    };
  };
}

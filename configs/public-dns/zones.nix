{ lib, master }:
let
  inherit (lib) concatMapStringsSep;

  masters = [
    "37.205.9.232"
  ];

  slaves = [
    "37.205.11.51"
  ];

  zoneDir = "/var/named";

  zones = [
    { name = "vpsfree.cz."; file = ./zone.vpsfree.cz.; }
    "10.205.37.in-addr.arpa."
    "164.8.185.in-addr.arpa."
    "165.8.185.in-addr.arpa."
    "166.8.185.in-addr.arpa."
    "167.8.185.in-addr.arpa."
    "8.205.37.in-addr.arpa."
    "9.205.37.in-addr.arpa."
    "12.205.37.in-addr.arpa."
    "13.205.37.in-addr.arpa."
    "14.205.37.in-addr.arpa."
    "15.205.37.in-addr.arpa."
    "0.0.1.0.0.4.b.3.3.0.a.2.ip6.arpa."
    "2.0.0.0.0.4.b.c.0.0.a.2.ip6.arpa."
    "1.0.0.0.0.4.b.c.0.0.a.2.ip6.arpa."
    "16-31.145.62.149.in-addr.arpa."
    "11.205.37.in-addr.arpa."
    "0.4.b.3.3.0.a.2.ip6.arpa."
    { name = "2.0.0.4.b.3.3.0.a.2.ip6.arpa."; masters = [ "37.205.8.113" ]; }
    { name = "3.0.0.4.b.3.3.0.a.2.ip6.arpa."; masters = [ "37.205.8.113" ]; }
  ];

  ipsToBind = ips: concatMapStringsSep " " (ip: "${ip};") ips;

  makeZones = map makeZone zones;

  makeZone = zone:
    let
      fn =
        if !master || ((builtins.isAttrs zone) && (builtins.hasAttr "masters" zone)) then
          makeSlaveZone
        else makeMasterZone;

      attrset =
        if builtins.isAttrs zone then
          zone
        else if builtins.isString zone then
          { name = zone; }
        else
          abort "zone has to be attrset or string";
    in fn attrset;

  makeMasterZone = zone: {
    inherit (zone) name;
    master = true;
    inherit slaves;
    file = zone.file or "${zoneDir}/zone.${zone.name}";
  };

  makeSlaveZone = zone: {
    inherit (zone) name;
    master = false;
    masters = zone.masters or masters;
    file = "zone.${zone.name}";
    extraConfig = ''
      allow-transfer { "none"; };
    '';
  };
in makeZones

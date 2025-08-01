{
  lib,
  primary,
  filterZones ? null,
}:
let
  inherit (lib) concatMapStringsSep filter;

  primaries = [
    "37.205.9.232" # ns1
  ];

  secondaries = [
    "172.16.9.200" # ns0
    "37.205.11.51" # ns2
    "37.205.15.45" # ns3
    "37.205.11.85" # ns4
  ];

  zoneDir = "/var/named";

  zones = [
    {
      name = "vpsfree.cz.";
      file = ./zone.vpsfree.cz.;
    }
    "167.8.185.in-addr.arpa."
    {
      name = "2.0.0.4.b.3.3.0.a.2.ip6.arpa.";
      primaries = [ "37.205.8.113" ];
    }
    {
      name = "3.0.0.4.b.3.3.0.a.2.ip6.arpa.";
      primaries = [ "37.205.8.113" ];
    }
  ];

  ipsToBind = ips: concatMapStringsSep " " (ip: "${ip};") ips;

  makeZones = map makeZone zones;

  makeZone =
    zone:
    let
      fn =
        if !primary || ((builtins.isAttrs zone) && (builtins.hasAttr "primaries" zone)) then
          makeSecondaryZone
        else
          makePrimaryZone;

      attrset =
        if builtins.isAttrs zone then
          zone
        else if builtins.isString zone then
          { name = zone; }
        else
          abort "zone has to be attrset or string";
    in
    fn attrset;

  makePrimaryZone = zone: {
    inherit (zone) name;
    master = true;
    slaves = secondaries;
    file = zone.file or "${zoneDir}/zone.${zone.name}";
  };

  makeSecondaryZone = zone: {
    inherit (zone) name;
    master = false;
    masters = zone.primaries or primaries;
    file = "zone.${zone.name}";
    extraConfig = ''
      allow-transfer { none; };
    '';
  };

  filteredZones = zones: if isNull filterZones then zones else filter filterZones zones;

in
filteredZones makeZones

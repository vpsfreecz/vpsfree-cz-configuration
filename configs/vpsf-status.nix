{ config, pkgs, lib, confLib, confData, ... }:
with lib;
let
  allMachines = confLib.getClusterMachines config.cluster;

  findNodes = loc:
    filter (m: m.metaConfig.node != null && m.metaConfig.host.location == loc && m.metaConfig.monitoring.enable && isNull m.carrier) allMachines;

  filterServices = machine: fn:
    let
      serviceList = mapAttrsToList (name: svConfig: {
        inherit machine name svConfig;
      }) machine.metaConfig.services;
    in
      filter (sv: fn sv.svConfig) serviceList;

  findDnsResolverServices = loc:
    flatten (map (m:
      optional (m.metaConfig.host.location == loc) (filterServices m (sv: sv.monitor == "dns-resolver"))
    ) allMachines);

  locationNodes = loc: map (m: {
      name = "${m.metaConfig.host.name}.${m.metaConfig.host.location}";
      id = m.metaConfig.node.id;
      ip_address = m.metaConfig.addresses.primary.address;
    }) (findNodes loc);

  sortedLocationNodes = loc: sort (a: b: a.id < b.id) (locationNodes loc);

  locationDnsResolvers = loc: map (sv: {
      name = sv.machine.metaConfig.host.fqdn;
      ip_address = sv.machine.metaConfig.addresses.primary.address;
    }) (findDnsResolverServices loc);

  dnsResolvers = rec {
    prg = locationDnsResolvers "prg";
    brq = locationDnsResolvers "brq";
    all = prg ++ brq;
  };
in {
  services.vpsf-status = {
    enable = true;
    settings = {
      notice_file = "/etc/status.html";

      check_interval = 30;

      vpsadmin = {
        api_url = "https://api.vpsfree.cz";
        webui_url = "https://vpsadmin.vpsfree.cz";
        console_url = "https://console.vpsfree.cz/vzconsole.js";
      };

      locations = [
        {
          id = 3;
          label = "Praha";
          nodes =
            (sortedLocationNodes "prg") # matches also Praha Storage
            ++
            (sortedLocationNodes "pgnd")
            ++
            (sortedLocationNodes "stg");
          dns_resolvers = dnsResolvers.prg;
        }
        {
          id = 4;
          label = "Brno";
          nodes = sortedLocationNodes "brq";
          dns_resolvers = dnsResolvers.brq;
        }
      ];

      web_services = [
        {
          label = "vpsfree.cz";
          description = "Website in Czech";
          url = "https://vpsfree.cz";
        }
        {
          label = "vpsfree.org";
          description = "Website in English";
          url = "https://vpsfree.org";
        }
        {
          label = "kb.vpsfree.cz";
          description = "Knowledge Base in Czech";
          url = "https://kb.vpsfree.cz";
        }
        {
          label = "kb.vpsfree.org";
          description = "Knowledge Base in English";
          url = "https://kb.vpsfree.org";
        }
        {
          label = "ZNC";
          description = "IRC bouncer";
          url = "https://im.vpsfree.cz/znc/";
          method = "get";
        }
      ];

      nameservers = [
        {
          name = "ns1.vpsfree.cz";
          domain = "vpsfree.cz";
        }
        {
          name = "ns2.vpsfree.cz";
          domain = "vpsfree.cz";
        }
        {
          name = "ns3.vpsfree.cz";
          domain = "vpsfree.cz";
        }
        {
          name = "ns4.vpsfree.cz";
          domain = "vpsfree.cz";
        }
      ];
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."status.vpsf.cz" = {
      onlySSL = true;
      sslCertificateKey = "/private/nginx/status.vpsf.cz.key";
      sslCertificate = "/private/nginx/status.vpsf.cz.crt";
      locations."/".proxyPass = "http://127.0.0.1:${toString config.services.vpsf-status.port}";
    };
  };

  networking.firewall.extraCommands = concatMapStringsSep "\n" (net: ''
    iptables -A nixos-fw -p tcp --dport 443 -s ${net} -j nixos-fw-accept
  '') confData.cloudflare.ipv4;

  # To reach the DNS resolvers via the private network instead of LTE
  networking.interfaces.enp1s0.ipv4.routes = map (dns: {
    address = dns.ip_address; prefixLength = 32; via = "172.16.254.1";
  }) dnsResolvers.all;
}

{ config, ... }:
{
  cluster."org.vpsadminos/int.cache" = rec {
    managed = false;
    spin = "nixos";
    container.id = 14573;
    host = {
      name = "cache";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.30";
      prefix = 32;
    };
    services = {
      nix-serve = { };
      node-exporter = { };
    };
  };

  cluster."org.vpsadminos/int.gh-runner1" = rec {
    managed = false;
    spin = "nixos";
    pins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 27535;
    host = {
      name = "gh-runner1";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.21";
      prefix = 32;
    };
    services = {
      node-exporter = { };
    };
  };

  cluster."org.vpsadminos/int.gh-runner2" = rec {
    managed = false;
    spin = "nixos";
    pins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 27536;
    host = {
      name = "gh-runner2";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.22";
      prefix = 32;
    };
    services = {
      node-exporter = { };
    };
  };

  cluster."org.vpsadminos/int.images" = rec {
    managed = false;
    spin = "nixos";
    pins.channels = [
      "nixos-stable"
      "os-staging"
    ];
    container.id = 14561;
    host = {
      name = "images";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.15";
      prefix = 32;
    };
    services = {
      nginx = { };
      node-exporter = { };
    };
  };

  cluster."org.vpsadminos/int.iso" = rec {
    managed = false;
    spin = "nixos";
    container.id = 14562;
    host = {
      name = "iso";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.16";
      prefix = 32;
    };
    services = {
      nginx = { };
      node-exporter = { };
    };
  };

  cluster."org.vpsadminos/int.www" = rec {
    managed = false;
    spin = "nixos";
    container.id = 14563;
    host = {
      name = "www";
      domain = "int.vpsadminos.org";
    };
    addresses.primary = {
      address = "172.16.4.17";
      prefix = 32;
    };
    services = {
      nginx = { };
      node-exporter = { };
    };
  };

  cluster."org.vpsadminos/proxy" = rec {
    managed = false;
    spin = "nixos";
    container.id = 14006;
    host = {
      name = "proxy";
      domain = "vpsadminos.org";
    };
    addresses = {
      v4 = [
        {
          address = "37.205.14.58";
          prefix = 32;
        }
      ];
      v6 = [
        {
          address = "2a03:3b40:fe:48::1";
          prefix = 64;
        }
      ];
    };
    services.node-exporter = { };
  };
}

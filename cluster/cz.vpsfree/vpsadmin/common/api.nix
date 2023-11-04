{ config, pkgs, lib, confMachine, confLib, ... }:
with lib;
let
  db = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.db";
  };

  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  rabbitmqs = map (name:
    confLib.findConfig {
      cluster = config.cluster;
      name = "cz.vpsfree/vpsadmin/int.${name}";
    }
  ) [ "rabbitmq1" "rabbitmq2" "rabbitmq3" ];
in {
  vpsadmin.api = {
    enable = true;

    configDirectory = ../../../../configs/vpsadmin/api;

    address = confMachine.addresses.primary.address;
    servers = 8;

    allowedIPv4Ranges = [
      "${proxyPrg.addresses.primary.address}/32"
    ];

    database = {
      host = db.addresses.primary.address;
      user = "vpsadmin-api";
      name = "vpsadmin";
      passwordFile = "/private/vpsadmin-db.pw";
      autoSetup = false;
    };

    rake.enableDefaultTasks = mkDefault false;
  };

  vpsadmin.supervisor = {
    enable = true;

    configDirectory = ../../../../configs/vpsadmin/api;

    servers = 2;

    database = {
      host = db.addresses.primary.address;
      user = "vpsadmin-supervisor";
      name = "vpsadmin";
      passwordFile = "/private/vpsadmin-supervisor-db.pw";
      autoSetup = false;
    };

    rabbitmq = {
      hosts = map (rabbitmq: "${rabbitmq.addresses.primary.address}") rabbitmqs;
      virtualHost = "vpsadmin_prod";
      username = "supervisor";
      passwordFile = "/private/vpsadmin-rabbitmq.pw";
    };
  };

  environment.systemPackages = with pkgs; [
    git
  ];
}

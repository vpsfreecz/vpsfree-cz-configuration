{
  config,
  pkgs,
  lib,
  confMachine,
  confLib,
  ...
}:
with lib;
let
  db = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.db";
  };

  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
in
{
  vpsadmin.api = {
    enable = true;

    configDirectory = ../../../../configs/vpsadmin/api;

    address = confMachine.addresses.primary.address;
    workers = 8;

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
      username = "supervisor";
      passwordFile = "/private/vpsadmin-rabbitmq.pw";
    };
  };

  vpsadmin.console-router = {
    enable = true;

    address = confMachine.addresses.primary.address;

    rabbitmq = {
      username = "console-router";
      passwordFile = "/private/vpsadmin-console-rabbitmq.pw";
    };

    allowedIPv4Ranges = [
      "${proxyPrg.addresses.primary.address}/32"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
  ];
}

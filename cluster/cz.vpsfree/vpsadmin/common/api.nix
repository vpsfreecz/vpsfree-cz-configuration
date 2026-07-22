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

  allMachines = confLib.getClusterMachines config.cluster;
  monitors = filter (m: m.metaConfig.monitoring.isMonitor) allMachines;
  addressCidrs =
    addresses:
    map (addr: "${addr.address}/${toString addr.prefix}") (
      (addresses.v4 or [ ]) ++ (addresses.v6 or [ ])
    );
  monitorCidrs = unique (concatMap (m: addressCidrs m.metaConfig.addresses) monitors);
  proxyCidrs = unique (addressCidrs proxyPrg.addresses);
in
{
  vpsadmin.deploymentConfig = {
    monitoring.download_pool_service_discovery = {
      allowed_networks = monitorCidrs;
      trusted_proxies = proxyCidrs;
    };
  };

  vpsadmin.databaseSetup = {
    database = {
      host = db.addresses.primary.address;
      user = "vpsadmin-database";
      name = "vpsadmin";
      passwordFile = "/private/vpsadmin-database-db.pw";
    };
    autoSetup = false;
  };

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
    };

    notifications.rabbitmq = {
      enable = true;
      username = "notification";
      passwordFile = "/private/vpsadmin-notification-rabbitmq.pw";
    };

    rake.enableDefaultTasks = mkDefault false;
  };

  vpsadmin.notifications.telegram = {
    enable = true;
    botTokenFile = "/private/vpsadmin-telegram-bot-token";
    receiveMode = "webhook";

    webhook = {
      listenAddress = confMachine.addresses.primary.address;
      port = 9293;
      path = "/_telegram/webhook";
      publicUrl = "https://api.vpsfree.cz/_telegram/webhook";
      secretTokenFile = "/private/vpsadmin-telegram-webhook-secret";
    };
  };

  vpsadmin.telegramReceiver = {
    enable = true;
    configDirectory = ../../../../configs/vpsadmin/api;

    allowedIPv4Ranges = [
      "${proxyPrg.addresses.primary.address}/32"
    ];

    database = {
      host = db.addresses.primary.address;
      user = "vpsadmin-api";
      name = "vpsadmin";
      passwordFile = "/private/vpsadmin-db.pw";
    };
  };

  vpsadmin.notificationDispatcher = {
    enable = true;
    configDirectory = ../../../../configs/vpsadmin/api;
    actions = [
      "email"
      "telegram"
      "webhook"
    ];

    database = {
      host = db.addresses.primary.address;
      user = "vpsadmin-api";
      name = "vpsadmin";
      passwordFile = "/private/vpsadmin-db.pw";
    };

    rabbitmq = {
      username = "notification";
      passwordFile = "/private/vpsadmin-notification-rabbitmq.pw";
    };

    smtp = {
      address = "prasiatko.int.vpsfree.cz";
      port = 25;
    };
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

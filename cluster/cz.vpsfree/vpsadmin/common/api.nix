{ config, pkgs, lib, confMachine, confLib, ... }:
with lib;
let
  apiConfigRepo = pkgs.fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsadmin-config";
    rev = "0827d58d6d7e4827428680902e51e714888ea0d7";
    sha256 = "sha256-VghoqtikGSWyIy4fHCJ0vNHJ1Ih0ffwx/sogRIcbdJU=";
  };

  db = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/vpsadmin/int.db";
  };

  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
in {
  vpsadmin.api = {
    enable = true;

    plugins = [
      "monitoring"
      "newslog"
      "outage_reports"
      "payments"
      "requests"
      "webui"
    ];

    configDirectory = apiConfigRepo;

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

  environment.systemPackages = with pkgs; [
    git
  ];
}

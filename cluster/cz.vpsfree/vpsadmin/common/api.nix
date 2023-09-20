{ config, pkgs, lib, confMachine, confLib, ... }:
with lib;
let
  apiConfigRepo = pkgs.fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsadmin-config";
    rev = "e10b94eeb4025db281941f4da16a7542058a61a2";
    sha256 = "sha256-h1vzLBwTaW9Gvr2lonOwv2x3vPtVFIVnxhDuxRFNoxs=";
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

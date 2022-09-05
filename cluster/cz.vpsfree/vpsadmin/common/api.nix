{ config, pkgs, lib, confMachine, confLib, ... }:
with lib;
let
  apiConfigRepo = pkgs.fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "vpsadmin-config";
    rev = "760d4ac1fc1d1821644c64770fd6b022a3c1d2dd";
    sha256 = "sha256-HZiqRY4qGqkYyx+UQY0uVcpYj/bTXh7NsLuFXJZKkZw=";
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

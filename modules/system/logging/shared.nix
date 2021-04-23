{ lib, config, confMachine, confLib }:
with lib;
let
  topLevelConfig = config;
in rec {
  cfg = topLevelConfig.system.logging;

  machines = confLib.getClusterMachines topLevelConfig.cluster;

  loggers = filter (d: d.config.logging.isLogger) machines;

  locationLoggers = filter (d: d.config.host.location == confMachine.host.location) loggers;

  anyLogger = if loggers == [] then null else head loggers;

  logger = if locationLoggers == [] then anyLogger else head locationLoggers;

  enable = cfg.enable && !isNull logger && logger.config.host.fqdn != confMachine.host.fqdn;

  services = logger.config.services;

  options = {
    system.logging = {
      enable = mkOption {
        type = types.bool;
        description = "Send logs to central log system";
      };
    };
  };

  config = {
    system.logging.enable = mkDefault confMachine.logging.enable;
  };
}

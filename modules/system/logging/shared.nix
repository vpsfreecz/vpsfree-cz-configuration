{ lib, config, deploymentInfo, confLib }:
with lib;
let
  topLevelConfig = config;
in rec {
  cfg = topLevelConfig.system.logging;

  deployments = confLib.getClusterDeployments topLevelConfig.cluster;

  loggers = filter (d: d.config.logging.isLogger) deployments;

  locationLoggers = filter (d: d.location == deploymentInfo.location) loggers;

  anyLogger = if loggers == [] then null else head loggers;

  logger = if locationLoggers == [] then anyLogger else head locationLoggers;

  enable = cfg.enable && !isNull logger && logger.fqdn != deploymentInfo.fqdn;

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
    system.logging.enable = mkDefault deploymentInfo.config.logging.enable;
  };
}

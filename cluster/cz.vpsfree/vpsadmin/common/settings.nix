{ config, confLib, ... }:
let
  rabbitmqs = map (name:
    confLib.findConfig {
      cluster = config.cluster;
      name = "cz.vpsfree/vpsadmin/int.${name}";
    }
  ) [ "rabbitmq1" "rabbitmq2" "rabbitmq3" ];
in {
  vpsadmin = {
    plugins = [
      "monitoring"
      "newslog"
      "outage_reports"
      "payments"
      "requests"
      "webui"
    ];

    rabbitmq = {
      hosts = map (rabbitmq: "${rabbitmq.addresses.primary.address}") rabbitmqs;
      virtualHost = "vpsadmin_prod";
    };
  };
}

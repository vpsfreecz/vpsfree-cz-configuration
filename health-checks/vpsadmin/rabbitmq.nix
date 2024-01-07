{ host }:
{
  systemd.unitProperties = {
    "rabbitmq.service" = [
      { property = "ActiveState"; value = "active"; }
    ];
  };

  machineCommands = [
    {
      command = [ "rabbitmq-diagnostics" "check_running" ];
      standardOutput.include = [
        "RabbitMQ on node rabbit@${host.name} is fully booted and running"
      ];
    }
  ];
}

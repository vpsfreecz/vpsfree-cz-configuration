{
  systemd.unitProperties = {
    "prometheus.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];
  };

  machineCommands = [
    {
      description = "Check Prometheus health endpoint";
      command = [
        "curl"
        "--fail"
        "--silent"
        "--show-error"
        "--max-time"
        "10"
        "http://localhost:9090/-/healthy"
      ];
      standardOutput.include = [
        "Prometheus Server is Healthy"
      ];
    }
  ];
}

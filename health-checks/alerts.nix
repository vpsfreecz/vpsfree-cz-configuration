{
  systemd.unitProperties = {
    "alertmanager.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];

    "sachet.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];
  };

  machineCommands = [
    {
      description = "Check Alertmanager health endpoint";
      command = [
        "curl"
        "--fail"
        "--silent"
        "--show-error"
        "--max-time"
        "10"
        "http://localhost:9093/-/healthy"
      ];
      standardOutput.include = [
        "OK"
      ];
    }
  ];
}

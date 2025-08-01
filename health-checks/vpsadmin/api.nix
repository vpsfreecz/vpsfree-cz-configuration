{
  systemd.unitProperties = {
    "vpsadmin-api.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];

    "vpsadmin-supervisor.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];

    "vpsadmin-console-router.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];
  };

  machineCommands = [
    {
      description = "Check vpsAdmin API server at :9292";
      command = [
        "curl"
        "--fail"
        "http://{addresses.primary.address}:9292"
      ];
      standardOutput.include = [
        "HaveAPI"
        "</html>"
      ];
    }
  ];
}

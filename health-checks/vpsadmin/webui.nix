{
  systemd.unitProperties = {
    "phpfpm-vpsadmin-webui.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];

    "nginx.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];
  };

  machineCommands = [
    {
      description = "Check vpsAdmin webui";
      command = [
        "curl"
        "--fail"
        "http://localhost"
      ];
      standardOutput.include = [
        "vpsAdmin"
        "</html>"
      ];
    }
  ];
}

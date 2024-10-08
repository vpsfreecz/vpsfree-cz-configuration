{
  systemd.unitProperties = {
    "vpsadmin-api.service" = [
      { property = "ActiveState"; value = "active"; }
    ];

    "vpsadmin-supervisor.service" = [
      { property = "ActiveState"; value = "active"; }
    ];

    "vpsadmin-console-router.service" = [
      { property = "ActiveState"; value = "active"; }
    ];
  };

  machineCommands = builtins.genList (i:
    let
      port = toString (9292 + i);
    in {
      description = "Check vpsAdmin API server #${toString i} at :${port}";
      command = [ "curl" "--fail" "http://{addresses.primary.address}:${port}" ];
      standardOutput.include = [
        "HaveAPI"
        "</html>"
      ];
    }) 8;
}

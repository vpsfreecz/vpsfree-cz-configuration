{
  systemd.unitProperties = {
    "vpsadmin-api.service" = [
      { property = "ActiveState"; value = "active"; }
    ];

    "vpsadmin-scheduler.service" = [
      { property = "ActiveState"; value = "active"; }
    ];

    "vpsadmin-supervisor.service" = [
      { property = "ActiveState"; value = "active"; }
    ];

    "vpsadmin-console-router.service" = [
      { property = "ActiveState"; value = "active"; }
    ];
  };
}

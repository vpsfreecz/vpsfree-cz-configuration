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
}

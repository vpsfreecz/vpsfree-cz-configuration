{
  systemd.unitProperties = {
    "prometheus.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];
  };
}

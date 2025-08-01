{
  vpsfree = rec {
    host = "meet.vpsfree.cz";
    url = "https://${host}";
    alias = host;
    jvbExporterPorts = [
      9100
      9700
    ];
    videoBridges = {
      jvb1 = "37.205.14.138";
      jvb2 = "37.205.14.150";
      jvb3 = "37.205.14.163";
      jvb4 = "37.205.14.178";
      jvb5 = "37.205.14.182";
      jvb6 = "37.205.14.207";
      jvb7 = "37.205.14.214";
      jvb8 = "37.205.14.219";
      jvb9 = "37.205.14.231";
      jvb10 = "37.205.14.250";
      jvb11 = "37.205.13.90";
    };
  };
}

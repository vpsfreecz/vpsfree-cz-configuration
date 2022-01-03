{
  vpsfree = rec {
    host = "meet.vpsfree.cz";
    url = "https://${host}";
    alias = host;
    jvbExporterPort = 9700;
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

  linuxdays = rec {
    host = "meet.linuxdays.cz";
    url = "https://${host}";
    alias = host;
    jvbExporterPort = 9100;
    videoBridges = {
      "ld-jvb1" = "37.205.8.129";
      "ld-jvb2" = "37.205.8.211";
      "ld-jvb3" = "37.205.8.244";
      "ld-jvb4" = "37.205.12.30";
      "ld-jvb5" = "37.205.12.33";
      "ld-jvb6" = "37.205.12.55";
    };
  };
}

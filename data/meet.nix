{
  vpsfree = rec {
    host = "meet.vpsfree.cz";
    url = "https://${host}";
    alias = host;
    videoBridges = {
      "jvb1" = "37.205.14.168";
      "jvb2" = "37.205.14.153";
      "jvb3" = "37.205.12.167";
      "jvb4" = "37.205.12.173";
      "jvb5" = "37.205.12.178";
      "jvb6" = "37.205.12.180";
      "jvb7" = "37.205.14.129";
      "jvb8" = "37.205.14.154";
      "jvb9" = "37.205.14.3";
      "jvb12" = "37.205.14.235";
      "jvb16" = "185.8.164.60";
    };
  };

  linuxdays = rec {
    host = "meet.linuxdays.cz";
    url = "https://${host}";
    alias = host;
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

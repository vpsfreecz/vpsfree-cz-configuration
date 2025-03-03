{ config, ... }:
{
  confctl.carrier.netboot = {
    enable = true;

    isoImages = [
      {
        file = /srv/iso-images/systemrescue-11.01-amd64.iso;
        label = "systemrescue-11.01-amd64";
      }
    ];

    allowedIPv4Ranges = [
      "172.16.254.0/24"
      "172.19.254.0/24"
      "172.16.250.0/24"
      "172.16.251.0/24"
      "172.16.252.0/24"
      "172.16.253.0/24"
      "172.19.0.0/23"
    ];
  };
}
{ config, ... }:
{
  confctl.carrier.netboot = {
    enable = true;

    allowedIPv4Ranges = [
      "172.16.254.0/24"
      "172.19.254.0/24"
    ];
  };
}
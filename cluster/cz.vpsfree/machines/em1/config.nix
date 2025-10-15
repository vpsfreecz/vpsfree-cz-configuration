{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware.nix
    ../common/all.nix
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = false;
    devices = [ "/dev/sda" ];
  };

  networking.interfaces.enp1s0.useDHCP = true;

  networking.interfaces.enp1s0.ipv6.addresses = [
    {
      address = "2a01:4f8:1c1a:7604::1";
      prefixLength = 64;
    }
  ];

  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "enp1s0";
  };

  networking.nameservers = lib.mkForce [ ];

  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  networking.firewall.allowedUDPPorts = [ 51820 ];

  networking.wireguard.interfaces = {
    wg0 = {
      # 172.31.0.32/30    PEER-APUPRG-EM1       apu.prg <-> em1
      # 172.31.0.36/30    PEER-APUBRQ-EM1       apu.brq <-> em1
      ips = [
        "172.31.0.34/30"
        "172.31.0.38/30"
      ];

      listenPort = 51820;

      privateKeyFile = "/private/wireguard/private_key";

      allowedIPsAsRoutes = true;

      peers = [
        {
          # apu.int.prg
          publicKey = "J+fkGMDEhFyrfRGTp4gml8qP90ipGKnjVeK6mWLysnI=";
          presharedKeyFile = "/private/wireguard/preshared_key";
          allowedIPs = [
            "172.31.0.33/32"
            "172.16.0.0/12"
          ];
        }

        {
          # apu.int.brq
          publicKey = "/5yoMupw4j5KxVZdFJpt/OtOepurwwj+dCLoIYUAoDE=";
          presharedKeyFile = "/private/wireguard/preshared_key";
          allowedIPs = [
            "172.31.0.37/32"
            "172.19.0.0/23"
          ];
        }
      ];
    };
  };

  system.stateVersion = "25.05";
}

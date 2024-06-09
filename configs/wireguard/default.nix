{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  networking.nat.enable = true;
  networking.nat.externalInterface = "vlan220";
  networking.nat.internalInterfaces = [ "wg0" ];

  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "172.16.107.1/24"];

      listenPort = 51820;

      postSetup = ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 172.16.107.0/24 -o vlan220 -j MASQUERADE
      '';

      postShutdown = ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 172.16.107.0/24 -o vlan220 -j MASQUERADE
      '';

      privateKeyFile = "/private/wireguard/private_key";

      peers = [
        { # snajpa - laptop
          publicKey = "kvkin1ssGdwnRdRZExGiYryywNGy4+D84DJCgyIcXVI=";
          presharedKeyFile = "/private/wireguard/preshared_keys/snajpa.psk";
          allowedIPs = [ "172.16.107.10/32" ];
        }

        { # snajpa - ws
          publicKey = "oFZRUhQH5soGmiMuiuuhmM5X9SSyxTH2/6xVZfjDaHo=";
          presharedKeyFile = "/private/wireguard/preshared_keys/snajpa.psk";
          allowedIPs = [ "172.16.107.11/32" ];
        }

        { # aither - ws
          publicKey = "74Q77kXuMJ4Kz4Tn52n7xRreRvvuuqAnAND4HbVythI=";
          presharedKeyFile = "/private/wireguard/preshared_keys/aither.psk";
          allowedIPs = [ "172.16.107.30/32" ];
        }

        { # aither - laptop
          publicKey = "PWtq9d/f3FXoor6M7yxdvmL3fFDoGELwS3oNIYz1nEo=";
          presharedKeyFile = "/private/wireguard/preshared_keys/aither.psk";
          allowedIPs = [ "172.16.107.31/32" ];
        }

        { # aither - ipad
          publicKey = "QKmJ9iiSil26k4vyRsYfxkiW6IBxHhUwnTfzWPYIC1U=";
          presharedKeyFile = "/private/wireguard/preshared_keys/aither.psk";
          allowedIPs = [ "172.16.107.32/32" ];
        }

        { # aither - phone
          publicKey = "XzwrDrBRYaA2N3mPDBnX9cwVP3koAJ6vD+1BqVea5zU=";
          presharedKeyFile = "/private/wireguard/preshared_keys/aither.psk";
          allowedIPs = [ "172.16.107.33/32" ];
        }

        { # toms
          publicKey = "OPOPOqy/vzU3LWJMZ3l6zqE4y8G02AmPHJF1XVN/WAI=";
          presharedKeyFile = "/private/wireguard/preshared_keys/toms.psk";
          allowedIPs = [ "172.16.107.40/32" ];
        }

        { # roman
          publicKey = "4ikPBCKPz5aMPN0QPGw//lXZzDoz8//w+6dWxspoP38=";
          presharedKeyFile = "/private/wireguard/preshared_keys/roman.psk";
          allowedIPs = [ "172.16.107.50/32" ];
        }

        { # kerrycze - desktop
          publicKey = "NxQwqOLW0GO5VTBdcHC5fanFkUZ1QpohBsUsFB+4LkU=";
          presharedKeyFile = "/private/wireguard/preshared_keys/kerrycze.psk";
          allowedIPs = [ "172.16.107.60/32" ];
        }

        { # kerrycze - laptop
          publicKey = "+O+Mlk+MO0TmtHnjulD4n+B5XNKcn5C+cTPSalYbdl0=";
          presharedKeyFile = "/private/wireguard/preshared_keys/kerrycze.psk";
          allowedIPs = [ "172.16.107.61/32" ];
        }
      ];
    };
  };
}

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
        { # snajpa - ws
          publicKey = "OjvzbXNnJEmTKwOqXrxs091OW6MOB+UUklTN5AWsGnY=";
          presharedKeyFile = "/private/wireguard/preshared_keys/snajpa.psk";
          allowedIPs = [ "172.16.107.10/32" ];
        }

        { # snajpa - laptop
          publicKey = "dEyobTgNPuTBp+Ufpn+ny8Al56htVofZfbJf7N+QuHE=";
          presharedKeyFile = "/private/wireguard/preshared_keys/snajpa.psk";
          allowedIPs = [ "172.16.107.11/32" ];
        }

        { # martyet - laptop
          publicKey = "fDZXHPIqbBtudHlS8UKeyUI97QDMzH3xPS3pgwIozBE=";
          presharedKeyFile = "/private/wireguard/preshared_keys/martyet.psk";
          allowedIPs = [ "172.16.107.20/32" ];
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
      ];
    };
  };
}
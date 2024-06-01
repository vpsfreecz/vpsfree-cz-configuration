{ config, ... }:
{
  networking.wireguard.interfaces = {
    wg0 = {
      listenPort = 51820;

      # IP address, must be first allocated in the server configuration
      ips = [ "172.16.107.<your ip>/24" ];

      # Generate the key or change the path
      privateKeyFile = "/private/wireguard/vpsfree.cz/private_key";

      allowedIPsAsRoutes = true;
      peers = [
        { # vpn.vpsfree.cz
          publicKey = "gGEYszgEW2s9wPC3KrBvduNVUjZbsUaB+0yKw8JVI1s=";
          # Set your preshared key
          presharedKeyFile = "/private/wireguard/vpsfree.cz/preshared_key";
          allowedIPs = [ "172.16.0.0/12" ];
          endpoint = "37.205.12.254:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };

  networking.firewall.allowedUDPPorts = [ 51820 ];
}

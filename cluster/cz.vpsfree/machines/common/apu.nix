{
  config,
  lib,
  pkgs,
  confLib,
  confMachine,
  confData,
  flakeInputs,
  inputsInfo,
  ...
}:
with lib;
let
  smsGatewayInput = inputsInfo."vpsfree-sms-gateway".input;

  alerters = [
    "cz.vpsfree/containers/prg/int.alerts1"
    "cz.vpsfree/containers/prg/int.alerts2"
  ];

  vpsadminApis = [
    "cz.vpsfree/vpsadmin/int.api1"
    "cz.vpsfree/vpsadmin/int.api2"
  ];

  allMachines = confLib.getClusterMachines config.cluster;
  monitors = filter (m: m.metaConfig.monitoring.isMonitor) allMachines;
  gatewayClients =
    map (
      machine:
      confLib.findMetaConfig {
        cluster = config.cluster;
        name = machine;
      }
    ) (alerters ++ vpsadminApis)
    ++ map (m: m.metaConfig) monitors;

  em1 = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/machines/em1";
  };

in
{
  boot = {
    loader.grub = {
      enable = true;
      device = "/dev/sda";
      extraConfig = "serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1; terminal_input serial; terminal_output serial";
    };

    kernelParams = [ "console=ttyS0,115200n8" ];

    kernel.sysctl."net.ipv4.ip_forward" = 1;
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_USB_INTERFACE_NUM}=="01", SYMLINK+="ttyUSB-EC25-nmea"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_USB_INTERFACE_NUM}=="02", SYMLINK+="ttyUSB-EC25-at", OWNER="${config.services.vpsfreeSmsGateway.user}"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_USB_INTERFACE_NUM}=="03", SYMLINK+="ttyUSB-EC25-modem"
    SUBSYSTEM=="net", ACTION=="add", ENV{ID_VENDOR_ID}=="2c7c", ENV{ID_MODEL_ID}=="0125", TAG+="systemd", ENV{SYSTEMD_WANTS}="modemNet.service", NAME="lte0"
  '';

  users.groups = {
    "tty-vpsf-net".members = [ "snajpa" ];
  };

  users.users = {
    snajpa = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZx+5fCM/NBwVZItoTTs6wv57yFcfipM1Xl7SOyn0sj snajpa@snajpabook.vpsfree.cz"
      ];
    };
  };

  networking.interfaces.lte0.useDHCP = true;

  networking.firewall.extraCommands =
    let
      clientRules = concatMapStringsSep "\n" (client: ''
        # Allow access to SMS gateway from ${client.host.fqdn}
        iptables -A nixos-fw -p tcp --dport ${toString config.services.vpsfreeSmsGateway.port} -s ${client.addresses.primary.address} -j nixos-fw-accept
      '') gatewayClients;
    in
    ''
      ### Alertmanagers and vpsAdmin API to SMS gateway
      ${clientRules}
    '';

  # VPN to em1.vpsfree.cz
  networking.wireguard.interfaces = {
    wg0 = {
      listenPort = 51820;

      privateKeyFile = "/private/wireguard/em1.vpsfree.cz/private_key";

      allowedIPsAsRoutes = true;

      peers = [
        {
          # em1.vpsfree.cz
          publicKey = "QEMI1v0Vh1Xh0TJWe8OT9+18Nj9BHZ7PO+TuqaXfxTo=";
          presharedKeyFile = "/private/wireguard/em1.vpsfree.cz/preshared_key";
          allowedIPs = [
            "172.31.0.32/30"
            "172.31.0.36/30"
          ];
          endpoint = "${em1.addresses.primary.address}:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";

  environment.systemPackages = with pkgs; [
    usbutils
    wireguard-tools
  ];

  services.vpsfreeSmsGateway = {
    enable = true;
    package = flakeInputs.${smsGatewayInput}.packages.${pkgs.stdenv.hostPlatform.system}.default;
    listenAddress = confMachine.addresses.primary.address;
    port = confMachine.services.sms-gateway.port;
    gatewayName = confMachine.name;
    alertmanagerTokenFile = "/private/alertmanager/sms_gateway_token.txt";
    vpsadminTokenFile = "/private/vpsadmin-sms-gateway-token";
    statusTokenFile = "/private/vpsfree-sms-gateway/status-token";
    callbackTokenFile = "/private/vpsadmin-sms-callback-token";
    settings = {
      modem = {
        driver = "modem";
        device = "/dev/ttyUSB-EC25-at";
        attempts = 5;
        cooldown = "5s";
        timeout = "30s";
      };

      limits = {
        alertmanager_max_segments = 6;
        vpsadmin_max_segments = 3;
      };

      alertmanager.receivers = {
        "sms-aither".to = [ "+420775386453" ];
        "sms-snajpa".to = [ "+420720107791" ];
      };

      inbound.webhooks = [ ];
    };
  };

  systemd.services.vpsfree-sms-gateway = {
    bindsTo = [ "sys-subsystem-net-devices-lte0.device" ];
    after = [ "sys-subsystem-net-devices-lte0.device" ];
  };
}

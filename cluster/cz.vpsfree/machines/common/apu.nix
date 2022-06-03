{ config, lib, pkgs, confLib, confMachine, confData, ... }:
with lib;
let

  modemNetBringUp = pkgs.writers.writeBashBin "modem-network-bring-up" ''
    ip link set down lte0
    echo Y > /sys/class/net/lte0/qmi/raw_ip
    ip link set up lte0
    qmicli --device=/dev/cdc-wdm0 --device-open-proxy --wds-start-network="ip-type=4,apn=gprsa.public" --client-no-release-cid
    udhcpc -q -f -n -i lte0
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  '';

  alerters = [
    "cz.vpsfree/containers/prg/int.alerts1"
    "cz.vpsfree/containers/prg/int.alerts2"
  ];

in {
  boot = {
    loader.grub = {
      enable = true;
      version = 2;
      device = "/dev/sda";
      extraConfig = "serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1; terminal_input serial; terminal_output serial";
    };

    kernelParams = [ "console=ttyS0,115200n8" ];
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_USB_INTERFACE_NUM}=="01", SYMLINK+="ttyUSB-EC25-nmea"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_USB_INTERFACE_NUM}=="02", SYMLINK+="ttyUSB-EC25-at", OWNER="${config.services.sachet.user}"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_USB_INTERFACE_NUM}=="03", SYMLINK+="ttyUSB-EC25-modem"
    SUBSYSTEM=="net", ACTION=="add", ENV{ID_VENDOR_ID}=="2c7c", ENV{ID_MODEL_ID}=="0125", TAG+="systemd", ENV{SYSTEMD_WANTS}="modemNet.service", NAME="lte0"
  '';

  users.groups = {
    "crashdump".members = [ "crashdump" ];
    "tty-vpsf-net".members = [ "snajpa" "dante" ];
  };

  users.users = {
    crashdump = {
      isNormalUser = true;
      shell = null;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINqqtUK0MaKpMVkUnzjwXYv/7jr1m0E02YqMulMXJmUm snajpa@snajpadev"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZx+5fCM/NBwVZItoTTs6wv57yFcfipM1Xl7SOyn0sj snajpa@snajpabook.vpsfree.
cz"
      ];
    };

    snajpa = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZx+5fCM/NBwVZItoTTs6wv57yFcfipM1Xl7SOyn0sj snajpa@snajpabook.vpsfree.cz"
      ];
    };
    dante = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCv2+MmO2eiA/zEoaWL/hyueSZY1P+dOBX8Wa17EL8nmcaFFJbXNdeQj+/boBlVctZG8uvqyvGNs3wxKIrypd8Xet5TiEG04JaJhu+LvGb6DBdfB2KLxmZrgmfZ3q9tH3NxZgLeJdpe+/QQ5PBqPnpplqH2oaeG6LrmU1Z9JhAfAmHrVUUiJV6alTH5crYMBu+gQ0PwmM63pANyaXvB3/hbnHeq60vHSAdLLdPr7LBOLv+da1qy0Qg03kg7BJn3RNHO2mirT9W0WJYWgtB83NAAXRQO/jp9n7+oaHfSiXLAImXPX6n1HWkFTS/ZKvVlz6U3yFNca4Ihdr8J8+CYwXhe0+aU+7/CEXaofGtQaN5fCNOrzj/xJTR2n3/1iXkEzOCEpwad3vTMuKh0jcsdx5JgBQAnFgYfUC8C395lWxqlT7tIMBuQcCcbRqn02VAGU/076M7LvVoAJUTPhPOly/EYTfBOr+Y2a9o4F6j5Ogjv2LXtR275ujH9JfVl02b3yLs= dante@macbook.local"
      ];
    };
  };

  system.activationScripts.crashDumpDir = {
    text = ''
      mkdir -p /var/crashdump || true
      chown root:crashdump /var/crashdump
      chmod 730 /var/crashdump
      chmod g+s /var/crashdump
    '';
    deps = [ "users" "groups" ];
  };

  services.atftpd = {
    enable = true;
    root = "/var/crashdump";
    extraOptions = [ "--group crashdump" ];
  };

  networking.interfaces.lte0.useDHCP = false;

  networking.firewall.extraCommands =
    let
      alerterRules = concatMapStringsSep "\n" (machine:
        let
          alerter = confLib.findConfig {
            cluster = config.cluster;
            name = machine;
          };
        in ''
          # Allow access to sachet from ${machine}
          iptables -A nixos-fw -p tcp --dport ${toString config.services.sachet.port} -s ${alerter.addresses.primary.address} -j nixos-fw-accept
        ''
      ) alerters;

      tftpRules = concatMapStringsSep "\n" (net: ''
        # Allow access from ${net.location} @ ${net.address}/${toString net.prefix}
        iptables -A nixos-fw -p udp -s ${net.address}/${toString net.prefix} --dport 69 -j nixos-fw-accept
      '') confData.vpsadmin.networks.management.ipv4;
    in ''
      ### Alertmanagers to sachet
      ${alerterRules}

      ### TFTP for crashdump
      ${tftpRules}
    '';

  systemd.services.modemNet = {
    description = "modemNet";
    enable = true;
    path = with pkgs; [ iproute2 libqmi busybox ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${modemNetBringUp}/bin/modem-network-bring-up";
    };
    bindsTo = [ "sys-subsystem-net-devices-lte0.device" ];
    after = [ "sys-subsystem-net-devices-lte0.device" ];
    wantedBy = [ "multi-user.target" ];
  };

  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  environment.systemPackages = with pkgs; [
    modemNetBringUp
    usbutils
  ];

  services.sachet = {
    enable = true;
    listenAddress = confMachine.addresses.primary.address;
    port = confMachine.services.sachet.port;
    settings = {
      providers.modem = {
        device = "/dev/ttyUSB-EC25-at";
      };

      receivers = [
        {
          name = "team-sms";
          provider = "modem";
          to = [
            # aither
            "+420775386453"

            # martyet
            "+420777423709"

            # snajpa
            "+420720107791"
          ];
        }
      ];
    };
  };

  systemd.services.sachet = {
    bindsTo = [ "sys-subsystem-net-devices-lte0.device" ];
    after = [ "sys-subsystem-net-devices-lte0.device" ];
  };
}

{ config, pkgs, ... }:
let

  modemNetBringUp = pkgs.writers.writeBashBin "modem-network-bring-up" ''
    ip link set down lte0
    echo Y > /sys/class/net/lte0/qmi/raw_ip
    ip link set up lte0
    qmicli --device=/dev/cdc-wdm0 --device-open-proxy --wds-start-network="ip-type=4,apn=gprsa.public" --client-no-release-cid
    udhcpc -q -f -n -i lte0
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  '';

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
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_USB_INTERFACE_NUM}=="02", SYMLINK+="ttyUSB-EC25-at", OWNER="smsd"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_USB_INTERFACE_NUM}=="03", SYMLINK+="ttyUSB-EC25-modem"
    SUBSYSTEM=="net", ACTION=="add", ENV{ID_VENDOR_ID}=="2c7c", ENV{ID_MODEL_ID}=="0125", TAG+="systemd", ENV{SYSTEMD_WANTS}="modemNet.service", NAME="lte0"
  '';

  users.groups."tty-vpsf-net".members = [ "snajpa" ];

  users.users = {
    snajpa = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZx+5fCM/NBwVZItoTTs6wv57yFcfipM1Xl7SOyn0sj snajpa@snajpabook.vpsfree.cz"
      ];
    };
  };

  networking.interfaces.lte0.useDHCP = false;

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

  services.gammu-smsd = {
    enable = true;
    device.path = "/dev/ttyUSB-EC25-at";
    backend.service = "files";
    extraConfig.smsd = ''
      CheckSecurity = 0
    '';
  };

  systemd.services.gammu-smsd.after = [ "sys-subsystem-net-devices-lte0.device" ];
}

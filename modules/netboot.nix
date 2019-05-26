{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.netboot;
  server = cfg.host;

  ipxe_item_nixos = name: item: ''
    :${name}
    imgfree
    imgfetch http://${server}/${name}/bzImage init=${builtins.unsafeDiscardStringContext item.toplevel}/init loglevel=7 || goto normal
    imgfetch http://${server}/${name}/initrd || goto normal
    imgverify bzImage http://${server}/${name}/bzImage.sig
    imgverify initrd http://${server}/${name}/initrd.sig
    imgselect bzImage
    boot
  '';


  # node netboot images are private
  privateDir = "priv";

  ipxe_item_vpsadminos = name: item: ''
    :${name}
    imgfree
    imgfetch http://${server}/${privateDir}/${name}/kernel systemConfig=${builtins.unsafeDiscardStringContext item.toplevel} ${toString item.kernelParams} || goto normal
    imgfetch http://${server}/${privateDir}/${name}/initrd || goto normal
    imgfetch http://${server}/${privateDir}/${name}/root.squashfs root.squashfs || goto normal
    imgverify kernel http://${server}/${privateDir}/${name}/kernel.sig
    imgverify initrd http://${server}/${privateDir}/${name}/initrd.sig
    imgverify root.squashfs http://${server}/${privateDir}/${name}/root.squashfs.sig
    imgselect kernel
    boot
  '';

  concatNl = concatStringsSep "\n";
  items_nixos = concatNl (mapAttrsToList ipxe_item_nixos cfg.nixosItems);
  items_vpsadminos = concatNl (mapAttrsToList ipxe_item_vpsadminos cfg.vpsadminosItems);

  all_items = cfg.nixosItems // cfg.vpsadminosItems;

  items_symlinks = items: subfolder: concatNl (mapAttrsToList (name: x: ''
      mkdir -p $out/${subfolder}/${name}
      for i in ${x.dir}/*; do
        ln -s $i $out/${subfolder}/${name}/$( basename $i)
        signit $out/${subfolder}/${name}/$( basename $i )
      done
    '') items);

  menu_items = concatNl (mapAttrsToList (name: x: "item ${name} ${x.menu}" )
    (filterAttrs (const (hasAttr "menu")) all_items));

  mapping_items = concatNl (mapAttrsToList (mac: item: "iseq \${mac} ${mac} && goto ${item} ||") cfg.mappings);

  ipxe_script = pkgs.writeText "script.ipxe" ''
    #!ipxe
    echo ${cfg.banner} stage 2

    :net
    set example_client:hex 53:54:00:70:e6:6c
    iseq ''${mac} ''${example_client} && goto vpsadminos ||
    ${mapping_items}
    goto menu

    :menu
    :restart
    menu iPXE boot menu
    item normal Boot normally
    ${optionalString cfg.includeNetbootxyz "item netbootxyz netboot.xyz"}
    ${menu_items}
    item loop Start iPXE shell
    item off Shutdown
    item reset Reboot
    choose --default vpsadminos --timeout 5000 res || goto restart
    goto ''${res}

    :off
    poweroff
    goto off
    :reset
    reboot
    goto reset

    :loop
    login || goto cancelled

    iseq ''${password} ${cfg.password} && goto is_correct ||
    echo password wrong
    sleep 5
    goto loop

    :cancelled
    echo you gave up, goodbye
    sleep 5
    poweroff
    goto cancelled

    :is_correct
    shell

    ${optionalString cfg.includeNetbootxyz ''
      :netbootxyz
      imgtrust --allow
      chain http://boot.netboot.xyz
    ''}

    ${items_vpsadminos}
    ${items_nixos}
  '';

  ipxe = pkgs.lib.overrideDerivation pkgs.ipxe (x: {
    script = pkgs.writeText "embed.ipxe" ''
      #!ipxe
      echo ${cfg.banner} stage 1
      imgtrust ${optionalString (!cfg.includeNetbootxyz) "--permanent"}
      dhcp
      imgfetch http://${server}/script.ipxe
      imgverify script.ipxe http://${server}/script.ipxe.sig
      chain script.ipxe
      echo temporary debug shell
      shell
    '';
    ca_cert = /secrets/ca/root.pem;
    nativeBuildInputs = x.nativeBuildInputs ++ [ pkgs.openssl ];
    makeFlags = x.makeFlags ++ [
      ''EMBED=''${script}''
      ''TRUST=''${ca_cert}''
      "CERT=${/secrets/ca/codesign.crt},${/secrets/ca/root.pem}"
    ];

    enabledOptions = x.enabledOptions ++ [ "CONSOLE_SERIAL" "POWEROFF_CMD" "IMAGE_TRUST_CMD" ];
  });

  pxeLinuxDefault = pkgs.writeText "default" ''
    DEFAULT ipxe
    LABEL ipxe
    KERNEL ipxe.lkrn
    '';

  tftp_root = pkgs.runCommand "tftproot" {} ''
    mkdir -pv $out
    mkdir $out/pxelinux.cfg

    ln -s ${pxeLinuxDefault} $out/pxelinux.cfg/default

    ln -s ${pkgs.syslinux}/share/syslinux/pxelinux.0 $out/pxelinux.0
    ln -s ${pkgs.syslinux}/share/syslinux/ldlinux.c32 $out/ldlinux.c32

    ln -s ${ipxe}/ipxe.lkrn $out/ipxe.lkrn

    #cp -vi ${ipxe}/undionly.kpxe $out/undionly.kpxe
  '';

  nginx_root = pkgs.runCommand "nginxroot" { buildInputs = [ pkgs.openssl ]; } ''
    mkdir -pv $out

    ln -sv ${ipxe_script} $out/script.ipxe
    function signit {
      openssl cms -sign -binary -noattr -in $1 -signer ${/secrets/ca/codesign.crt} -inkey ${/secrets/ca/codesign.key} -certfile ${/secrets/ca/root.pem} -outform DER -out ''${1}.sig
    }
    signit $out/script.ipxe

    ${items_symlinks cfg.nixosItems ""}
    ${items_symlinks cfg.vpsadminosItems privateDir}
  '';
in
{
  options = {
    netboot = rec {
      host = mkOption {
        type = types.str;
        description = "Hostname or IP address of the netboot server";
      };

      banner = mkOption {
        type = types.str;
        description = "Message to display on ipxe script load";
        default = "ipxe loading";
      };

      includeNetbootxyz = mkOption {
        type = types.bool;
        description = "Include netboot.xyz entry";
        default = false;
      };

      password = mkOption {
        type = types.str;
        description = "IPXE menu password";
        default = "letmein";
      };

      nixosItems = mkOption {
        type = types.attrsOf types.unspecified;
        default = {};
      };

      vpsadminosItems = mkOption {
        type = types.attrsOf types.unspecified;
        default = {};
      };

      mappings = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };

      acmeSSL = mkOption {
        type = types.bool;
        description = "Enable ACME and SSL for netboot host";
        default = false;
      };
    };
  };

  config = {
    networking.firewall.allowedUDPPorts = [ 68 69 ];
    networking.firewall.allowedTCPPorts = [ 80 ] ++ lib.optional cfg.acmeSSL 443;

    services.tftpd = {
        enable = true;
        path = tftp_root;
    };

    services.nginx = {
      enable = true;
      virtualHosts = {
        "${server}" = {
          root = nginx_root;
          addSSL = cfg.acmeSSL;
          enableACME = cfg.acmeSSL;
          locations = {
            "/" = {
              extraConfig = "autoindex on;";
            };
            "/${privateDir}" = {
              extraConfig = ''
                allow   172.16.254.0/24;
                allow   172.19.254.0/24;
                deny    all;
              '';
            };
          };
        };
      };
    };
  };
}

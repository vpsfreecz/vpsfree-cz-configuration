{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.services.netboot;
  server = cfg.host;
  secretsDir = cfg.secretsDir;
  # these are needed for iPXE build
  # Warning: secretsDir will end up in a nix/store
  caCert = "${secretsDir}/root.pem";
  caCodesign = "${secretsDir}/codesign.crt";

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

  ipxe_boot_vpsadminos = { name, item, runlevel ? "default", kernelParams ? [] }: ''
    imgfree
    imgfetch http://${server}/${name}/kernel systemConfig=${builtins.unsafeDiscardStringContext item.toplevel} ${toString item.kernelParams} runlevel=${runlevel} ${concatStringsSep " " kernelParams} || goto normal
    imgfetch http://${server}/${name}/initrd || goto normal
    imgfetch http://${server}/${name}/root.squashfs root.squashfs || goto normal
    imgverify kernel http://${server}/${name}/kernel.sig
    imgverify initrd http://${server}/${name}/initrd.sig
    imgverify root.squashfs http://${server}/${name}/root.squashfs.sig
    imgselect kernel
    boot
  '';

  ipxe_item_vpsadminos = name: item: ''
    :${name}
    menu ${name} menu
    item ${name}_default Default runlevel
    item ${name}_nopools Default runlevel without container imports
    item ${name}_nostart Default runlevel without container autostart
    item ${name}_rescue Rescue runlevel (network and sshd)
    item ${name}_single Single-user runlevel (console only)
    choose --default ${name}_default --timeout 5000 runlevel || goto :restart
    goto ''${runlevel}

    :${name}_default
    ${ipxe_boot_vpsadminos { inherit name item; runlevel = "default"; }}

    :${name}_nopools
    ${ipxe_boot_vpsadminos { inherit name item; runlevel = "default"; kernelParams = [ "osctl.pools=0" ]; }}

    :${name}_nostart
    ${ipxe_boot_vpsadminos { inherit name item; runlevel = "default"; kernelParams = [ "osctl.autostart=0" ]; }}

    :${name}_rescue
    ${ipxe_boot_vpsadminos { inherit name item; runlevel = "rescue"; }}

    :${name}_single
    ${ipxe_boot_vpsadminos { inherit name item; runlevel = "single"; }}
  '';

  concatNl = concatStringsSep "\n";
  items_nixos = concatNl (mapAttrsToList ipxe_item_nixos cfg.nixosItems);
  items_vpsadminos = concatNl (mapAttrsToList ipxe_item_vpsadminos cfg.vpsadminosItems);

  all_items = cfg.nixosItems // cfg.vpsadminosItems;

  items_symlinks = items: concatNl (mapAttrsToList (name: x: ''
      mkdir -p $out/${name}
      for i in ${x.dir}/*; do
        ln -s $i $out/${name}/$( basename $i)
        signit $out/${name}/$( basename $i )
      done
    '') items);

  menu_items = concatNl (mapAttrsToList (name: x: "item ${name} ${x.menu}" )
    (filterAttrs (const (hasAttr "menu")) all_items));

  extract_mapping = name: item:
    map (mac: nameValuePair mac name) (item.macs or []);

  extract_mappings = items:
    flatten (mapAttrsToList extract_mapping items);

  all_mappings =
    mergeAttrs
      (listToAttrs (flatten (map extract_mappings [ cfg.nixosItems cfg.vpsadminosItems ])))
      cfg.extraMappings;

  mapping_items =
    concatNl (mapAttrsToList (mac: item: "iseq \${mac} ${mac} && goto ${item} ||") all_mappings);

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

  ipxe = pkgs.lib.overrideDerivation pkgs.ipxe (x: rec {
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
    nativeBuildInputs = x.nativeBuildInputs ++ [ pkgs.openssl ];
    makeFlags = x.makeFlags ++ [
      "EMBED=${script}"
      "TRUST=${caCert}"
      "CERT=${caCodesign},${caCert}"
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
      openssl cms -sign -binary -noattr -in $1 -signer ${secretsDir}/codesign.crt -inkey ${secretsDir}/codesign.key -certfile ${secretsDir}/root.pem -outform DER -out ''${1}.sig
    }
    signit $out/script.ipxe

    ${items_symlinks cfg.nixosItems}
    ${items_symlinks cfg.vpsadminosItems}
  '';
in
{
  options = {
    services.netboot = rec {
      enable = mkEnableOption "Enable netboot server";

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

      secretsDir = mkOption {
        type = types.path;
        description = "Directory containing signing secrets";
        default = /secrets/ca;
      };

      nixosItems = mkOption {
        type = types.attrsOf types.unspecified;
        default = {};
      };

      vpsadminosItems = mkOption {
        type = types.attrsOf types.unspecified;
        default = {};
      };

      extraMappings = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };

      acmeSSL = mkOption {
        type = types.bool;
        description = "Enable ACME and SSL for netboot host";
        default = false;
      };

      allowedIPRanges = mkOption {
        type = types.listOf types.str;
        description = ''
          Allow HTTP access for these IP ranges, if not specified
          access is not restricted.
        '';
        default = [];
        example = "10.0.0.0/24";
      };
    };
  };

  config = mkIf cfg.enable {
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
              extraConfig = ''
                autoindex on;
                ${optionalString (cfg.allowedIPRanges != []) ''
                  ${concatStringsSep "\n" (flip map cfg.allowedIPRanges (range: "allow ${range};"))}
                  deny all;
                ''}
              '';
            };
          };
        };
      };
    };
  };
}

{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.services.netboot;
  server = cfg.host;
  secretsDir = cfg.secretsDir;

  allItems = cfg.nixosItems // cfg.vpsadminosItems;

  concatNl = concatStringsSep "\n";

  # See https://wiki.syslinux.org/wiki/index.php?title=PXELINUX#Configuration
  transformMac = mac: replaceStrings [ ":" ] [ "-" ] mac;

  symlinkItemsBoot = items: concatNl (mapAttrsToList (name: item: ''
    mkdir -p $out/boot/${name}
    for i in ${item.dir}/{kernel,bzImage,initrd}; do
      [ -e "$i" ] && ln -s $i $out/boot/${name}/$( basename $i)
    done
  '') items);

  symlinkItemsRootfs = items: concatNl (mapAttrsToList (name: item: ''
    mkdir -p $out/${name}
    for i in ${item.dir}/root.squashfs; do
      ln -s $i $out/${name}/$( basename $i)
    done
  '') items);

  nginxRoot = pkgs.runCommand "nginxroot" { buildInputs = [ pkgs.openssl ]; } ''
    mkdir -pv $out

    ${symlinkItemsRootfs cfg.nixosItems}
    ${symlinkItemsRootfs cfg.vpsadminosItems}
  '';

  extractMapping = name: item:
    map (mac: nameValuePair mac name) (item.macs or []);

  extractMappings = items:
    flatten (mapAttrsToList extractMapping items);

  allMappings =
    mergeAttrs
      (listToAttrs (flatten (map extractMappings [ cfg.nixosItems cfg.vpsadminosItems ])))
      cfg.extraMappings;

  osFragmentVar =
    { name, item, variant, label, runlevel ? "default", kernelParams ? [] }: ''
      LABEL ${variant}
        MENU LABEL ${label}
        LINUX boot/${name}/kernel
        INITRD boot/${name}/initrd
        APPEND httproot=http://${server}/${name}/root.squashfs init=${builtins.unsafeDiscardStringContext item.toplevel}/init ${toString item.kernelParams} runlevel=${runlevel} ${concatStringsSep " " kernelParams}
    '';

  osFragment = name: item:
    let
      default = osFragmentVar {
        inherit name item;
        variant = "default";
        label = "Default runlevel";
      };

      nopools = osFragmentVar {
        inherit name item;
        variant = "nopools";
        label = "Default runlevel without container imports";
        kernelParams = [ "osctl.pools=0" ];
      };

      nostart = osFragmentVar {
        inherit name item;
        variant = "nostart";
        label = "Default runlevel without container autostart";
        kernelParams = [ "osctl.autostart=0" ];
      };

      rescue = osFragmentVar {
        inherit name item;
        variant = "rescue";
        label = "Rescue runlevel (network and sshd)";
        runlevel = "rescue";
      };

      single = osFragmentVar {
        inherit name item;
        variant = "single";
        label = "Single-user runlevel (console only)";
        runlevel = "single";
      };

      variants = concatNl [
        default
        nopools
        nostart
        rescue
        single
      ];
    in ''
      MENU TITLE ${name}

      ${variants}

      LABEL mainmenu
        MENU LABEL < Main Menu
        KERNEL menu.c32
        APPEND pxelinux.cfg/default
    '';

  osItemIncludeConfigs = mapAttrs (name: item:
    pkgs.writeText "${name}.cfg" (osFragment name item)
  ) cfg.vpsadminosItems;

  osItemDirectConfigs = mapAttrs (name: item: pkgs.writeText "${name}.cfg" ''
    DEFAULT menu.c32
    TIMEOUT 50
    ${osFragment name item}
  '') cfg.vpsadminosItems;

  osMenuFragment = mapAttrsToList (name: item: ''
    LABEL ${name}
      MENU LABEL ${name} >
      KERNEL menu.c32
      APPEND pxeserver/${name}.cfg
  '') cfg.vpsadminosItems;

  pxeOsMenu = pkgs.writeText "vpsadminos.cfg" ''
    MENU TITLE vpsAdminOS

    LABEL mainmenu
      MENU LABEL < Main Menu
      KERNEL menu.c32
      APPEND pxelinux.cfg/default

    ${concatNl osMenuFragment}
  '';

  nixosMenuFragment = mapAttrsToList (name: item: ''
    LABEL ${name}
      MENU LABEL ${item.menu or name}
      LINUX boot/${name}/bzImage
      INITRD boot/${name}/initrd
      APPEND init=${builtins.unsafeDiscardStringContext item.toplevel}/init loglevel=7
  '') cfg.nixosItems;

  pxeNixosMenu = pkgs.writeText "nixos.cfg" ''
    MENU TITLE NixOS

    LABEL mainmenu
      MENU LABEL < Main Menu
      KERNEL menu.c32
      APPEND pxelinux.cfg/default

    ${concatNl nixosMenuFragment}
  '';

  pxeLinuxDefault = pkgs.writeText "default" ''
    DEFAULT menu.c32
    PROMPT 0
    TIMEOUT 0
    MENU TITLE ${config.networking.hostName}

    LABEL nixos
      MENU LABEL NixOS >
      KERNEL menu.c32
      APPEND pxeserver/nixos.cfg

    LABEL vpsadminos
      MENU LABEL vpsAdminOS >
      KERNEL menu.c32
      APPEND pxeserver/vpsadminos.cfg

    LABEL local_boot
      MENU LABEL Local Boot
      LOCALBOOT 0

    LABEL warm_reboot
      MENU LABEL Warm Reboot
      KERNEL reboot.c32
      APPEND --warm

    LABEL cold_reboot
      MENU LABEL Cold Reboot
      KERNEL reboot.c32
  '';

  tftpRoot = pkgs.runCommand "tftproot" {} ''
    mkdir -pv $out
    mkdir $out/pxelinux.cfg $out/pxeserver

    # pxelinux programs
    for prog in pxelinux.0 ldlinux.c32 libcom32.c32 libutil.c32 menu.c32 reboot.c32 ; do
      ln -s ${pkgs.syslinux}/share/syslinux/$prog $out/$prog
    done

    # The default configuration
    ln -s ${pxeLinuxDefault} $out/pxelinux.cfg/default

    # Per-mac address configs
    ${concatNl (mapAttrsToList (mac: name: ''
      ln -s ${osItemDirectConfigs.${name}} $out/pxelinux.cfg/01-${transformMac mac}
    '') allMappings)}

    # Grouped menus for NixOS and vpsAdminOS items
    ln -s ${pxeNixosMenu} $out/pxeserver/nixos.cfg
    ln -s ${pxeOsMenu} $out/pxeserver/vpsadminos.cfg

    ${concatNl (mapAttrsToList (name: cfg: ''
      ln -s ${cfg} $out/pxeserver/${name}.cfg
    '') osItemIncludeConfigs)}

    # Links for kernels and initrd
    ${symlinkItemsBoot cfg.nixosItems}
    ${symlinkItemsBoot cfg.vpsadminosItems}
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
    networking.firewall = {
      allowedTCPPorts = [ 80 ] ++ lib.optional cfg.acmeSSL 443;

      extraCommands = mkIf (cfg.allowedIPRanges != []) (concatNl (map (net: ''
        iptables -A nixos-fw -p udp -s ${net} --dport 68 -j nixos-fw-accept
        iptables -A nixos-fw -p udp -s ${net} --dport 69 -j nixos-fw-accept
      '') cfg.allowedIPRanges));
    };

    services.tftpd = {
      enable = true;
      path = tftpRoot;
    };

    services.nginx = {
      enable = true;

      appendConfig = ''
        worker_processes auto;
      '';

      virtualHosts = {
        "${server}" = {
          root = nginxRoot;
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

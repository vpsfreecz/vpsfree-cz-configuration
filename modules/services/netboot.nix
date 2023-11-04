{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.services.netboot;
  server = cfg.host;

  allItems = cfg.nixosItems // cfg.vpsadminosItems;

  concatNl = concatStringsSep "\n";

  # See https://wiki.syslinux.org/wiki/index.php?title=PXELINUX#Configuration
  transformMac = mac: replaceStrings [ ":" ] [ "-" ] mac;

  copyOrSymlink = name: item: type: pattern: pkgs.runCommand "netboot-${name}-${type}" {} ''
    mkdir $out
    for i in ${item.dir}/${pattern}; do
      [ ! -e "$i" ] && continue
      ${if cfg.copyItems then ''
      cp -L $i $out/$(basename $i)
      '' else ''
      ln -s $i $out/$(basename $i)
      ''}
    done
  '';

  deployItemsBoot = items: concatNl (mapAttrsToList (name: item: ''
    mkdir -p $out/boot
    ln -s ${copyOrSymlink name item "boot" "{kernel,bzImage,initrd}"} $out/boot/${name}
  '') items);

  deployItemsRootfs = items: concatNl (mapAttrsToList (name: item: ''
    ln -s ${copyOrSymlink name item "rootfs" "root.squashfs"} $out/${name}
  '') items);

  nginxRoot = pkgs.runCommand "nginxroot" { buildInputs = [ pkgs.openssl ]; } ''
    mkdir -pv $out

    ${deployItemsRootfs cfg.nixosItems}
    ${deployItemsRootfs cfg.vpsadminosItems}
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
    ${deployItemsBoot cfg.nixosItems}
    ${deployItemsBoot cfg.vpsadminosItems}
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

      copyItems = mkOption {
        type = types.bool;
        default = true;
        description = ''
          If enabled, kernel/initrd/squashfs images are copied to tftp/nginx
          roots, so that dependencies on the contained store paths are dropped.

          When deploying to a remote PXE server, you want this option to be enabled
          to reduce the amount of data being transfered. If the PXE server
          is running on the build machine itself, disabling this option will
          make the build faster.
        '';
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

      tftp.bindAddress = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          The address for the TFTP server to bind on
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [ 80 ] ++ lib.optional cfg.acmeSSL 443;

      extraCommands = mkIf (cfg.allowedIPRanges != []) (concatNl (map (net: ''
        # Allow access from ${net} for netboot
        iptables -A nixos-fw -p udp -s ${net} ${optionalString (!isNull cfg.tftp.bindAddress) "-d ${cfg.tftp.bindAddress}"} --dport 68 -j nixos-fw-accept
        iptables -A nixos-fw -p udp -s ${net} ${optionalString (!isNull cfg.tftp.bindAddress) "-d ${cfg.tftp.bindAddress}"} --dport 69 -j nixos-fw-accept
      '') cfg.allowedIPRanges));
    };

    systemd.services.netboot-atftpd = {
      description = "TFTP Server for Netboot";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      # runs as nobody
      serviceConfig.ExecStart = toString ([
        "${pkgs.atftp}/sbin/atftpd"
        "--daemon"
        "--no-fork"
      ] ++ (optional (!isNull cfg.tftp.bindAddress) [ "--bind-address" cfg.tftp.bindAddress ])
        ++ [ tftpRoot ]);
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

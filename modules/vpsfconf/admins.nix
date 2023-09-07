{ config, pkgs, lib, ... }:
let
  inherit (lib) mkOption types;

  makeSshKeys = name: admin: map (pubkey: (lib.concatStringsSep "," [
    ''environment="VPSFCONF_ADMIN=${name}"''
    ''environment="VPSADMIN_USER_ID=${toString admin.vpsadmin.id}"''
    ''environment="VPSADMIN_USER_NAME=${admin.vpsadmin.name}"''
  ]) + " " + pubkey) admin.publicKeys;

  makeInteractiveShellInit = admins:
    let
      withShell = lib.filterAttrs (name: admin: admin.interactiveShellInit != null) admins;
      script = name: admin: pkgs.writeText "admin-${name}.sh" admin.interactiveShellInit;
      fragments = lib.mapAttrsToList (name: admin: ''
        if [ "$VPSADMIN_USER_ID" == "${toString admin.vpsadmin.id}" ] ; then
          . ${script name admin}
        fi
      '') withShell;
    in lib.concatStringsSep "\n" fragments;

  adminModule =
    { config, name, ... }:
    {
      options = {
        vpsadmin = mkOption {
          type = types.submodule {
            options = {
              id = mkOption {
                type = types.int;
                description = "vpsAdmin user ID";
              };

              name = mkOption {
                type = types.str;
                description = "vpsAdmin user name";
              };
            };
          };
          description = lib.mdDoc ''
            Associated vpsAdmin account
          '';
        };

        publicKeys = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "SSH public keys";
        };

        publicKeysForSsh = mkOption {
          type = types.listOf types.str;
          readOnly = true;
          description = lib.mdDoc ''
            SSH public keys to be used by `users.user.<name>.openssh.authorizedKeys`
          '';
        };

        interactiveShellInit = mkOption {
          type = types.nullOr types.lines;
          default = null;
          description = lib.mdDoc ''
            Shell script code called during interactive bash shell initialisation
          '';
        };
      };

      config = {
        publicKeysForSsh = makeSshKeys name config;
      };
    };
in {
  options = {
    vpsfconf.admins = mkOption {
      type = types.attrsOf (types.submodule adminModule);
      default = {};
      description = lib.mdDoc ''
        Declare vpsFree.cz admins.

        Since all admins share the root account, this module defines environment
        variables to identify which admin is currently logged in over SSH.
        The following environment variables are defined:

          - `VPSFCONF_ADMIN` name of the admin in this configuration,
          - `VPSADMIN_USER_ID` id of the admin in vpsAdmin,
          - `VPSADMIN_USER_NAME` name in vpsAdmin.

        It is also possible to set interactive shell init scripts that are run
        only when the specific admin logs in.
      '';
    };
  };

  config = {
    services.openssh.settings.PermitUserEnvironment = "VPSFCONF_ADMIN,VPSADMIN_USER_ID,VPSADMIN_USER_NAME";

    programs.bash.interactiveShellInit = makeInteractiveShellInit config.vpsfconf.admins;
  };
}

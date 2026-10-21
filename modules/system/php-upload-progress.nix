{ lib, ... }:
{
  # Disable session upload progress as a precaution pending upstream PHP fixes.
  options.services.phpfpm.pools = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config = {
          phpOptions = lib.mkAfter ''
            session.upload_progress.enabled = Off
          '';

          # Enforce this after package INI and per-directory configuration.
          settings."php_admin_flag[session.upload_progress.enabled]" = lib.mkForce false;
        };
      }
    );
  };
}

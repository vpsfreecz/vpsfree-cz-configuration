{ pkgs, lib, config, confLib, ... }:
{
  vpsadmin.nodectld = {
    enable = true;

    settings = {
      mode = "minimal";

      vpsadmin = {
        net_interfaces = [ "venet0" ];

        transaction_public_key = pkgs.writeText "transaction.key" ''
          -----BEGIN PUBLIC KEY-----
          MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3NbZREAR9D/24C4NK99s
          ZXfOXWXRRhwo2PFAqAeCrKD5ptZqgr4MBXPCvIhS+FgEMl5EEHqroanSYiT1M+X0
          Kn+2qXJuff+ePe3iiihjxhLxn0WxC5HI5aEigOhSfKNWnH71brMZwN6CIhrb0muh
          dEQ6CjpdRXAbP497HcnCoZ5GmWLxKrIw526aoimU3M+MoSnDvZ5eAxuXHnEVpvXc
          guSgWMYhcMTJnWUnyZR4RwmUEFSiWQ1TvjsxG94zCfr/sUtC3DrOJYqC3YPGnIhJ
          VEu0Ub2NW/uSKVhtlGGCXqhW8HCtd9+VXrpna2x6GZlLvcEMfNuMD6UJqmsfI18W
          HwIDAQAB
          -----END PUBLIC KEY-----
        '';
      };

      mailer = {
        smtp_server = "mxproxy.vpsfree.cz";
        smtp_port = 25;
      };
    };
  };
}

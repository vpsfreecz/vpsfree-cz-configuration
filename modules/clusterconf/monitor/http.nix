{
  "vpsfree_cz" = {
    targets = [ "https://vpsfree.cz/prihlaska/fyzicka-osoba/" ];
    host = "vpsfree.cz";
    labels = {
      alias = "vpsfree.cz";
      type = "vpsfree-web";
    };
  };

  "vpsfree_org" = {
    targets = [ "https://vpsfree.org/registration/fyzicka-osoba/" ];
    host = "vpsfree.org";
    labels = {
      alias = "vpsfree.org";
      type = "vpsfree-web";
    };
  };

  "api_vpsfree_cz" = {
    targets = [ "https://api.vpsfree.cz/" ];
    host = "api.vpsfree.cz";
    labels = {
      alias = "api.vpsfree.cz";
      type = "vpsadmin-api";
    };
  };

  "console_vpsfree_cz" = {
    targets = [ "https://console.vpsfree.cz/vzconsole.js" ];
    host = "console.vpsfree.cz";
    labels = {
      alias = "vpsadmin.vpsfree.cz";
      type = "vpsadmin-console";
    };
  };

  "vpsadmin_vpsfree_cz" = {
    targets = [ "https://vpsadmin.vpsfree.cz/" ];
    host = "vpsadmin.vpsfree.cz";
    labels = {
      alias = "vpsadmin.vpsfree.cz";
      type = "vpsadmin-webui";
    };
  };
}

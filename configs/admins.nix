{ config, confData, ... }:
{
  vpsfconf.admins = {
    aither = {
      vpsadmin = {
        id = 51;
        name = "Aither";
      };

      publicKeys = confData.sshKeys.aither.all;
    };

    kerrycze = {
      vpsadmin = {
        id = 53;
        name = "KerryCZE";
      };

      publicKeys = [ confData.sshKeys.kerrycze ];
    };

    martyet = {
      vpsadmin = {
        id = 2442;
        name = "martyet";
      };

      publicKeys = [ confData.sshKeys.martyet ];
    };

    snajpa = {
      vpsadmin = {
        id = 1;
        name = "snajpa";
      };

      publicKeys = [ confData.sshKeys.snajpa ];
    };
  };
}

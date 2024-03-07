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

    snajpa = {
      vpsadmin = {
        id = 1;
        name = "snajpa";
      };

      publicKeys = [ confData.sshKeys.snajpa ];
    };
  };
}

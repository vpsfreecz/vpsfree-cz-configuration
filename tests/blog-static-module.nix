{ nixpkgs }:
let
  lib = nixpkgs.lib;
  candidate = ../cluster/cz.vpsfree/containers/int.blog/static-blog.nix;
  wordpress = ../cluster/cz.vpsfree/containers/int.blog/wordpress.nix;
  evaluate =
    modules:
    (import "${nixpkgs}/nixos/lib/eval-config.nix" {
      system = "x86_64-linux";
      specialArgs.confLib.findMetaConfig = _: {
        addresses.primary.address = "127.0.0.1";
      };
      modules = [
        wordpress
        ({ lib, ... }: {
          options.cluster = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          config = {
            system.stateVersion = "26.05";
            networking.hostName = "blog-fixture";
          };
        })
      ]
      ++ modules;
    }).config;
  original = evaluate [ ];
  disabled = evaluate [ candidate ];
  enabled = evaluate [
    candidate
    { services.vpsfree-static-blog.enable = true; }
  ];
  forbidden = evaluate [
    candidate
    {
      services.vpsfree-static-blog = {
        enable = true;
        pull.enable = true;
      };
    }
  ];
  effective = c: {
    wordpress = c.services.wordpress.sites."blog.vpsfree.cz".settings;
    wordpressRoot = c.services.nginx.virtualHosts."blog.vpsfree.cz".root;
    wordpressListen = c.services.nginx.virtualHosts."blog.vpsfree.cz".listen;
    virtualHostNames = builtins.attrNames c.services.nginx.virtualHosts;
    tcpPorts = c.networking.firewall.allowedTCPPorts;
    firewall = c.networking.firewall.extraCommands;
    units = builtins.attrNames c.systemd.services;
    timers = builtins.attrNames c.systemd.timers;
    users = builtins.attrNames c.users.users;
    tmpfiles = c.systemd.tmpfiles.rules;
  };
  cs = enabled.services.nginx.virtualHosts.static-blog-cs;
  en = enabled.services.nginx.virtualHosts.static-blog-en;
  disabledSame = effective original == effective disabled;
  wpPreserved =
    enabled.services.nginx.virtualHosts."blog.vpsfree.cz".root
    == original.services.nginx.virtualHosts."blog.vpsfree.cz".root
    &&
      enabled.services.nginx.virtualHosts."blog.vpsfree.cz".listen
      == original.services.nginx.virtualHosts."blog.vpsfree.cz".listen;
  blocked = lib.any (
    a: lib.hasInfix "installed machine-coordination admission" a.message && !a.assertion
  ) forbidden.assertions;
in
assert disabledSame;
assert wpPreserved;
assert blocked;
assert !(builtins.elem 8080 enabled.networking.firewall.allowedTCPPorts);
assert cs.root == "/var/lib/blog/current/cs" && en.root == "/var/lib/blog/current/en";
assert cs.locations."= /feed/".alias == "/var/lib/blog/current/cs/feed/index.xml";
assert cs.locations."~* \\.php(?:/|$)".return == "404";
assert enabled.services.nginx.virtualHosts.static-blog-unknown-host.locations."/".return == "444";
assert !(builtins.hasAttr "blog-static-pull" enabled.systemd.timers);
{
  disabledEffectiveStateIdentical = disabledSame;
  existingWordpressPreserved = wpPreserved;
  scheduledActivationRefused = blocked;
  newListenerPorts = map (listen: listen.port) cs.listen;
  staticRoots = [
    cs.root
    en.root
  ];
  feedContentType = cs.locations."= /feed/".extraConfig;
  phpDenied = true;
  unknownHostRejected = true;
}

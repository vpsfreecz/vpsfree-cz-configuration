self: super: {
  geminabox = super.callPackage ../packages/geminabox { };

  node-exporter-textfile-collector-scripts =
    super.callPackage ../packages/node-exporter-textfile-collector-scripts.nix
      { };

  mosh-osc-colors = super.callPackage ../packages/mosh-osc-colors.nix { };

  discourse-oauth-signup-policy = super.callPackage ../packages/discourse-oauth-signup-policy { };

  ruby-bepasty-client = super.callPackage ../packages/ruby-bepasty-client { };

  sachet = super.callPackage ../packages/sachet { };

  syslog-exporter = super.callPackage ../packages/syslog-exporter { };

  ssh-exporter = super.callPackage ../packages/ssh-exporter { };

  vpsfree-irc-bot = super.callPackage ../packages/vpsfree-irc-bot { };
}

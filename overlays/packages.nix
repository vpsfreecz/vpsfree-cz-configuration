self: super:
{
  geminabox = super.callPackage ../packages/geminabox {};

  node-exporter-textfile-collector-scripts = super.callPackage ../packages/node-exporter-textfile-collector-scripts.nix {};

  ruby-bepasty-client = super.callPackage ../packages/ruby-bepasty-client {};

  sachet = super.callPackage ../packages/sachet {};

  syslog-exporter = super.callPackage ../packages/syslog-exporter {};

  ssh-exporter = super.callPackage ../packages/ssh-exporter {};

  vpsf-status = super.callPackage ../packages/vpsf-status {};

  vpsfree-irc-bot = super.callPackage ../packages/vpsfree-irc-bot {};
}

self: super:
{
  geminabox = super.callPackage ../packages/geminabox {};

  havesnippet-client = super.callPackage ../packages/havesnippet-client {};

  node-exporter-textfile-collector-scripts = super.callPackage ../packages/node-exporter-textfile-collector-scripts.nix {};

  sachet = super.callPackage ../packages/sachet {};

  vpsf-status = super.callPackage ../packages/vpsf-status {};

  vpsfree-irc-bot = super.callPackage ../packages/vpsfree-irc-bot {};
}

self: super:
{
  havesnippet-client = super.callPackage ../packages/havesnippet-client {};

  node-exporter-textfile-collector-scripts = super.callPackage ../packages/node-exporter-textfile-collector-scripts.nix {};

  sachet = super.callPackage ../packages/sachet {};
}

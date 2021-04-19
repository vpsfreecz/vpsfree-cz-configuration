self: super:
{
  graylogPlugins = super.graylogPlugins // (super.callPackage ../packages/graylog/plugins.nix {});

  havesnippet-client = super.callPackage ../packages/havesnippet-client {};

  node-exporter-textfile-collector-scripts = super.callPackage ../packages/node-exporter-textfile-collector-scripts.nix {};

  sachet = super.callPackage ../packages/sachet {};
}

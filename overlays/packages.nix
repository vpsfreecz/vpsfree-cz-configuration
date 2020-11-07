self: super:
{
  graylogPlugins = super.graylogPlugins // (super.callPackage ../packages/graylog/plugins.nix {});

  havesnippet-client = super.callPackage ../packages/havesnippet-client {};

  sachet = super.callPackage ../packages/sachet {};
}

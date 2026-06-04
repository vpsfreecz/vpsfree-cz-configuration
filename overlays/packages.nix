self: super:
let
  muninCgiPerlPath =
    with self.perlPackages;
    makeFullPerlPath [
      CGI
      CGIFast
    ];
in
{
  geminabox = super.callPackage ../packages/geminabox { };

  node-exporter-textfile-collector-scripts =
    super.callPackage ../packages/node-exporter-textfile-collector-scripts.nix
      { };

  munin = super.munin.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ../packages/munin/use-lib-in-fcgi-scripts.patch
    ];

    postFixup = (oldAttrs.postFixup or "") + ''
      for file in "$out"/www/cgi/*; do
        substituteInPlace "$file" \
          --replace-fail "export PERL5LIB='" "export PERL5LIB='${muninCgiPerlPath}:"
      done
    '';
  });

  mosh-osc-colors = super.callPackage ../packages/mosh-osc-colors.nix { };

  discourse-oauth-signup-policy = super.callPackage ../packages/discourse-oauth-signup-policy { };

  ruby-bepasty-client = super.callPackage ../packages/ruby-bepasty-client { };

  sachet = super.callPackage ../packages/sachet { };

  syslog-exporter = super.callPackage ../packages/syslog-exporter { };

  ssh-exporter = super.callPackage ../packages/ssh-exporter { };

  vpsfree-irc-bot = super.callPackage ../packages/vpsfree-irc-bot { };
}

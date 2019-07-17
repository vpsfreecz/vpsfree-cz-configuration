let
  pkgs = import <nixpkgs> { overlays = [ (import ./overlays/morph.nix) ]; };
  lib = pkgs.lib;
  stdenv = pkgs.stdenv;

in stdenv.mkDerivation rec {
  name = "vpsfree-cz-configuration";

  buildInputs = with pkgs; [
    git
    morph
    nix-prefetch-git
    ruby
  ];

  shellHook = ''
    BASEDIR="$(realpath `pwd`)"
    export GEM_HOME="$(pwd)/.gems"
    BINDIR="$(ruby -e 'puts Gem.bindir')"
    mkdir -p "$BINDIR"
    export PATH="$BINDIR:$PATH"
    export RUBYLIB="$GEM_HOME:$BASEDIR/confctl/lib"
    gem install --no-document bundler
    pushd confctl
    bundle install
    popd

    cat <<EOF > "$BINDIR/confctl"
    #!${pkgs.ruby}/bin/ruby
    ENV['BUNDLE_GEMFILE'] = "$BASEDIR/confctl/Gemfile"

    require 'bundler'
    Bundler.setup

    load File.join('$BASEDIR', 'confctl/bin/confctl')
    EOF
    chmod +x "$BINDIR/confctl"
  '';
}

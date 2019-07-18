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
    openssl
    ruby
  ];

  shellHook = ''
    BASEDIR="$(realpath `pwd`)"
    export GEM_HOME="$(pwd)/.gems"
    BINDIR="$(ruby -e 'puts Gem.bindir')"
    mkdir -p "$BINDIR"
    export PATH="$BINDIR:$PATH"
    export RUBYLIB="$GEM_HOME:$BASEDIR/confctl/lib"
    export MANPATH="$BASEDIR/confctl/man:$(man --path)"
    gem install --no-document bundler
    pushd confctl
    bundle install
    rake md2man:man
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

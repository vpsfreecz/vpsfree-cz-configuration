{ config, pkgs, lib, confLib, confMachine, ... }:
let
  proxyPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  geminaboxPort = confMachine.services.geminabox.port;

  # Script to remove unused vpsAdminOS gems from the repository. We keep only
  # gems which are used in selected branches of the vpsAdminOS repository.
  # Unused gems are removed after 30 days.
  gcVpsAdminOSGems = pkgs.writeScript "gc-vpsadminos-gems" ''
    #!${pkgs.bash}/bin/bash

    set -e

    ### Configuration
    REPO_URL="https://github.com/vpsfreecz/vpsadminos"
    REPO_DIR="${config.services.geminabox.stateDir}/gc/vpsadminos.git"
    KEEP_BRANCH_PATTERNS="master staging prod-* staging-* devel devel-aither devel-snajpa osctl-env-exec"
    KEEP_DAYS=30
    GEM_DIR="${config.services.geminabox.settings.data}/gems"
    TRASH_DIR="${config.services.geminabox.stateDir}/trash"
    GEM_NAME_RX="(libosctl|osctl|osctld|osctl-exporter|osctl-exportfs|osctl-image|osctl-repo|osup|svctl|osvm|test-runner)"
    GEM_VERSION_RX="\d+\.\d+\.\d+\.build\d+\.gem"
    GEM_RX="''${GEM_NAME_RX}-''${GEM_VERSION_RX}"
    ###

    # Clone repo
    if [ ! -d "$REPO_DIR" ] ; then
      mkdir -p "$REPO_DIR"
      ${pkgs.git}/bin/git clone --mirror --bare "$REPO_URL" "$REPO_DIR" > /dev/null
    fi

    # Update repo
    cd "$REPO_DIR"
    ${pkgs.git}/bin/git fetch --all > /dev/null

    # Build a list of branches
    KEEP_BRANCH_NAMES=""

    for branch in $KEEP_BRANCH_PATTERNS ; do
      KEEP_BRANCH_NAMES="$KEEP_BRANCH_NAMES $(${pkgs.git}/bin/git branch --list "$branch" --format '%(refname:short)')"
    done

    # Get a list of all existing builds
    BUILDS_FILE=`mktemp /tmp/gc.XXXXXX`

    for commit in `${pkgs.git}/bin/git rev-list $KEEP_BRANCH_NAMES -- .build_id` ; do
      ${pkgs.git}/bin/git show $commit:.build_id >> "$BUILDS_FILE"
    done

    # Remove old builds
    cd "$GEM_DIR"
    for pkg in `find -mtime +$KEEP_DAYS -name "*.gem" -printf "%f\n" | grep -P "$GEM_RX"` ; do
      build_id=`echo $pkg | grep -oP "$GEM_VERSION_RX"`
      build_id="''${build_id%.*}"
      if ! grep -qx "$build_id" "$BUILDS_FILE" ; then
        echo "gc '$pkg'"
        mv "$pkg" "$TRASH_DIR/"
      fi
    done

    rm -f "$BUILDS_FILE"
  '';

  # Script to remove unused vpsAdmin gems from the repository. We keep only
  # gems which are used in selected branches of the vpsAdmin repository.
  # Unused gems are removed after 30 days.
  gcVpsAdminGems = pkgs.writeScript "gc-vpsadmin-gems" ''
    #!${pkgs.bash}/bin/bash

    set -e

    ### Configuration
    REPO_URL="https://github.com/vpsfreecz/vpsadmin"
    REPO_DIR="${config.services.geminabox.stateDir}/gc/vpsadmin.git"
    KEEP_BRANCH_PATTERNS="master devel prod-* staging-*"
    KEEP_DAYS=30
    GEM_DIR="${config.services.geminabox.settings.data}/gems"
    TRASH_DIR="${config.services.geminabox.stateDir}/trash"
    GEM_NAME_RX="(libnodectld|nodectl|nodectld)"
    GEM_VERSION_RX="\d+\.\d+\.\d+\.dev\.build\d+"
    GEM_RX="''${GEM_NAME_RX}-''${GEM_VERSION_RX}\.gem"
    ###

    # Clone repo
    if [ ! -d "$REPO_DIR" ] ; then
      mkdir -p "$REPO_DIR"
      ${pkgs.git}/bin/git clone --mirror --bare "$REPO_URL" "$REPO_DIR" > /dev/null
    fi

    # Update repo
    cd "$REPO_DIR"
    ${pkgs.git}/bin/git fetch --all > /dev/null

    # Build a list of branches
    KEEP_BRANCH_NAMES=""

    for branch in $KEEP_BRANCH_PATTERNS ; do
      KEEP_BRANCH_NAMES="$KEEP_BRANCH_NAMES $(${pkgs.git}/bin/git branch --list "$branch" --format '%(refname:short)')"
    done

    # Get a list of all existing builds
    BUILDS_FILE=`mktemp /tmp/gc.XXXXXX`

    for commit in `${pkgs.git}/bin/git rev-list $KEEP_BRANCH_NAMES -- packages/nodectld/Gemfile.lock` ; do
      ${pkgs.git}/bin/git show $commit:packages/nodectld/Gemfile.lock \
        | grep -xP "  nodectld \(= $GEM_VERSION_RX\)(!)?" \
        | grep -oP "$GEM_VERSION_RX" \
        >> "$BUILDS_FILE"
    done

    # Remove old builds
    cd "$GEM_DIR"
    for pkg in `find -mtime +$KEEP_DAYS -name "*.gem" -printf "%f\n" | grep -P "$GEM_RX"` ; do
      build_id=`echo $pkg | grep -oP "$GEM_VERSION_RX"`
      if ! grep -qx "$build_id" "$BUILDS_FILE" ; then
        echo "gc '$pkg'"
        mv "$pkg" "$TRASH_DIR/"
      fi
    done

    rm -f "$BUILDS_FILE"
  '';
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking.firewall.extraCommands = ''
    # Allow access to geminabox from proxy.prg
    iptables -A nixos-fw -p tcp --dport ${toString geminaboxPort} -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
  '';

  services.geminabox = {
    enable = true;
    address = "0.0.0.0";
    port = geminaboxPort;

    settings = {
      allow_replace = false;
      allow_delete = false;
    };

    pushBasicAuth = {
      enable = true;
      users = {
        aither = "/private/geminabox/aither.pw";
        aitherdev = "/private/geminabox/aitherdev.pw";
      };
    };

    garbage-collector = {
      enable = true;
      scripts = [
        gcVpsAdminOSGems
        gcVpsAdminGems
      ];
    };
  };

  system.stateVersion = "22.05";
}

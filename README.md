vpsfree.cz configuration
========================

This project uses harness from https://github.com/grafted-in/nixops-manager.
nixops command is wrapped with `./deploy/manage` script with pinned nixpkgs.


1. Install Nix - https://nixos.org/nix/

2. Clone this repository

    ~~~~~ bash
    git clone https://github.com/vpsfreecz/vpsfree-cz-configuration/
    ~~~~~

3. Geneate certificate authority for IPXE

    ~~~~~ bash
    ./gen-ca
    ~~~~~

4. Create the deployment:

    ~~~~~ bash
    ./deploy/manage virt create '<network.nix>' '<network-libvirt.nix>'
    ~~~~~

5. Deploy!

    ~~~~~ bash
    ./deploy/manage virt deploy
    ~~~~~

Production/staging deployment
-----------------------------

Requires `git-crypt`:

```bash
nix-env -iA git-crypt
git-crypt unlock
./deploy/manage prod deploy
```

Testing builds
--------------

```bash
./deploy/manage prod deploy --build-only
```


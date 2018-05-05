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

4. Generate keys for Hydra

    ~~~~~ bash
    ssh-keygen -C "hydra@hydra.example.org" -N "" -f id_buildfarm
    ~~~~~

5. Create the deployment:

    ~~~~~ bash
    ./deploy/manage virt create '<network.nix>' '<network-libvirt.nix>'
    ~~~~~

6. Deploy!

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

Hydra specific
--------------

Ensure that the main server knows the binary cache for `nixos`:

```bash
./deploy/manage prod ssh hydra -- nix-channel --update
```

Testing builds
--------------

```bash
./deploy/manage prod deploy --build-only
```


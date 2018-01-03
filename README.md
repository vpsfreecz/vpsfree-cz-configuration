vpsfree.cz configuration
========================

1. Install NixOps - https://nixos.org/nixops/manual/#chap-installation

2. Configure environment

    ~~~~~ bash
    source activate
    ~~~~~

    This configures `NIX_PATH`, `NIXOPS_DEPLOYMENT` variables and configures prompt.

3. Generate keys for Hydra

    ~~~~~ bash
    ssh-keygen -C "hydra@hydra.example.org" -N "" -f id_buildfarm
    ~~~~~

4. Create the deployment:

    ~~~~~ bash
    nixops create network.nix network-prod.nix
    ~~~~~

5. Deploy!

    ~~~~~ bash
    nixops deploy
    ~~~~~

Virtualized deployment
----------------------

```bash
nixops create -d virt network.nix network-libvirt.nix
nixops deploy -d virt
```

Hydra specific
--------------

Ensure that the main server knows the binary cache for `nixos`:

```bash
nixops ssh hydra -- nix-channel --update
```

vpsfree.cz configuration
========================

1. Install Nix - https://nixos.org/nix/

2. Clone this repository

    ~~~~~ bash
    git clone https://github.com/vpsfreecz/vpsfree-cz-configuration/
    ~~~~~

3. Geneate certificate authority for IPXE

    ~~~~~ bash
    ./gen-ca
    ~~~~~

4. Install [morph overlay](overlays/morph.nix) 

    ~~~~~ nix
    nixpkgs.overlays = [ (import ../overlays/morph.nix) ];
    ~~~~~


5. Install morph itself

    ~~~~~ bash
    nix-shell -p morph
    ~~~~~

6. Deploy!

    ~~~~~ bash
    morph deploy morph.nix
    ~~~~~

Testing builds
--------------

```bash
morph build morph.nix
```

Service specifics
-----------------

Grafana
~~~~~~~

To set admin password for grafana use
```bash
grafana-cli admin reset-admin-password --homepath "/var/lib/grafana/" <NewPass>
```

---
title: Nix The World
slides:
    separator_vertical: ^\s*-v-\s*$
plugins:
    - name: RevealMermaid
      extra_javascript:
          - https://cdn.jsdelivr.net/npm/reveal.js-mermaid-plugin/plugin/mermaid/mermaid.min.js
---

# Nix The World
# :globe_showing_americas:
# Part 3? <!-- .element: class="fragment" -->

---

## :snowflake: Flakes :snowflake:
```nix
{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
    packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

  };
}
```

Notes:
- Previously it was asked if OVPN had a flake
    - it did not
- There was also a question about feasibility of using nix with cpm
    - these are my continuing investigations

- Recap flakes

---

## :building_construction: Flake Inputs :building_construction:
```nix
# A GitHub repository.
inputs.import-cargo = {
  type = "github";
  owner = "edolstra";
  repo = "import-cargo";
};

# An indirection through the flake registry.
inputs.nixpkgs = {
  type = "indirect";
  id = "nixpkgs";
};
```

Notes:
- Supports things like git, plain https, or even local files

---

## :factory: Flake Outputs :factory:
```nix[1-46|23-26]
{
  # Executed by `nix build .#<name>`
  packages."<system>"."<name>" = derivation;
  # Executed by `nix build .`
  packages."<system>".default = derivation;
  # Executed by `nix run .#<name>`
  apps."<system>"."<name>" = {
    type = "app";
    program = "<store-path>";
    meta = {description = "..."; inherit otherMetaAttrs; };
  };
  # Executed by `nix run . -- <args?>`
  apps."<system>".default = { type = "app"; program = "..."; meta = {description = "..."; inherit otherMetaAttrs; }; };

  # Formatter (alejandra, nixfmt, treefmt-nix or nixpkgs-fmt)
  formatter."<system>" = derivation;
  # Used for nixpkgs packages, also accessible via `nix build .#<name>`
  legacyPackages."<system>"."<name>" = derivation;
  # Overlay, consumed by other flakes
  overlays."<name>" = final: prev: { };
  # Default overlay
  overlays.default = final: prev: { };
  # Nixos module, consumed by other flakes
  nixosModules."<name>" = { config, ... }: { options = {}; config = {}; };
  # Default module
  nixosModules.default = { config, ... }: { options = {}; config = {}; };
  # Used with `nixos-rebuild switch --flake .#<hostname>`
  # nixosConfigurations."<hostname>".config.system.build.toplevel must be a derivation
  nixosConfigurations."<hostname>" = {};
  # Used by `nix develop .#<name>`
  devShells."<system>"."<name>" = derivation;
  # Used by `nix develop`
  devShells."<system>".default = derivation;
  # Hydra build jobs
  hydraJobs."<attr>"."<system>" = derivation;
  # Used by `nix flake init -t <flake>#<name>`
  templates."<name>" = {
    path = "<store-path>";
    description = "template description goes here?";
  };
  # Used by `nix flake init -t <flake>`
  templates.default = { path = "<store-path>"; description = ""; };
  # Executed by `nix flake check`
  checks."<system>"."<name>" = derivation;
}
```

Notes:
Call attention to the attributes options and config in nixosModules

---

## :globe_with_meridians: OVPN :globe_with_meridians:

```mermaid
%%{init: {'theme': 'neutral', "flowchart" : { "curve" : "basis" } } }%%
graph LR

    subgraph DNS
        ETC_HOSTS["1: /etc/hosts"]
    end

    VPN_REQUEST["cloudlab"]
    INTERNET_REQUEST["*.ftpaccess.cc"]

    VPN_REQUEST --> ETC_HOSTS
    INTERNET_REQUEST -.-> DNS

    IP_TABLES{"2: iptables"}

    DNS ==> IP_TABLES

    IP_TABLES --> REDSOCKS["3: Redsocks"]
    subgraph "VM"
        SSH["SSH Server"] --> AnyConnect
    end

    subgraph SSH_CLIENT["4: SSH client"]
        SOCKS["SOCKS5 Proxy"]
    end

    REDSOCKS --> SOCKS
    SOCKS --> SSH
    AnyConnect --> OVPN(["Corp Server"])

    IP_TABLES -.-> INTERNET([Internet])

linkStyle default stroke-width:4px,fill:none,stroke:green;
```

---

## :globe_with_meridians: OVPN :globe_with_meridians:

1. Write /etc/hosts entries
2. Apply iptable rules
3. Redirect VPN requests to redsocks instance
4. Create SOCKS5 Proxy running over SSH to VM

---

## :snowflake: Flakes :snowflake:
### OVPN: flake.nix
```nix[2-4|6|7|8-25|27-46]
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, }: {
    nixosModules.default = { config, lib, pkgs, ... }: {
      options.ovpn = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether to enable the ovpn service
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          description = ''
            User to run services as
          '';
        };

        # trunc
      };

      config = lib.mkIf config.ovpn.enable {
          networking = {
            extraHosts = (
              lib.concatStringsSep "\n" (
                map (
                  host_record: let
                    host = lib.splitString " " host_record;
                  in "${lib.elemAt host 1} ${lib.elemAt host 0}"
                )
                domains
              )
            );
            firewall.allowedTCPPorts = [
              config.ovpn.redsocks-port
              config.ovpn.socks-port
            ];
          };
        # trunc
    };

}
```

Notes:
This example has been truncated, the actual file is less than 433 lines

---

## :robot: NixOS Config :robot:
```nix[7-10|13|16-24]
{
  description = "NixOS configuration for yokley";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    ovpn-flake = {
      url = "git+ssh://git@cloudlab.us.oracle.com:2222/tpm/tpm_dev/playground/ovpn.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, ovpn-flake, ... }: {
    nixosConfigurations = {
      "machine" = nixpkgs.lib.nixosSystem {
        modules = [
          ovpn-flake.nixosModules.default
          {
            ovpn = {
              enable = true;
              user = "yokley";
            };
          }
        ];
      };
    };
  };
}
```

---

## :building_construction: Flake Inputs :building_construction:
<img src="https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExZmprNDl5Z3RubmprNHJhNnJxaXo4c3V5NTNvdmFxNTB5dzB4bnpjcyZlcD12MV9naWZzX3NlYXJjaCZjdD1n/wAy8hHX87PPazO0IEu/giphy.gif" class="r-stretch" />

Notes:
Inputs are pretty straightforward. They're just upstream dependencies

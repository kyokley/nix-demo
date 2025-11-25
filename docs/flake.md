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
### a.k.a. How I joined the cult of Nix <!-- .element: class="fragment" -->

Notes:
- The focus of this demo will be flake files specifically with respect to NixOS and not just Nix

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

-v-

## :globe_with_meridians: OVPN :globe_with_meridians:

1. Write /etc/hosts entries
2. Apply iptable rules
3. Redirect VPN requests to redsocks instance
4. Create SOCKS5 Proxy running over SSH to VM

---

## :snowflake: Flakes :snowflake:
#### OVPN: flake.nix
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
This example has been truncated, the actual file is 433 lines

Show actual file on cloudlab/scm

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

## :detective: Flakes Recap :detective:
* SSH client running SOCKS5 proxy <!-- .element: class="fragment" -->
* Spin up and configure a redsocks instance <!-- .element: class="fragment" -->
* Generate and apply a set of iptable rules <!-- .element: class="fragment" -->
* Insert entries into /etc/hosts <!-- .element: class="fragment" -->
* Everything implemented in systemd services on start up <!-- .element: class="fragment" -->
### ...all in 433 lines of code! <!-- .element: class="fragment" -->

Notes:
Are you not entertained??

---

## :snowflake: Flakes Rock! :snowflake:
<img src="https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExZmprNDl5Z3RubmprNHJhNnJxaXo4c3V5NTNvdmFxNTB5dzB4bnpjcyZlcD12MV9naWZzX3NlYXJjaCZjdD1n/wAy8hHX87PPazO0IEu/giphy.gif" class="r-stretch" />

Notes:
Inputs are pretty straightforward. They're just upstream dependencies

---

## Are we done yet?
# NO! <!-- .element: class="fragment" -->

Notes:
Of course not! Anything being distributed needs tests

---

## Tests for OS functionality???
<img src="https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExcG5jbjd1dnBxZnF2OG93bnZoOW5wNzM2eWplMHl6bW5meWd3aWhiNCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/hv53DaYcXWe3nRbR1A/giphy.gif" class="r-stretch" />

---

## :thinking_face: Options :thinking_face:
- Bash
- Docker/Podman
- Ansible

Notes:
- Bash is brutal and you're probably only testing the local host
- It may be possible to run systemd in docker but not recommended because multiple processes
- Ansible spin up real compute instances in a VPS but costs money, teardown is a gamble, and juggling networking

---

## Ideal Test Case

```mermaid
%%{init: {'theme': 'neutral', "flowchart" : { "curve" : "basis" } } }%%

graph TD
    HOST["Host"]
    VM
    EXTERNAL["External"]
    INTERNAL["Internal"]

    HOST --> EXTERNAL
    HOST --> VM
    VM --> INTERNAL
    HOST -. "BLOCKED" .-> INTERNAL
    VM -. "BLOCKED" .-> EXTERNAL

linkStyle default stroke-width:4px,fill:none,stroke:green;
```

---

## Demo
<img src="https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExN2pzYmN6dXBuNG1uYXY0eTZiaTd3Zmo5enY2enc3dDA3ZjFhdTg4cCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/cFdHXXm5GhJsc/giphy.gif" class="r-stretch" />

---

## :detective: Flakes Recap Again :detective:
* SSH client running SOCKS5 proxy
* Spin up and configure a redsocks instance
* Generate and apply a set of iptable rules
* Insert entries into /etc/hosts
* Everything implemented in systemd services on start up
* And tests! <!-- .element: class="fragment" -->
### ...still in 433 lines of code!

---

## Caveats
* The OVPN flake only controls the host
* Losing the SSH connection to the VM requires restarting SSH service
* No proxy settings are required for docker if host network is used

---

## Fin
<img src="https://media2.giphy.com/media/v1.Y2lkPTc5MGI3NjExMGJlejd4bWRpcWd5dnpiZXBoMmlkM2NkYnlkbW5zdjFpaXNqcGRkeSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3o7qDEq2bMbcbPRQ2c/giphy.gif" class="r-stretch" />

Notes:
- Questions?

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

### A tale in 3 parts

---

## :snowflake: What is Nix? :snowflake:
0. A programming language <!-- .element: class="fragment" -->
1. A package manager <!-- .element: class="fragment" -->
2. An operating system <!-- .element: class="fragment" -->

...A way of life? <!-- .element: class="fragment" -->

<img src="https://nixos-and-flakes.thiscute.world/logo.png" class="r-stretch" />

---

## :desktop_computer: Programming :desktop_computer:
### devenv.sh
```nix [12-23|25-27|45-59]
{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  env.GREET = "Nix Demo";

  packages = [];

  languages = {
    python = {
      enable = true;
      version = "3.10";
      uv = {
        enable = true;
        sync = {
            enable = true;
        };
      };
    };
  };

  processes = {
    serve.exec = "uvx mkslides serve docs/";
  };

  containers."nix-demo" = {
    name = "kyokley/nix-demo";
    startupCommand = config.processes.serve.exec;
  };

  scripts = {
    hello.exec = ''
      echo Welcome to $GREET
      echo
    '';
  };

  enterShell = ''
    hello
  '';

  git-hooks.hooks = {
    alejandra.enable = true;
    hadolint.enable = false;
    check-merge-conflicts.enable = true;
    check-added-large-files.enable = true;
    check-toml.enable = true;
    check-yaml.enable = true;
    checkmake.enable = true;
    detect-private-keys.enable = true;
    ripsecrets.enable = true;
    ruff-format.enable = true;
    trim-trailing-whitespace.enable = true;
    yamlfmt.enable = true;
    yamllint.enable = false;
  };
}
```

Notes:
Nix the programming language

-v-
## :desktop_computer: Programming :desktop_computer:
### How to [VPN](https://github.com/kyokley/nix-demo/blob/main/docs/vpn.mermaid)?

```mermaid
%%{init: {'theme': 'neutral', "flowchart" : { "curve" : "basis" } } }%%

graph LR
    VPN_REQUEST["cloudlab"]
    INTERNET_REQUEST["*.ftpaccess.cc"]

    VPN_REQUEST --> ETC_HOSTS["1: /etc/hosts"]
    INTERNET_REQUEST --> ETC_HOSTS

    IP_TABLES{"2: iptables"}

    ETC_HOSTS --> IP_TABLES
    ETC_HOSTS --> DNS

    DNS --> IP_TABLES

    IP_TABLES --> REDSOCKS["3: Redsocks"]
    subgraph "VM"
        SSH["SSH Server"] --> AnyConnect
    end
    REDSOCKS --> |socks5| SSH_CLIENT["4: SSH client"]
    SSH_CLIENT --> SSH
    AnyConnect --> OVPN(["Corp Server"])

    IP_TABLES --> INTERNET([Internet])

linkStyle default stroke-width:4px,fill:none,stroke:green;
```
Notes:
*.ftpaccess.cc domains are blocked

-v-

## :desktop_computer: Programming :desktop_computer:
### ovpn.nix
```nix [86-95|47-63|7-24|97-114]
{
  pkgs,
  lib,
  ...
}: let
  domains = [];
  redsocks-listen-port = "12345";
  redsocks-config = pkgs.writeText "redsocks.conf" ''
    base {
        log_debug = on;
        log_info = on;
        daemon = off;
        redirector = iptables;
        redsocks_conn_max = 4096;
    }

    redsocks {
        local_ip = 127.0.0.1;
        local_port = ${redsocks-listen-port};
        ip = 127.0.0.1;
        port = ${vm-socks-port};
        type = socks5;
    }
  '';
  stop-tunnel = pkgs.writeShellScriptBin "stop-tunnel" ''
    ${pkgs.iptables}/bin/iptables-save | grep -v REDSOCKS | ${pkgs.iptables}/bin/iptables-restore
  '';
  start-tunnel = (
    pkgs.writeShellScriptBin
    "start-tunnel"
    (
      let
        configure-tunnel = (
          let
            reserved-ips = [
              # TODO: add ipv6-equivalent
              "0.0.0.0/8"
              "10.0.0.0/8"
              "127.0.0.0/8"
              "169.254.0.0/16"
              "172.16.0.0/12"
              "192.168.0.0/16"
              "224.168.0.0/4"
              "240.168.0.0/4"
            ];
          in
            pkgs.writeShellScriptBin "configure-tunnel" (
              lib.concatStringsSep
              "\n"
              (
                [
                  "${pkgs.iptables}/bin/iptables -t nat -N REDSOCKS || true"
                ]
                ++ map (x: "${pkgs.iptables}/bin/iptables -t nat -A REDSOCKS -d " + x + " -j RETURN || true") reserved-ips
                ++ [
                  "${pkgs.iptables}/bin/iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports ${redsocks-listen-port} || true"
                  ''${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -i docker0 -p tcp -j DNAT --to-destination 127.0.0.1:${redsocks-listen-port} -m comment --comment "REDSOCKS docker rule" || true''
                ]
                ++ map (host_record: let
                  host = lib.splitString " " host_record;
                in "${pkgs.iptables}/bin/iptables -t nat -A OUTPUT -p tcp -d ${lib.elemAt host 1}/32 -j REDSOCKS || true")
                domains
              )
            )
        );
      in ''
        if [ $(id -u) -ne 0 ]
          then echo Please run this script as root or using sudo!
          exit
        fi
        ${pkgs.iptables}/bin/iptables-save | grep REDSOCKS >/dev/null 2>&1 || ${configure-tunnel}/bin/configure-tunnel
        ${pkgs.redsocks}/bin/redsocks -c ${redsocks-config}
      ''
    )
  );
  user = "yokley";
  vm-ip = "127.0.0.1";
  vm-port = "3022";
  vm-socks-port = "8081";
in {
  environment.systemPackages = [
    start-tunnel
    stop-tunnel
  ];

  networking.extraHosts = (
    lib.concatStringsSep "\n" (
      map (
        host_record: let
          host = lib.splitString " " host_record;
        in "${lib.elemAt host 1} ${lib.elemAt host 0}"
      )
      domains
    )
  );

  systemd.services = {
    ssh-tunnel = {
      enable = true;
      description = "Tunnels for VPN";
      serviceConfig = {
        Type = "simple";
        User = "${user}";
      };
      script = toString (
        pkgs.writeShellScript "ssh-tunnel" ''
          ${pkgs.wait4x}/bin/wait4x tcp ${vm-ip}:${vm-port} --timeout 0 --interval 10s
          ${pkgs.openssh}/bin/ssh -p ${vm-port} ${user}@${vm-ip} -D ${vm-socks-port} -Nv
        ''
      );
      wants = ["network-online.target"];
      after = ["network-online.target"];
      wantedBy = ["multi-user.target"];
    };

    redirect-traffic = {
      enable = true;
      description = "Redsocks redirect traffic";
      serviceConfig = {
        Type = "simple";
      };
      script = "${start-tunnel}/bin/start-tunnel";
      postStop = "${stop-tunnel}/bin/stop-tunnel";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      wantedBy = ["multi-user.target"];
    };
  };
}
```

---

## :package: Packages :package:
### Installing libraries
```bash
sh-5.2# nix-shell -p devenv
```

Notes:
Nix the package manager!

-v-

## :package: Packages :package:
### Installing libraries
```text
these 33 paths will be fetched (75.63 MiB download, 352.04 MiB unpacked):
  /nix/store/bwkb907myixfzzykp21m9iczkhrq5pfy-binutils-2.43.1
  /nix/store/2qssg7pjgadwmqns6jm3qlr5bbdl4dcr-binutils-2.43.1-lib
  /nix/store/x9as7x6f7cdgcskvvn3yp02m662krr7y-binutils-wrapper-2.43.1
  /nix/store/b52i89as6gi475dazksqasvd7f9bppvl-boehm-gc-8.2.8
  /nix/store/vqjygx23hkim1kpidik5xcs9whayf3sr-bzip2-1.0.8-bin
  /nix/store/zr62cxlgkldv8fs7dgak30clwmcsycr9-cachix-1.7.5-bin
  /nix/store/kzf3sh3qsrwrqvddyacdxz0b8ncn35xr-devenv-1.3.1
  /nix/store/cxwsmlr3xh1ml4r0kgdjrknw7504b9f8-diffutils-3.10
  /nix/store/k5x874vwcaxlan1cw248lwqr4l4v7hyk-ed-1.20.2
  /nix/store/y1563grxzk23mapa57a6qzsjaqyvcw76-elfutils-0.191
  /nix/store/ka4sync4bccr9mz2ys0dbqjn24hp8v57-expand-response-params
  /nix/store/g4lksqp6l8qiab4a0as21s6556xh4gyp-file-5.45
  /nix/store/nnin69nrnrrmnv2scbwyfkgh1rf51gh1-gawk-5.3.1
  /nix/store/4krab2h0hd4wvxxmscxrw21pl77j4i7j-gcc-13.3.0
  /nix/store/4apajimszc47rxwcpvc3g3rj2icinl71-gcc-wrapper-13.3.0
  /nix/store/lw21wr626v5sdcaxxkv2k4zf1121hfc9-glibc-2.40-36-dev
  /nix/store/y11zr71f9i1zy1vrdy3kjx8j6slsb3l3-gmp-6.3.0
  /nix/store/rlnih3wlxxwqn4xdahjgfjydvv78kvki-gnu-config-2024-01-01
  /nix/store/9y5kd90fdbrq3r4yc9mpqn82f93zdgyq-gnumake-4.4.1
  /nix/store/xxfkk4gqnaimiwzi6mmsmcs9bl2r8y7f-isl-0.20
  /nix/store/gi2n9v8n5n37rmzjvcp0r3b3a5w17qfs-libgit2-1.8.4-lib
  /nix/store/0qqs7bkfk21h8vh7m3x84hphciqv75lm-libmpc-1.3.1
  /nix/store/dvsai0ym9czjl5mcsarcdwccb70615n4-linux-headers-6.10
  /nix/store/wfxkyxmg47bhj098im5rp60hmkagn96x-mpfr-4.2.1
  /nix/store/mlic086jky8mmmq3r3s4b080q840pdk0-nix-2.24-devenv
  /nix/store/bm7xjrw6mw2pgnjf2pnmsdyyaq5j56gq-nix-2.24-devenv-man
  /nix/store/w4l4xvw461ywc4ia3accj5i3hh50n4r8-nix-2.24.10
  /nix/store/ijl95ypkqvp33y8nvcsfhcf9psx2mmrd-nix-2.24.10-man
  /nix/store/mdmansf6zkzsnrcf4h3yav5kz93rh03y-patch-2.7.6
  /nix/store/9q63d382x7k2h6cc2pfsb39ar3n6f9wg-patchelf-0.15.0
  /nix/store/m1p78gqlc0pw3sdbz3rdhklzm0g26g96-stdenv-linux
  /nix/store/ljlah5wqcbix5wg8rvm3g8rc7k9zn1qg-update-autotools-gnu-config-scripts-hook
  /nix/store/5180mi672sl6ikiwyhvgnxasz6iqxws0-xz-5.6.3-bin
copying path '/nix/store/nnin69nrnrrmnv2scbwyfkgh1rf51gh1-gawk-5.3.1' from 'https://cache.nixos.org'...
copying path '/nix/store/rlnih3wlxxwqn4xdahjgfjydvv78kvki-gnu-config-2024-01-01' from 'https://cache.nixos.org'...
copying path '/nix/store/bm7xjrw6mw2pgnjf2pnmsdyyaq5j56gq-nix-2.24-devenv-man' from 'https://cache.nixos.org'...
copying path '/nix/store/b52i89as6gi475dazksqasvd7f9bppvl-boehm-gc-8.2.8' from 'https://cache.nixos.org'...
copying path '/nix/store/vqjygx23hkim1kpidik5xcs9whayf3sr-bzip2-1.0.8-bin' from 'https://cache.nixos.org'...
copying path '/nix/store/cxwsmlr3xh1ml4r0kgdjrknw7504b9f8-diffutils-3.10' from 'https://cache.nixos.org'...
copying path '/nix/store/k5x874vwcaxlan1cw248lwqr4l4v7hyk-ed-1.20.2' from 'https://cache.nixos.org'...
copying path '/nix/store/ka4sync4bccr9mz2ys0dbqjn24hp8v57-expand-response-params' from 'https://cache.nixos.org'...
copying path '/nix/store/g4lksqp6l8qiab4a0as21s6556xh4gyp-file-5.45' from 'https://cache.nixos.org'...
copying path '/nix/store/9y5kd90fdbrq3r4yc9mpqn82f93zdgyq-gnumake-4.4.1' from 'https://cache.nixos.org'...
copying path '/nix/store/dvsai0ym9czjl5mcsarcdwccb70615n4-linux-headers-6.10' from 'https://cache.nixos.org'...
copying path '/nix/store/ijl95ypkqvp33y8nvcsfhcf9psx2mmrd-nix-2.24.10-man' from 'https://cache.nixos.org'...
copying path '/nix/store/9q63d382x7k2h6cc2pfsb39ar3n6f9wg-patchelf-0.15.0' from 'https://cache.nixos.org'...
copying path '/nix/store/5180mi672sl6ikiwyhvgnxasz6iqxws0-xz-5.6.3-bin' from 'https://cache.nixos.org'...
copying path '/nix/store/y1563grxzk23mapa57a6qzsjaqyvcw76-elfutils-0.191' from 'https://cache.nixos.org'...
copying path '/nix/store/gi2n9v8n5n37rmzjvcp0r3b3a5w17qfs-libgit2-1.8.4-lib' from 'https://cache.nixos.org'...
copying path '/nix/store/2qssg7pjgadwmqns6jm3qlr5bbdl4dcr-binutils-2.43.1-lib' from 'https://cache.nixos.org'...
copying path '/nix/store/y11zr71f9i1zy1vrdy3kjx8j6slsb3l3-gmp-6.3.0' from 'https://cache.nixos.org'...
copying path '/nix/store/ljlah5wqcbix5wg8rvm3g8rc7k9zn1qg-update-autotools-gnu-config-scripts-hook' from 'https://cache.nixos.org'...
copying path '/nix/store/mdmansf6zkzsnrcf4h3yav5kz93rh03y-patch-2.7.6' from 'https://cache.nixos.org'...
copying path '/nix/store/w4l4xvw461ywc4ia3accj5i3hh50n4r8-nix-2.24.10' from 'https://cache.nixos.org'...
copying path '/nix/store/mlic086jky8mmmq3r3s4b080q840pdk0-nix-2.24-devenv' from 'https://cache.nixos.org'...
copying path '/nix/store/lw21wr626v5sdcaxxkv2k4zf1121hfc9-glibc-2.40-36-dev' from 'https://cache.nixos.org'...
copying path '/nix/store/bwkb907myixfzzykp21m9iczkhrq5pfy-binutils-2.43.1' from 'https://cache.nixos.org'...
copying path '/nix/store/xxfkk4gqnaimiwzi6mmsmcs9bl2r8y7f-isl-0.20' from 'https://cache.nixos.org'...
copying path '/nix/store/wfxkyxmg47bhj098im5rp60hmkagn96x-mpfr-4.2.1' from 'https://cache.nixos.org'...
copying path '/nix/store/zr62cxlgkldv8fs7dgak30clwmcsycr9-cachix-1.7.5-bin' from 'https://cache.nixos.org'...
copying path '/nix/store/0qqs7bkfk21h8vh7m3x84hphciqv75lm-libmpc-1.3.1' from 'https://cache.nixos.org'...
copying path '/nix/store/x9as7x6f7cdgcskvvn3yp02m662krr7y-binutils-wrapper-2.43.1' from 'https://cache.nixos.org'...
copying path '/nix/store/4krab2h0hd4wvxxmscxrw21pl77j4i7j-gcc-13.3.0' from 'https://cache.nixos.org'...
copying path '/nix/store/kzf3sh3qsrwrqvddyacdxz0b8ncn35xr-devenv-1.3.1' from 'https://cache.nixos.org'...
copying path '/nix/store/4apajimszc47rxwcpvc3g3rj2icinl71-gcc-wrapper-13.3.0' from 'https://cache.nixos.org'...
copying path '/nix/store/m1p78gqlc0pw3sdbz3rdhklzm0g26g96-stdenv-linux' from 'https://cache.nixos.org'...
```

-v-

## :package: Packages :package:
### Anatomy of a Store Entry

/nix/store/bwkb907myixfzzykp21m9iczkhrq5pfy-binutils-2.43.1

Store path: /nix/store/ <!-- .element: class="fragment" -->

Hash: bwkb907myixfzzykp21m9iczkhrq5pfy <!-- .element: class="fragment" -->

Library: binutils-2.43.1 <!-- .element: class="fragment" -->

---

## :package: Packages :package:
### Nix Store
- What lives in the store?
    - Libraries<!-- .element: class="fragment" -->
    - Executables <!-- .element: class="fragment" -->
    - Even config files <!-- .element: class="fragment" -->

Notes: Why does this matter?

`nix-shell -p postgresql_{13,16}`

`nix-shell -p libreoffice-{still,fresh}`
---

## :robot: Operating System :robot:
### The Immutable OS
```nix [8-12|23-25|27|16-19|14|2-6]
{pkgs, ...}: {
  imports = [
    ../../programs/ovpn.nix
    ../../programs/tailscale.nix
    ../../misc/laptop.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = ["bcachefs"];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "mars";

  environment.systemPackages = with pkgs; [
    protonvpn-gui
    gnome-keyring
  ];

  system.stateVersion = "24.05"; # Don't touch me!

  networking.extraHosts = ''
    192.168.1.101 saturn
  '';

  services.xserver.videoDrivers = ["amdgpu"];
}
```

Notes:
Nix the Operating System aka NixOS

Show immutability of /etc/hostname

Other Immutable OSes:
3. 1. NixOS / Guix
3. 2. Endless OS
3. 3. Fedora Silverblue
3. 4. OpenSUSE MicroOS / Aeon
3. 5. Vanilla OS
3. 6. Alpine Linux (with LBU)

---

## :robot: Operating System :robot:
### What if NixOS isn't for me?
#### Nix Runs on: <!-- .element: class="fragment" -->
- Linux <!-- .element: class="fragment" -->
- MacOS <!-- .element: class="fragment" -->
- WSL <!-- .element: class="fragment" -->

---

## Demo
<img src="https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif" class="r-stretch" />

---

## :robot: Operating System :robot:
##### (...and friends)
### Special Abilities
- Reproducibility <!-- .element: class="fragment" -->
- Reusabililty <!-- .element: class="fragment" -->
- Stability <!-- .element: class="fragment" -->
- Garbage Collectibility :thinking: <!-- .element: class="fragment" -->

Notes:
Build ubuntu container

`nix-shell -p git devenv`

Clone git repo and run `devenv shell`

Show `devenv container copy nix-demo` on host


WHY???

Car printer analogy!

Using config files along with nix store guarantees reproducibility.

Modularity gives reusability and composability.

Syntax and consistency checks improve stability. Also configs can live in git. Plus generations!

To demonstrate garbage collecting, run
`nix-store --gc`

---

## :woozy_face: Disadvantages :face_with_spiral_eyes:
- Confusing error messages <!-- .element: class="fragment" -->
- Documentation is lacking <!-- .element: class="fragment" -->
- Steep learning curve <!-- .element: class="fragment" -->

---

## Further Reading
https://nixos.org/

https://nix-community.github.io/home-manager/

https://devenv.sh/

https://github.com/kyokley/nixvim

https://github.com/kyokley/nix-demo

---
title: Nix The World
slides:
    separator_vertical: ^\s*-v-\s*$
---

# Nix The World :globe_showing_americas:
### A tale in 3 parts

---

## :snowflake: What is Nix? :snowflake:
1. A programming language <!-- .element: class="fragment" -->
2. A package manager <!-- .element: class="fragment" -->
3. An operating system <!-- .element: class="fragment" -->


...A way of life? <!-- .element: class="fragment" -->

<img src="https://nixos-and-flakes.thiscute.world/logo.png" class="r-stretch" />

---

## :desktop_computer: Programming :desktop_computer:
### devenv.sh
```nix [14-24|26-29|48-63]
{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  # https://devenv.sh/basics/
  env.GREET = "Nix Demo";

  # https://devenv.sh/packages/
  packages = [];

  # https://devenv.sh/languages/
  languages = {
    python = {
      enable = true;
      version = "3.10";
      uv = {
        enable = true;
        sync.enable = true;
      };
    };
  };

  # https://devenv.sh/processes/
  processes = {
    serve.exec = "uv run mkslides serve docs/";
  };

  containers."nix-demo" = {
    name = "kyokley/nix-demo";
    startupCommand = config.processes.serve.exec;
  };

  # https://devenv.sh/scripts/
  scripts = {
    hello.exec = ''
      echo Welcome to $GREET
      echo
    '';
  };

  enterShell = ''
    hello
  '';

  # https://devenv.sh/git-hooks/
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
-v-

## :desktop_computer: Programming :desktop_computer:
### ovpn.nix
```nix [21-28|42-58|70-78]
{ pkgs, lib, ... }: let
  domains = [ ];
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
        port = 8081;
        type = socks5;
    }
  '';
  start-tunnel = pkgs.writeShellScriptBin "start-tunnel" ''
    if [ $(id -u) -ne 0 ]
      then echo Please run this script as root or using sudo!
      exit
    fi
    iptables-save | grep REDSOCKS >/dev/null 2>&1 || configure-tunnel
    ${pkgs.redsocks}/bin/redsocks -c ${redsocks-config}
  '';
  configure-tunnel = let
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
          "iptables -t nat -N REDSOCKS || true"
        ]
        ++ map (x: "iptables -t nat -A REDSOCKS -d " + x + " -j RETURN || true") reserved-ips
        ++ [
          "iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports ${redsocks-listen-port} || true"
          ''iptables -t nat -A PREROUTING -i docker0 -p tcp -j DNAT --to-destination 127.0.0.1:${redsocks-listen-port} -m comment --comment "REDSOCKS docker rule" || true''
        ]
        ++ map (host_record: let
          host = lib.splitString " " host_record;
        in "iptables -t nat -A OUTPUT -p tcp -d ${lib.elemAt host 1}/32 -j REDSOCKS || true")
        domains
      )
    );
  stop-tunnel = pkgs.writeShellScriptBin "stop-tunnel" ''
    iptables-save | grep -v REDSOCKS | iptables-restore
  '';
in {
  environment.systemPackages = [
    start-tunnel
    configure-tunnel
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
}
```

---

## :package: Packages :package:
### Installing libraries
```bash
sh-5.2# nix-shell -p devenv
```

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

---

## :package: Packages :package:
### Nix Store
- What lives in the store?
    - Libraries<!-- .element: class="fragment" -->
    - Executables <!-- .element: class="fragment" -->
    - Even config files <!-- .element: class="fragment" -->

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
    192.168.50.126 saturn
  '';

  services.xserver.videoDrivers = ["amdgpu"];
}
```

---

## :robot: Operating System :robot:
#### (...and friends)
- Reproducibility
- Generations
- Garbage Collecting

---

## What if NixOS isn't for me?
### Nix Runs on: <!-- .element: class="fragment" -->
- Linux <!-- .element: class="fragment" -->
- MacOS <!-- .element: class="fragment" -->
- WSL <!-- .element: class="fragment" -->
- And of course, NixOS <!-- .element: class="fragment" -->

---

## Demo
<img src="https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif" class="r-stretch" />

---

## Further Reading
https://nixos.org/

https://devenv.sh/

https://github.com/kyokley/nixvim

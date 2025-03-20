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
  packages = [pkgs.git];

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
    run-ubuntu.exec = ''
      docker build -t kyokley/ubuntu-with-nix --network=host .
      docker run --rm -it --net=host kyokley/ubuntu-with-nix /bin/bash
    '';
    vim.exec = "nix run github:kyokley/nixvim -- $@";
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
    checkmake.enable = true;
    detect-private-keys.enable = true;
    ripsecrets.enable = true;
    ruff-format.enable = true;
    trim-trailing-whitespace.enable = true;
  };

  # See full reference at https://devenv.sh/reference/options/
}

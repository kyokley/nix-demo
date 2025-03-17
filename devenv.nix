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

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  # enterTest = ''
  #   echo "Running tests"
  #   git --version | grep --color=auto "${pkgs.git.version}"
  # '';

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
    ruff.enable = true;
    ruff-format.enable = true;
    trim-trailing-whitespace.enable = true;
    yamlfmt.enable = true;
    yamllint.enable = false;
  };

  # See full reference at https://devenv.sh/reference/options/
}

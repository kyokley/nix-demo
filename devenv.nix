{ pkgs, lib, config, inputs, ... }:
{
  # https://devenv.sh/basics/
  env.GREET = "Nix Demo";

  # https://devenv.sh/packages/
  packages = [];

  # https://devenv.sh/languages/
  languages = {
    python = {
      enable = true;
      version = "3.12";
      uv.enable = true;
    };
  };

  # https://devenv.sh/processes/
  processes = {
    serve.exec = "uv run mkslides serve docs/";
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
  };

  # See full reference at https://devenv.sh/reference/options/
}

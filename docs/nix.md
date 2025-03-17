---
title: Nix The World
---

# Nix The World
### or: How I Learned to Stop Worrying and Love Reproducibility <!-- .element: class="fragment" -->

---

## What is Nix?
- A package manager <!-- .element: class="fragment" -->
- A programming language <!-- .element: class="fragment" -->
- An operating system <!-- .element: class="fragment" -->
- ...A way of life? <!-- .element: class="fragment" -->

---
## devenv.sh
```nix
{ pkgs, lib, config, inputs, ... }:
{
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
}
```

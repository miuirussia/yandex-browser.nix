# yandex-browser.nix

Nix files for installing Yandex Browser on NixOS

**Warning!** Yandex removes old releases from its repository, so always use the new version of this repository

## Cache

Use cachix cache for faster builds: https://app.cachix.org/cache/yandex-browser-nix#pull

## Installation

1. Using `nix profile`:

```sh
 # Stable version
 nix profile install github:miuirussia/yandex-browser.nix#yandex-browser-stable

 # Beta version
 nix profile install github:miuirussia/yandex-browser.nix#yandex-browser-beta
```
2. Add to your flake inputs:

``` nix
 {
   inputs = {
     nixpkgs = { url = "..."; };
     yandex-browser = { url = "github:miuirussia/yandex-browser.nix"; inputs.nixpkgs.follows = "nixpkgs"; };
   };
 }
```

Run `nix flake lock --update-input yandex-browser` before rebuild to get new versions and hashes.

3. Using old nix:

```nix
  yandex-browser = import (fetchTarball "https://github.com/miuirussia/yandex-browser.nix/archive/master.tar.gz");

  # Stable version
  yandex-browser.packages.x86_64-linux.yandex-browser-stable;
  # Beta version
  yandex-browser.packages.x86_64-linux.yandex-browser-stable;
```

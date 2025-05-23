{
  description = "Yandex Browser";

  inputs = {
    nixpkgs = { url = "github:miuirussia/nixpkgs/nixpkgs-unstable"; };

    # flakes
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
  };

  outputs = { self, nixpkgs, ... }:
    let
      stableFile = ./meta/yandex-browser-stable.json;
      betaFile = ./meta/yandex-browser-beta.json;

      getMeta = with builtins; file: fromJSON (readFile file);
      getName = file:
        let
          info = getMeta file;
        in
        "${info.pname}-${info.version}";

      betaMeta = getMeta betaFile;
      stableMeta = getMeta stableFile;

      # Fix cached failure https://discourse.nixos.org/t/flakes-with-unfree-licenses/9405/3
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [
            (getName stableFile)
            (getName betaFile)
          ];
        };
      };
      node = pkgs.nodejs;

      browsers = {
        yandex-browser-beta = pkgs.callPackage ((import ./browser) betaMeta) { };
        yandex-browser-stable = pkgs.callPackage ((import ./browser) stableMeta) { };
      };
    in
    {
      packages.x86_64-linux = browsers;

      devShell.x86_64-linux = pkgs.mkShell {
        buildInputs = [
          node
        ];
      };

      apps.x86_64-linux = {
        update-browser = {
          type = "app";
          program = toString (pkgs.writeScript "update-browser" ''
            #!/usr/bin/env bash
            set -exuo pipefail

            ${node}/bin/node scripts/update.js
          '');
        };

        update-codecs = {
          type = "app";
          program = toString (pkgs.writeScript "update-codecs" ''
            #!/usr/bin/env bash
            set -exuo pipefail

            export STABLE=${browsers.yandex-browser-stable}
            export BETA=${browsers.yandex-browser-beta}

            ${node}/bin/node scripts/codecs.js
          '');
        };
      };
    };
}

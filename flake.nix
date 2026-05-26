{
  description = "Logos App Builder - Build and run Logos UI applications (QML modules + standalone apps)";

  inputs = {
    logos-nix.url = "github:logos-co/logos-nix";
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    logos-standalone-app.url = "github:logos-co/logos-standalone-app";
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    nix-bundle-logos-module-install.url = "github:logos-co/nix-bundle-logos-module-install";
    nixpkgs.follows = "logos-nix/nixpkgs";
  };

  outputs = { self, nixpkgs, logos-module-builder, logos-standalone-app, nix-bundle-lgx, nix-bundle-logos-module-install, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        inherit system;
        pkgs = import nixpkgs { inherit system; };
      });

      lib = import ./lib {
        inherit nixpkgs nix-bundle-lgx nix-bundle-logos-module-install logos-standalone-app;
        inherit logos-module-builder;
        inherit (nixpkgs) lib;
      };
    in
    {
      lib = lib;

      templates = {
        ui-qml-backend = {
          path = ./templates/ui-qml-backend;
          description = "Logos ui_qml module with C++ backend (process-isolated) and QML view";
        };

        ui-qml = {
          path = ./templates/ui-qml;
          description = "Logos ui_qml module (QML-only, no C++ backend)";
        };
      };

      checks = forAllSystems ({ pkgs, system, ... }: {
        # Pure Nix evaluation tests (collectAllModuleDeps)
        default = import ./tests {
          inherit pkgs;
          inherit (nixpkgs) lib;
          collectAllModuleDeps = lib.collectAllModuleDeps;
        };
        # Integration test: builds a QML module from a fixture
        qml-integration = import ./tests/test-qml-integration.nix {
          inherit pkgs;
          mkLogosQmlModule = lib.mkLogosQmlModule;
          fixturesRoot = ./tests/fixtures;
        };
      });
    };
}

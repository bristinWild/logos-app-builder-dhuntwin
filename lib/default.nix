# Main entry point for logos-app-builder library
# Provides builders for UI/QML modules and standalone app launching.
# Delegates C++ plugin compilation to logos-module-builder.
{ nixpkgs, lib, logos-module-builder, logos-standalone-app, nix-bundle-lgx, nix-bundle-logos-module-install }:

let
  moduleBuilderLib = logos-module-builder.lib;

  # Reuse utilities from logos-module-builder
  common = moduleBuilderLib.common;
  parseMetadata = moduleBuilderLib.parseMetadata;

  collectAllModuleDeps = import ./collectAllModuleDeps.nix { inherit lib nix-bundle-lgx; };

  mkLogosQmlModule = import ./mkLogosQmlModule.nix {
    inherit nixpkgs nix-bundle-lgx nix-bundle-logos-module-install logos-standalone-app lib;
    inherit common parseMetadata collectAllModuleDeps;
    inherit logos-module-builder;
  };

  mkStandaloneApp = import ./mkStandaloneApp.nix;

  mkLogosApp = import ./mkLogosApp.nix {
    inherit nixpkgs lib logos-standalone-app nix-bundle-lgx;
    inherit common collectAllModuleDeps mkStandaloneApp;
  };

in {
  inherit mkLogosQmlModule;
  inherit mkLogosApp;
  inherit mkStandaloneApp;
  inherit collectAllModuleDeps;

  inherit common parseMetadata;

  version = "0.1.0";
}

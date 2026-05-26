# Higher-level standalone app builder for UI modules.
# Composes collectAllModuleDeps + mkStandaloneApp into a ready-to-use
# apps output. Usable by both QML (ui_qml) and legacy UI modules.
{ nixpkgs, lib, logos-standalone-app, nix-bundle-lgx, common, collectAllModuleDeps, mkStandaloneApp }:

{
  # Required: the module's packages output (attrset of system -> { default, ... })
  packages,

  # Required: path to metadata.json
  configFile,

  # Optional: all flake inputs (for resolving module dependencies)
  flakeInputs ? {},

  # Optional: override the standalone app
  logosStandalone ? null,

  # Optional: format for pluginDir layout ("qt-plugin" or "qml")
  format ? "qt-plugin",
}:

let
  config = (import ./parseMetadataInline.nix { inherit lib; }) configFile;

  resolvedStandalone =
    if logosStandalone != null then logosStandalone
    else logos-standalone-app;

  systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
  forAllSystems = f: lib.genAttrs systems (system: f system);

in {
  apps = forAllSystems (system:
    let
      pkgs = import nixpkgs { inherit system; };
      allDeps = collectAllModuleDeps system flakeInputs config.dependencies;
    in {
      default = mkStandaloneApp {
        inherit pkgs;
        standalone   = resolvedStandalone.packages.${system}.default;
        plugin       = packages.${system}.default;
        metadataFile = configFile;
        dirName      = "logos-${config.name}-plugin-dir";
        inherit format;
        moduleDeps   = allDeps;
      };
    }
  );
}

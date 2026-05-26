# ui_qml module builder — QML view + optional C++ backend (process-isolated).
# Calls buildCppPlugin (from logos-module-builder) only when config.main is set;
# the resulting `combined` output bundles the plugin .so (when present) with the
# QML view directory.
{ nixpkgs, lib, common, parseMetadata, collectAllModuleDeps, logos-module-builder, nix-bundle-lgx, nix-bundle-logos-module-install, logos-standalone-app }:

{
  src,
  configFile,
  flakeInputs ? {},
  externalLibInputs ? {},
  extraBuildInputs ? [],
  extraNativeBuildInputs ? [],
  configOverrides ? {},
  preConfigure ? "",
  postInstall ? "",
  logosStandalone ? null,
}:

let
  rawConfig = parseMetadata.parseModuleConfig (builtins.readFile configFile);
  config = common.recursiveMerge [ rawConfig configOverrides ];

  _ = assert config.type == "ui_qml" || builtins.throw
    "mkLogosQmlModule: metadata.json type must be \"ui_qml\", got \"${config.type}\"";
  assert config.view != null || builtins.throw
    "mkLogosQmlModule: metadata.json must specify a \"view\" field (e.g. \"qml/Main.qml\")";
  null;

  hasBackend = config.main != null;

  # Delegate C++ compilation to logos-module-builder's shared pipeline
  built =
    if hasBackend
    then logos-module-builder.lib.buildCppPlugin {
      inherit src configFile flakeInputs externalLibInputs extraBuildInputs
              extraNativeBuildInputs configOverrides preConfigure postInstall;
    }
    else null;

  viewDir = builtins.dirOf config.view;

  mkStandaloneApp = import ./mkStandaloneApp.nix;

  forAllSystems = f: lib.genAttrs common.systems (system: f system);

  pkgsFor = system:
    if hasBackend
    then built.perSystem.${system}.pkgs
    else import nixpkgs { inherit system; };

  iconFiles = lib.optional (config.icon != null) (src + "/${config.icon}");

  mkCombined = system: pluginLib: suffix:
    let pkgs = pkgsFor system;
        iconInstall = pkgs.lib.concatStringsSep "\n" (map (icon: ''
          install -D -m644 ${icon} $out/lib/${config.icon}
        '') iconFiles);
    in (pkgs.runCommand "logos-${config.name}-module${suffix}" {} ''
      mkdir -p $out/lib

      ${lib.optionalString (pluginLib != null) ''
        if [ -d "${pluginLib}/lib" ]; then
          cp -rL ${pluginLib}/lib/* $out/lib/
        fi
      ''}

      cp ${configFile} $out/lib/metadata.json
      ${iconInstall}

      if [ -d "${src}/src/${viewDir}" ] && [ "${viewDir}" != "." ]; then
        mkdir -p "$out/lib/${viewDir}"
        cp -r "${src}/src/${viewDir}/." "$out/lib/${viewDir}/"
        echo "Copied QML view directory from src/${viewDir}"
      elif [ -d "${src}/${viewDir}" ] && [ "${viewDir}" != "." ]; then
        mkdir -p "$out/lib/${viewDir}"
        cp -r "${src}/${viewDir}/." "$out/lib/${viewDir}/"
        echo "Copied QML view directory from ${viewDir}"
      elif [ -f "${src}/src/${config.view}" ]; then
        cp "${src}/src/${config.view}" "$out/lib/${config.view}"
        echo "Copied QML entry file from src/${config.view}"
      elif [ -f "${src}/${config.view}" ]; then
        cp "${src}/${config.view}" "$out/lib/${config.view}"
        echo "Copied QML entry file: ${config.view}"
      else
        echo "Warning: QML view '${config.view}' not found in source"
      fi
    '') // { inherit src; version = config.version; };

  packages = forAllSystems (system:
    let
      moduleLib =
        if hasBackend then built.perSystem.${system}.moduleLib else null;
      moduleLibPortable =
        if hasBackend then built.perSystem.${system}.moduleLibPortable else null;

      combined = mkCombined system moduleLib "";

    in {
      default = combined;
    } // lib.optionalAttrs hasBackend {
      "${config.name}-lib" = moduleLib;
      lib = moduleLib;
    } // lib.optionalAttrs (moduleLibPortable != null) {
      "${config.name}-lib-portable" = moduleLibPortable;
      lib-portable = moduleLibPortable;
    }
  );

  lgxPackages = forAllSystems (system:
    let
      bundleLgx = nix-bundle-lgx.bundlers.${system}.default;
      bundleLgxPortable = nix-bundle-lgx.bundlers.${system}.portable;
      installDev = nix-bundle-logos-module-install.bundlers.${system}.dev;
      installPortable = nix-bundle-logos-module-install.bundlers.${system}.portable;

      moduleLib =
        if hasBackend then built.perSystem.${system}.moduleLib else null;
      moduleLibPortable =
        if hasBackend then built.perSystem.${system}.moduleLibPortable else null;

      combined = mkCombined system moduleLib "";
      combinedForPortable =
        if moduleLibPortable != null
        then mkCombined system moduleLibPortable "-portable"
        else combined;
    in {
      lgx = bundleLgx combined;
      install = installDev combined;
      lgx-portable = bundleLgxPortable combinedForPortable;
      install-portable = installPortable combinedForPortable;
    }
  );

  resolvedStandalone =
    if logosStandalone != null then logosStandalone
    else logos-standalone-app;

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
        format       = if hasBackend then "qt-plugin" else "qml";
        moduleDeps   = allDeps;
      };
    }
  );

  testsDir = src + "/tests";
  hasTestsDir = builtins.pathExists testsDir;
  testFiles =
    if hasTestsDir then
      let
        entries = builtins.attrNames (builtins.readDir testsDir);
        mjsFiles = builtins.filter (name: lib.hasSuffix ".mjs" name) entries;
      in map (name: testsDir + "/${name}") mjsFiles
    else [];
  hasUiTests = testFiles != [];

  integrationTestPackages = lib.optionalAttrs hasUiTests (forAllSystems (system:
    let
      mkPluginTest = resolvedStandalone.lib.${system}.mkPluginTest;
      pkgs = pkgsFor system;
      allDeps = collectAllModuleDeps system flakeInputs config.dependencies;
    in {
      integration-test = mkPluginTest {
        inherit pkgs testFiles;
        pluginPkg = packages.${system}.default;
        moduleDeps = allDeps;
        name = "${config.name}-integration-test";
      };

      test-framework = resolvedStandalone.packages.${system}.logos-qt-mcp;
    }
  ));

  mergedPackages = lib.mapAttrs (system: sysPkgs:
    sysPkgs // (lgxPackages.${system} or {}) // (integrationTestPackages.${system} or {})
  ) packages;

in {
  packages = mergedPackages;
  devShells =
    if hasBackend
    then built.devShells
    else lib.genAttrs common.systems (system:
      { default = (pkgsFor system).mkShell {}; });
  inherit apps config;
  metadataJson = builtins.readFile configFile;
}

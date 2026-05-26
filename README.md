# Logos App Builder

Shared Nix library for building Logos UI applications — QML modules with optional C++ backends and standalone app launching.

## Overview

`logos-app-builder` provides the build infrastructure for UI/QML Logos modules and standalone application preview. It delegates C++ plugin compilation to [`logos-module-builder`](https://github.com/logos-co/logos-module-builder) and layers on QML view bundling, standalone app wrapping, and UI integration tests.

### What it provides

| Function | Purpose |
|---|---|
| `mkLogosQmlModule` | Build ui_qml modules (QML-only or QML + C++ backend) |
| `mkLogosApp` | Add standalone app launching (`nix run`) to any UI module |
| `mkStandaloneApp` | Lower-level: wrap a plugin into a runnable app |
| `collectAllModuleDeps` | Resolve transitive module dependencies for bundling |

### What stays in logos-module-builder

Core/backend module building: `mkLogosModule`, `buildCppPlugin`, `mkExternalLib`, `parseMetadata`, `mkLogosModuleTests`, CMake macros, and core module templates.

## Usage

### QML-only module (no C++ backend)

```nix
# flake.nix
{
  inputs.logos-app-builder.url = "github:logos-co/logos-app-builder";

  outputs = inputs@{ logos-app-builder, ... }:
    logos-app-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
```

### QML module with C++ backend

```nix
# flake.nix
{
  inputs = {
    logos-app-builder.url = "github:logos-co/logos-app-builder";
    some_module.url = "github:logos-co/logos-some-module";
  };

  outputs = inputs@{ logos-app-builder, ... }:
    logos-app-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
```

### Legacy UI module (type: "ui") with standalone app

For legacy UI modules built with `logos-module-builder.lib.mkLogosModule`, use `mkLogosApp` to add `apps` output:

```nix
# flake.nix
{
  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    logos-app-builder.url = "github:logos-co/logos-app-builder";
  };

  outputs = inputs@{ logos-module-builder, logos-app-builder, ... }:
    let
      module = logos-module-builder.lib.mkLogosModule {
        src = ./.;
        configFile = ./metadata.json;
        flakeInputs = inputs;
      };
      appOutputs = logos-app-builder.lib.mkLogosApp {
        packages = module.packages;
        configFile = ./metadata.json;
        flakeInputs = inputs;
      };
    in module // { inherit (appOutputs) apps; };
}
```

## Templates

Scaffold a new UI module:

```bash
# QML-only module
nix flake init -t github:logos-co/logos-app-builder#ui-qml

# QML + C++ backend module
nix flake init -t github:logos-co/logos-app-builder#ui-qml-backend
```

## metadata.json

UI modules use `type: "ui_qml"` and must specify a `view` field:

```json
{
  "name": "my_ui_module",
  "version": "1.0.0",
  "type": "ui_qml",
  "view": "qml/Main.qml",
  "main": "my_ui_module_plugin",
  "dependencies": ["some_core_module"]
}
```

- `view` (required): Path to the QML entry point
- `main` (optional): C++ plugin name. Omit for QML-only modules.
- `dependencies`: Core modules this UI depends on (resolved transitively)

## Architecture

```
logos-app-builder
  ├── lib/
  │   ├── default.nix              # Entry point
  │   ├── mkLogosQmlModule.nix     # QML + optional C++ backend builder
  │   ├── mkLogosApp.nix           # Standalone app output for any UI module
  │   ├── mkStandaloneApp.nix      # Low-level standalone wrapper
  │   ├── collectAllModuleDeps.nix # Transitive dependency resolver
  │   └── parseMetadataInline.nix  # Lightweight metadata parser
  ├── templates/
  │   ├── ui-qml/                  # QML-only template
  │   └── ui-qml-backend/         # QML + C++ backend template
  └── tests/
      ├── test-qml-integration.nix
      ├── test-collectAllModuleDeps.nix
      └── fixtures/
```

## Relationship with logos-module-builder

`logos-app-builder` takes `logos-module-builder` as a flake input and accesses its library functions via `logos-module-builder.lib`. When a QML module has a C++ backend (`main` is set in metadata.json), `mkLogosQmlModule` calls `logos-module-builder.lib.buildCppPlugin` for compilation, then bundles the result with the QML view.

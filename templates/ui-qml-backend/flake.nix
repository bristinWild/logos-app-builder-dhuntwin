{
  description = "Logos ui_qml module (C++ backend + QML view) — replace with your description";

  inputs = {
    logos-app-builder.url = "github:logos-co/logos-app-builder";
    # Add core module dependencies as inputs (must match metadata.json "dependencies"), e.g.:
    # some_module.url = "github:logos-co/logos-some-module";
  };

  outputs = inputs@{ logos-app-builder, ... }:
    logos-app-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}

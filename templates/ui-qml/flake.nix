{
  description = "Logos QML UI Module — replace with your description";

  inputs = {
    logos-app-builder.url = "github:logos-co/logos-app-builder";
  };

  outputs = inputs@{ logos-app-builder, ... }:
    logos-app-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}

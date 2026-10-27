{
  description = "Logos tor_ui: manage the Tor that comes with Logos.";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    # Follows this builder: a skewed generated ABI crashes in provider init.
    tor_module = {
      url = "github:logos-co/logos-tor-module";
      inputs.logos-module-builder.follows = "logos-module-builder";
    };
  };

  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}

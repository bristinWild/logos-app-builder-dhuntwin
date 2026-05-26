# Lightweight metadata parser for mkLogosApp (reads name, type, dependencies)
{ lib }:

configFile:
let
  raw = builtins.fromJSON (builtins.readFile configFile);
  safeList = val: if builtins.isList val then val else [];
in {
  name         = raw.name or (throw "metadata.json must specify 'name'");
  type         = raw.type or "core";
  dependencies = safeList (raw.dependencies or []);
}

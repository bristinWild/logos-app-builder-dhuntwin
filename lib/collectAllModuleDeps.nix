# Recursively collect all module dependencies (direct + transitive) from flake
# inputs, using each module's exported config.dependencies to walk the tree.
# Returns a flat attrset: { moduleName = lgxDerivation; ... }
# Uses the LGX package output (packages.lgx) which bundles the plugin plus
# any external libraries it depends on.  When a dependency lacks packages.lgx,
# it is automatically bundled into an LGX package using nix-bundle-lgx.
{ lib, nix-bundle-lgx }:

let
  collectAllModuleDeps = system: inputs: depNames:
    let
      depInputs = lib.filterAttrs (n: _: builtins.elem n depNames) inputs;

      autoBundleLgx = drv:
        if nix-bundle-lgx == null then
          builtins.throw "collectAllModuleDeps: dependency lacks packages.${system}.lgx and nix-bundle-lgx is not available to auto-bundle it. Either add an lgx output to the dependency or ensure nix-bundle-lgx is passed."
        else if !(nix-bundle-lgx ? bundlers.${system}.default) then
          builtins.throw "collectAllModuleDeps: nix-bundle-lgx does not provide a bundler for system ${system}."
        else
          nix-bundle-lgx.bundlers.${system}.default drv;

      direct = lib.mapAttrs (_: input:
        if input ? packages.${system}.lgx
        then input.packages.${system}.lgx
        else if input ? packages.${system}.lib
        then autoBundleLgx input.packages.${system}.lib
        else if input ? packages.${system}.default
        then autoBundleLgx input.packages.${system}.default
        else input
      ) depInputs;

      transitive = builtins.foldl' (acc: name:
        let
          input = depInputs.${name};
          tdeps = (input.config or {}).dependencies or [];
          tinputs = input.inputs or {};
        in
          if tdeps == [] then acc
          else acc // (collectAllModuleDeps system tinputs tdeps)
      ) {} (builtins.attrNames depInputs);
    in
      transitive // direct;

in collectAllModuleDeps

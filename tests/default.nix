# Test runner for logos-app-builder
# Pure Nix evaluation tests — no compilation needed.
# Usage: nix build .#checks.<system>.default
{ pkgs, lib, collectAllModuleDeps }:

let
  assertEq = name: actual: expected:
    if actual == expected then true
    else builtins.throw "FAIL ${name}: expected ${builtins.toJSON expected}, got ${builtins.toJSON actual}";

  assertBool = name: actual: expected:
    if actual == expected then true
    else builtins.throw "FAIL ${name}: expected ${builtins.toString expected}, got ${builtins.toString actual}";

  assertHasAttr = name: attrset: key:
    if builtins.hasAttr key attrset then true
    else builtins.throw "FAIL ${name}: missing attribute '${key}' in ${builtins.toJSON (builtins.attrNames attrset)}";

  collectDepsTests = import ./test-collectAllModuleDeps.nix {
    inherit assertEq assertBool assertHasAttr collectAllModuleDeps;
  };

  allTests = collectDepsTests;
  allPassed = builtins.deepSeq allTests (builtins.length allTests);

in pkgs.runCommand "logos-app-builder-tests" {} ''
  echo "Running logos-app-builder tests..."
  echo "All ${builtins.toString allPassed} tests passed."
  mkdir -p $out
  echo "${builtins.toString allPassed} tests passed" > $out/results.txt
''

{ pkgs }:

let callPackage = pkgs.callPackage;
in {
  unityhub = callPackage ./unityhub {};
}

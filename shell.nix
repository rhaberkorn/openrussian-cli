{ pkgs ? (import <nixpkgs> {}) }:
let
  openrussian = pkgs.callPackage ./default.nix {};
in
pkgs.mkShell {
  buildInputs = [ openrussian ];
}

_: {
  perSystem.text.readme.parts.dendritic = ''
    ## Dendritic Pattern

    This repository follows the dendritic pattern from `mightyiam/dendritic`: every
    Nix file under `modules/` is a top-level flake-parts module, and feature
    modules register named NixOS and Home Manager modules instead of importing
    distant paths directly.

  '';
}

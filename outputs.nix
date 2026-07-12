inputs:
let
  evaluation = inputs.flake-parts.lib.evalFlakeModule { inherit inputs; } {
    imports = [ (inputs.import-tree ./modules) ];
  };
in
evaluation.config.processedFlake

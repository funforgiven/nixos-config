_: {
  perSystem =
    { pkgs, ... }:
    let
      quickshellSource = ../funforgiven/window-manager/quickshell;
    in
    {
      checks.quickshell-niri-state =
        pkgs.runCommand "quickshell-niri-state-test"
          {
            nativeBuildInputs = [ pkgs.nodejs ];
          }
          ''
            node --test ${quickshellSource}/tests/*.test.js
            touch "$out"
          '';
    };
}

_: {
  nixos.modules.polkit-agent =
    { config, ... }:
    let
      kdeSelected = config.dendritic.polkit.agent == "kde";
    in
    {
      systemd.user.services.niri-flake-polkit.enable = kdeSelected;

      assertions = [
        {
          assertion = config.programs.niri.enable;
          message = "The selected polkit agent requires the Niri system feature.";
        }
        {
          assertion = config.systemd.user.services.niri-flake-polkit.enable == kdeSelected;
          message = "The KDE polkit unit must match dendritic.polkit.agent.";
        }
      ];
    };
}

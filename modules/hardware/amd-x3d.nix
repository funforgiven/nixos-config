_: {
  nixos.modules.amd-x3d =
    {
      lib,
      pkgs,
      ...
    }:
    let
      profiles = pkgs.writeTextDir "reaper.conf" ''
        name = "reaper"
        performance_mode = false
        scx_sched = none
        scx_sched_props = default
        vcache_mode = cache
        idle_inhibit = false
        dmem_protect = false
        disable_split_lock = false
        start_script = ""
        stop_script = ""
      '';
    in
    {
      environment.etc = {
        "falcond/config.conf".text = ''
          enable_performance_mode = false
          scx_sched = none
          scx_sched_props = default
          vcache_mode = freq
          profile_mode = none
          poll_interval_ms = 9000
        '';
        "falcond/profiles".source = profiles;
      };

      systemd.services.falcond = {
        description = "Falcond X3D preference daemon";
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = lib.getExe pkgs.falcond;
          User = "root";
          Restart = "on-failure";
        };
      };
    };
}

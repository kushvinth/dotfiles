{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.borgmatic-agent;
in
{
  options.services.borgmatic-agent = {
    enable = lib.mkEnableOption "scheduled borgmatic backups (config: /etc/borgmatic/config.yaml)";

    hour = lib.mkOption {
      type = lib.types.ints.between 0 23;
      default = 21;
      description = "Hour of the daily run. A run is also triggered whenever a volume mounts.";
    };
  };

  config = lib.mkIf cfg.enable {
    # A user agent, not a root daemon: the repo lives in the user's home and the
    # passphrase comes from the user's login Keychain (encryption_passcommand),
    # which root can't read. The config's `before` hook skips the run (exit 75)
    # when the source volume isn't mounted.
    launchd.user.agents.borgmatic = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.borgmatic}/bin/borgmatic"
          "--config"
          "/etc/borgmatic/config.yaml"
          "--verbosity"
          "0"
          "--syslog-verbosity"
          "1"
        ];
        StartCalendarInterval = [
          {
            Hour = cfg.hour;
            Minute = 0;
          }
        ];
        StartOnMount = true;
        RunAtLoad = false;
        ProcessType = "Background";
        LowPriorityIO = true;
        EnvironmentVariables.PATH = "${
          lib.makeBinPath [
            pkgs.borgbackup
            pkgs.coreutils
          ]
        }:/usr/bin:/bin:/usr/sbin:/sbin";
        StandardOutPath = "/tmp/borgmatic.log";
        StandardErrorPath = "/tmp/borgmatic.log";
      };
    };
  };
}

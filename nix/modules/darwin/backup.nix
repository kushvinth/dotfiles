{
  flake.modules.darwin.backup =
    {
      config,
      lib,
      pkgs,
      user,
      ...
    }:
    let
      cfg = config.services.borgmatic-agent;
      borgmaticConfig = ''
        source_directories:
            - /Volumes/UNTITLED

        repositories:
            - path: /Users/${user}/LocalStorage/Developer/xtenik/backup
              label: xteink

        compression: lz4

        exclude_patterns:
            - /Volumes/UNTITLED/.Trashes
            - /Volumes/UNTITLED/.TemporaryItems
            - /Volumes/UNTITLED/.fseventsd
            - /Volumes/UNTITLED/.Spotlight-V100

        archive_name_format: 'xteink-{now:%Y%m%d_%H%M%S}'

        keep_daily: 7
        keep_weekly: 4
        keep_monthly: 3

        encryption_passcommand: security find-generic-password -a ${user} -s "borg-xteink" -w

        commands:
            - before: action
              when:
                  - create
              run:
                  - mount | grep -q "/Volumes/UNTITLED" || { echo "Volume not mounted; skipping"; exit 75; }
      '';
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
        environment.etc."borgmatic/config.yaml".text = borgmaticConfig;

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
            StandardOutPath = "/Users/${user}/Library/Logs/borgmatic.log";
            StandardErrorPath = "/Users/${user}/Library/Logs/borgmatic.log";
          };
        };
      };
    };
}

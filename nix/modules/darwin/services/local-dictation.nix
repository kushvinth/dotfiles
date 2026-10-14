{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  cfg = config.services.local-dictation;
  inherit (lib) mkOption types;

  label = "${config.launchd.labelPrefix}.whisper-server";
  # While this exists launchd keeps whisper-server alive (KeepAlive.PathState).
  # /tmp is wiped at boot, so nothing starts until the guard has seen the battery.
  runFlag = "/tmp/local-dictation.${user}.on";

  ollamaEnv = lib.concatStrings (
    lib.mapAttrsToList (n: v: "launchctl setenv ${n} ${lib.escapeShellArg v}\n") cfg.ollama.environment
  );

  guard = pkgs.writeShellApplication {
    name = "dictation-guard";
    text = ''
      # Last decision; also gone after a reboot, so the first run after login always acts.
      state=/tmp/local-dictation.${user}.state
      last=$(cat "$state" 2>/dev/null || true)

      batt=$(pmset -g batt)
      pct=100
      [[ $batt =~ ([0-9]+)% ]] && pct=''${BASH_REMATCH[1]}
      if [[ $batt == *"'AC Power'"* ]]; then
        want=on reason="AC power"
      elif ${lib.boolToString cfg.batteryGuard.stopOnBattery}; then
        want=off reason="on battery ($pct%)"
      elif ((pct < ${toString cfg.batteryGuard.minPercent})); then
        want=off reason="battery $pct% < ${toString cfg.batteryGuard.minPercent}%"
      else
        want=on reason="battery $pct%"
      fi

      start() {
        touch ${runFlag}
        ${lib.optionalString cfg.ollama.manage ''
          ${ollamaEnv}
          ${lib.optionalString (cfg.ollama.environment != { }) ''
            # Opened at login before the variables above existed: restart once so they apply.
            if [[ -z $last ]] && pgrep -xq Ollama; then
              pkill -TERM -x Ollama || true
              for _ in $(seq 20); do pgrep -xq Ollama || break; sleep 0.5; done
            fi
          ''}
          pgrep -xq Ollama || open -j -a Ollama
        ''}
      }

      stop() {
        rm -f ${runFlag}
        launchctl kill SIGTERM "gui/$(id -u)/${label}" 2>/dev/null || true
        ${lib.optionalString cfg.ollama.manage ''
          # Ollama.app treats SIGTERM like Quit and stops its server and runners.
          pkill -TERM -x Ollama || true
        ''}
      }

      if [[ ''${1:-} == status ]]; then
        svc=$(launchctl print "gui/$(id -u)/${label}" 2>/dev/null) || svc=""
        if [[ $svc =~ state\ =\ ([a-z ]+) ]]; then svc=''${BASH_REMATCH[1]}; else svc="not loaded"; fi
        echo "guard: $want ($reason), last applied: ''${last:-never}"
        echo "whisper-server: $svc"
        echo "ollama: $(pgrep -xq Ollama && echo running || echo stopped)"
        exit 0
      fi

      # Only act on changes, so quitting or opening Ollama by hand is left alone.
      [[ $want == "$last" ]] && exit 0
      echo "$(date '+%F %T') $want: $reason"
      if [[ $want == on ]]; then start; else stop; fi
      echo "$want" >"$state"
    '';
  };

  # whisper-server's VAD step gets slower with every request (86 ms on the
  # first clip, ~3 s by the 50th; whisper-cpp 1.9.2) until it restarts. Restart
  # it after `restartAfter` clips, only while idle, never if it isn't running.
  log = "/tmp/whisper-server.log";
  recycle = pkgs.writeShellApplication {
    name = "whisper-recycle";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
    ];
    text = ''
      target="gui/$(id -u)/${label}"
      launchctl print "$target" 2>/dev/null | grep -q 'state = running' || exit 0
      [[ -f ${log} ]] || exit 0

      # Clips since the server's last start.
      clips=$(awk '/whisper_init_from_file_with_params_no_state/ { n = 0 } /vad time =/ { n++ } END { print n + 0 }' ${log})
      ((clips >= ${toString cfg.restartAfter})) || exit 0

      # Idle: nothing logged for a minute, so no dictation is cut off.
      (($(date +%s) - $(stat -c %Y ${log}) >= 60)) || exit 0

      : >${log}
      launchctl kickstart -k "$target"
      echo "$(date '+%F %T') restarted whisper-server after $clips clips"
    '';
  };
in
{
  options.services.local-dictation = {
    enable = lib.mkEnableOption "local speech-to-text for FreeFlow (whisper.cpp with a Core ML encoder)";

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "FreeFlow's Transcription API URL is http://127.0.0.1:<port>/v1.";
    };

    model = mkOption {
      type = types.str;
      default = "ggml-large-v3-turbo-q5_0.bin";
      description = "File in pkgs.whisper-models. A matching -encoder.mlmodelc next to it runs on the Neural Engine.";
    };

    language = mkOption {
      type = types.str;
      default = "en";
      description = "Default language; a `language` field in the request overrides it.";
    };

    vad = mkOption {
      type = types.bool;
      default = true;
      description = "Silero VAD: skip silence, which also stops Whisper hallucinating on quiet clips.";
    };

    restartAfter = mkOption {
      type = types.ints.positive;
      # VAD grows ~60-90 ms per clip, so 10 keeps it under ~1 s.
      default = 10;
      description = "Restart whisper-server after this many clips (while idle): its VAD step gets slower with every request.";
    };

    batteryGuard = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Stop whisper-server (and Ollama.app) when the battery runs low; start them again on AC.";
      };

      minPercent = mkOption {
        type = types.ints.between 0 100;
        default = 20;
        description = "On battery below this charge, stop the services.";
      };

      stopOnBattery = mkOption {
        type = types.bool;
        default = false;
        description = "Stop the services whenever unplugged, regardless of charge.";
      };

      interval = mkOption {
        type = types.ints.positive;
        default = 60;
        description = "Seconds between battery checks.";
      };
    };

    ollama = {
      manage = mkOption {
        type = types.bool;
        default = true;
        description = "Let the battery guard quit and reopen Ollama.app along with whisper-server.";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = {
          # Ollama defaults to 32k context with 24-47 GB of VRAM. FreeFlow's cleanup
          # prompt is ~1.6k tokens, so 8k leaves room and keeps the KV cache small.
          OLLAMA_CONTEXT_LENGTH = "8192";
        };
        description = ''
          Variables for Ollama.app, set with `launchctl setenv` (at activation and by
          the guard before it opens the app). The app's own context-length slider
          wins when it is set.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional cfg.batteryGuard.enable guard;

    launchd.user.envVariables = cfg.ollama.environment;

    launchd.user.agents.whisper-server = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.whisper-cpp}/bin/whisper-server"
          "--model"
          "${pkgs.whisper-models}/${cfg.model}"
          "--host"
          "127.0.0.1"
          "--port"
          (toString cfg.port)
          # FreeFlow posts to <Transcription API URL>/audio/transcriptions.
          "--inference-path"
          "/v1/audio/transcriptions"
          "--language"
          cfg.language
          # One segment per clip: no mid-sentence newlines in the text FreeFlow pastes.
          "--no-timestamps"
        ]
        ++ lib.optionals cfg.vad [
          "--vad"
          "--vad-model"
          "${pkgs.whisper-models}/ggml-silero-v6.2.0.bin"
        ];
        # FreeFlow uploads 16 kHz mono WAV, so no --convert/ffmpeg.
        WorkingDirectory = "/tmp";
        RunAtLoad = !cfg.batteryGuard.enable;
        KeepAlive = if cfg.batteryGuard.enable then { PathState.${runFlag} = true; } else true;
        StandardOutPath = log;
        StandardErrorPath = log;
      };
    };

    launchd.user.agents.whisper-recycle = lib.mkIf cfg.vad {
      serviceConfig = {
        ProgramArguments = [ "${recycle}/bin/whisper-recycle" ];
        StartInterval = 120;
        ProcessType = "Background";
        StandardOutPath = "/tmp/whisper-recycle.log";
        StandardErrorPath = "/tmp/whisper-recycle.log";
      };
    };

    launchd.user.agents.dictation-guard = lib.mkIf cfg.batteryGuard.enable {
      serviceConfig = {
        ProgramArguments = [ "${guard}/bin/dictation-guard" ];
        RunAtLoad = true;
        StartInterval = cfg.batteryGuard.interval;
        ProcessType = "Background";
        StandardOutPath = "/tmp/dictation-guard.log";
        StandardErrorPath = "/tmp/dictation-guard.log";
      };
    };
  };
}

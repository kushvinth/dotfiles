{
  config,
  pkgs,
  lib,
  ...
}:
let
  user = config.system.primaryUser;
  userHome = config.users.users.${user}.home;
  # Activation runs as root; per-user prefs must be written in the user's session.
  asUser = cmd: ''launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- ${cmd}'';
in
{
  system.defaults = {

    # ── Dock ─────────────────────────────────────
    dock = {
      autohide = true;
      orientation = "right";
      tilesize = 104;
      magnification = true;
      largesize = 46;
      mineffect = "genie";
      minimize-to-application = true;
      mru-spaces = false;
      show-recents = false;
      showMissionControlGestureEnabled = true;
      showAppExposeGestureEnabled = true;
      showDesktopGestureEnabled = true;
      showLaunchpadGestureEnabled = true;
      expose-group-apps = true;

      # Replaces the whole Dock on each switch (was dockutil --add).
      persistent-apps = [
        "/Applications/Ghostty.app"
        "/Applications/Zen.app"
        "/Applications/Nix Apps/Zed.app"
        "/Applications/Nix Apps/Obsidian.app"
        "/Applications/Visual Studio Code.app"
        "/Applications/Discord.app"
        "/System/Applications/Music.app"
        "/System/Applications/System Settings.app"
      ];
      persistent-others = [
        {
          folder = {
            path = "${userHome}/Downloads";
            displayas = "folder";
            showas = "grid";
          };
        }
      ];

      # Hot corners: 13 Lock Screen, 5 Screen Saver, 4 Desktop, 14 Quick Note.
      # Cmd modifiers are set under CustomUserPreferences."com.apple.dock".
      wvous-tl-corner = 13;
      wvous-tr-corner = 5;
      wvous-bl-corner = 4;
      wvous-br-corner = 14;
    };

    # ── Finder ───────────────────────────────────
    finder = {
      ShowPathbar = true;
      ShowStatusBar = false;
      ShowHardDrivesOnDesktop = false;
      ShowExternalHardDrivesOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      ShowMountedServersOnDesktop = false;
      FXPreferredViewStyle = "icnv";
      FXRemoveOldTrashItems = true;
      CreateDesktop = true;
      NewWindowTarget = "Other";
      NewWindowTargetPath = "file:///Users/${user}/LocalStorage/";
      _FXSortFoldersFirst = true;
      FXEnableExtensionChangeWarning = false;
    };

    # ── Trackpad ─────────────────────────────────
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    # ── Screencapture ────────────────────────────
    screencapture = {
      location = "~/LocalStorage/Screenshot";
      type = "png";
      disable-shadow = true;
      target = "file";
    };

    # ── Window Manager (Stage Manager) ───────────
    WindowManager = {
      GloballyEnabled = false;
      AutoHide = false;
      HideDesktop = true;
      StandardHideWidgets = true;
      EnableTilingByEdgeDrag = false;
      EnableTiledWindowMargins = false;
      EnableTilingOptionAccelerator = false;
      AppWindowGroupingBehavior = true;
      StandardHideDesktopIcons = false;
    };

    # ── Menu bar clock ───────────────────────────
    menuExtraClock = {
      ShowDate = 0;
      ShowDayOfWeek = true;
      ShowAMPM = true;
      ShowSeconds = false;
      IsAnalog = false;
      FlashDateSeparators = false;
    };

    # ── Global ───────────────────────────────────
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      AppleEnableSwipeNavigateWithScrolls = true;
      AppleKeyboardUIMode = 0;
      InitialKeyRepeat = 15;
      KeyRepeat = 6;
      NSAutomaticCapitalizationEnabled = true;
      NSAutomaticDashSubstitutionEnabled = true;
      NSAutomaticPeriodSubstitutionEnabled = true;
      NSAutomaticQuoteSubstitutionEnabled = true;
      NSAutomaticSpellingCorrectionEnabled = true;
      _HIHideMenuBar = true;
      "com.apple.trackpad.scaling" = 2.5;
      "com.apple.trackpad.forceClick" = false;
      "com.apple.springing.enabled" = false;
      "com.apple.springing.delay" = 0.5;
      "com.apple.sound.beep.feedback" = 0;
      "com.apple.swipescrolldirection" = true;
      "com.apple.keyboard.fnState" = true;
      AppleTemperatureUnit = "Celsius";
      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
    };

    # ── Mouse tracking speed (native option) ─────
    ".GlobalPreferences" = {
      "com.apple.mouse.scaling" = 3.0;
    };

    # ── CustomUserPreferences (Tier 2) ──────────
    # Settings that this nix-darwin version doesn't expose as typed options
    CustomUserPreferences = {

      # ── Dock — hot corner modifiers (Cmd) ──────
      "com.apple.dock" = {
        wvous-tl-modifier = 1048576;
        wvous-tr-modifier = 1048576;
        wvous-bl-modifier = 1048576;
        wvous-br-modifier = 1048576;
      };

      # ── NSGlobalDomain extras ──────────────────
      NSGlobalDomain = {
        AppleActionOnDoubleClick = "Maximize";
        AppleMenuBarVisibleInFullscreen = false;
        AppleMiniaturizeOnDoubleClick = false;
        AppleReduceDesktopTinting = false;
        AppleAntiAliasingThreshold = 4;
        AppleAquaColorVariant = 1;
        NSAutomaticTextCompletionEnabled = true;
        ContextMenuGesture = true;
        AppleLocale = "en_IN";
        "com.apple.scrollwheel.scaling" = 0.5;
        "com.apple.sound.beep.flash" = false;
        "com.apple.mouse.doubleClickThreshold" = 1.8;
      };

      # ── Trackpad — advanced gestures ──────────
      "com.apple.AppleMultitouchTrackpad" = {
        TrackpadThreeFingerTapGesture = 2;
        TrackpadFourFingerHorizSwipeGesture = 2;
        TrackpadFourFingerVertSwipeGesture = 2;
        TrackpadFourFingerPinchGesture = 2;
        TrackpadFiveFingerPinchGesture = 2;
        TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
        TrackpadHandResting = 1;
        ForceSuppressed = 1;
        ActuateDetents = 0;
        TrackpadMomentumScroll = 1;
        TrackpadHorizScroll = 1;
        TrackpadScroll = 1;
        TrackpadPinch = 1;
        TrackpadRotate = 1;
        TrackpadTwoFingerDoubleTapGesture = 1;
        FirstClickThreshold = 1;
        SecondClickThreshold = 1;
        USBMouseStopsTrackpad = 0;
        version = 12;
      };

      # ── Bluetooth trackpad (same settings) ────
      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
        TrackpadThreeFingerTapGesture = 2;
        TrackpadFourFingerHorizSwipeGesture = 2;
        TrackpadFourFingerVertSwipeGesture = 2;
        TrackpadFourFingerPinchGesture = 2;
        TrackpadFiveFingerPinchGesture = 2;
        TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
        TrackpadHandResting = 1;
        TrackpadThreeFingerDrag = 1;
        TrackpadRightClick = 1;
        Clicking = 1;
        USBMouseStopsTrackpad = 0;
        version = 5;
      };

      # ── Screencapture extras ──────────────────
      "com.apple.screencapture" = {
        showsClicks = true;
        video = true;
        style = "display";
      };

      # ── Control Center / Menu Bar visibility ──
      "com.apple.controlcenter" = {
        "NSStatusItem Visible Bluetooth" = false;
        "NSStatusItem Visible AccessibilityShortcuts" = false;
        "NSStatusItem Visible KeyboardBrightness" = false;
        "NSStatusItem Visible NowPlaying" = true;
        "NSStatusItem Visible BentoBox" = true;
        "NSStatusItem Visible DoNotDisturb" = true;
      };

      # ── Spotlight — clipboard history ─────────
      "com.apple.Spotlight" = {
        PasteboardHistoryTimeout = 0;
        PasteboardHistoryVersion = 2;
        EnabledPreferenceRules = [ "System.clipboardHistory" ];
      };

      # ── Symbolic HotKeys ──────────────────────
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "7" = {
            enabled = true;
            value = {
              parameters = [
                65535
                120
                8650752
              ];
              type = "standard";
            };
          };
          "8" = {
            enabled = true;
            value = {
              parameters = [
                65535
                99
                8650752
              ];
              type = "standard";
            };
          };
          "9" = {
            enabled = true;
            value = {
              parameters = [
                65535
                118
                8650752
              ];
              type = "standard";
            };
          };
          "10" = {
            enabled = true;
            value = {
              parameters = [
                65535
                96
                8650752
              ];
              type = "standard";
            };
          };
          "11" = {
            enabled = true;
            value = {
              parameters = [
                65535
                97
                8650752
              ];
              type = "standard";
            };
          };
          "12" = {
            enabled = true;
            value = {
              parameters = [
                65535
                122
                8650752
              ];
              type = "standard";
            };
          };
          "13" = {
            enabled = true;
            value = {
              parameters = [
                65535
                98
                8650752
              ];
              type = "standard";
            };
          };
          "32" = {
            enabled = true;
            value = {
              parameters = [
                65535
                126
                8650752
              ];
              type = "standard";
            };
          };
          "33" = {
            enabled = true;
            value = {
              parameters = [
                65535
                125
                8650752
              ];
              type = "standard";
            };
          };
          "34" = {
            enabled = true;
            value = {
              parameters = [
                65535
                126
                8781824
              ];
              type = "standard";
            };
          };
          "35" = {
            enabled = true;
            value = {
              parameters = [
                65535
                125
                8781824
              ];
              type = "standard";
            };
          };
          "36" = {
            enabled = true;
            value = {
              parameters = [
                65535
                103
                8388608
              ];
              type = "standard";
            };
          };
          "37" = {
            enabled = true;
            value = {
              parameters = [
                65535
                103
                8519680
              ];
              type = "standard";
            };
          };
          "79" = {
            enabled = true;
            value = {
              parameters = [
                65535
                123
                8650752
              ];
              type = "standard";
            };
          };
          "80" = {
            enabled = true;
            value = {
              parameters = [
                65535
                123
                8781824
              ];
              type = "standard";
            };
          };
          "81" = {
            enabled = true;
            value = {
              parameters = [
                65535
                124
                8650752
              ];
              type = "standard";
            };
          };
          "82" = {
            enabled = true;
            value = {
              parameters = [
                65535
                124
                8781824
              ];
              type = "standard";
            };
          };
          "118" = {
            enabled = true;
            value = {
              parameters = [
                65535
                18
                262144
              ];
              type = "standard";
            };
          };
          "119" = {
            enabled = true;
            value = {
              parameters = [
                65535
                19
                262144
              ];
              type = "standard";
            };
          };
          "120" = {
            enabled = true;
            value = {
              parameters = [
                65535
                20
                262144
              ];
              type = "standard";
            };
          };
          "121" = {
            enabled = true;
            value = {
              parameters = [
                65535
                21
                262144
              ];
              type = "standard";
            };
          };
          "122" = {
            enabled = true;
            value = {
              parameters = [
                65535
                23
                262144
              ];
              type = "standard";
            };
          };
          "57" = {
            enabled = true;
            value = {
              parameters = [
                65535
                100
                8650752
              ];
              type = "standard";
            };
          };
          "59" = {
            enabled = true;
            value = {
              parameters = [
                65535
                96
                9437184
              ];
              type = "standard";
            };
          };
          # 64 = Cmd+Space (Spotlight search) — disabled
          "64" = {
            enabled = false;
          };
          "65" = {
            enabled = true;
            value = {
              parameters = [
                65535
                49
                1572864
              ];
              type = "standard";
            };
          };
          "51" = {
            enabled = true;
            value = {
              parameters = [
                39
                50
                1572864
              ];
              type = "standard";
            };
          };
          "52" = {
            enabled = true;
            value = {
              parameters = [
                100
                2
                1572864
              ];
              type = "standard";
            };
          };
          "98" = {
            enabled = true;
            value = {
              parameters = [
                47
                44
                1179648
              ];
              type = "standard";
            };
          };
          "15" = {
            enabled = false;
          };
          "16" = {
            enabled = false;
          };
          "17" = {
            enabled = false;
          };
          "18" = {
            enabled = false;
          };
          "19" = {
            enabled = false;
            value = {
              parameters = [
                45
                27
                1572864
              ];
              type = "standard";
            };
          };
          "20" = {
            enabled = false;
          };
          "21" = {
            enabled = false;
            value = {
              parameters = [
                56
                28
                1835008
              ];
              type = "standard";
            };
          };
          "22" = {
            enabled = false;
          };
          "23" = {
            enabled = false;
            value = {
              parameters = [
                92
                42
                1572864
              ];
              type = "standard";
            };
          };
          "24" = {
            enabled = false;
          };
          "25" = {
            enabled = false;
            value = {
              parameters = [
                46
                47
                1835008
              ];
              type = "standard";
            };
          };
          "26" = {
            enabled = false;
            value = {
              parameters = [
                44
                43
                1835008
              ];
              type = "standard";
            };
          };
          "27" = {
            enabled = true;
            value = {
              parameters = [
                96
                50
                1048576
              ];
              type = "standard";
            };
          };
          "28" = {
            enabled = false;
            value = {
              parameters = [
                51
                20
                1179648
              ];
              type = "standard";
            };
          };
          "29" = {
            enabled = false;
            value = {
              parameters = [
                51
                20
                1441792
              ];
              type = "standard";
            };
          };
          "30" = {
            enabled = false;
            value = {
              parameters = [
                52
                21
                1179648
              ];
              type = "standard";
            };
          };
          "31" = {
            enabled = false;
            value = {
              parameters = [
                52
                21
                1441792
              ];
              type = "standard";
            };
          };
          "160" = {
            enabled = false;
          };
          "162" = {
            enabled = true;
            value = {
              parameters = [
                65535
                96
                9961472
              ];
              type = "standard";
            };
          };
          "163" = {
            enabled = false;
          };
          "164" = {
            enabled = false;
          };
          "175" = {
            enabled = true;
            value = {
              parameters = [
                65535
                65535
                0
              ];
              type = "standard";
            };
          };
          "176" = {
            enabled = true;
            value = {
              parameters = [
                92
                42
                1835008
              ];
              type = "standard";
            };
          };
          "179" = {
            enabled = false;
          };
          "181" = {
            enabled = false;
            value = {
              parameters = [
                54
                22
                1179648
              ];
              type = "standard";
            };
          };
          "182" = {
            enabled = false;
            value = {
              parameters = [
                54
                22
                1441792
              ];
              type = "standard";
            };
          };
          "184" = {
            enabled = false;
            value = {
              parameters = [
                53
                23
                1179648
              ];
              type = "standard";
            };
          };
        };
      };

      # ── Finder — ShowPreviewPane / ShowSidebar ─
      "com.apple.finder" = {
        ShowPreviewPane = true;
        ShowSidebar = true;
        FinderSpawnTab = true;
        FXPreferredGroupBy = "Kind";
      };

      # ── Login window ───────────────────────────
      "com.apple.loginwindow" = {
        MiniBuddyLaunch = 1;
        TALLogoutSavesState = 1;
      };

    };
  };

  # ──────────────────────────────────────────────
  # Tier 3 — post-activation script
  # (things that can't be expressed as plist keys)
  #
  # nix-darwin only runs a fixed set of activation script names, so custom
  # names (dock, finder, filevault, ...) were silently never executed. Everything
  # here lives in postActivation and runs as the primary user where needed.
  # Dropped on purpose:
  #  - dock/hot corners/Spotlight → typed options above
  #  - text replacements → macOS ignores NSUserDictionaryReplacementItems now
  #  - Finder IconViewSettings → `-dict-add` would wipe the rest of that dict
  #  - `fdesetup enable` → interactive and prints the recovery key; warn instead
  # ──────────────────────────────────────────────

  system.activationScripts.postActivation.text = ''
    # ── File associations ─────────────────────────
    ${asUser "${pkgs.duti}/bin/duti -s app.zen-browser.zen public.html all"} || true

    # ── Accessibility (best effort: needs Full Disk Access for the terminal) ──
    echo "dotfiles: setting accessibility options..." >&2
    ${asUser "/usr/bin/defaults write com.apple.universalaccess reduceMotion -bool true"} || true
    ${asUser "/usr/bin/defaults write com.apple.universalaccess reduceTransparency -bool false"} || true
    ${asUser "/usr/bin/defaults write com.apple.universalaccess increaseContrast -bool false"} || true
    ${asUser "/usr/bin/defaults write com.apple.universalaccess whiteOnBlack -bool false"} || true
    ${asUser "/usr/bin/defaults write com.apple.universalaccess grayscale -bool false"} || true
    ${asUser "/usr/bin/defaults write com.apple.universalaccess contrast -int 0"} || true
    ${asUser "/usr/bin/defaults write com.apple.universalaccess flashScreen -bool false"} || true
    ${asUser "/usr/bin/defaults write com.apple.universalaccess customFonts -bool true"} || true
    ${asUser "/usr/bin/defaults write com.apple.universalaccess closeViewZoomFactor -int 1"} || true
    ${asUser "/usr/bin/defaults write com.apple.Accessibility AssistiveControlType -int 2"} || true
    ${asUser "/usr/bin/defaults write com.apple.Accessibility KeyboardAccessFocusRingTimeout -int 15"} || true

    # ── Symbolic hotkeys — apply without relogin ─
    ${asUser "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u"} || true

    # ── FileVault — check only ──────────────────
    fileVaultStatus="$(/usr/bin/fdesetup status 2>/dev/null || true)"
    if [[ "$fileVaultStatus" != *"FileVault is On"* ]]; then
      echo "dotfiles: warning: FileVault is off; enable it once with: sudo fdesetup enable" >&2
    fi
  '';
}

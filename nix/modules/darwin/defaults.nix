{
  config,
  pkgs,
  lib,
  ...
}:
let
  user = config.system.primaryUser;
in
{
  system.defaults = {

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
    };

    finder = {
      ShowPathbar = true;
      ShowStatusBar = false;
      ShowHardDrivesOnDesktop = false;
      ShowExternalHardDrivesOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      ShowMountedServersOnDesktop = false;
      FXPreferredViewStyle = "icnv";
      FXRemoveOldTrashItems = true;
      FinderSpawnTab = true;
      CreateDesktop = true;
      NewWindowTarget = "PfLo";
      NewWindowTargetPath = "file:///Users/${user}/LocalStorage/";
    };

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
      USBMouseStopsTrackpad = false;
    };

    screencapture = {
      location = "~/LocalStorage/Screenshot";
      type = "png";
      disable-shadow = true;
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      AppleActionOnDoubleClick = "Maximize";
      AppleMenuBarVisibleInFullscreen = false;
      AppleMiniaturizeOnDoubleClick = false;
      AppleReduceDesktopTinting = false;
      AppleAntiAliasingThreshold = 4;
      AppleEnableSwipeNavigateWithScrolls = true;
      AppleAquaColorVariant = 1;
      AppleKeyboardUIMode = 0;
      InitialKeyRepeat = 15;
      KeyRepeat = 6;
      NSAutomaticCapitalizationEnabled = true;
      NSAutomaticDashSubstitutionEnabled = true;
      NSAutomaticPeriodSubstitutionEnabled = true;
      NSAutomaticQuoteSubstitutionEnabled = true;
      NSAutomaticSpellingCorrectionEnabled = true;
      NSAutomaticTextCompletionEnabled = true;
      _HIHideMenuBar = true;
      "com.apple.mouse.scaling" = 3.0;
      "com.apple.trackpad.scaling" = 2.5;
      "com.apple.scrollwheel.scaling" = 0.5;
      "com.apple.trackpad.forceClick" = false;
      "com.apple.springing.enabled" = false;
      "com.apple.springing.delay" = 0.5;
      "com.apple.sound.beep.feedback" = false;
      "com.apple.sound.beep.flash" = false;
      "com.apple.swipescrolldirection" = true;
      "com.apple.keyboard.fnState" = 1;
      "com.apple.mouse.doubleClickThreshold" = 1.8;
      ContextMenuGesture = true;
      AppleLocale = "en_IN";
      AppleTemperatureUnit = "Celsius";
      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = true;
    };

    CustomUserPreferences = {

      "com.apple.WindowManager" = {
        GloballyEnabled = false;
        AutoHide = false;
        HideDesktop = true;
        StandardHideWidgets = true;
        EnableTilingByEdgeDrag = false;
        EnableTiledWindowMargins = false;
        EnableTilingOptionAccelerator = false;
        AppWindowGroupingBehavior = 1;
        StandardHideDesktopIcons = false;
      };

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
        version = 12;
      };

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

      "com.apple.screencapture" = {
        showsClicks = true;
        video = true;
        style = "display";
        target = "file";
      };

      "com.apple.controlcenter" = {
        "NSStatusItem Visible Bluetooth" = false;
        "NSStatusItem Visible AccessibilityShortcuts" = false;
        "NSStatusItem Visible KeyboardBrightness" = false;
        "NSStatusItem Visible NowPlaying" = true;
        "NSStatusItem Visible BentoBox" = true;
        "NSStatusItem Visible DoNotDisturb" = true;
      };

      "com.apple.menuextra.clock" = {
        ShowDate = 2;
        ShowDayOfWeek = 1;
        ShowAMPM = 1;
        ShowSeconds = 0;
        IsAnalog = 0;
        FlashDateSeparators = 0;
      };

      "com.apple.Spotlight" = {
        PasteboardHistoryTimeout = 0;
        PasteboardHistoryVersion = 2;
        EnabledPreferenceRules = [ "System.clipboardHistory" ];
      };

      "com.apple.universalaccess" = {
        reduceMotion = true;
        reduceTransparency = false;
        increaseContrast = false;
        whiteOnBlack = false;
        grayscale = false;
        contrast = 0;
        flashScreen = false;
        customFonts = true;
        closeViewZoomFactor = 1;
      };

      "com.apple.Accessibility" = {
        UserAssignableHotKeys = [
          { symbolichotkey = 7;  enabled = false; }
          { symbolichotkey = 8;  enabled = false; }
          { symbolichotkey = 9;  enabled = false; }
          { symbolichotkey = 10; enabled = false; }
          { symbolichotkey = 11; enabled = false; }
        ];
        AssistiveControlType = 2;
        KeyboardAccessFocusRingTimeout = 15;
      };

      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          7 = { enabled = true;  value = { parameters = [ 65535 120 8650752 ]; type = "standard"; }; };
          8 = { enabled = true;  value = { parameters = [ 65535 99  8650752 ]; type = "standard"; }; };
          9 = { enabled = true;  value = { parameters = [ 65535 118 8650752 ]; type = "standard"; }; };
          10 = { enabled = true; value = { parameters = [ 65535 96  8650752 ]; type = "standard"; }; };
          11 = { enabled = true; value = { parameters = [ 65535 97  8650752 ]; type = "standard"; }; };
          12 = { enabled = true; value = { parameters = [ 65535 122 8650752 ]; type = "standard"; }; };
          13 = { enabled = true; value = { parameters = [ 65535 98  8650752 ]; type = "standard"; }; };
          32 = { enabled = true; value = { parameters = [ 65535 126 8650752 ]; type = "standard"; }; };
          33 = { enabled = true; value = { parameters = [ 65535 125 8650752 ]; type = "standard"; }; };
          34 = { enabled = true; value = { parameters = [ 65535 126 8781824 ]; type = "standard"; }; };
          35 = { enabled = true; value = { parameters = [ 65535 125 8781824 ]; type = "standard"; }; };
          36 = { enabled = true; value = { parameters = [ 65535 103 8388608 ]; type = "standard"; }; };
          37 = { enabled = true; value = { parameters = [ 65535 103 8519680 ]; type = "standard"; }; };
          79 = { enabled = true; value = { parameters = [ 65535 123 8650752 ]; type = "standard"; }; };
          80 = { enabled = true; value = { parameters = [ 65535 123 8781824 ]; type = "standard"; }; };
          81 = { enabled = true; value = { parameters = [ 65535 124 8650752 ]; type = "standard"; }; };
          82 = { enabled = true; value = { parameters = [ 65535 124 8781824 ]; type = "standard"; }; };
          118 = { enabled = true; value = { parameters = [ 65535 18  262144 ]; type = "standard"; }; };
          119 = { enabled = true; value = { parameters = [ 65535 19  262144 ]; type = "standard"; }; };
          120 = { enabled = true; value = { parameters = [ 65535 20  262144 ]; type = "standard"; }; };
          121 = { enabled = true; value = { parameters = [ 65535 21  262144 ]; type = "standard"; }; };
          122 = { enabled = true; value = { parameters = [ 65535 23  262144 ]; type = "standard"; }; };
          57 = { enabled = true;  value = { parameters = [ 65535 100 8650752 ]; type = "standard"; }; };
          59 = { enabled = true;  value = { parameters = [ 65535 96  9437184 ]; type = "standard"; }; };
          65 = { enabled = true;  value = { parameters = [ 65535 49  1572864 ]; type = "standard"; }; };
          51 = { enabled = true; value = { parameters = [ 39 50 1572864 ]; type = "standard"; }; };
          52 = { enabled = true; value = { parameters = [ 100 2 1572864 ]; type = "standard"; }; };
          98 = { enabled = true; value = { parameters = [ 47 44 1179648 ]; type = "standard"; }; };
          15 = { enabled = false; };
          16 = { enabled = false; };
          17 = { enabled = false; };
          18 = { enabled = false; };
          19 = { enabled = false; value = { parameters = [ 45 27 1572864 ]; type = "standard"; }; };
          20 = { enabled = false; };
          21 = { enabled = false; value = { parameters = [ 56 28 1835008 ]; type = "standard"; }; };
          22 = { enabled = false; };
          23 = { enabled = false; value = { parameters = [ 92 42 1572864 ]; type = "standard"; }; };
          24 = { enabled = false; };
          25 = { enabled = false; value = { parameters = [ 46 47 1835008 ]; type = "standard"; }; };
          26 = { enabled = false; value = { parameters = [ 44 43 1835008 ]; type = "standard"; }; };
          27 = { enabled = true;  value = { parameters = [ 96 50 1048576 ]; type = "standard"; }; };
          28 = { enabled = false; value = { parameters = [ 51 20 1179648 ]; type = "standard"; }; };
          29 = { enabled = false; value = { parameters = [ 51 20 1441792 ]; type = "standard"; }; };
          30 = { enabled = false; value = { parameters = [ 52 21 1179648 ]; type = "standard"; }; };
          31 = { enabled = false; value = { parameters = [ 52 21 1441792 ]; type = "standard"; }; };
          160 = { enabled = false; };
          162 = { enabled = true;  value = { parameters = [ 65535 96 9961472 ]; type = "standard"; }; };
          163 = { enabled = false; };
          164 = { enabled = false; };
          175 = { enabled = true;  value = { parameters = [ 65535 65535 0 ]; type = "standard"; }; };
          176 = { enabled = true;  value = { parameters = [ 92 42 1835008 ]; type = "standard"; }; };
          179 = { enabled = false; };
          181 = { enabled = false; value = { parameters = [ 54 22 1179648 ]; type = "standard"; }; };
          182 = { enabled = false; value = { parameters = [ 54 22 1441792 ]; type = "standard"; }; };
          184 = { enabled = false; value = { parameters = [ 53 23 1179648 ]; type = "standard"; }; };
        };
      };

      "com.apple.finder" = {
        ShowPreviewPane = true;
        ShowSidebar = true;
      };

      "com.apple.loginwindow" = {
        MiniBuddyLaunch = 1;
        TALLogoutSavesState = 1;
      };

      "com.apple.NSUserDictionaryReplacementItems" = [
        {
          on = 1;
          replace = "omw";
          with = "On my way!";
        }
      ];

    };
  };

  system.activationScripts = {

    dock = {
      deps = [ ];
      text = ''
        echo "dotfiles: setting dock persistent apps & hot corners..." >&2

        ${pkgs.dockutil}/bin/dockutil --no-restart \
          --add '/Applications/Zen.app' \
          --add '/Applications/Ghostty.app' \
          --add '/Applications/Zed.app' \
          --add '/Applications/Obsidian.app' \
          --add '/Applications/Visual Studio Code.app' \
          --add '/Applications/Discord.app' \
          --add '/System/Applications/Music.app' \
          --add '/System/Applications/System Settings.app' \
          --add '~/Downloads' --view grid --display folder \
          2>/dev/null || true

        defaults write com.apple.dock wvous-tl-corner   -int 13
        defaults write com.apple.dock wvous-tl-modifier -int 1048576
        defaults write com.apple.dock wvous-tr-corner   -int 5
        defaults write com.apple.dock wvous-tr-modifier -int 1048576
        defaults write com.apple.dock wvous-bl-corner   -int 4
        defaults write com.apple.dock wvous-bl-modifier -int 1048576
        defaults write com.apple.dock wvous-br-corner   -int 14
        defaults write com.apple.dock wvous-br-modifier -int 1048576

        killall Dock || true
      '';
    };

    finder = {
      deps = [ ];
      text = ''
        echo "dotfiles: setting finder view options..." >&2

        defaults write com.apple.finder StandardViewSettings -dict-add \
          IconViewSettings '{ showItemInfo = 1; }'

        killall Finder || true
      '';
    };

    spotlight = {
      deps = [ ];
      text = ''
        echo "dotfiles: enabling clipboard history..." >&2
        defaults write com.apple.Spotlight PasteboardHistoryTimeout -int 0
        defaults write com.apple.Spotlight PasteboardHistoryVersion -int 2

        killall Spotlight 2>/dev/null || true
      '';
    };

  };
}

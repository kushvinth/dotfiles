{
  ...
}:
{
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = false;
    brews = [
      "mas"
    ];
    casks = [ ];
    masApps = {
      BatteryHealth2 = 1120214373;
    };
  };
}

{ ... }:
{
  imports = [
    ./darwin.nix
  ];

  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    defaults = {
      trackpad = {
        Clicking = true; # Whether to enable trackpad tap to click
        Dragging = true; # Whether to enable tap-to-drag

        # Whether to enable trackpad right click
        TrackpadRightClick = true; 

        # Whether to enable three finger drag
        TrackpadThreeFingerDrag = true; 

        # 0 to disable three finger tap, 2 to trigger Look up & data detectors
        TrackpadThreeFingerTapGesture = 0; 
      };
    };
  };
}

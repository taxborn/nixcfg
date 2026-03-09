{
  stdenv,
  src,
  libinput,
  libxkbcommon,
  pixman,
  pkg-config,
  wayland,
  wayland-protocols,
  wayland-scanner,
  wlroots,
  xwayland,
}:
stdenv.mkDerivation {
  pname = "dwl";
  version = "unstable";
  inherit src;

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
  ];

  buildInputs = [
    libinput
    libxkbcommon
    pixman
    wayland
    wayland-protocols
    wlroots
    xwayland
  ];

  makeFlags = [ "PREFIX=$(out)" ];

  meta = {
    description = "dwl - dwm for Wayland (custom fork)";
    mainProgram = "dwl";
  };
}

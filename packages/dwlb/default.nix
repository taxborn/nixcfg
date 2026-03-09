{
  stdenv,
  fetchFromGitHub,
  fcft,
  pixman,
  wayland,
  wayland-protocols,
  wayland-scanner,
  pkg-config,
}:
stdenv.mkDerivation rec {
  pname = "dwlb";
  version = "unstable-2025-01-01";

  src = fetchFromGitHub {
    owner = "kolunmi";
    repo = "dwlb";
    rev = "48dbe00bdb98a1ae6a0e60558ce14503616aa759";
    hash = "sha256-S0jkoELkF+oEmXqiWZ8KJYtWAHEXR/Y93jl5yHgUuSM=";
  };

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
  ];

  buildInputs = [
    fcft
    pixman
    wayland
    wayland-protocols
  ];

  makeFlags = [ "PREFIX=$(out)" ];

  meta = {
    description = "A status bar for dwl";
    homepage = "https://github.com/kolunmi/dwlb";
    mainProgram = "dwlb";
  };
}

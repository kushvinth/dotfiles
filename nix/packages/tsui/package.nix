{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "tsui";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "neuralink";
    repo = "tsui";
    rev = "v${version}";
    hash = "sha256-DVkiZc+7XNgj47T1uZg6bnfoMw+0dP4+72AxfCYKcL4=";
  };

  vendorHash = "sha256-FIbkPE5KQ4w7Tc7kISQ7ZYFZAoMNGiVlFWzt8BPCf+A=";

  ldflags = [ "-X main.Version=${version}" ];

  meta = with lib; {
    description = "An elegant TUI for configuring Tailscale";
    homepage = "https://neuralink.com/tsui";
    license = licenses.mit;
    platforms = platforms.darwin;
    mainProgram = "tsui";
  };
}

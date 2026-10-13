# gnhf (github.com/kunchenguid/gnhf), the agent runner behind the gnhf-rounds
# skill. npm-only, not in nixpkgs: the published tarball is a single bundled
# dist/cli.mjs plus two runtime deps, so this lays out node_modules by hand
# instead of buildNpmPackage (which needs a lockfile the package doesn't ship).
# Bump: new version + hashes (`nix store prefetch-file <tgz url>`).
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
}:
let
  npm = name: version: hash: {
    inherit name;
    src = fetchurl {
      url = "https://registry.npmjs.org/${name}/-/${name}-${version}.tgz";
      inherit hash;
    };
  };
  deps = [
    (npm "commander" "14.0.3" "sha256-WElwPFAODzJOsBNA2L2h+exI/De7e+lxLrDdUqrZL2w=")
    (npm "js-yaml" "4.3.2" "sha256-x7JB0iJM+SU/9ThUqkzuh9qRvYicTQ+jo//RBB7O5bE=")
    (npm "argparse" "2.0.1" "sha256-J5A4R/yCFeb8WjPoFJD3urpmQD+KreM3cbmIzKCXcow=")
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gnhf";
  version = "0.1.51";
  src = fetchurl {
    url = "https://registry.npmjs.org/gnhf/-/gnhf-${finalAttrs.version}.tgz";
    hash = "sha256-8rrtCWz0npY+V4tsd37SESPlIfElAN69lCIend0Yoew=";
  };
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall
    lib=$out/lib/node_modules/gnhf
    mkdir -p $lib/node_modules
    cp -r . $lib
    ${lib.concatMapStrings (d: ''
      mkdir -p $lib/node_modules/${d.name}
      tar -xzf ${d.src} -C $lib/node_modules/${d.name} --strip-components=1
    '') deps}
    makeWrapper ${lib.getExe nodejs} $out/bin/gnhf --add-flags $lib/dist/cli.mjs
    runHook postInstall
  '';
  meta = {
    description = "Run a coding agent in committed iterations";
    homepage = "https://github.com/kunchenguid/gnhf";
    license = lib.licenses.mit;
    mainProgram = "gnhf";
  };
})

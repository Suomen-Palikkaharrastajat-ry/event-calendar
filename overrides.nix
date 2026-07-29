# Repo-local Haskell package overrides, applied on top of ghc96 in devenv.nix.
#
# `pkgs` is passed in so overrides can reach the `pkgs.haskell.lib` helpers
# (dontCheck, doJailbreak, callHackageDirect, …).
#
# statics-common is the shared package from master-builder; it is built straight
# from the pinned submodule rather than from Hackage. qrcode-core and
# qrcode-juicypixels are not in nixpkgs' ghc96 set, so they are pinned here.
{ pkgs }:
hself: hsuper: {
  statics-common =
    hself.callCabal2nix "statics-common"
      ./vendor/master-builder/packages-hs/statics-common
      { };

  qrcode-core = hsuper.callPackage (
    {
      mkDerivation,
      base,
      binary,
      bytestring,
      case-insensitive,
      containers,
      dlist,
      primitive,
      text,
      vector,
    }:
    mkDerivation {
      pname = "qrcode-core";
      version = "0.9.11";
      sha256 = "sha256-bYbshOLd8XarNGzIbopFLmc/3KAdYkHDH++l0cm2iaI=";
      libraryHaskellDepends = [
        base
        binary
        bytestring
        case-insensitive
        containers
        dlist
        primitive
        text
        vector
      ];
    }
  ) { };
  qrcode-juicypixels = hsuper.callPackage (
    {
      mkDerivation,
      base,
      base64-bytestring,
      bytestring,
      JuicyPixels,
      qrcode-core,
      text,
      vector,
    }:
    mkDerivation {
      pname = "qrcode-juicypixels";
      version = "0.8.7";
      sha256 = "sha256-4tZ8n18LK790VNUMkbSNDu4Jh7lc/2PvqVhQh1BIb/M=";
      libraryHaskellDepends = [
        base
        base64-bytestring
        bytestring
        JuicyPixels
        qrcode-core
        text
        vector
      ];
    }
  ) { };
}

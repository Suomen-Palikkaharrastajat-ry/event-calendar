self: super: {
  qrcode-core = super.callPackage (
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
  qrcode-juicypixels = super.callPackage (
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

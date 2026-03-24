# Downgrade PocketBase to match production (0.31.0).
# Override is needed because nixpkgs/master tracks the latest release.
# Hashes sourced from nixpkgs commit 594420d4 (pocketbase: 0.30.4 -> 0.31.0).
final: prev: {
  pocketbase = prev.pocketbase.overrideAttrs (
    finalAttrs: old: {
      version = "0.31.0";
      src = final.fetchFromGitHub {
        owner = "pocketbase";
        repo = "pocketbase";
        rev = "v${finalAttrs.version}";
        hash = "sha256-YCYihhPq24JdJKAU8zr4h4z131zj4BN3Qh/y5tHmyRs=";
      };
      vendorHash = "sha256-wsPJIlsq4Q26cce69a0oqEalfDrNIMVFt8ufdj+WId4=";
    }
  );
}

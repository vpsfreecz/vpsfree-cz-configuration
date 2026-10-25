self: super:
let
  version = super.brotli.version;
  decoderFix = super.fetchurl {
    url = "https://github.com/google/brotli/commit/0ed4268a4401abcb4472096340477cf4af7d1a2b.patch?full_index=1";
    hash = "sha256-1vliUJAAIj3vcGKVgim9CEV+XgMuftDR2U+3kLBUsfw=";
  };
in
{
  # Backport the complete decoder correction without changing the 1.2.0 ABI.
  # https://www.cve.org/CVERecord?id=CVE-2026-111497
  # Remove this overlay when all selected inputs provide CVE-2026-111497's fix
  # and their Node recipes compose with the corrected common Brotli package.
  brotli =
    if super.lib.versionAtLeast version "1.2.1" then
      super.brotli
    else if version == "1.2.0" then
      super.brotli.overrideAttrs (oldAttrs: {
        # Node 22/26 already append this fix to patches. Run after those patches
        # and preserve existing hooks, accepting only the complete applied fix.
        postPatch =
          (oldAttrs.postPatch or "")
          + "\n"
          + ''
            if patch --force --reverse --dry-run --fuzz=0 -p1 < ${decoderFix}; then
              echo "Brotli CVE-2026-111497 fix is already applied"
            elif patch --force --dry-run --fuzz=0 -p1 < ${decoderFix}; then
              patch --force --fuzz=0 -p1 < ${decoderFix} || exit 1
              patch --force --reverse --dry-run --fuzz=0 -p1 < ${decoderFix} || exit 1
            else
              echo "Cannot apply or verify the complete Brotli CVE-2026-111497 fix" >&2
              exit 1
            fi
          '';
      })
    else
      throw "Brotli CVE-2026-111497 overlay does not support version ${version}";
}

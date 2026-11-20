#!/usr/bin/env bash
# Fetch the patched Noctalia RPM (lock-screen on-screen keyboard) released by
# shad0wcrawl3r/noctalia-osk into <dir>, verified by checksum and by GitHub's
# build-provenance attestation (built by that repo's release workflow).
#
#   fetch-noctalia.sh <dir>        needs: gh (authenticated, or GH_TOKEN), podman
#
# Picks the newest release for Fedora's current noctalia version. If there is
# none yet (Fedora updated since the last release), it falls back to the newest
# release and warns. If that release says Fedora already has the feature, <dir>
# stays empty and the image installs Fedora's package.
set -euo pipefail

REPO=shad0wcrawl3r/noctalia-osk
WORKFLOW="$REPO/.github/workflows/release.yml"
dest="$1"
mkdir -p "$dest"

evr="$(podman run --rm registry.fedoraproject.org/fedora:45 \
  dnf5 -q repoquery --latest-limit=1 --queryformat '%{evr}\n' noctalia | tail -1)"
test -n "$evr"
echo "Fedora noctalia: $evr"

tags="$(gh release list -R "$REPO" --exclude-drafts --limit 200 --json tagName -q '.[].tagName')"
tag="$(awk -v p="${evr}-r" 'index($0, p) == 1' <<< "$tags" | sort -V | tail -1)"
if [[ -z "$tag" ]]; then
  tag="$(gh release view -R "$REPO" --json tagName -q .tagName)"
  echo "::warning title=Noctalia release::no $REPO release for Fedora noctalia $evr yet; using $tag"
fi
echo "Using $REPO release $tag"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
gh release download "$tag" -R "$REPO" -D "$work"
(cd "$work" && sha256sum -c SHA256SUMS)

if [[ -e "$work/upstream-has-feature.txt" ]]; then
  cat "$work/upstream-has-feature.txt"
  exit 0
fi
shopt -s nullglob
rpms=("$work"/noctalia-*.rpm)
(( ${#rpms[@]} > 0 )) || { echo "::error::release $tag has no RPM"; exit 1; }
for rpm in "${rpms[@]}"; do
  gh attestation verify "$rpm" -R "$REPO" --signer-workflow "$WORKFLOW" >/dev/null
  echo "attestation ok: $(basename "$rpm")"
  cp "$rpm" "$dest/"
done
ls -l "$dest"

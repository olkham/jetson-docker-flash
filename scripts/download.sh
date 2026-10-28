#!/usr/bin/env bash
# Download a board's Jetson Linux BSP and sample rootfs into downloads/. Runs on the host.
set -Eeuo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
source scripts/lib.sh
load_board "${1:-}" "$PWD"
command -v curl >/dev/null || { echo 'curl is required: sudo apt install curl' >&2; exit 1; }
if command -v lbzip2 >/dev/null; then bz=lbzip2
elif command -v bzip2 >/dev/null; then bz=bzip2
else echo 'bzip2 is required to verify downloads: sudo apt install bzip2' >&2; exit 1
fi
# NVIDIA publishes no checksums for these files, so check the size the server
# reports and the bzip2 integrity of the result.
remote_size() {
  curl -sfIL --max-time 60 "$1" | tr -d '\r' | awk 'tolower($1) == "content-length:" { n = $2 } END { print n + 0 }'
}
mkdir -p downloads
echo "Jetson Linux $L4T_VERSION (JetPack $JETPACK) for $DESCRIPTION"
for url in "$BSP_URL" "$ROOTFS_URL"; do
  name=${url##*/}
  dest=downloads/$name
  size=$(remote_size "$url")
  (( size > 0 )) || { echo "Could not get the size of $url from NVIDIA." >&2; exit 1; }
  if [[ -f $dest ]] && (( $(stat -c %s "$dest") == size )); then
    echo "Already downloaded: $dest"
    continue
  fi
  # Partial downloads stay as .part so prepare never picks them up; re-running resumes them.
  if [[ ! -f $dest.part ]] || (( $(stat -c %s "$dest.part") < size )); then
    echo "Downloading $name ($(( size / 1024 / 1024 )) MiB)"
    curl -fL --retry 5 --retry-delay 5 -C - -o "$dest.part" "$url"
  fi
  actual=$(stat -c %s "$dest.part")
  if (( actual != size )); then
    echo "Size mismatch for $name: got $actual bytes, expected $size. Delete $dest.part and retry." >&2
    exit 1
  fi
  echo "Verifying archive integrity: $name"
  "$bz" -t "$dest.part" || { echo "Corrupt download: delete $dest.part and retry." >&2; exit 1; }
  mv "$dest.part" "$dest"
done
echo "Downloads complete. Next: ./jetson-flash.sh prepare ${1}"

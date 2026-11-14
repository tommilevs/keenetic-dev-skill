#!/usr/bin/env bash
# Self-test for keenetic-dev: scaffold → build → ipk → feed, then inspect the package.
# Usage: tests/selftest.sh [workdir]
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$SKILL_DIR/bin/keenetic-dev"
WORK="${1:-/mnt/c/workspace/dsh/tmp/kd-selftest}"
APP="kd-demo"
MODULE="github.com/tommilevs/kd-demo"

echo "== workspace: $WORK"
rm -rf "$WORK"
mkdir -p "$WORK"

echo "== init"
"$BIN" init "$WORK/app" --module "$MODULE" --name "$APP" --port 8099

echo "== build"
"$BIN" build --project "$WORK/app" --version 0.1.0 --all

echo "== ipk"
"$BIN" ipk --bin "$WORK/app/dist/${APP}_linux_arm64" --arch aarch64-3.10 --version 0.1.0 --project "$WORK/app"
"$BIN" ipk --bin "$WORK/app/dist/${APP}_linux_arm"    --arch armv7-3.2  --version 0.1.0 --project "$WORK/app"

echo "== feed"
"$BIN" feed --dir "$WORK/app/dist"

IPK="$WORK/app/dist/${APP}_0.1.0_aarch64-3.10.ipk"
echo "== package layout ($IPK)"
tar -tzf "$IPK" | sort | sed 's/^/   /'

echo "== control file"
rm -rf "$WORK/x"; mkdir -p "$WORK/x"
tar -xzf "$IPK" -C "$WORK/x"
tar -xzf "$WORK/x/control.tar.gz" -C "$WORK/x"
sed 's/^/   /' "$WORK/x/control"

echo "== data tree"
tar -tzf "$WORK/x/data.tar.gz" | sort | sed 's/^/   /'

echo "== Packages index"
head -14 "$WORK/app/dist/Packages" | sed 's/^/   /'

echo "== assertions"
fail=0
assert() { if eval "$2"; then echo "   ok   $1"; else echo "   FAIL $1"; fail=$((fail+1)); fi; }
assert "ipk is gzip tar with debian-binary" "tar -tzf '$IPK' | grep -qx ./debian-binary"
assert "control.tar.gz present" "tar -tzf '$IPK' | grep -qx ./control.tar.gz"
assert "data.tar.gz present" "tar -tzf '$IPK' | grep -qx ./data.tar.gz"
assert "binary installed to /opt/bin" "tar -tzf '$WORK/x/data.tar.gz' | grep -q 'opt/bin/$APP'"
assert "init script shipped" "tar -tzf '$WORK/x/data.tar.gz' | grep -q 'opt/etc/init.d/S99$APP'"
assert "arch string correct" "grep -q '^Architecture: aarch64-3.10' '$WORK/x/control'"
assert "Packages has blank line between stanzas" "python3 -c 'import sys;d=open(sys.argv[1]).read();sys.exit(0 if \"\n\nPackage:\" in d else 1)' '$WORK/app/dist/Packages'"
assert "Packages.gz exists" "test -s '$WORK/app/dist/Packages.gz'"
assert "version injected into binary" "grep -aq '0.1.0' '$WORK/app/dist/${APP}_linux_arm64'"

[ "$fail" -eq 0 ] && echo "== SELFTEST PASSED" || { echo "== SELFTEST FAILED ($fail)"; exit 1; }

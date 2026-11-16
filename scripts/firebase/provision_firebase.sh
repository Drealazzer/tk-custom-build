#!/bin/sh
# Provision the gitignored Firebase config (Keeper/Resources/Firebase) into the
# current working tree. Idempotent: returns immediately if already present.
#
# Why this exists: the Firebase config dir is gitignored, so a fresh `git worktree`
# never gets it.
set -eu

TOPLEVEL="$(git rev-parse --show-toplevel)"
if [ -d "$TOPLEVEL/ios" ]; then
  cd "$TOPLEVEL/ios"
else
  cd "$TOPLEVEL"
fi
DEST="Keeper/Resources/Firebase"
MARKER="Keeper/GoogleService-Info.plist"

# Already provisioned — nothing to do (this is the hot path on every build).
[ -f "$DEST/$MARKER" ] && exit 0

# Prefer the main working tree's copy: no network, no SSH. --git-common-dir points
# at the shared `.git`; its parent is the main working tree root.
COMMON_GIT_DIR="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
MAIN_ROOT="$(dirname "$COMMON_GIT_DIR")/ios"
if [ "$MAIN_ROOT" != "$PWD" ]; then
  SRC="$MAIN_ROOT/$DEST"
  if [ -f "$SRC/$MARKER" ]; then
    echo "Provisioning Firebase config from main working tree: $SRC"
    rm -rf "$DEST"
    cp -R "$SRC" "$DEST"
    exit 0
  fi
  # A main tree still on the pre-rename layout keeps the config under
  # Tonkeeper/Resources/Firebase with Tonkeeper* subfolders; copy it and rename.
  LEGACY_SRC="$MAIN_ROOT/Tonkeeper/Resources/Firebase"
  if [ -f "$LEGACY_SRC/Tonkeeper/GoogleService-Info.plist" ]; then
    echo "Provisioning Firebase config from main working tree (legacy layout): $LEGACY_SRC"
    rm -rf "$DEST"
    cp -R "$LEGACY_SRC" "$DEST"
    for legacy in "$DEST"/Tonkeeper*; do
      [ -d "$legacy" ] || continue
      mv "$legacy" "$DEST/Keeper${legacy##*/Tonkeeper}"
    done
    exit 0
  fi
fi

# FIREBASE_LOCAL_ONLY is for callers that must not touch the network: the
# post-checkout hook provisions in the background, where an SSH clone could prompt or
# hang unseen. `make compile` runs this again in the foreground and clones there.
[ -z "${FIREBASE_LOCAL_ONLY:-}" ] || exit 0

# Fallback: create mock stub if absent
echo "Creating mock GoogleService-Info.plist stubs..."
mkdir -p "$DEST/Keeper" "$DEST/KeeperDev" "$DEST/KeeperUK"
for target in Keeper KeeperDev KeeperUK; do
  PLIST_FILE="$DEST/$target/GoogleService-Info.plist"
  if [ ! -f "$PLIST_FILE" ]; then
    cat << 'EOF' > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q</string>
	<key>GCM_SENDER_ID</key>
	<string>123456789012</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>PROJECT_ID</key>
	<string>tonkeeper-mock</string>
	<key>STORAGE_BUCKET</key>
	<string>tonkeeper-mock.appspot.com</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<false/>
	<key>GOOGLE_APP_ID</key>
	<string>1:123456789012:ios:abcdef1234567890abcdef</string>
</dict>
</plist>
EOF
  fi
done
exit 0

#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PROJECT="$ROOT_DIR/ios/TagNote/TagNote.xcodeproj"
SCHEME="TagNote"
MODE="${1:-unit}"

case "$MODE" in
  unit)
    ONLY_TESTING="TagNoteTests"
    ;;
  e2e|ui)
    ONLY_TESTING="TagNoteUITests"
    ;;
  all)
    ONLY_TESTING=""
    ;;
  *)
    echo "usage: $0 [unit|e2e|all]" >&2
    exit 64
    ;;
esac

pick_destination() {
  if [[ -n "${IOS_TEST_DESTINATION:-}" ]]; then
    echo "$IOS_TEST_DESTINATION"
    return 0
  fi

  local devices
  if ! devices="$(xcrun simctl list devices available 2>/tmp/tagnote-simctl.err)"; then
    echo "CoreSimulator is not available in this session." >&2
    cat /tmp/tagnote-simctl.err >&2 || true
    echo >&2
    echo "Open Xcode once, install an iOS Simulator runtime, or run this from a GUI macOS session." >&2
    exit 69
  fi

  local name
  name="$(printf '%s\n' "$devices" | awk '
    /^[[:space:]]+iPhone/ {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+\([0-9A-Fa-f-]+\).*/, "", line)
      print line
      exit
    }
  ')"

  if [[ -z "$name" ]]; then
    echo "No available iPhone simulator devices were found." >&2
    echo "Installed Xcode destinations:" >&2
    xcodebuild -showdestinations -project "$PROJECT" -scheme "$SCHEME" >&2 || true
    echo >&2
    echo "Create one in Xcode: Window > Devices and Simulators > Simulators." >&2
    exit 70
  fi

  echo "platform=iOS Simulator,name=$name"
}

DESTINATION="$(pick_destination)"
echo "Using destination: $DESTINATION"

cmd=(
  xcodebuild test
  -project "$PROJECT"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
)

if [[ -n "$ONLY_TESTING" ]]; then
  cmd+=("-only-testing:$ONLY_TESTING")
fi

"${cmd[@]}"

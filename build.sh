#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

ACTION="${1:-run}"
case "$ACTION" in test|build|run|ui-test|check|ios|archive|clean) ;; *) echo "Usage: ./build.sh [test|build|run|ui-test|check|ios|archive|clean]"; exit 2 ;; esac

caffeinate -di &
AWAKE_PID=$!
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/eagle-force-build.XXXXXX")"
cleanup() { rm -rf "$SCRATCH"; kill "$AWAKE_PID" 2>/dev/null || true; }
trap cleanup EXIT
trap 'exit 130' INT TERM

if command -v go >/dev/null 2>&1; then go clean -cache; fi
# Build caches stay outside the checkout and are removed by the exit trap.
if [ -d .artifacts ]; then rm -rf .artifacts; fi
if [ "$ACTION" = clean ]; then rm -rf build .build; exit 0; fi
mkdir -p build

if [ "$ACTION" = test ] || [ "$ACTION" = check ]; then
    swift test --scratch-path "$SCRATCH/core" 2>&1 | tee build/core-tests.log
    if [ "$ACTION" = test ]; then exit 0; fi
fi

ICON_DIR="Resources/Assets.xcassets/AppIcon.appiconset"
if [ ! -f "$ICON_DIR/icon.png" ]; then
    sips -z 1024 1024 Resources/Artwork/icon-source.png --out "$ICON_DIR/icon.png" >/dev/null
fi
PROJECT_ARGS=(-project EagleForce.xcodeproj -scheme EagleForce -derivedDataPath "$SCRATCH/DerivedData")

if [ "$ACTION" = archive ]; then
    : "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple Developer team ID before archiving}"
    xcodebuild "${PROJECT_ARGS[@]}" -configuration Release -destination 'generic/platform=iOS' \
        -archivePath "$PWD/build/EagleForce.xcarchive" "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM" archive 2>&1 | tee build/archive.log
    exit 0
fi

if [ "$ACTION" = ios ]; then
    xcodebuild "${PROJECT_ARGS[@]}" -configuration Release -destination 'generic/platform=iOS' \
        CODE_SIGNING_ALLOWED=NO build 2>&1 | tee build/ios-build.log
    ditto "$SCRATCH/DerivedData/Build/Products/Release-iphoneos/EagleForce.app" build/EagleForce-unsigned.app
    exit 0
fi

if [ -z "${SIMULATOR_UDID:-}" ]; then
    SIMULATOR_UDID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; print(next((d["udid"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["name"]=="EagleForce-QA"), ""))')"
    if [ -z "$SIMULATOR_UDID" ]; then
        RUNTIME="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; print(next(r["identifier"] for r in reversed(json.load(sys.stdin)["runtimes"]) if r["isAvailable"] and r["name"].startswith("iOS")))')"
        DEVICE_TYPE="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=next(r for r in json.load(sys.stdin)["runtimes"] if r["identifier"]==sys.argv[1]); print(next(d["identifier"] for d in r["supportedDeviceTypes"] if d["productFamily"]=="iPhone" and "Max" not in d["name"]))' "$RUNTIME")"
        SIMULATOR_UDID="$(xcrun simctl create EagleForce-QA "$DEVICE_TYPE" "$RUNTIME")"
    fi
fi
echo "$SIMULATOR_UDID" > build/simulator-udid.txt
BOOT_STATE="$(xcrun simctl list devices -j | python3 -c 'import json,sys; uid=sys.argv[1]; print(next(d["state"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["udid"]==uid))' "$SIMULATOR_UDID")"
if [ "$BOOT_STATE" != Booted ]; then xcrun simctl boot "$SIMULATOR_UDID"; fi
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

if [ "$ACTION" = ui-test ] || [ "$ACTION" = check ]; then
    TEST_ARGS=()
    if [ -n "${UI_TEST_FILTER:-}" ]; then
        IFS=',' read -r -a FILTERS <<< "$UI_TEST_FILTER"
        for FILTER in "${FILTERS[@]}"; do TEST_ARGS+=("-only-testing:$FILTER"); done
    fi
    RESULT_PATH="$PWD/build/UI-$(date +%Y%m%d-%H%M%S).xcresult"
    xcodebuild "${PROJECT_ARGS[@]}" -configuration Debug -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
        -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath "$RESULT_PATH" CODE_SIGNING_ALLOWED=NO ${TEST_ARGS[@]+"${TEST_ARGS[@]}"} test 2>&1 | tee build/ui-tests.log
    if ! /usr/bin/grep -Eq 'Executed [1-9][0-9]* tests?' build/ui-tests.log; then
        echo "No UI tests executed. UI_TEST_FILTER entries must be Target/Class/testMethod (comma-separated)." >&2
        exit 1
    fi
    echo "$RESULT_PATH" > build/latest-ui-result.txt
else
    xcodebuild "${PROJECT_ARGS[@]}" -configuration Debug -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
        CODE_SIGNING_ALLOWED=NO build 2>&1 | tee build/simulator-build.log
fi

ditto "$SCRATCH/DerivedData/Build/Products/Debug-iphonesimulator/EagleForce.app" build/EagleForce.app
if [ "$ACTION" != build ]; then
    # Installing over the same bundle preserves its existing Application Support save.
    xcrun simctl terminate "$SIMULATOR_UDID" com.kevin.eagleforce 2>/dev/null || true
    xcrun simctl install "$SIMULATOR_UDID" build/EagleForce.app
    xcrun simctl launch "$SIMULATOR_UDID" com.kevin.eagleforce
    DEVELOPER_DIR_PATH="$(xcode-select -p)"
    if [ -d "$DEVELOPER_DIR_PATH/../Applications/DeviceHub.app" ]; then
        open -a "$DEVELOPER_DIR_PATH/../Applications/DeviceHub.app"
    elif [ -d "$DEVELOPER_DIR_PATH/Applications/Simulator.app" ]; then
        open -a "$DEVELOPER_DIR_PATH/Applications/Simulator.app" --args -CurrentDeviceUDID "$SIMULATOR_UDID"
    else
        echo "App is running in CoreSimulator. Open your Xcode device viewer and select EagleForce-QA."
    fi
fi
echo "Done: $ACTION (simulator $SIMULATOR_UDID). Temporary build caches removed on exit."

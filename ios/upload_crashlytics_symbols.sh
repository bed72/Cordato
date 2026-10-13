set -eu

if [ "$CONFIGURATION" != "Release" ] || [ "$PLATFORM_NAME" != "iphoneos" ]; then
  exit 0
fi

export PATH="$PATH:$FLUTTER_ROOT/bin:${PUB_CACHE:-$HOME/.pub-cache}/bin"

upload_script="$BUILD_DIR/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"

if [ ! -f "$upload_script" ]; then
  derived_data_path="${BUILD_ROOT%%/Build/*}"
  upload_script="$derived_data_path/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
fi

if [ ! -f "$upload_script" ]; then
  printf '%s\n' 'Firebase Crashlytics upload script not found in Swift Package Manager checkouts.' >&2
  exit 1
fi

flutterfire upload-crashlytics-symbols \
  --upload-symbols-script-path="$upload_script" \
  --platform=ios \
  --apple-project-path="$SRCROOT" \
  --env-platform-name="$PLATFORM_NAME" \
  --env-configuration="$CONFIGURATION" \
  --env-project-dir="$PROJECT_DIR" \
  --env-built-products-dir="$BUILT_PRODUCTS_DIR" \
  --env-dwarf-dsym-folder-path="$DWARF_DSYM_FOLDER_PATH" \
  --env-dwarf-dsym-file-name="$DWARF_DSYM_FILE_NAME" \
  --env-infoplist-path="$INFOPLIST_PATH" \
  --default-config=default

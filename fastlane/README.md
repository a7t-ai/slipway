fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios bump_version

```sh
[bundle exec] fastlane ios bump_version
```

Bump version based on calendar or increment build number

### ios test_suite

```sh
[bundle exec] fastlane ios test_suite
```

Run unit tests with optional test plan

### ios ci_test

```sh
[bundle exec] fastlane ios ci_test
```

Run tests optimized for CI

### ios deliver_to_testflight

```sh
[bundle exec] fastlane ios deliver_to_testflight
```

Build and deliver to TestFlight

### ios assign_build_to_group

```sh
[bundle exec] fastlane ios assign_build_to_group
```

Assign an existing TestFlight build to a beta group

### ios validate_delivery

```sh
[bundle exec] fastlane ios validate_delivery
```

Validate build configuration without uploading

### ios create_app_store_version

```sh
[bundle exec] fastlane ios create_app_store_version
```

Create or update App Store version entry without uploading binary

### ios write_app_store_release_notes

```sh
[bundle exec] fastlane ios write_app_store_release_notes
```

Write release notes to App Store Connect for all supported locales

### ios upload_app_store_metadata

```sh
[bundle exec] fastlane ios upload_app_store_metadata
```

Upload App Store metadata from fastlane/metadata (all locales) for a version

### ios add_build_to_release

```sh
[bundle exec] fastlane ios add_build_to_release
```

Add build to App Store release and optionally submit for review

### ios validate_app_store_version_for_release

```sh
[bundle exec] fastlane ios validate_app_store_version_for_release
```

Validate that App Store version is ready for release

### ios release_app_to_store

```sh
[bundle exec] fastlane ios release_app_to_store
```

Release app version to App Store with phased release and scheduling options

### ios find_version_ready_for_release

```sh
[bundle exec] fastlane ios find_version_ready_for_release
```

Find version that is ready for release (in PENDING_DEVELOPER_RELEASE state)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture + frame + generate uploadable App Store screenshots for every locale

### ios screenshots_capture_only

```sh
[bundle exec] fastlane ios screenshots_capture_only
```

Capture only, skip framing and marketing render

### ios screenshots_frame

```sh
[bundle exec] fastlane ios screenshots_frame
```

Frame existing captures with frameit

### ios screenshots_render

```sh
[bundle exec] fastlane ios screenshots_render
```

Re-render marketing slides from existing framed captures

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload uploadable screenshots to App Store Connect

### ios verify_setup

```sh
[bundle exec] fastlane ios verify_setup
```

Verify Fastlane setup and configuration

### ios regenerate_match_profiles

```sh
[bundle exec] fastlane ios regenerate_match_profiles
```

Regenerate match provisioning profiles

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

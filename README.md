<div align="center">

<img src="assets/hero.png" alt="Slipway hero" width="720" />

# Slipway

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**A self-publishing toolkit for iOS apps. A weekly release train, on rails.**

</div>

Slipway turns a clean Xcode project into one that ships on a weekly cadence with almost no human touch. Three orchestrator workflows drive the train. Everything else (version bumps, App Store metadata uploads, TestFlight delivery, screenshot generation, signing cert refresh) is a step they call. Configure once via GitHub Actions variables and secrets, no find and replace.

## The weekly release train

Three crons. One cycle.

### Tuesday 03:00 UTC, `trigger-new-version-process.yml`

The big one. Submits a brand new version for App Store review in a single chain:

1. **Bump version** for the new release.
2. **Create the App Store Connect version entry** (so Apple knows a new version is coming).
3. **Write release notes** from the `CHANGES_IN_VERSION.md` bullets, with a copywriting persona (optional, can be skipped to keep manual notes).
4. **Upload App Store metadata** (descriptions, keywords, beta contact info) from `fastlane/metadata/`.
5. **Deliver to TestFlight** (build, sign with Match, notarize, upload).
6. **Add the build to the App Store release entry** and **submit for review**.
7. **Clear release notes** for the next cycle.
8. **Notify** on Slack with a per-step status table.

Seven downstream workflows fan in from one orchestrator. By breakfast on Tuesday, the version that was merged through the prior week is sitting in Apple's review queue.

### Tuesday 04:00 UTC, `kick-off-next-weeks-release.yml`

One hour after the submission, Slipway opens the next cycle:

1. **Get the current marketing version** from `vars.XCCONFIG_PATH`.
2. **Create an annotated git tag** for the version that just got submitted (force-push allowed, so reruns are safe).
3. **Bump the version** for next week's work (calls `bump-version.yml`).
4. **Notify** on Slack.

This is what frees `main` for the new week's commits without polluting the just-submitted version's history.

### Friday 12:00 UTC, `release-this-weeks-version.yml`

By Friday, Apple has approved the build that was submitted on Tuesday. This workflow flips it live with a phased release:

1. **Determine the version that is "Ready for Sale"** via the App Store Connect API.
2. **Release the app** (calls `release-app.yml` to do the actual phased-release activation).
3. **Notify** on Slack.

Phased release means Apple rolls the update out to a small percentage of users on day one and ramps to 100% over a week, so a bad release can be paused before it reaches everyone.

### The rhythm

```
Mon          Tue 03:00 UTC                  Tue 04:00 UTC          Fri 12:00 UTC
─── ──────── ────────────────────────────── ──────────────────── ────────────────
Dev          trigger-new-version-process    kick-off-next-weeks-  release-this-
finalizes    builds + submits last week's   release tags + bumps  weeks-version
the week's   work for App Store review      version for next week activates the
PRs                                                                phased release
                            ◄────── Apple review (~ 3 to 5 days) ─────►
```

Every step is its own workflow file. You can run them by hand via `workflow_dispatch`, or let the crons drive the train.

## Configure (no find and replace)

Slipway workflows read from GitHub Actions repository variables and secrets. Set these once in your fork at *Settings, Secrets and variables, Actions* and every workflow picks up the values.

### Variables (`vars.*`)

| Variable          | Example          | Purpose                                                                |
| ----------------- | ---------------- | ---------------------------------------------------------------------- |
| `APP_NAME`        | `MyApp`                       | Xcode scheme and display name used in workflow logs, notifications, and read by Fastlane as `ENV["APP_NAME"]`. |
| `APP_SLUG`        | `myapp`                       | Lowercase identifier used in paths and marketing references. Fastlane reads as `ENV["APP_SLUG"]`.              |
| `BUNDLE_ID`       | `com.example.myapp`           | Apple bundle identifier. Match and Appfile read as `ENV["BUNDLE_ID"]`.                                          |
| `XCCONFIG_PATH`   | `Config/Base.xcconfig`        | Path to the xcconfig that holds `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Workflows + Fastlane read it. |
| `MARKETING_URL`   | `myapp.example`               | Optional. Marketing URL referenced in release notes and the App Store entry.                                    |

> **How the wiring works.** Every workflow that invokes Fastlane has a top-level `env:` block that exports `vars.*` and `secrets.*` so Ruby (`ENV["BUNDLE_ID"]`, etc.) can read them. If you add a new workflow that runs `bundle exec fastlane`, copy the env block from `bump-version.yml` to keep it consistent.

### Secrets

#### App Store Connect

| Secret                            | Purpose                                                                                                                      |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `APPLE_ID`                        | Apple ID used by Match and Fastlane (read into Ruby as `ENV["APPLE_ID"]`).                                                                |
| `APPLE_TEAM_ID`                   | Apple Developer Team ID, for example `A1B2C3D4E5`. Used by Match, Appfile, and the build workflows.                                       |
| `APPLE_ITC_TEAM_ID`               | Optional. App Store Connect team ID. Only required if your Apple ID is on multiple App Store Connect teams.                               |
| `APP_STORE_CONNECT_KEY_ID`        | App Store Connect API key ID. *Users and Access, Integrations, App Store Connect API.*                                                    |
| `APP_STORE_CONNECT_ISSUER_ID`     | Issuer ID for the same key.                                                                                                               |
| `APP_STORE_CONNECT_KEY_CONTENT`   | Full `.p8` private key contents (paste the file content directly, including the `BEGIN/END PRIVATE KEY` lines).                            |

#### Code signing

| Secret                            | Purpose                                                                                                                      |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `APPLE_CERTIFICATE`               | Base64 encoded `.p12` distribution certificate.                                                                              |
| `APPLE_CERTIFICATE_PASSWORD`      | Password protecting the `.p12`.                                                                                              |
| `MATCH_GIT_URL`                   | SSH URL of the Match certificates repository (read into Ruby as `ENV["MATCH_GIT_URL"]`).                                     |
| `MATCH_PASSWORD`                  | Fastlane Match decryption password.                                                                                          |
| `MATCH_GIT_BASIC_AUTHORIZATION`   | Base64 encoded `username:PAT` for the Match certs repo.                                                                      |

#### GitHub access

| Secret                            | Purpose                                                                                                                      |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `RELEASE_PAT`                     | Personal Access Token with `repo` and `workflow` scope, used to commit version bumps and tags back from inside CI.           |

#### TestFlight beta metadata (required by `upload-metadata.yml` and `deliver-to-testflight.yml`)

| Secret                              | Purpose                                                                                                                |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `BETA_CONTACT_EMAIL`                | Beta App Review contact email shown to App Store reviewers.                                                            |
| `BETA_CONTACT_PHONE`                | Beta App Review contact phone number.                                                                                  |
| `BETA_DEMO_ACCOUNT_NAME`            | Demo account username (if your app requires login for review).                                                         |
| `BETA_DEMO_ACCOUNT_PASSWORD`        | Demo account password.                                                                                                 |

#### Git identity for automated commits

| Secret              | Purpose                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| `GIT_USER_NAME`     | `user.name` used by version-bump and clear-release-notes commits.                                      |
| `GIT_USER_EMAIL`    | `user.email` for the same commits. Pair with a no-reply address like `actions@users.noreply.github.com`. |

#### Release notes generation (required by `write-release-notes.yml`)

| Secret              | Purpose                                                                                                                                |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `DEEPSEEK_API_KEY`  | DeepSeek API key. `scripts/workflows/generate_release_notes.sh` uses it to turn `CHANGES_IN_VERSION.md` bullets into App Store copy.   |

#### Notifications (optional)

| Secret                                 | Purpose                                                                                                                  |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `SLACK_WEBHOOK_GITHUB_EVENTS_CHANNEL`  | Incoming Slack webhook for release status updates. Swap for Telegram or Discord by editing the relevant workflow steps.  |
| `SLACK_USER_ID`                        | Slack member ID to `@mention` in delivery notifications (for example on TestFlight upload failure).                       |
| `SLACK_LEO_ID`                         | Slack member ID to `@mention` for the kick-off workflow's final summary. Rename the secret if you prefer a generic key.   |

#### Claude Code (optional)

| Secret                            | Purpose                                                                                                                      |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `CLAUDE_CODE_OAUTH_TOKEN`         | Used by `claude.yml` (the `@claude` PR mention bot) and `claude-code-review.yml`. Skip if you do not want Claude on PRs.     |

## What is in the box

### Root files

| File                       | What it does                                                                                                                                       |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CHANGES_IN_VERSION.md`    | The contract between developers and the release-notes pipeline. Devs append one bullet per PR above the `### Default Release Notes` header. The release-notes generator turns those bullets into App Store copy. After each release ships, `clear-release-notes.yml` wipes the top section and leaves the default fallback pool untouched. |
| `Gemfile`                  | Ruby dependencies: `fastlane`, `xcov`, `xcpretty`, plus Ruby 3.4+ compatibility gems. Loaded by `bundle exec fastlane` in every fastlane-invoking workflow.                                                                                                                                                                                |
| `Gemfile.lock`             | Pinned versions for reproducible installs. Cached by the `setup-ruby-gems` composite action using a `hashFiles('**/Gemfile.lock')` key.                                                                                                                                                                                                  |

### `.github/actions/`, composite actions

Internal helpers the workflows call via `uses: ./.github/actions/<name>`.

| Action                | What it does                                                                                                                            |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `setup-ruby-gems`     | Pin Homebrew Ruby on the PATH, configure Bundler to use `vendor/bundle`, restore the gem cache, run `bundle install --jobs 4 --retry 3`. |
| `setup-xcode`         | Select a specific Xcode app (`/Applications/Xcode-X.Y.Z.app`) and export `DEVELOPER_DIR` + `SDKROOT` for downstream steps.               |
| `slack-notify`        | Send a standardized Slack message keyed on `${{ vars.APP_NAME }}`. Wraps `slackapi/slack-github-action@v2.1.0`.                          |

### `.github/workflows/`, 22 workflows

The three orchestrators are listed first. They are the entry points. The building blocks are reusable workflows the orchestrators call. The standalone workflows run on their own triggers (push, PR, manual).

#### Orchestrators (the weekly train)

| Workflow                                | Trigger                | What it does                                                                                          |
| --------------------------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------- |
| **`trigger-new-version-process.yml`**   | Tue 03:00 UTC + manual | Bumps version, creates App Store entry, writes notes, uploads metadata, delivers to TestFlight, submits for review, clears notes. The big one. |
| **`kick-off-next-weeks-release.yml`**   | Tue 04:00 UTC + manual | Tags the just-submitted version and bumps for next week's work.                                       |
| **`release-this-weeks-version.yml`**    | Fri 12:00 UTC + manual | Finds the version Apple approved this week and activates the phased release.                          |

#### Building blocks (called by the orchestrators)

| Workflow                              | What it does                                                                                          |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `bump-version.yml`                    | Patch, minor, major, or `next_week_release` version bump via Fastlane. Pushes the bump commit back.   |
| `create-tag.yml`                      | Cut a `vYY.MM.N` tag from the current `main`, annotated, force-push optional.                          |
| `create-appstore-version.yml`         | Create the next App Store Connect version entry (for example `26.5.2`) ahead of submission.            |
| `write-release-notes.yml`             | Generate the *What is New* copy from `CHANGES_IN_VERSION.md`, applying the copywriting persona.        |
| `upload-metadata.yml`                 | Upload localized App Store metadata (description, keywords, beta contact) from `fastlane/metadata/`.   |
| `deliver-to-testflight.yml`           | Build, sign with Match, notarize, and upload to TestFlight via App Store Connect API.                  |
| `add-build-to-release.yml`            | Attach the built `.ipa` to the App Store version entry and submit for review.                          |
| `clear-release-notes.yml`             | Reset `CHANGES_IN_VERSION.md` for the next cycle.                                                      |
| `release-app.yml`                     | Activate phased release on a version that is already Ready for Sale.                                  |

#### Standalone (own triggers)

| Workflow                              | Trigger                | What it does                                                                                          |
| ------------------------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------- |
| `ci.yml`                              | push, PR               | Build and test on every push and PR. Fast feedback path.                                              |
| `run-unit-tests.yml`                  | manual + on demand     | Standalone unit test runner, useful for matrix runs across schemes.                                   |
| `version-sync.yml`                    | manual                 | Sync the marketing version and build number across `xcconfig` and `Info.plist`.                       |
| `regenerate-match-profiles.yml`       | manual + schedule      | Refresh signing certificates and provisioning profiles via Fastlane Match.                            |
| `assign-build-to-group.yml`           | manual                 | Promote a TestFlight build to one or more beta groups.                                                |
| `upload-screenshots.yml`              | manual                 | Upload App Store screenshots from `fastlane/screenshots/` only (no metadata, no build).                |
| `generate-screenshots.yml`            | manual                 | Run UI snapshot tests via `fastlane snapshot` to produce the simulator screenshots themselves.        |
| `delete-artifacts.yml`                | schedule + manual      | Sweep old workflow artifacts to keep the storage bill under control.                                   |
| `claude.yml`                          | `@claude` mention      | Optional. PR conversation bot using the Claude Code action.                                            |
| `claude-code-review.yml`              | PR opened              | Optional. Automated PR review using the Claude Code action.                                            |

> All workflows ship **disabled** in this repository because Slipway is the template, not an active CI pipeline. Re-enable the ones you want in your fork from the Actions tab, or via `gh api --method PUT /repos/{owner}/{repo}/actions/workflows/{id}/enable`.

### `fastlane/`, lanes and supporting config

| File                           | What it does                                                                                                                                    |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `Fastfile`                     | Root file that wires the lane modules together.                                                                                                 |
| `Fastfile.appstore.rb`         | App Store Connect lanes: `create_appstore_version`, `upload_metadata`, `submit_for_review`, and so on.                                          |
| `Fastfile.delivery.rb`         | Build, sign, notarize, and TestFlight upload lanes.                                                                                             |
| `Fastfile.screenshots.rb`      | `snapshot` lane for UI test driven screenshots and organization for App Store Connect.                                                          |
| `Fastfile.testing.rb`          | Unit and UI test lanes with the right scheme and destination wiring.                                                                            |
| `Fastfile.versioning.rb`       | `bump_version` lane and the `version-sync` glue.                                                                                                |
| `Appfile`                      | App identifier and Apple ID, read from `ENV["BUNDLE_ID"]` and `ENV["APPLE_ID"]`.                                                                |
| `Matchfile`                    | Fastlane Match configuration. Reads cert repo URL, identifier, and username from environment variables.                                         |
| `Snapfile`                     | `fastlane snapshot` config: devices, languages, scheme, output dir.                                                                             |
| `Framefile.json`               | Image framing config (device frames around screenshots).                                                                                        |
| `Pluginfile`                   | Fastlane plugin pinning.                                                                                                                        |
| `background.png`               | Background asset used by the screenshot compositor.                                                                                             |
| `marketing/generate.py`        | Composite App Store marketing screenshots from raw UI snapshots: gradient backgrounds, tilted iPhone mockup, bold headline overlays per locale. |
| `marketing/config.json`        | Per-locale headlines and theme colors used by `generate.py`.                                                                                    |

### `scripts/`, supporting code

| File                                            | What it does                                                                                                                 |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `generate_icons.py`                             | Generate every required iOS app icon size from one source image (PNG, JPG, or SVG via Inkscape). Outputs an `AppIcon.appiconset` ready to drop into your Xcode `Assets.xcassets`. |
| `workflows/generate_release_notes.sh`           | Read user facing notes from `CHANGES_IN_VERSION.md` (`--changes-file`), then build the *What is New* string with a copywriting persona. Falls back to a random default if the section is empty. |
| `workflows/clear_release_notes.sh`              | Reset `CHANGES_IN_VERSION.md` at the start of a new release cycle.                                                            |
| `workflows/copywriting_persona.md`              | Prompt fragment used by `generate_release_notes.sh` to keep release notes copy consistent.                                   |

## 60 second integration

This assumes you have an iOS app, a GitHub repo, and an Apple Developer account.

1. **Copy these into your iOS project**: `.github/workflows/`, `.github/actions/`, `fastlane/`, `scripts/`, plus `Gemfile`, `Gemfile.lock`, and `CHANGES_IN_VERSION.md` at the root.
2. **Set repository variables** at *Settings, Secrets and variables, Actions, Variables*. At minimum: `APP_NAME`, `APP_SLUG`, `BUNDLE_ID`, `XCCONFIG_PATH`. Optionally `MARKETING_URL`.
3. **Set the required secrets** in the same panel. See the [Secrets](#secrets) table above for the full list (App Store Connect, code signing, TestFlight beta metadata, git identity, `DEEPSEEK_API_KEY` for release notes, optional Slack and Claude).
4. **Install gems locally** once: `bundle install`.
5. **Run Match once** to sync signing certificates: `bundle exec fastlane match appstore` from your machine.
6. **Drop a source app icon** anywhere and run `python3 scripts/generate_icons.py path/to/source.png`. Replace the resulting `AppIcon.appiconset` in your `Assets.xcassets`.
7. **Push a tag**: `git tag v26.05.1 && git push origin v26.05.1`. `release-app.yml` takes over from there.

If you run on a self hosted macOS runner instead of `macos-latest`, find and replace `runs-on: macos-latest` with your runner labels (for example `[self-hosted, macOS, ARM64]`) across the workflow files. That is the only file edit Slipway asks for.

## Apps built with Slipway

Real iOS apps shipping releases through this pipeline:

| [FareHawk](https://farehawk.app) | [Kinderuntersuchungsheft](https://kinderuntersuchungsheft.com) | [Einbürgerung Pro](https://einbuergerung.pro) | [Reellette](https://reellette.app) |
| :---: | :---: | :---: | :---: |
| <a href="https://farehawk.app"><img src="https://leocardz.com/assets/images/apps/farehawk.png" width="96" alt="FareHawk" /></a> | <a href="https://kinderuntersuchungsheft.com"><img src="https://leocardz.com/assets/images/apps/u-heft.png" width="96" alt="Kinderuntersuchungsheft" /></a> | <a href="https://einbuergerung.pro"><img src="https://leocardz.com/assets/images/apps/einbuergerung-pro.png" width="96" alt="Einbürgerung Pro" /></a> | <a href="https://reellette.app"><img src="https://leocardz.com/assets/images/apps/reellette.png" width="96" alt="Reellette" /></a> |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE)

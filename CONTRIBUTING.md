# Contributing to Slipway

Thanks for considering a contribution. Slipway is a set of GitHub Actions workflows, Fastlane lanes, and Python/shell scripts that turns a vanilla iOS Xcode project into a self-publishing one. The codebase is intentionally small: YAML, Ruby (Fastlane), and a couple of focused Python scripts.

## Reporting bugs / requesting features

Use the issue templates under [.github/ISSUE_TEMPLATE/](./.github/ISSUE_TEMPLATE/). Bug reports need:

- The workflow / lane / script that broke.
- A workflow run URL or log snippet (sanitize secrets first).
- The Xcode + macOS + fastlane versions on the runner.

## Submitting changes

1. Fork the repo and branch off `main`.
2. Keep changes focused — one logical change per PR.
3. Lint:
   - YAML: `actionlint` on workflow files.
   - Shell: `shellcheck` on any `.sh`.
   - Ruby: `rubocop` (optional, but encouraged) on Fastlane files.
   - Python: `ruff` (or `black` + `flake8`).
4. Test by exercising the affected workflow/lane on a fork or a throw-away repo before opening the PR.
5. Open the PR using the [pull request template](./.github/PULL_REQUEST_TEMPLATE.md).

## Code style

- **YAML:** 2-space indent, lowercase keys, double quotes for strings, comments above the line they describe.
- **Fastlane Ruby:** match the existing two-space style. Prefer named lanes (`desc` + `lane :name do ... end`) over long anonymous blocks.
- **Shell:** POSIX-compatible where possible; bashisms only when readability wins.
- **Python:** Type-hinted where it adds clarity. `argparse` over `sys.argv` for any script with more than one positional argument.

## Things we generally won't accept

- Workflows hard-coded to a single app or org. Use `${{ env.* }}` / inputs / matrix so the template stays reusable.
- Adding heavy framework dependencies (large gems, npm dev tools) when a 20-line shell script would do.
- Lane logic that hides what Fastlane is actually doing under custom DSL. Slipway favors readable lanes a junior iOS dev can audit.

## Code of Conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md). Be kind, be precise, be useful.

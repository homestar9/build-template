# Changelog

All notable changes to this project are written down here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-07-29

### Added

- First version of the build kit: `Build`, `Release`, `Bump`, `TestEngines`, `Install`,
  and `Doctor`, sharing one settings file at `build/build.json`.
- `box run-script release` runs the whole release: checks, remote sync, tests, build,
  ForgeBox publish, git tag, and a GitHub Release with the changelog notes and the zip
  attached.
- `release:check` reports whether a project is ready to release and prints the fix for
  anything that is not.
- `release:dryrun` rehearses a release and publishes nothing.
- `release:hotfix` and `:skipTests=true` skip the test suite, with a warning.
- `test:engines` runs the suite on every engine in turn, stopping at the first failure and
  naming the engines that already passed.
- `bump:major`, `bump:minor`, and `bump:patch` raise the version and move `[Unreleased]`
  notes into a dated section. Prereleases follow SemVer, so finishing `1.2.0-beta.3` with
  `bump:patch` gives `1.2.0` rather than skipping to `1.2.1`.
- `bump:beta`, `bump:alpha`, and `bump:prerelease` start and step prereleases, with a
  `:preid` argument for other labels.
- `Install.cfc` sets a project up in one command, working out the test runner from
  `box.json` and the engine list from the `server-*.json` files in the project root.
- Packages are checked before they ship: the build counts the files it staged against the
  files in the zip and stops on any difference.
- Packages are stamped with the short git commit hash they were built from.
- `excludesAdd` appends to the default exclude list, so keeping one extra file out of a
  package is a one line change.
- An optional GitHub Actions workflow in `build/templates/`.

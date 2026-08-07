# Changelog

All notable changes to this project are written down here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2028-08-07

### Added

- A TestBox suite for version rules, changelog parsing, project settings, public task APIs,
  multi-engine control flow, installation, package builds, and safe release dry runs.

### Changed

- All build task components now use direct names, smaller workflow functions, and plain-language
  documentation for developers who are new to the project.
- Version, changelog, and project-detection rules now live in small internal services under
  `build/lib/`.
- Multi-engine documentation now states that every configured engine runs before the command
  reports all failures.

## [1.3.0] - 2028-08-03

### Added

- `release:existing-tag` for publishing a release tag created while finishing a Gitflow
  release in tools such as GitKraken.

### Changed

- The Gitflow guide now makes the branch transitions explicit: create the release branch
  first, bump and commit on that branch, then finish into production and `develop`.
- Git command sequences now include their equivalent review, stage, commit, and push workflow
  for people using GitKraken or another Git GUI.
- GitKraken has its own finish path and safe guidance for intentional, stale, and previously
  published tags.

## [1.2.0] - 2026-07-31

### Added

- A Gitflow release cheat sheet covering plain Git, pull-request, `git-flow`, and hotfix paths.
- Existing-tag release mode for publishing tags created by Gitflow or tag-triggered CI.
- `release:skip-tests` as the clear name for the existing skip-tests release behavior.

### Changed

- Release dry runs can rehearse non-production branches with a warning, while real releases
  remain restricted to the configured production branch.
- Release synchronization is fast-forward-only, and normal releases now reject tags that
  already exist locally or on the remote.
- Installation prefers Gitflow's configured production branch, and Git guidance now uses
  explicit review, staging, and commit steps for newer Git users.
- The optional GitHub Actions workflow can publish an existing tag and requests only the
  repository-content permission needed to create the release.

## [1.1.0] - 2026-07-30

### Added

- New installations write complete, project-specific exclusion defaults into
  `build/build.json`. Module packages get the broad ColdBox-style development exclusions;
  applications preserve deployment content such as `modules`, `.htaccess`, and `.well-known`.
- Installation discovers both `server.json` and root-level `server-*.json` files in stable
  filename order, naming them from `app.cfengine`, the server name, or the filename.

### Changed

- The shipped `build.json` is now a marked starter that a fresh install replaces
  automatically. Existing unmarked and malformed configurations remain untouched unless
  installation is run with `:force=true`.

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

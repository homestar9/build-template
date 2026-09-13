# build-template

![Build Template Logo](https://raw.githubusercontent.com/homestar9/build-template/refs/heads/master/build-template-logo.avif)

`build-template` is a [CommandBox](https://www.ortussolutions.com/products/commandbox) module
that releases CFML projects. Install it once on each machine and it gives you a `release`
namespace that can:

- run your TestBox tests;
- build and check a release zip; and
- publish the package to ForgeBox and GitHub.

Each project keeps only a small `build.json`. You never copy the kit into a repository, and
one `box update` brings every project on the machine up to date.

## How a release works

The normal release process has four parts:

1. Write a short description of your changes under `[Unreleased]` in `CHANGELOG.md`.
2. Run `box release bump` to update the version and date those notes.
3. Check the project and rehearse the release.
4. Run the real release.

The release stops if it finds a problem, such as uncommitted changes, a missing changelog
entry, failed tests, or a version that has already been released.

## Before you install

Every machine needs:

- [CommandBox](https://www.ortussolutions.com/products/commandbox)
- [Git](https://git-scm.com/)

Depending on how a project is configured, you may also need:

- [GitHub CLI](https://cli.github.com/) for GitHub Releases;
- a ForgeBox account for ForgeBox publishing; and
- a running test server when `runTests` is `true`.

Sign in to the services you use:

```bash
gh auth login
box forgebox login
```

## Install

```bash
box install build-template
```

That installs the module into CommandBox itself, so the commands are available in every
project. Then, in a project's root folder:

```bash
box release init
```

The installer:

- writes `build.json` with settings detected from your project; and
- creates `CHANGELOG.md` if the project does not have one.

Add `--docs` to copy the detailed `RELEASE.md` guide into the project, and `--ci` to copy a
GitHub Actions workflow to `.github/workflows/release.yml`. Rerunning it is safe: existing
files are kept unless you pass `--force`. Afterwards, review `build.json` and correct anything
the installer could not detect, especially the test runner URL and release branch.

## Update

```bash
box update build-template --system
```

Every project on the machine uses the updated kit at once. A project can insist on a newer
kit with `minimumKitVersion` in `build.json`; a machine with an older kit is told to update
instead of releasing with the wrong behaviour.

## Moving from 1.x

Projects that copied the 1.x `build` folder keep working until you migrate them: the old
`build/build.json` still loads, with a notice. To move a project over:

```bash
box release migrate --dryRun
box release migrate
```

This moves `build/build.json` to `build.json`, deletes the kit's own files from `build/`
(anything else in there is kept), and rewrites the 1.x `box run-script` entries in `box.json`
to the new commands. Review with `git diff`, then commit. Add `--removeScripts` to delete the
old scripts instead of rewriting them.

## Your first release

This example assumes the current version is `1.0.0` and you are releasing `1.0.1`.

### 1. Write the release notes

Add a useful line under `## [Unreleased]` in `CHANGELOG.md`:

```markdown
## [Unreleased]

### Fixed

- Fixed the login form validation.
```

These notes become the body of the GitHub Release.

### 2. Update the version

For a bug fix, run:

```bash
box release bump patch
```

This changes the version in `box.json` from `1.0.0` to `1.0.1` and moves the notes into a
dated `1.0.1` section.

Use a different level when needed:

```bash
box release bump minor    # 1.0.0 -> 1.1.0 for a new feature
box release bump major    # 1.0.0 -> 2.0.0 for a breaking change
```

### 3. Review and commit the changes

```bash
git status
git diff
git add box.json CHANGELOG.md
git diff --staged
git commit -m "Release 1.0.1"
```

If your changelog has a different filename, use that filename in the `git add` command.
The commit is only local until you send it to the remote with `git push`.

**Using GitKraken or another Git GUI?** Review the changed `box.json` and changelog, stage only
those release files, review the staged changes, commit them as `Release 1.0.1`, and then push
the current branch. Those are the GUI equivalents of the commands above.

### 4. Check that the project is ready

Start the project's test server if tests are enabled, then run:

```bash
box release check
```

This command changes nothing. It checks the installed kit, the settings, the Git repository,
the changelog, the required tools, the service logins, and the test server. If something is
wrong, it prints what to fix.

### 5. Rehearse the release

```bash
box release run --dryRun
```

The dry run executes the checks, tests, and package build, but does not publish, tag, or push
anything.

### 6. Publish

```bash
box release run
```

The release:

1. checks the project;
2. fast-forwards the configured production branch from its Git remote;
3. runs the tests and builds a verified zip;
4. publishes to ForgeBox when enabled; and
5. creates the Git tag and GitHub Release when enabled.

The finished zip and checksum are saved under `.artifacts/`.

## Commands

Run these from anywhere inside a project. `box release help` prints the same list.

| Command | Use it to |
| --- | --- |
| `box release check` | Find anything that would stop a release. |
| `box release run --dryRun` | Rehearse a release without publishing. |
| `box release run` | Build and publish the current version. |
| `box release run --existingTag` | Publish a tag already created at the checked-out commit by Gitflow or GitKraken. Pushes the tag first if origin does not have it yet. |
| `box release run --skipTests` | Publish without rerunning tests that were already completed. |
| `box release bump patch` | Release a backward-compatible bug fix. |
| `box release bump minor` | Release a backward-compatible feature. |
| `box release bump major` | Release a breaking change. |
| `box release bump preminor beta` | Start a prerelease, for example `1.1.0-beta.1`. |
| `box release package` | Build and check the zip without publishing it. |
| `box release engines` | Run the test suite on each configured CFML engine. |
| `box release notes` | Show the release notes for the current version. |
| `box release github` | Finish a release that stopped after publishing. |
| `box release init` | Set a project up: `build.json` and `CHANGELOG.md`. |
| `box release migrate` | Move a project off the 1.x copied `build` folder. |

Full help for any command: `box help release run`.

## Common settings

Edit `build.json` in the project root to change how the commands work. The installer creates
this file with values detected from your project and a complete package exclusion list.

### Choose the production branch

`branch` is the branch that receives release tags and published versions, normally `main` or
`master`. In a Gitflow repository it is the production branch, never `develop` or a temporary
`release/*` branch. The installer reads Gitflow's configured production branch when available,
but you should still verify the generated value.

```json
{
    "branch": "main"
}
```

### Require a kit version

```json
{
    "minimumKitVersion": "2.0.0"
}
```

The installer writes the version it was run with. Raise it when the project starts depending
on a newer kit feature.

### Publish to GitHub but not ForgeBox

```json
{
    "publish": {
        "forgebox": false,
        "github": true
    }
}
```

### Build an application instead of a module

An application still gets a versioned zip and can still get a GitHub Release:

```json
{
    "projectType": "app",
    "publish": {
        "forgebox": false,
        "github": true
    }
}
```

### Do not run tests during the build

Use this when another system, such as CI, is responsible for running the tests:

```json
{
    "runTests": false
}
```

### Keep extra files out of the package

`excludes` is the complete list of regular expressions matched against top-level files and
folders. A module starts with broad packaging defaults: build and test tooling, downloaded
dependencies, server definitions, editor workspaces, agent notes, archives, and hidden files
stay out. An application gets a narrower list: possible deployment content such as `modules`,
`resources`, package manifests, `.htaccess`, and `.well-known` remains available.

Edit `excludes` when you need to change that baseline. Use `excludesAdd` for project-specific
additions that should sit on top of it. For example, this keeps the top-level `docs` folder out
of the package:

```json
{
    "excludesAdd": [
        "^docs$"
    ]
}
```

Use double backslashes when a regular expression needs a backslash because the value is JSON.

### Test more than one CFML engine

During `release init`, `server.json` and every `server-*.json` file in the project root are
added here in filename order. Nested server files are deliberately ignored. A readable name
comes from `app.cfengine`, then the server's `name`, then its filename; review the generated
list and remove any server that is not part of your compatibility suite.

Each `configFile` remains a CommandBox server JSON file in the project root:

```json
{
    "engines": [
        {
            "name": "Lucee 5",
            "configFile": "server-lucee@5.json"
        },
        {
            "name": "Adobe 2023",
            "configFile": "server-adobe@2023.json"
        }
    ]
}
```

Run the configured list with:

```bash
box release engines
```

The engines run one at a time. Every engine still runs after a failure. The final report lists
all results, and the command returns an error when any engine failed.

## Common problems

| Message | What to do |
| --- | --- |
| `Command "release" cannot be resolved` | The module is not installed in this CommandBox. Run `box install build-template`. |
| `No box.json found` | Run the command from inside a CommandBox project. |
| `This project needs build-template X or newer` | Run `box update build-template --system`. |
| `You have uncommitted changes` | Commit or stash the changes, then run the command again. |
| `No answer from the test server` | Start the project's test server, check `testRunner`, or turn off `runTests` if tests run elsewhere. |
| `Could not find the GitHub CLI` | Install `gh`, open a new terminal, and run `gh auth login`. |
| `has no "## [version]" section` | Add notes under `[Unreleased]`, then run `box release bump`. |
| `Tag v1.2.3 already exists` | That version has already been released. Bump the version before trying again. |
| `Tag v1.2.3 is on origin at a different commit` | Your local tag and the published tag disagree. Do not move the published tag; check the release history or choose a new version. |
| `build.json is not valid JSON` | Check for missing quotes, trailing commas, or backslashes that need to be doubled. |

Start with `box release check` when you are unsure. It reports all readiness problems without
changing the project.

## Develop the build kit

Install the development dependencies and run the tests:

```bash
box install
box run-script test
```

The test runner loads this checkout as the `build-template` module inside its own CommandBox,
so the specs always exercise the working copy, even when a released copy is installed
globally. Unit tests cover the version, changelog, configuration, project-detection, and
migration rules. Integration tests create throwaway projects under the ignored `.test-work/`
folder and run the real commands in them through `tests/support/Invoke.cfc`, with a local Git
remote. The tests never publish to ForgeBox or GitHub.

To try the working copy as a real install, run `box install <path to this checkout>` and open a
new shell; `box release help` should list the commands. The kit releases itself with its own
`box release run`.

The commands in `commands/release/` stay thin. The work happens in `models/`, and pure rules
that do not need CommandBox live in their own components there so they are easy to test.

## More information

- [Detailed release guide](templates/RELEASE.md)
- [Optional GitHub Actions workflow](templates/github-release.yml)
- [Changelog](CHANGELOG.md)
- [MIT License](LICENSE)

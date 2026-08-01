# build-template

`build-template` is a set of [CommandBox](https://www.ortussolutions.com/products/commandbox)
tasks for CFML projects. Copy the `build` folder into a project and it can:

- run your TestBox tests;
- build and check a release zip; and
- publish the package to ForgeBox and GitHub.

You control the build through `build/build.json`. You should not need to edit the CFML task
files.

## How a release works

The normal release process has four parts:

1. Write a short description of your changes under `[Unreleased]` in `CHANGELOG.md`.
2. Run a `bump` command to update the version and date those notes.
3. Check the project and rehearse the release.
4. Run the real release.

The release task stops if it finds a problem, such as uncommitted changes, a missing changelog
entry, failed tests, or a version that has already been released.

## Before you install

Every project needs:

- [CommandBox](https://www.ortussolutions.com/products/commandbox)
- [Git](https://git-scm.com/)
- a `box.json` file

Depending on how your project is configured, you may also need:

- [GitHub CLI](https://cli.github.com/) for GitHub Releases;
- a ForgeBox account for ForgeBox publishing; and
- a running test server when `runTests` is `true`.

Sign in to the services you use:

```bash
gh auth login
box forgebox login
```

## Install

1. Download or clone this repository.
2. Copy the `build` folder into the root of your CFML project.
3. Open a terminal in your project root and run:

```bash
box task run taskFile=build/Install.cfc
```

The installer:

- replaces the marked starter `build/build.json` with settings detected from your project;
- adds build and release scripts to `box.json`;
- creates `CHANGELOG.md` if the project does not have one; and
- copies a detailed `RELEASE.md` guide into the project root.

The starter marker only exists in the file shipped with this kit. The installer leaves every
unmarked `build.json` and existing script alone, so rerunning it is safe. After installation,
review `build/build.json` and correct anything the installer could not detect, especially the
test runner URL and release branch.

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
box run-script bump:patch
```

This changes the version in `box.json` from `1.0.0` to `1.0.1` and moves the notes into a
dated `1.0.1` section.

Use a different command when needed:

```bash
box run-script bump:minor    # 1.0.0 -> 1.1.0 for a new feature
box run-script bump:major    # 1.0.0 -> 2.0.0 for a breaking change
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
`git status` lists the changed files, `git diff` lets you review them, and `git add` selects
what the next commit will contain. `git diff --staged` previews that selection. The commit is
only local until you send it to the remote with `git push`.

### 4. Check that the project is ready

Start the project's test server if tests are enabled, then run:

```bash
box run-script release:check
```

This command changes nothing. It checks the settings, Git repository, changelog, required
tools, service logins, and test server. If something is wrong, it prints what to fix.

### 5. Rehearse the release

```bash
box run-script release:dryrun
```

The dry run executes the checks, tests, and package build, but does not publish, tag, or push
anything.

### 6. Publish

```bash
box run-script release
```

The release task:

1. checks the project;
2. fast-forwards the configured production branch from its Git remote;
3. runs the tests and builds a verified zip;
4. publishes to ForgeBox when enabled; and
5. creates the Git tag and GitHub Release when enabled.

The finished zip and checksum are saved under `.artifacts/`.

## Common commands

| Command | Use it to |
| --- | --- |
| `box run-script release:check` | Find anything that would stop a release. |
| `box run-script release:dryrun` | Rehearse a release without publishing. |
| `box run-script release` | Build and publish the current version. |
| `box run-script release:skip-tests` | Publish without rerunning tests that were already completed. |
| `box run-script release:hotfix` | Alias for `release:skip-tests`; it does not manage a Gitflow hotfix branch. |
| `box run-script bump:patch` | Release a backward-compatible bug fix. |
| `box run-script bump:minor` | Release a backward-compatible feature. |
| `box run-script bump:major` | Release a breaking change. |
| `box run-script test:engines` | Run the test suite on each configured CFML engine. |
| `box run-script build:package` | Build and check the zip without publishing it. |

The generated `RELEASE.md` explains Gitflow releases, prereleases, hotfixes, and recovery from
a release that stops partway through.

## Common settings

Edit `build/build.json` to change how the tasks work. The installer creates this file with
values detected from your project and a complete package exclusion list. Keeping that list in
the project makes its package contents predictable when the build kit is upgraded later.

### Choose the production branch

`branch` is the branch that receives release tags and published versions—normally `main` or
`master`. In a Gitflow repository it is the production branch, never `develop` or a temporary
`release/*` branch. The installer reads Gitflow's configured production branch when available,
but you should still verify the generated value.

```json
{
    "branch": "main"
}
```

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

During installation, `server.json` and every `server-*.json` file in the project root are
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
box run-script test:engines
```

The engines run one at a time and the command stops at the first failure.

## Common problems

| Message | What to do |
| --- | --- |
| `You have uncommitted changes` | Commit or stash the changes, then run the command again. |
| `No answer from the test server` | Start the project's test server, check `testRunner`, or turn off `runTests` if tests run elsewhere. |
| `Could not find the GitHub CLI` | Install `gh`, open a new terminal, and run `gh auth login`. |
| `has no "## [version]" section` | Add notes under `[Unreleased]`, then run the correct `bump` command. |
| `Tag v1.2.3 already exists` | That version has already been released. Bump the version before trying again. |
| `build.json is not valid JSON` | Check for missing quotes, trailing commas, or backslashes that need to be doubled. |

Start with `box run-script release:check` when you are unsure. It reports all readiness
problems without changing the project.

## More information

- [Detailed release guide](build/templates/RELEASE.md)
- [Optional GitHub Actions workflow](build/templates/github-release.yml)
- [Changelog](CHANGELOG.md)
- [MIT License](LICENSE)

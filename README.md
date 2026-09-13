# build-template

![build-template logo](https://raw.githubusercontent.com/homestar9/build-template/refs/heads/master/build-template-logo.avif)

`build-template` is a [CommandBox](https://www.ortussolutions.com/products/commandbox) module
for releasing CFML projects. Install the module once on each computer. It adds `release`
commands that can:

- run TestBox tests;
- build and check a release zip file; and
- publish a package to ForgeBox and GitHub.

Each project stores its release settings in one small `build.json` file. You do not need to
copy the build kit into every project. One `box update` command updates the kit for every
project on the computer.

## How a release works

A normal release has four main steps:

1. Add a short description of your changes under `[Unreleased]` in `CHANGELOG.md`.
2. Run `box release bump` to change the version and date the release notes.
3. Check the project and run a release practice run.
4. Run the real release.

The release stops when it finds a problem. For example, it stops for uncommitted changes,
missing release notes, failed tests, or a version that was already released.

## Before you install

Every computer needs:

- [CommandBox](https://www.ortussolutions.com/products/commandbox)
- [Git](https://git-scm.com/)

Your project settings may also require:

- [GitHub CLI](https://cli.github.com/) to create GitHub Releases;
- a ForgeBox account to publish to ForgeBox; and
- a running test server when `runTests` is `true`.

Sign in to each service that you use:

```bash
gh auth login
box forgebox login
```

## Install

```bash
box install build-template
```

This command installs the module in CommandBox. The release commands then work in every
project. Go to a project's root folder and run:

```bash
box release init
```

The setup command:

- creates `build.json` with settings found in the project; and
- creates `CHANGELOG.md` when the project does not already have one.

Use `--docs` to copy the detailed `RELEASE.md` guide into the project. Use `--ci` to copy a
GitHub Actions workflow to `.github/workflows/release.yml`. You can safely run the setup
command again. It keeps existing files unless you use `--force`.

Review `build.json` after setup. Correct any setting that could not be found automatically.
Pay special attention to the test runner URL and release branch.

## Update

```bash
box update build-template --system
```

This command updates the kit for every project on the computer. A project can require a
specific kit version through `minimumKitVersion` in `build.json`. Release commands stop and
show the update command when the installed kit is too old.

## Move a project from version 1.x

Projects that contain the old 1.x `build` folder continue to work before migration. The kit
reads the old `build/build.json` file and prints a migration notice. Run these commands to
migrate the project:

```bash
box release migrate --dryRun
box release migrate
```

The migration moves `build/build.json` to `build.json`. It deletes only the files that the 1.x
kit added under `build/`. It keeps all other files in that folder. It also updates the old
`box run-script` entries in `box.json` to use the new release commands.

Review the result with `git diff`, and then commit it. Use `--removeScripts` if you want to
delete the old scripts instead of updating them.

## Your first release

This example starts at version `1.0.0` and releases version `1.0.1`.

### 1. Write the release notes

Add a clear note under `## [Unreleased]` in `CHANGELOG.md`:

```markdown
## [Unreleased]

### Fixed

- Fixed the login form validation.
```

This text becomes the description of the GitHub Release.

### 2. Change the version

Run this command for a bug fix:

```bash
box release bump patch
```

The command changes the version in `box.json` from `1.0.0` to `1.0.1`. It also moves the
notes into a dated `1.0.1` section.

Use a different level for other types of changes:

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

Use your changelog filename in the `git add` command if it is not `CHANGELOG.md`. The commit
stays on your computer until you send it to the remote repository with `git push`.

If you use GitKraken or another Git app, follow the same steps in the app. Review `box.json`
and the changelog. Stage only those release files. Review the staged changes, commit them as
`Release 1.0.1`, and push the current branch.

### 4. Check the project

Start the project's test server when tests are enabled. Then run:

```bash
box release check
```

This command does not change anything. It checks the installed kit, settings, Git repository,
changelog, required tools, service logins, and test server. It prints a specific fix for each
problem.

### 5. Practice the release

```bash
box release run --dryRun
```

This practice run performs the checks, tests, and package build. It does not publish, create
a tag, or push anything.

### 6. Publish

```bash
box release run
```

The release command:

1. checks the project;
2. updates the local production branch without creating a merge commit;
3. runs the tests and builds a checked zip file;
4. publishes to ForgeBox when ForgeBox publishing is enabled; and
5. creates the Git tag and GitHub Release when GitHub publishing is enabled.

The final zip file and its checksums are stored under `.artifacts/`.

## Commands

Run these commands from any folder inside a project. `box release help` prints the same list.

| Command | What it does |
| --- | --- |
| `box release check` | Finds problems that would stop a release. |
| `box release run --dryRun` | Practices a release without publishing. |
| `box release run` | Builds and publishes the current version. |
| `box release run --existingTag` | Publishes a tag that Gitflow or GitKraken already created at the checked-out commit. It pushes the tag when origin does not have it. |
| `box release run --skipTests` | Publishes without running the tests again. |
| `box release bump patch` | Releases a bug fix that remains compatible with older versions. |
| `box release bump minor` | Releases a new feature that remains compatible with older versions. |
| `box release bump major` | Releases a change that is not compatible with older versions. |
| `box release bump preminor beta` | Starts a prerelease such as `1.1.0-beta.1`. |
| `box release package` | Builds and checks the zip file without publishing. |
| `box release engines` | Runs the tests on each configured CFML engine. |
| `box release notes` | Shows the release notes for the current version. |
| `box release github` | Finishes a release that stopped after publishing. |
| `box release init` | Creates `build.json` and `CHANGELOG.md` for a project. |
| `box release migrate` | Moves a project away from the copied 1.x `build` folder. |

Run `box help release run` to see all help for one command.

## Common settings

Edit `build.json` in the project root to control the release commands. The setup command
creates this file from settings that it finds in the project. It also adds a full list of
files that should not be included in the package.

### Choose the production branch

`branch` is the branch that receives release tags and published versions. This is usually
`main` or `master`. For Gitflow projects, use the production branch. Do not use `develop` or a
temporary `release/*` branch. The setup command uses Gitflow's configured production branch
when it can find one. Always check the generated value.

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

The setup command writes the current kit version. Increase this value when the project starts
using a feature from a newer kit version.

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

An application still gets a versioned zip file. It can also get a GitHub Release.

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

Use this setting when another system, such as CI, runs the tests:

```json
{
    "runTests": false
}
```

### Keep extra files out of the package

`excludes` is the full list of regular expressions used to match top-level files and folders.
The default module list excludes build tools, test tools, downloaded dependencies, server
settings, editor files, agent notes, archives, and hidden files. An application uses a smaller
list. This smaller list allows possible deployment files such as `modules`, `resources`,
package manifests, `.htaccess`, and `.well-known`.

Edit `excludes` to replace the default list. Use `excludesAdd` to add project-specific rules
without replacing the defaults. This example excludes the top-level `docs` folder:

```json
{
    "excludesAdd": [
        "^docs$"
    ]
}
```

JSON requires two backslashes when a regular expression needs one literal backslash.

### Test more than one CFML engine

During `release init`, the setup command finds `server.json` and each `server-*.json` file in
the project root. It adds the files to `engines` in filename order. It does not search nested
folders. The displayed engine name comes from `app.cfengine`, the server's `name`, or the
filename, in that order. Review the list and remove servers that are not part of your
compatibility tests.

Each `configFile` must name a CommandBox server JSON file in the project root:

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

Run the configured engine list with:

```bash
box release engines
```

The engines run one at a time. A failure does not stop the remaining engines. The final report
lists every result. The command returns an error when one or more engines fail.

## Common problems

| Message | How to fix it |
| --- | --- |
| `Command "release" cannot be resolved` | Install the module in this CommandBox with `box install build-template`. |
| `No box.json file was found` | Run the command from inside a CommandBox project. |
| `This project requires build-template X or newer` | Run `box update build-template --system`. |
| `You have uncommitted changes` | Commit or stash the changes, and then run the command again. |
| `The test server ... did not answer` | Start the project's test server. You can also correct `testRunner` or set `runTests` to `false` when tests run somewhere else. |
| `Could not find the GitHub CLI` | Install `gh`, open a new terminal, and run `gh auth login`. |
| `does not have a "## [version]" section` | Add notes under `[Unreleased]`, and then run `box release bump`. |
| `Tag v1.2.3 already exists` | That version was already released. Change the version before trying again. |
| `Tag v1.2.3 points to a different commit on origin` | The local and remote tags point to different commits. Do not move the published tag. Check the release history or use a new version. |
| `build.json contains invalid JSON` | Check for missing quotes, extra commas, or backslashes that must be doubled. |

Run `box release check` when you do not know what is wrong. It reports release problems
without changing the project.

## Develop the build kit

Install the development dependencies and run the tests:

```bash
box install
box run-script test
```

The test runner loads this checkout as the `build-template` module in its own CommandBox. The
tests use the working copy even when another version is installed globally. Unit tests cover
version rules, changelog handling, settings, project detection, and migration. Integration
tests create temporary projects under the ignored `.test-work/` folder. They run the real
commands through `tests/support/Invoke.cfc` and use a local Git remote. The tests never publish
to ForgeBox or GitHub.

To test the working copy as an installed module, run `box install <path to this checkout>`.
Then open a new shell. `box release help` should list the commands. The kit uses its own
`box release run` command to release itself.

Files in `commands/release/` contain the small command entry points. Files in `models/` contain
the release work. Rules that do not need CommandBox are kept in separate model components so
they are easier to test.

## More information

- [Detailed release guide](templates/RELEASE.md)
- [Optional GitHub Actions workflow](templates/github-release.yml)
- [Changelog](CHANGELOG.md)
- [MIT License](LICENSE)

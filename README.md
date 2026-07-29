# build-template

A drop-in build and release kit for CFML projects using [CommandBox](https://www.ortussolutions.com/products/commandbox).

Copy one folder into your project and you get three commands:

```
box run-script test:engines    # run the whole test suite on every engine
box run-script bump:patch      # raise the version and date the changelog
box run-script release         # build, publish, tag, and create a GitHub Release
```

It works for ForgeBox modules, GitHub-only releases, and plain apps. Everything a project
needs to change lives in one small settings file, so you never edit the code.

---

## What it does for you

- **Refuses to release when something is wrong.** Uncommitted work, wrong branch, a version
  already released, missing release notes, or a tool that is not signed in all stop the release
  *before* anything is published.
- **Never publishes untested code.** The test suite runs during the build and stops it on any
  failure.
- **Checks the package is complete.** It counts the files it staged against the files in the
  zip and stops if they differ. This catches an ignore rule quietly dropping source folders,
  which is the kind of mistake that ships a broken package and breaks every install.
- **Writes your release notes for you.** The changelog section for the version becomes the
  GitHub Release body.
- **Tells you how to finish by hand** if something fails after publishing, because a published
  version cannot be taken back.

---

## Install

### From GitHub

1. Download or clone this repository.
2. Copy its **`build`** folder into the root of your project.
3. From your project root, run:

```
box task run taskFile=build/Install.cfc
```

That one command works out sensible settings from your project, writes `build/build.json`,
adds the scripts to your `box.json`, and creates a changelog and a `RELEASE.md` if you do not
have them. It never overwrites anything you already have.

### What it looks like afterwards

```
your-project/
├── box.json              <- scripts added, nothing else touched
├── changelog.md          <- created if missing
├── RELEASE.md            <- the routine, written down
└── build/
    ├── build.json        <- THE ONLY FILE YOU EDIT
    ├── BuildConfig.cfc
    ├── Build.cfc
    ├── Bump.cfc
    ├── Doctor.cfc
    ├── Install.cfc
    ├── Release.cfc
    ├── TestEngines.cfc
    └── templates/
```

---

## Quick start

```
box run-script release:check     # is everything ready? fix whatever it lists
box run-script release:dryrun    # full rehearsal, publishes nothing
box run-script release           # the real thing
```

`release:check` is worth running first. It checks git, your remote, the GitHub CLI, ForgeBox,
your changelog, and your test server, and prints the exact command to fix anything that is
wrong.

---

## The commands

| Command | What it does |
| --- | --- |
| `release` | The whole release: check, sync, build, publish, tag, GitHub Release. |
| `release:check` | Checks whether you are ready to release. Changes nothing. |
| `release:dryrun` | Everything except publishing, tagging, and pushing. Prints what it would do. |
| `release:hotfix` | Same as `release` but skips the test suite. Warns loudly. |
| `test:engines` | Runs the whole suite on every engine in turn. |
| `bump:patch` / `bump:minor` / `bump:major` | Raises the version and moves your `[Unreleased]` notes into a dated section. |
| `bump:beta` / `bump:alpha` | Starts a prerelease of the next minor version, `1.1.0` → `1.2.0-beta.1`. |
| `bump:prerelease` | Steps an existing prerelease forward, `beta.3` → `beta.4`. |
| `build:package` | Builds and checks the zip without publishing anything. |

---

## Settings: `build/build.json`

Every setting is optional. Anything you leave out uses the default below, so a file containing
only `{}` works.

| Setting | Default | What it does |
| --- | --- | --- |
| `projectType` | `"module"` | `"module"` publishes to ForgeBox. `"app"` builds a zip and does not. |
| `branch` | `"main"` | The branch releases come from. A release refuses to run from any other. |
| `changelog` | `"changelog.md"` | Your changelog file name. |
| `testRunner` | from `box.json` | The TestBox runner URL. Taken from your `testbox.runner` when blank. |
| `runTests` | `true` | Whether the build runs the suite. Set false if only CI runs tests. |
| `gitSync` | `true` | Whether the release checks out and pulls the branch first. |
| `requireCleanTree` | `true` | Whether uncommitted work stops a release. |
| `publish.forgebox` | `true` | Publish to ForgeBox. Off by default when `projectType` is `"app"`. |
| `publish.github` | `true` | Tag the version and create a GitHub Release. |
| `excludesAdd` | `[]` | Extra things to keep out of the package. **This is the one you will use.** |
| `excludes` | see below | Replaces the whole default exclude list. For unusual cases only. |
| `engines` | `[]` | The engines `test:engines` runs, in order. |
| `warmup.attempts` | `60` | How many times to check whether a starting server is up. |
| `warmup.delaySeconds` | `5` | How long to wait between those checks. |
| `coldboxMapping` | `"test-harness/coldbox"` | Where ColdBox lives, if your build needs it mapped. |
| `stagingDir` | `".tmp"` | Where the package is assembled. |
| `artifactsDir` | `".artifacts"` | Where the finished zip and checksums go. |
| `tagPrefix` | `"v"` | The prefix for version tags, giving `v1.2.3`. |

### What is excluded by default

The build folder, `modules`, `node_modules`, `test-harness`, `tests`, `test-results`, `temp`,
`plans`, any `server-*.json`, `AGENTS.md`, `CLAUDE.md`, `DEVNOTES.md`, `RELEASE.md`, `.bak`
files, any archive (`.zip`, `.tar`, and friends), and every hidden file or folder such as
`.git` and `.env`.

Each entry is a regular expression matched against the name of each **top-level** item. Only
the top level is checked, and a folder that survives is copied whole.

---

## Customising

### Keep one extra file out of the package

The most common change. Say you have a logo in your project root that users do not need:

```json
{
    "excludesAdd": [ "my-logo\\.avif$" ]
}
```

Backslashes must be doubled in JSON. `\\.` means a literal dot.

To exclude a whole top-level folder:

```json
{
    "excludesAdd": [ "^[\\/]?docs$" ]
}
```

### Skip the test suite

Three ways, depending on what you want:

```json
{ "runTests": false }
```

turns it off for every build. For a one-off, when you have just run the tests yourself:

```
box run-script release:hotfix
```

Both print a loud warning, because an untested release is worth noticing.

### Release to GitHub only, not ForgeBox

```json
{
    "publish": { "forgebox": false, "github": true }
}
```

### Publish a private ForgeBox package

Nothing changes here. Mark the package private in your own `box.json`:

```json
{ "private": true }
```

### Build an app rather than a module

```json
{ "projectType": "app" }
```

You still get a checked, versioned zip in `.artifacts/`, plus tagging and a GitHub Release.
ForgeBox publishing is off unless you switch it on.

### Release from a branch other than `main`

```json
{ "branch": "production" }
```

### Ship alphas and betas

Version numbers follow SemVer, where `1.2.0-beta.3` comes **before** `1.2.0`. The commands
follow the same rule, so finishing a beta lands on the version it was leading up to instead of
stepping past it.

Start a prerelease of the next minor version:

```
box run-script bump:beta      # 1.1.0 -> 1.2.0-beta.1
box run-script bump:alpha     # 1.1.0 -> 1.2.0-alpha.1
```

Step it forward as you go:

```
box run-script bump:prerelease    # 1.2.0-beta.1 -> 1.2.0-beta.2
```

Then release it for real. `patch` settles on the version the beta was for, rather than skipping
to `1.2.1`:

```
box run-script bump:patch     # 1.2.0-beta.2 -> 1.2.0
```

For a prerelease of a patch or a major instead of a minor, name the level directly:

```
box task run taskFile=build/Bump.cfc :level=prepatch     # 1.1.0 -> 1.1.1-beta.1
box task run taskFile=build/Bump.cfc :level=premajor     # 1.1.0 -> 2.0.0-beta.1
```

Add `:preid=rc` to any of those to use a different label. Switching label restarts the count, so
`1.2.0-alpha.7` with `:preid=beta` becomes `1.2.0-beta.1`.

GitHub Releases for a prerelease are flagged as such automatically, because the version contains
a hyphen.

### Add engines to the test sweep

```json
{
    "engines": [
        { "name": "Lucee 5",    "configFile": "server-lucee@5.json" },
        { "name": "Adobe 2023", "configFile": "server-adobe@2023.json" }
    ]
}
```

Put the engines you trust first. The sweep stops at the first failure, so a problem with a
rarely used engine still leaves you results for the others.

---

## How a release runs

`box run-script release` does this, stopping at the first problem:

1. **Checks** — clean checkout, right branch, version not already released, changelog section
   exists, GitHub CLI signed in. All of this happens before anything permanent.
2. **Lines up with the remote** — checks out the release branch and pulls.
3. **Builds** — runs the suite, stages the source minus exclusions, stamps the version, zips
   it, counts the files, writes checksums.
4. **Publishes to ForgeBox** — from the built folder, never the project root.
5. **Tags and releases on GitHub** — with the changelog notes and the zip attached.

**Why publish from the built folder?** Publishing from your project root packages using
`.gitignore`, and one broad ignore rule can quietly drop source folders from what people
install. Publishing what the build produced sends exactly what the build checked.

---

## When something goes wrong

| Message | What it means and what to do |
| --- | --- |
| `You have uncommitted changes` | Commit or stash first. The release refuses so that the forced checkout cannot throw work away. |
| `No answer from the test server` | Start your server, or set `runTests` to false. |
| `Could not find the GitHub CLI` | Install it from [cli.github.com](https://cli.github.com), then **open a new terminal**. A terminal keeps the PATH it started with, so a tool installed afterwards looks missing until you open a new one. |
| `The GitHub CLI is not signed in` | Run `gh auth login`. |
| `Permission denied (publickey)` | git cannot sign in to your remote. Add your SSH key at [github.com/settings/ssh/new](https://github.com/settings/ssh/new), or switch to HTTPS: `git remote set-url origin https://github.com/<you>/<repo>.git` then `gh auth setup-git`. |
| `has no "## [1.2.3]" section` | Run a `bump:` command to move your notes into a dated section. |
| `Tag v1.2.3 already exists` | That version is released. Raise the version first. |
| `The zip is incomplete` | Something is removing files during packaging. Check `.gitignore` and your `excludes`. |
| `build.json is not valid JSON` | Usually an unquoted value or a single backslash. Backslashes must be doubled. |

### A release that stopped halfway

Everything that can stop a release happens before publishing. If a step fails **after**
publishing, do not run the release again: the version is already out, so the checks will
refuse. The failure message prints the exact commands to finish by hand.

To finish just the tag and GitHub Release:

```
box task run taskFile=build/Release.cfc target=github :version=1.2.3
```

To see the release notes without doing anything:

```
box task run taskFile=build/Release.cfc target=github :version=1.2.3 :notesOnly=true
```

---

## Releasing from CI

`build/templates/github-release.yml` is a GitHub Actions workflow you can copy to
`.github/workflows/release.yml`. It builds and publishes when you push a version tag, and
stamps packages with the Actions run number instead of the commit hash.

---

## Updating this kit

Settings live in `build/build.json` and the code never needs editing, so updating is:

1. Replace the `.cfc` files in your `build` folder with the new ones.
2. Leave your `build.json` alone.

`templateVersion` in `build.json` records which version you set up with.

---

## Requirements

- CommandBox
- git
- The GitHub CLI (`gh`), only if you publish GitHub Releases
- A ForgeBox account, only if you publish there

Build tasks run inside CommandBox's own engine, so they work the same whichever CF engine your
project targets.

---

## Licence

MIT. See [LICENSE](LICENSE).

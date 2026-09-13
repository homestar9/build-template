# Release this project

Follow this guide from top to bottom for a normal release. Release settings are in
`build.json` in the project root. The commands come from the
[build-template](https://github.com/homestar9/build-template) CommandBox module.

## Set up your computer once

- Install CommandBox. Run `box version` to check it.
- Install build-template with `box install build-template`. Update it later with
  `box update build-template --system`.
- Sign in to GitHub CLI with `gh auth login` when the project creates GitHub Releases.
- Sign in to ForgeBox with `box forgebox login` when the project publishes there.
- Make sure you can start the test server unless `runTests` is `false` in `build.json`.
- Set `branch` in `build.json` to the production branch. This is usually `main` or `master`.
  For Gitflow projects, do not use `develop` or `release/*`.

Check the full setup with:

```
box release check
```

## Normal release steps

### 1. Write release notes while you work

Add each change under `## [Unreleased]` in the changelog. Write for the people who use the
project. This text becomes the GitHub Release description.

### 2. Test each engine

```
box release engines
```

This command runs the full test suite on each configured engine. It runs one engine at a
time. A failed engine does not stop the other engines. The command returns an error after all
engines finish if any engine failed.

This check can take a long time, so it is separate from the release command. Skip this step
when the project supports only one engine.

### 3. Change the version

> **Using Gitflow?** First create `release/<version>` from `develop`. Run the bump command on
> that release branch. Do not bump `develop` before creating the branch. The
> [Gitflow guide](#gitflow-guide) below lists every step.

```
box release bump patch     # bug fixes           1.0.0 -> 1.0.1
box release bump minor     # new features        1.0.0 -> 1.1.0
box release bump major     # breaking changes    1.0.0 -> 2.0.0
```

The command changes the version in box.json. It moves the `[Unreleased]` notes into a dated
section for the new version. It does not create a commit.

Add `--dryRun` to see the changes without writing any files.

The `[Unreleased]` section must contain at least one note. An empty section stops the command
before it changes the version or changelog. Add a simple note such as `- Maintenance release`
when there are no specific user-facing changes.

For the first `1.0.0` release, box.json may already contain `1.0.0`. Use this command to date
the notes without changing the version:

```
box release bump none
```

#### Alpha, beta, and other prereleases

Version numbers follow SemVer. A prerelease such as `1.2.0-beta.3` comes before `1.2.0`.
Finishing that beta produces `1.2.0`, not `1.2.1`.

```
box release bump preminor beta     # start:  1.1.0 -> 1.2.0-beta.1
box release bump preminor alpha    # start with the alpha label
box release bump prerelease        # update: 1.2.0-beta.1 -> 1.2.0-beta.2
box release bump patch             # finish: 1.2.0-beta.2 -> 1.2.0
```

`preminor` starts a prerelease of the next minor version. Use `prepatch` or `premajor` to
start a prerelease of the next patch or major version:

```
box release bump prepatch     # 1.1.0 -> 1.1.1-beta.1
box release bump premajor     # 1.1.0 -> 2.0.0-beta.1
```

The command will not start the next minor prerelease while another prerelease is active. This
rule prevents an accidental change from `1.2.0-beta.3` to `1.3.0-beta.1`. Use
`box release bump prerelease` to update the active prerelease. Use
`--allowPrereleaseRetarget` only when you intend to change its target version.

Add a label after the level to use a different label. For example,
`box release bump preminor rc` starts an `rc` prerelease. You can also change the label of an
active prerelease without changing its main version. For example,
`box release bump prerelease beta` changes `1.2.0-alpha.7` to `1.2.0-beta.1`.

GitHub marks a version as a prerelease when the version contains a hyphen.

| Level | What it does |
| --- | --- |
| `patch`, `minor`, `major` | Changes a normal version. For an active prerelease, it finishes the version that the prerelease targets. |
| `prerelease` | Updates an active prerelease, such as `beta.3` to `beta.4`. |
| `prepatch`, `preminor`, `premajor` | Starts a prerelease. The default label is `beta`. `preminor` requires `--allowPrereleaseRetarget` to change the target of an active prerelease. |
| `none` | Keeps the version and dates the changelog. |

### 4. Review and commit

```
git status
git diff -- box.json CHANGELOG.md
git add box.json CHANGELOG.md
git diff --staged
git commit -m "Release 1.0.1"
git push origin <current-branch>
```

Replace `CHANGELOG.md`, `1.0.1`, and `<current-branch>` with your project's values.

If you use GitKraken or another Git app, perform the same actions in the app. Review box.json
and the changelog. Stage only those release files. Review the staged changes. Commit them as
`Release 1.0.1`, and then push the current branch.

- `git status` lists changed and new files.
- `git diff` shows changes that are not staged.
- `git add` selects the listed files for the next commit.
- `git diff --staged` shows the exact content of the next commit.
- `git commit` saves that content in the local repository. It does not upload anything.
- `git push` sends the commit to the named branch on the `origin` remote.

List files in `git add` instead of using `git commit -am`. The `-a` option does not include new
files. A new release file could be missing from the commit.

### 5. Practice the release

```
box release run --dryRun
```

The practice run performs all checks and builds the full package. It prints the publish, tag,
and push commands without running them. It does not send anything outside your computer.

You can run this command from a Gitflow `release/*` branch. It warns that the real release
must run from the configured production branch.

### 6. Publish the release

Start a test server first unless `runTests` is `false`:

```
box release run
```

This command checks the project and updates the local branch from the remote. It runs the
tests, builds and checks the package, publishes it, creates the version tag, and creates the
GitHub Release.

## Gitflow guide

Gitflow uses branches for different stages of development:

- `develop` collects completed features.
- `release/<version>` prepares one release.
- The production branch contains published releases.

The `branch` setting always names the production branch. A finished release must be merged
into both production and `develop`.

Use this order:

1. Update `develop`, and then create the release branch from it.
2. On the release branch, change the version and commit the version and changelog.
3. Test and practice the release on the release branch.
4. Merge the release branch into both production and `develop`.
5. Publish from production with the command that matches how the tag was created.

See Atlassian's
[Gitflow workflow guide](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow/)
for more information about the branch model.

### Use plain Git or pull requests

In this method, the release command creates the tag. This example releases `1.2.0`. Replace
the version and production branch with your own values.

1. Update `develop` and create the release branch:

   ```
   git switch develop
   git pull --ff-only origin develop
   git switch -c release/1.2.0
   ```

2. While on `release/1.2.0`, finish the notes and change the version:

   ```
   box release bump minor
   git diff -- box.json CHANGELOG.md
   git add box.json CHANGELOG.md
   git diff --staged
   git commit -m "Release 1.2.0"
   ```

   Push the release branch:

   ```
   git push -u origin release/1.2.0
   ```

3. Test and practice on the release branch:

   ```
   box release engines
   box release run --dryRun
   ```

4. Merge `release/1.2.0` into production and `develop`. Use pull requests when the repository
   requires review. Keep the release branch until both merges are complete.

5. Switch to the updated production branch and publish:

   ```
   git switch main
   git pull --ff-only origin main
   box release check
   box release run
   ```

6. After publishing, confirm that both merges are complete. Then delete the local and remote
   release branches if your pull request system did not delete them.

A Gitflow hotfix starts from production instead of `develop`. It usually changes the patch
version. Change the version on the `hotfix/<version>` branch, and merge the branch into both
production and `develop`.

### Use GitKraken

GitKraken's **Finish release** action merges the release into production and `develop`. It
also creates a tag. It cannot finish a release without a tag. Set the version tag prefix under
**Preferences > Gitflow** so it matches `tagPrefix` in build.json. The usual prefix is `v`.
See the [GitKraken Gitflow documentation](https://help.gitkraken.com/gitkraken-desktop/git-flow/).

1. Create `release/1.2.0` from `develop` in GitKraken.
2. On `release/1.2.0`, run `box release bump minor`. Review and commit the changed files.
3. Test the project and run `box release run --dryRun` on the release branch.
4. Select **Finish release**. GitKraken merges both branches and creates `v1.2.0`.
5. Push production and `develop`. Then switch to the updated production branch. You do not
   need to push `v1.2.0` when publishing from your computer because
   `release run --existingTag` can push it. Push the tag yourself when a GitHub Actions job
   will publish the release. The tag push starts that job.
6. Use only one publishing method:
   - Let the GitHub Actions job publish after you push the tag; or
   - Run `box release run --existingTag` on your computer.

`release run --existingTag` performs the normal checks, tests, package build, ForgeBox
publish, and GitHub Release creation. It does not create or move the tag. It checks the tag on
origin before publishing. It pushes a local-only tag right before creating the GitHub Release.
It stops before publishing when origin has the tag at another commit. The tag must point to
the checked-out production commit.

Do not run the normal `box release run` after GitKraken finishes the release. The normal
command creates its own tag, so it rejects a tag that already exists.

### Use the `git-flow` extension

These commands use the extension's
[documented release `finish` behavior](https://github.com/nvie/gitflow/blob/develop/git-flow-release)
and its `-n` option, which finishes without creating a tag.

Set the extension's version tag prefix to match `tagPrefix`. The default in this example is
`v`:

```
git config gitflow.prefix.versiontag v
```

Choose one method so only one tool creates the tag:

- To publish with the release command, run `git flow release finish -n 1.2.0`. Gitflow merges
  the release into both branches without creating a tag. Push production and `develop`.
  Switch to production and run `box release run`. The release command creates and pushes
  `v1.2.0`.
- To let Gitflow create the tag, run `git flow release finish 1.2.0`. Push production,
  `develop`, and `v1.2.0`. Let the tag-based GitHub Actions job publish it, or switch to
  production and run `box release run --existingTag`.

Do not run the normal tagging form of `git flow release finish` followed by
`box release run`. Both commands try to create the same tag. The release command stops because
the tag already exists.

### Handle a tag that exists before Finish

First check whether the tag exists only on your computer or was pushed to origin:

```
git fetch --tags origin
git show --no-patch --decorate v1.2.0
git ls-remote --tags origin refs/tags/v1.2.0
```

- If both merges are complete and `v1.2.0` points to production `HEAD`, do not run Finish
  again. Push any branches that still need to be pushed. Then use
  `box release run --existingTag`, or push the tag to start the GitHub Actions job.
- If a merge is missing, merge the release into production and `develop` by hand or with pull
  requests. Do not use a command that tries to create the tag again. The tag must point to the
  final production `HEAD` before `release run --existingTag` can publish it.
- If the tag was created by mistake and exists only on your computer, delete it before using
  GitKraken Finish. In GitKraken, right-click the tag and select **Delete locally**. On the
  command line, run `git tag -d v1.2.0`.
- If the tag is on origin, was already published, or points to another commit, do not delete
  or move it without checking. The version may already be in use. Review the release history.
  Use a new version or plan a specific repair with your team.

## Skip tests that already ran

```
box release run --skipTests
```

This works like `release run`, but it skips the test suite and prints a clear warning. It does
not create, merge, or finish a Gitflow hotfix branch.

## Finish a release after a failure

All checks that can stop a release run before publishing. A later step can still fail after a
package was published. Do not run the full release again in that case. The version is already
published, so the checks will stop. The failure message shows the exact commands to finish
the release.

Run this command when the tag was not created:

```
box release github version=1.0.1
```

Run this command when the failure message says that the tag was already pushed:

```
box release github version=1.0.1 --existingTag
```

Run `box release notes 1.0.1` to see the notes for one version.

## Common problems

| Message | How to fix it |
| --- | --- |
| `Command "release" cannot be resolved` | Install the module with `box install build-template`. |
| `This project requires build-template X or newer` | Run `box update build-template --system`. |
| `You have uncommitted changes` | Commit or stash the changes first. The release will not replace uncommitted work. |
| `The test server ... did not answer` | Start the server, or set `runTests` to `false` in build.json. |
| `Could not find the GitHub CLI` | Install it and open a new terminal. A terminal uses the PATH value from when it started. |
| `Permission denied (publickey)` | Git cannot sign in to the remote. Add your SSH key to GitHub, or use an HTTPS remote. |
| `does not have a "## [1.0.1]" section` | Run `box release bump` to move the notes into a dated section. |
| `The "## [Unreleased]" section is empty` | Write at least one release note. No files were changed. |
| `is not a prerelease` | Use `box release bump preminor beta` to start a prerelease. |
| `is already a prerelease. preminor cannot change its target` | Use `box release bump prerelease`. Add `--allowPrereleaseRetarget` only when you intend to change the target version. |
| `Tag v1.0.1 already exists` | That version was already released. Use a new version. |
| `Tag v1.0.1 already exists on origin` | Fetch the tags and use a version that was not published. |
| `Tag v1.0.1 points to a different commit on origin` | The local and remote tags point to different commits. Do not move the published tag. Check the release history or use a new version. |
| `Tag v1.0.1 is local only` | No action is needed. `release run --existingTag` pushes the tag before creating the GitHub Release. |
| `Tag v1.0.1 does not point to the current commit` | A tag-based build checked out the wrong source. Check the workflow reference and version. |

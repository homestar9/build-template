/**
 * Checks, builds, and publishes one project version.
 *
 * `box release run` checks the repository first. It updates the production branch, builds the
 * package, and publishes to ForgeBox when enabled. It then creates a Git tag and a GitHub
 * Release when enabled.
 *
 * All checks run before the command publishes or pushes anything. If a later step fails, the
 * command prints the steps for finishing the same release. Use `--dryRun` to build and check
 * without publishing, creating a tag, or pushing.
 *
 * `--existingTag` publishes a tag created by another tool, such as Gitflow. It never creates
 * or moves the tag. It pushes a local-only tag right before creating the GitHub Release.
 */
component extends="build-template.models.BaseKitService" {

	property name="changelogService" inject="ChangelogService@build-template";

	/**
	 * Runs the full release process in the required order.
	 *
	 * @version     The release version. The default is the box.json version.
	 * @dryRun      Builds and checks without publishing, tagging, or pushing. It prints skipped steps.
	 * @skipTests   Skips the tests. Use only when the current version was already tested.
	 * @existingTag Publishes a tag that already points to HEAD. Tag-based CI uses this option.
	 * @buildID     An optional build ID for the package. CI uses its run number.
	 */
	function run(
		string version      = "",
		boolean dryRun      = false,
		boolean skipTests   = false,
		boolean existingTag = false,
		string buildID      = ""
	){
		var releaseVersion = len( trim( arguments.version ) ) ? trim( arguments.version ) : variables.config.version();
		var tagName        = variables.settings.tagPrefix & releaseVersion;

		if ( arguments.dryRun ) {
			print
				.line()
				.boldYellowLine( "PRACTICE RUN: Nothing will be published, tagged, or pushed." )
				.line()
				.toConsole();
		}

		// 1. Run every check before publishing or pushing anything.
		preflight(
			version     = releaseVersion,
			dryRun      = arguments.dryRun,
			existingTag = arguments.existingTag
		);

		// 2. Update a branch-based release from the remote. A practice run does not update the
		//    branch. A tag-based release must build the exact commit that is already checked out.
		if ( variables.settings.gitSync && !arguments.dryRun && !arguments.existingTag ) {
			syncWithRemote();
		} else if ( arguments.existingTag ) {
			print.greenLine( "Using existing tag #tagName# at the current commit. Skipping the branch update." ).toConsole();
		} else if ( variables.settings.gitSync ) {
			print.yellowLine( "Practice run: git pull was not run." ).toConsole();
		}

		// 3. Build the package. Failed tests stop the release.
		runBuild( releaseVersion, arguments.skipTests, arguments.buildID );

		// 4. Publish to ForgeBox from the checked build folder.
		if ( variables.settings.publish.forgebox ) {
			publishToForgebox( releaseVersion, arguments.dryRun );
		} else {
			print.line().yellowLine( "ForgeBox publish skipped because publish.forgebox is false in build.json." ).toConsole();
		}

		// 5. Create the tag and GitHub Release.
		if ( variables.settings.publish.github ) {
			github(
				version     = releaseVersion,
				dryRun      = arguments.dryRun,
				existingTag = arguments.existingTag
			);
		} else {
			print.yellowLine( "GitHub publish skipped because publish.github is false in build.json." ).toConsole();
		}

		print.line().toConsole();
		if ( arguments.dryRun ) {
			print
				.boldGreenLine( "Practice run complete. Nothing was published." )
				.line( "The package was built and checked. Run box release run to publish it." )
				.toConsole();
		} else {
			print.boldGreenLine( "Released #tagName#." ).toConsole();
		}
	}

	/**
	 * Runs every check required before publishing or pushing.
	 *
	 * @version     The release version.
	 * @dryRun      Allows conditions that are safe only during a practice run.
	 * @existingTag Requires the expected tag at HEAD instead of requiring no local tag.
	 */
	function preflight( string version = "", boolean dryRun = false, boolean existingTag = false ){
		var releaseVersion = len( trim( arguments.version ) ) ? trim( arguments.version ) : variables.config.version();

		print.boldBlueLine( "=== Checking ===" ).toConsole();
		var repositoryStatus = checkRepository();
		checkWorkingTree( repositoryStatus, arguments.dryRun );
		var branchName = checkReleaseBranch( arguments.existingTag, arguments.dryRun );

		var tagName   = variables.settings.tagPrefix & releaseVersion;
		var remoteTag = checkVersionTag( tagName, arguments.existingTag );
		checkReleaseChangelog( releaseVersion );
		checkGitHubCli( arguments.dryRun );

		printPreflightSummary(
			branchName,
			releaseVersion,
			tagName,
			arguments.dryRun,
			arguments.existingTag,
			remoteTag.status
		);
	}

	/**
	 * Prints release notes for one version without publishing.
	 *
	 * @version The version to show. The default is the box.json version.
	 */
	function notes( string version = "" ){
		return github( version = arguments.version, notesOnly = true );
	}

	// PREFLIGHT CHECKS

	private struct function checkRepository(){
		var status = variables.config.execNative( "git", [ "status", "--porcelain" ] );
		if ( status.exitCode == 127 ) {
			return stop( "Git was not found. Install it, or open a new terminal if you installed it recently." );
		}
		if ( status.exitCode != 0 ) {
			return stop( "Git could not read this folder (#status.output#). Check that it is a Git repository." );
		}
		return status;
	}

	private void function checkWorkingTree( required struct status, required boolean dryRun ){
		if ( variables.settings.requireCleanTree && len( trim( status.output ) ) ) {
			if ( arguments.dryRun ) {
				print
					.yellowLine( "  note  There are uncommitted changes. A real release would stop." )
					.toConsole();
			} else {
				return fail(
					"You have uncommitted changes. Commit or stash them, and then run this command again.",
					listToArray( status.output, chr( 10 ) ),
					"Uncommitted"
				);
			}
		}
	}

	private string function checkReleaseBranch( required boolean existingTag, required boolean dryRun ){
		var branch = variables.config.execNative( "git", [ "rev-parse", "--abbrev-ref", "HEAD" ] );
		if ( branch.exitCode != 0 ) {
			return stop( "Git could not identify the current branch (#branch.output#)." );
		}
		var branchName = trim( branch.output );
		if ( arguments.existingTag && branchName != variables.settings.branch && branchName != "HEAD" ) {
			return stop(
				"An existing-tag release must run from production branch #variables.settings.branch# or a detached tag checkout. "
				& "The current branch is #branchName#."
			);
		} else if ( !arguments.existingTag && branchName != variables.settings.branch && arguments.dryRun ) {
			print
				.boldYellowLine( "  warning  This practice run is on #branchName#, not production branch #variables.settings.branch#." )
				.yellowLine( "           Run the real release from #variables.settings.branch#." )
				.toConsole();
		} else if ( !arguments.existingTag && branchName != variables.settings.branch ) {
			return stop(
				"Releases must run from production branch #variables.settings.branch#. The current branch is #branchName#. "
				& "Switch branches or change ""branch"" in build.json."
			);
		}
		return branchName;
	}

	/**
	 * Checks the release tag locally and on origin. It returns the origin status so the summary
	 * can report whether the tag must be pushed.
	 */
	private struct function checkVersionTag( required string tagName, required boolean existingTag ){
		if ( arguments.existingTag ) {
			requireExistingTagAtHead( arguments.tagName );
			return checkExistingTagOnOrigin( arguments.tagName );
		}

		var tagCheck = variables.config.execNative( "git", [ "rev-parse", "-q", "--verify", "refs/tags/" & arguments.tagName ] );
		if ( tagCheck.exitCode == 0 ) {
			var tagCommit = variables.config.execNative( "git", [ "rev-list", "-n", "1", "refs/tags/" & arguments.tagName ] );
			if ( tagCommit.exitCode == 0 && trim( tagCommit.output ) == headCommit() ) {
				return stop(
					"Tag #arguments.tagName# already points to this commit. If Gitflow or GitKraken created the tag, "
					& "publish it with: box release run --existingTag"
				);
			}
			return stop(
				"Local tag #arguments.tagName# points to a different commit. Do not move a published tag. "
				& "Check the tag and release history, or use a new version."
			);
		}

		var remoteTag = remoteTagState( arguments.tagName );
		if ( remoteTag.status == "present" ) {
			return stop(
				"Tag #arguments.tagName# already exists on origin. Fetch the tags first. If Gitflow created it "
				& "for this release, check out its production commit and run box release run --existingTag. "
				& "Otherwise, use a new version."
			);
		}
		if ( remoteTag.status == "unknown" ) {
			return stop( "Origin could not be checked for tag #arguments.tagName# (#remoteTag.output#). Nothing was published." );
		}
		return remoteTag;
	}

	/**
	 * Checks an existing tag on origin after confirming that the local tag points to HEAD. A
	 * missing remote tag can be pushed later. A remote tag at another commit stops the release
	 * because a published tag must not move.
	 */
	private struct function checkExistingTagOnOrigin( required string tagName ){
		var remoteTag = remoteTagState( arguments.tagName );
		if ( remoteTag.status == "unknown" ) {
			return stop( "Origin could not be checked for tag #arguments.tagName# (#remoteTag.output#). Nothing was published." );
		}
		if ( remoteTag.status == "present" && remoteTag.commit != headCommit() ) {
			return stop(
				"Tag #arguments.tagName# points to a different commit on origin. Do not move a published tag. "
				& "Check the tag and release history, or use a new version."
			);
		}
		if ( remoteTag.status == "missing" ) {
			print
				.yellowLine( "  note  Tag #arguments.tagName# is local only. It will be pushed before the GitHub Release." )
				.toConsole();
		}
		return remoteTag;
	}

	private void function checkReleaseChangelog( required string releaseVersion ){
		if ( variables.settings.publish.github ) {
			extractChangelogSection( arguments.releaseVersion );
		}
	}

	private void function checkGitHubCli( required boolean dryRun ){
		if ( variables.settings.publish.github && !arguments.dryRun ) {
			var ghCheck = variables.config.execNative( "gh", [ "auth", "status" ] );
			if ( ghCheck.exitCode == 127 ) {
				return fail(
					"Could not find the GitHub CLI (gh).",
					[
						"Install it from https://cli.github.com. Then run: gh auth login",
						"",
						"If you just installed it, open a new terminal. A terminal keeps the PATH",
						"value from when it started and cannot see later changes."
					]
				);
			}
			if ( ghCheck.exitCode != 0 ) {
				return fail(
					"The GitHub CLI is not signed in. Nothing was published.",
					[ "gh auth login", "", "GitHub CLI output: " & ghCheck.output ]
				);
			}
		}
	}

	private void function printPreflightSummary(
		required string branchName,
		required string releaseVersion,
		required string tagName,
		required boolean dryRun,
		required boolean existingTag,
		string remoteTagStatus = ""
	){
		if ( arguments.existingTag ) {
			print.greenLine( "  ok  existing tag #arguments.tagName# points to the current commit" ).toConsole();
			if ( arguments.remoteTagStatus == "missing" ) {
				print.yellowLine( "  note  tag #arguments.tagName# is local only and will be pushed to origin" ).toConsole();
			} else {
				print.greenLine( "  ok  tag #arguments.tagName# is on origin" ).toConsole();
			}
			print.greenLine( "  ok  existing-tag release" ).toConsole();
		} else {
			print
				.greenLine( "  ok  clean checkout#( arguments.branchName == variables.settings.branch ? " on " & variables.settings.branch : "" )#" )
				.greenLine( "  ok  #arguments.releaseVersion# has not been released" )
				.toConsole();
		}
		print
			.greenLine( variables.settings.publish.github ? "  ok  changelog entry found" : "  --  changelog not needed" )
			.greenLine( variables.settings.publish.github && !arguments.dryRun ? "  ok  GitHub CLI ready" : "  --  GitHub CLI not needed" )
			.toConsole();
	}

	/**
	 * Creates and pushes a release tag. It creates a GitHub Release with changelog notes and
	 * attaches the built zip file.
 *
	 * `box release github` calls this function to finish a release that stopped after publishing.
	 *
	 * @version     The release version.
	 * @notesOnly   Prints release notes without creating or pushing a tag.
	 * @dryRun      Prints the commands without running them.
	 * @existingTag Uses a tag that already exists. It pushes the tag when origin does not have it.
	 */
	function github(
		string version      = "",
		boolean notesOnly   = false,
		boolean dryRun      = false,
		boolean existingTag = false
	){
		var releaseVersion = len( trim( arguments.version ) ) ? trim( arguments.version ) : variables.config.version();
		var tagName        = variables.settings.tagPrefix & releaseVersion;
		if ( arguments.existingTag ) {
			requireExistingTagAtHead( tagName );
		}

		var releaseNotes = extractChangelogSection( releaseVersion );
		if ( arguments.notesOnly ) {
			print.line().boldLine( "Release notes for #tagName#:" ).line( releaseNotes ).toConsole();
			return;
		}

		var ghArgs = buildGitHubArguments( releaseVersion, tagName, releaseNotes );

		if ( arguments.dryRun ) {
			return printGitHubDryRun( tagName, ghArgs, releaseNotes, arguments.existingTag );
		}

		return publishGitHubRelease( tagName, ghArgs, arguments.existingTag );
	}

	// GITHUB RELEASE STEPS

	private array function buildGitHubArguments(
		required string releaseVersion,
		required string tagName,
		required string notes
	){
		var projectSlug = variables.config.slug();
		var zipPath = variables.config.repoPath(
			"#variables.settings.artifactsDir#/#projectSlug#/#arguments.releaseVersion#/#projectSlug#-#arguments.releaseVersion#.zip"
		);
		if ( !fileExists( zipPath ) ) {
			return stop( "The built zip file is missing at #zipPath#. Build it first: box release package" );
		}

		// Give the notes to GitHub CLI as a file so their Markdown does not change.
		var notesFile = variables.config.repoPath( "#variables.settings.stagingDir#/release-notes.md" );
		if ( !directoryExists( getDirectoryFromPath( notesFile ) ) ) {
			directoryCreate( getDirectoryFromPath( notesFile ), true, true );
		}
		fileWrite( notesFile, arguments.notes );

		var ghArgs = [ "release", "create", arguments.tagName, "--title", arguments.tagName, "--notes-file", notesFile ];
		if ( isPrerelease( arguments.releaseVersion ) ) {
			ghArgs.append( "--prerelease" );
		}
		ghArgs.append( zipPath );

		var shaPath = zipPath & ".sha512";
		if ( fileExists( shaPath ) ) {
			ghArgs.append( shaPath );
		}
		return ghArgs;
	}

	private void function printGitHubDryRun(
		required string tagName,
		required array ghArgs,
		required string notes,
		required boolean existingTag
	){
		var preview = print.line().boldYellowLine( "Practice run. These commands would run next:" );
		if ( !arguments.existingTag ) {
			preview
				.line( "  git tag #arguments.tagName#" )
				.line( "  git push origin #variables.settings.branch#" )
				.line( "  git push origin #arguments.tagName#" );
		} else {
			var remoteTag = remoteTagState( arguments.tagName );
			if ( remoteTag.status == "missing" ) {
				preview.line( "  git push origin #arguments.tagName#" );
			} else if ( remoteTag.status == "unknown" ) {
				preview.yellowLine( "  (Origin could not be checked. A real release pushes #arguments.tagName# when it is missing.)" );
			}
		}
		preview
			.line( "  gh " & arrayToList( arguments.ghArgs, " " ) )
			.line()
			.boldLine( "Release notes for the practice run:" )
			.line( arguments.notes )
			.toConsole();
	}

	private void function publishGitHubRelease(
		required string tagName,
		required array ghArgs,
		required boolean existingTag
	){
		print.line().boldBlueLine( "=== Tagging and releasing on GitHub ===" ).toConsole();

		var result = { exitCode : 0, output : "" };
		if ( !arguments.existingTag ) {
			result = variables.config.execNative( "git", [ "tag", arguments.tagName ] );
			if ( result.exitCode != 0 ) {
				return stop( "Tag #arguments.tagName# could not be created: #result.output#" );
			}

			result = variables.config.execNative( "git", [ "push", "origin", variables.settings.branch ] );
			if ( result.exitCode != 0 ) {
				return failWithManualSteps( "The production branch could not be pushed (#result.output#).", arguments.tagName, arguments.ghArgs );
			}

			result = variables.config.execNative( "git", [ "push", "origin", arguments.tagName ] );
			if ( result.exitCode != 0 ) {
				return failWithManualSteps( "The tag could not be pushed (#result.output#).", arguments.tagName, arguments.ghArgs );
			}
		} else {
			pushExistingTagIfMissing( arguments.tagName, arguments.ghArgs );
		}

		result = variables.config.execNative( "gh", arguments.ghArgs );
		if ( result.exitCode != 0 ) {
			return fail(
				"The GitHub Release could not be created (#result.output#). The tag was already pushed.",
				[ "gh " & arrayToList( arguments.ghArgs, " " ) ],
				"Run this command to finish"
			);
		}

		print
			.greenLine(
				arguments.existingTag
					? "Created the GitHub Release for tag #arguments.tagName#."
					: "Created tag #arguments.tagName# and the GitHub Release."
			)
			.toConsole();
	}

	/**
	 * Pushes an existing tag when origin does not have it. This step runs right before creating
	 * the GitHub Release. It checks origin again because the github command can run by itself to
	 * finish a release that stopped earlier.
	 */
	private function pushExistingTagIfMissing( required string tagName, required array ghArgs ){
		var remoteTag = remoteTagState( arguments.tagName );
		if ( remoteTag.status == "unknown" ) {
			return failWithManualSteps(
				"Origin could not be checked for tag #arguments.tagName# (#remoteTag.output#).",
				arguments.tagName,
				arguments.ghArgs,
				false
			);
		}
		if ( remoteTag.status == "present" ) {
			if ( remoteTag.commit != headCommit() ) {
				return stop( "Tag #arguments.tagName# points to a different commit on origin. The release will not publish the wrong source." );
			}
			return;
		}

		var result = variables.config.execNative( "git", [ "push", "origin", arguments.tagName ] );
		if ( result.exitCode != 0 ) {
			return failWithManualSteps( "The tag could not be pushed (#result.output#).", arguments.tagName, arguments.ghArgs, false );
		}
		print.greenLine( "Pushed tag #arguments.tagName# to origin." ).toConsole();
		warnIfBranchNotOnOrigin();
	}

	/**
	 * Warns when the production branch may not include the pushed tag's commit. Pushing a tag
	 * sends its commit to origin, but it does not update the production branch.
	 */
	private void function warnIfBranchNotOnOrigin(){
		var branch  = variables.settings.branch;
		var unknown = "  warning  Could not confirm that #branch# is on origin. Push it if needed.";

		var remoteBranch = variables.config.execNative( "git", [ "ls-remote", "origin", "refs/heads/" & branch ] );
		if ( remoteBranch.exitCode != 0 || !len( trim( remoteBranch.output ) ) ) {
			print.yellowLine( unknown ).toConsole();
			return;
		}

		var remoteCommit = listFirst( listFirst( remoteBranch.output, chr( 10 ) ), chr( 9 ) );
		var ancestry     = variables.config.execNative( "git", [ "merge-base", "--is-ancestor", "HEAD", remoteCommit ] );
		if ( ancestry.exitCode == 1 ) {
			print
				.yellowLine( "  warning  origin/#branch# does not contain this commit. Push the branch: git push origin #branch#" )
				.toConsole();
		} else if ( ancestry.exitCode != 0 ) {
			print.yellowLine( unknown ).toConsole();
		}
	}

	// OTHER RELEASE HELPERS

	/**
	 * Checks that an existing lightweight or annotated tag points to the current commit. This
	 * prevents a recovery command from publishing files built from another commit.
	 */
	private function requireExistingTagAtHead( required string tagName ){
		var tagCheck = variables.config.execNative( "git", [ "rev-parse", "-q", "--verify", "refs/tags/" & arguments.tagName ] );
		if ( tagCheck.exitCode != 0 ) {
			return stop( "Existing-tag mode requires tag #arguments.tagName#, but this checkout does not contain it." );
		}

		var tagCommit = variables.config.execNative( "git", [ "rev-list", "-n", "1", "refs/tags/" & arguments.tagName ] );
		if ( tagCommit.exitCode != 0 || trim( tagCommit.output ) != headCommit() ) {
			return stop( "Tag #arguments.tagName# does not point to the current commit. The release will not publish the wrong source." );
		}
	}

	/**
	 * Checks one tag on origin without downloading it. The returned status is "present",
	 * "missing", or "unknown". A present tag also includes its commit.
 *
	 * git ls-remote prints each match as "<sha><tab><ref>". An annotated tag adds a second line
	 * ending in ^{}. The SHA on that line is the tagged commit. A lightweight tag already uses
	 * the commit SHA. Exit code 2 means that origin does not have the tag. Another nonzero code
	 * means that origin could not be checked.
	 */
	private struct function remoteTagState( required string tagName ){
		var result = variables.config.execNative(
			"git",
			[ "ls-remote", "--exit-code", "--tags", "origin", "refs/tags/" & arguments.tagName ]
		);
		if ( result.exitCode == 2 ) {
			return { status : "missing", commit : "", output : result.output };
		}
		if ( result.exitCode != 0 ) {
			return { status : "unknown", commit : "", output : result.output };
		}

		var commit = "";
		for ( var line in listToArray( result.output, chr( 10 ) ) ) {
			var sha = trim( listFirst( line, chr( 9 ) ) );
			var ref = trim( listLast( line, chr( 9 ) ) );
			if ( right( ref, 3 ) == "^{}" ) {
				commit = sha;
				break;
			}
			if ( ref == "refs/tags/" & arguments.tagName ) {
				commit = sha;
			}
		}
		return { status : "present", commit : commit, output : result.output };
	}

	/** Returns the full SHA for the current commit. */
	private string function headCommit(){
		var head = variables.config.execNative( "git", [ "rev-parse", "HEAD" ] );
		if ( head.exitCode != 0 ) {
			return stop( "Git could not identify the current commit (#head.output#)." );
		}
		return trim( head.output );
	}

	/**
	 * Builds the package and stops the release after a build failure.
	 *
	 * @version   The version to build.
	 * @skipTests Skips the tests.
	 * @buildID   An optional build ID for the package.
	 */
	private function runBuild( required string version, boolean skipTests = false, string buildID = "" ){
		print.line().boldBlueLine( "=== Building ===" ).toConsole();

		try {
			kitService( "PackageBuilder" ).run(
				version   = arguments.version,
				skipTests = arguments.skipTests,
				buildID   = arguments.buildID
			);
		} catch ( any exception ) {
			print.redLine( exception.message ).toConsole();
			return stop( "The build failed. Nothing was published." );
		}
	}

	/**
	 * Updates the current production branch with a fast-forward from origin. This includes remote
	 * changes without creating a merge commit. The earlier checks confirmed the branch and made
	 * sure there are no uncommitted changes.
	 */
	private function syncWithRemote(){
		print.line().boldBlueLine( "=== Updating from origin ===" ).toConsole();

		var result = variables.config.execNative( "git", [ "pull", "--ff-only", "origin", variables.settings.branch ] );
		if ( result.exitCode != 0 ) {
			var guidance = [ result.output ];
			if ( result.output contains "publickey" ) {
				guidance.append( "" );
				guidance.append( "Git cannot sign in to the remote. Add your SSH key at:" );
				guidance.append( "https://github.com/settings/ssh/new, or change the remote to HTTPS:" );
				guidance.append( "" );
				guidance.append( "  git remote set-url origin https://github.com/<you>/<repo>.git" );
				guidance.append( "  gh auth setup-git" );
			}
			return fail( "git pull failed.", guidance, "Git output" );
		}
		print.greenLine( "Up to date with origin/#variables.settings.branch#." ).toConsole();
	}

	/**
	 * Publishes the checked build folder instead of the project root.
 *
	 * Publishing the project root would use .gitignore when creating the package. A broad ignore
	 * rule could remove required source folders. The build folder contains the exact files that
	 * the package checks verified.
	 *
	 * @version The version to publish.
	 * @dryRun  Prints the publish commands without running them.
	 */
	private function publishToForgebox( required string version, boolean dryRun = false ){
		var slug       = variables.config.slug();
		var publishDir = variables.config.repoPath( "#variables.settings.stagingDir#/#slug#" );

		if ( arguments.dryRun ) {
			print
				.line()
				.boldYellowLine( "Practice run. These ForgeBox commands would run next:" )
				.line( "  cd #publishDir#" )
				.line( "  publish" )
				.toConsole();
			return;
		}

		if ( !directoryExists( publishDir ) ) {
			return stop( "The built package folder is missing at #publishDir#. Run the package build again." );
		}

		print.line().boldBlueLine( "=== Publishing to ForgeBox ===" ).toConsole();

		// Save the current folder so a failed publish does not leave CommandBox in the
		// temporary build folder.
		var originalDir = variables.shell.pwd();
		try {
			command( "publish" ).inWorkingDirectory( publishDir & "/" ).run();
		} catch ( any exception ) {
			return stop( "ForgeBox publishing failed (#exception.message#). Check your sign-in status: box forgebox whoami" );
		} finally {
			variables.shell.cd( originalDir );
		}

		print.greenLine( "Published #slug# #arguments.version# to ForgeBox." ).toConsole();
	}

	/**
	 * Stops after a late release failure and prints the commands needed to finish. The package
	 * may already be published, so running the full release again would fail its version checks.
	 *
	 * @reason            A description of the failure.
	 * @tagName           The release tag.
	 * @ghArgs            Arguments for the gh release command.
	 * @includeBranchPush Includes the branch push step. Existing-tag mode does not push a branch.
	 */
	private function failWithManualSteps(
		required string reason,
		required string tagName,
		required array ghArgs,
		boolean includeBranchPush = true
	){
		var steps = [];
		if ( arguments.includeBranchPush ) {
			steps.append( "git push origin " & variables.settings.branch );
		}
		steps.append( "git push origin " & arguments.tagName );
		steps.append( "gh " & arrayToList( arguments.ghArgs, " " ) );

		return fail(
			arguments.reason & " The package may already be published. Run the listed commands instead of starting the full release again.",
			steps,
			"Run these commands to finish"
		);
	}

	/** Returns release notes for one version from the configured changelog. */
	private string function extractChangelogSection( required string version ){
		var changelogPath = variables.config.repoPath( variables.settings.changelog );
		if ( !fileExists( changelogPath ) ) {
			return stop( "The project root does not contain #variables.settings.changelog#. Create it before releasing." );
		}

		try {
			return variables.changelogService.extractReleaseNotes(
				content       = fileRead( changelogPath ),
				version       = arguments.version,
				changelogName = variables.settings.changelog
			);
		} catch ( any exception ) {
			return stop( exception.message );
		}
	}

	/**
	 * Returns true when a version has a prerelease label after a hyphen, such as
	 * 1.0.0-beta.4. GitHub uses this result to mark a prerelease.
	 */
	private boolean function isPrerelease( required string version ){
		return find( "-", arguments.version ) > 0;
	}
}

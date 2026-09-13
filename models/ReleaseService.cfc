/**
 * Checks, builds, and publishes one project release.
 *
 * `box release run` checks the repository first. It then syncs the production branch, builds
 * the package, publishes to ForgeBox when enabled, creates a Git tag, and creates a GitHub
 * Release when enabled.
 *
 * The order protects the release. Every safe check runs before the first permanent publish.
 * If a later step fails, the task prints the commands needed to finish the same release.
 * Use `--dryRun` to build and check without publishing, tagging, or pushing.
 *
 * Existing-tag mode (`--existingTag`) publishes a tag another tool created, such as a Gitflow
 * finish. It never creates or moves that tag, but when origin does not have it yet the
 * release pushes it right before creating the GitHub Release, so a tag that was only pushed
 * locally cannot fail the release at its last step.
 */
component extends="build-template.models.BaseKitService" {

	property name="changelogService" inject="ChangelogService@build-template";

	/**
	 * Runs the complete release workflow in its required order.
	 *
	 * @version     The version to release. Defaults to the box.json version.
	 * @dryRun      Do everything except publish, tag, and push. Prints what it would have run.
	 * @skipTests   Skip the test suite. Use only when the current version has already been tested.
	 * @existingTag Publish a tag that already exists and points at HEAD. Used by tag-triggered CI.
	 * @buildID     Optional build identifier passed through to the package build. CI uses its run number.
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
				.boldYellowLine( "DRY RUN: nothing will be published, tagged, or pushed." )
				.line()
				.toConsole();
		}

		// 1. Checks. These run first so nothing permanent has happened if one fails.
		preflight(
			version     = releaseVersion,
			dryRun      = arguments.dryRun,
			existingTag = arguments.existingTag
		);

		// 2. Line up a branch-based release with the remote. A dry run changes nothing, and a
		//    tag-triggered release must build the immutable commit that is already checked out.
		if ( variables.settings.gitSync && !arguments.dryRun && !arguments.existingTag ) {
			syncWithRemote();
		} else if ( arguments.existingTag ) {
			print.greenLine( "Using existing tag #tagName# at the checked-out commit; skipping branch sync." ).toConsole();
		} else if ( variables.settings.gitSync ) {
			print.yellowLine( "Dry run: skipping git pull." ).toConsole();
		}

		// 3. Build. The suite runs here and stops the release if anything fails.
		runBuild( releaseVersion, arguments.skipTests, arguments.buildID );

		// 4. Publish to ForgeBox, from the built folder rather than the project root.
		if ( variables.settings.publish.forgebox ) {
			publishToForgebox( releaseVersion, arguments.dryRun );
		} else {
			print.line().yellowLine( "Skipping ForgeBox (publish.forgebox is false in build.json)." ).toConsole();
		}

		// 5. Tag and create the GitHub Release.
		if ( variables.settings.publish.github ) {
			github(
				version     = releaseVersion,
				dryRun      = arguments.dryRun,
				existingTag = arguments.existingTag
			);
		} else {
			print.yellowLine( "Skipping GitHub (publish.github is false in build.json)." ).toConsole();
		}

		print.line().toConsole();
		if ( arguments.dryRun ) {
			print
				.boldGreenLine( "Dry run finished. Nothing was published." )
				.line( "The package was built and checked. Run box release run when you are ready." )
				.toConsole();
		} else {
			print.boldGreenLine( "Released #tagName#." ).toConsole();
		}
	}

	/**
	 * Runs every check that must pass before the release can change remote systems.
	 *
	 * @version     The version being released.
	 * @dryRun      Soften the checks that only matter for a real release.
	 * @existingTag Require the expected tag at HEAD instead of requiring an untagged release branch.
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
	 * Prints the release notes for a version and stops.
	 *
	 * @version The version whose notes to show. Defaults to the box.json version.
	 */
	function notes( string version = "" ){
		return github( version = arguments.version, notesOnly = true );
	}

	// PREFLIGHT CHECKS

	private struct function checkRepository(){
		var status = variables.config.execNative( "git", [ "status", "--porcelain" ] );
		if ( status.exitCode == 127 ) {
			return stop( "Could not find git. Install it, or open a new terminal if you installed it recently." );
		}
		if ( status.exitCode != 0 ) {
			return stop( "git could not read this folder (#status.output#). Is it a git repository?" );
		}
		return status;
	}

	private void function checkWorkingTree( required struct status, required boolean dryRun ){
		if ( variables.settings.requireCleanTree && len( trim( status.output ) ) ) {
			if ( arguments.dryRun ) {
				print
					.yellowLine( "  note  you have uncommitted changes; a real release would stop here" )
					.toConsole();
			} else {
				return fail(
					"You have uncommitted changes. Commit or stash them, then run this again.",
					listToArray( status.output, chr( 10 ) ),
					"Uncommitted"
				);
			}
		}
	}

	private string function checkReleaseBranch( required boolean existingTag, required boolean dryRun ){
		var branch = variables.config.execNative( "git", [ "rev-parse", "--abbrev-ref", "HEAD" ] );
		if ( branch.exitCode != 0 ) {
			return stop( "git could not identify the checked-out branch (#branch.output#)." );
		}
		var branchName = trim( branch.output );
		if ( arguments.existingTag && branchName != variables.settings.branch && branchName != "HEAD" ) {
			return stop(
				"Existing-tag releases run from production branch #variables.settings.branch# or a detached tag checkout, "
				& "but you are on #branchName#."
			);
		} else if ( !arguments.existingTag && branchName != variables.settings.branch && arguments.dryRun ) {
			print
				.boldYellowLine( "  warning  rehearsing from #branchName#, not production branch #variables.settings.branch#" )
				.yellowLine( "           A real release still has to run from #variables.settings.branch#." )
				.toConsole();
		} else if ( !arguments.existingTag && branchName != variables.settings.branch ) {
			return stop(
				"Releases come from the production branch #variables.settings.branch#, but you are on #branchName#. "
				& "Switch branch, or change ""branch"" in build.json."
			);
		}
		return branchName;
	}

	/**
	 * Checks the release tag locally and on origin. Returns the origin state from
	 * remoteTagState() so the summary can say whether the tag still has to be pushed.
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
					"Tag #arguments.tagName# already exists at this commit. If Gitflow or GitKraken created it "
					& "intentionally, publish it with: box release run --existingTag"
				);
			}
			return stop(
				"Tag #arguments.tagName# already exists locally at a different commit. Do not move a published tag. "
				& "Verify the tag and release history, or choose a new version."
			);
		}

		var remoteTag = remoteTagState( arguments.tagName );
		if ( remoteTag.status == "present" ) {
			return stop(
				"Tag #arguments.tagName# already exists on origin. Fetch tags first. If a Gitflow tool created it "
				& "for this release, run box release run --existingTag from its tagged production "
				& "commit; otherwise the version is already claimed."
			);
		}
		if ( remoteTag.status == "unknown" ) {
			return stop( "Could not check origin for tag #arguments.tagName# (#remoteTag.output#). Nothing has been published." );
		}
		return remoteTag;
	}

	/**
	 * Existing-tag mode: the tag is already proven to sit at HEAD, so this decides what origin
	 * knows about it. A tag origin has never seen is fine and gets pushed later. A tag origin
	 * holds at a different commit is refused, because moving a published tag breaks everyone
	 * who already fetched it.
	 */
	private struct function checkExistingTagOnOrigin( required string tagName ){
		var remoteTag = remoteTagState( arguments.tagName );
		if ( remoteTag.status == "unknown" ) {
			return stop( "Could not check origin for tag #arguments.tagName# (#remoteTag.output#). Nothing has been published." );
		}
		if ( remoteTag.status == "present" && remoteTag.commit != headCommit() ) {
			return stop(
				"Tag #arguments.tagName# is on origin at a different commit. Do not move a published tag. "
				& "Verify the tag and release history, or choose a new version."
			);
		}
		if ( remoteTag.status == "missing" ) {
			print
				.yellowLine( "  note  tag #arguments.tagName# exists only in this checkout; it will be pushed to origin before the GitHub Release" )
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
						"Install it from https://cli.github.com, then run: gh auth login",
						"",
						"If you have just installed it, open a new terminal. A terminal keeps the",
						"PATH it started with, so a tool added afterwards looks missing until then."
					]
				);
			}
			if ( ghCheck.exitCode != 0 ) {
				return fail(
					"The GitHub CLI is not signed in, so stopping before anything is published.",
					[ "gh auth login", "", "What gh said: " & ghCheck.output ]
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
			print.greenLine( "  ok  existing tag #arguments.tagName# points to this commit" ).toConsole();
			if ( arguments.remoteTagStatus == "missing" ) {
				print.yellowLine( "  note  tag #arguments.tagName# is local only; it will be pushed to origin" ).toConsole();
			} else {
				print.greenLine( "  ok  tag #arguments.tagName# is on origin" ).toConsole();
			}
			print.greenLine( "  ok  existing-tag publish mode" ).toConsole();
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
	 * Tags the release, pushes it, and creates the GitHub Release with the changelog notes and
	 * the built zip attached.
	 *
	 * `box release github` runs this on its own to finish a release that stopped after publishing.
	 *
	 * @version     The version being released.
	 * @notesOnly   Print the release notes and stop. Nothing is tagged or pushed.
	 * @dryRun      Print what would run without doing it.
	 * @existingTag The expected tag already exists. It is pushed only if origin lacks it, then
	 *              the GitHub Release is created.
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
			return stop( "No built zip at #zipPath#. Build it first: box release package" );
		}

		// The GitHub CLI reads the notes from a file so their Markdown stays unchanged.
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
		var preview = print.line().boldYellowLine( "Dry run, would now run:" );
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
				preview.yellowLine( "  (could not check origin; a real run pushes #arguments.tagName# if origin lacks it)" );
			}
		}
		preview
			.line( "  gh " & arrayToList( arguments.ghArgs, " " ) )
			.line()
			.boldLine( "Release notes it would use:" )
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
				return stop( "Could not create tag #arguments.tagName#: #result.output#" );
			}

			result = variables.config.execNative( "git", [ "push", "origin", variables.settings.branch ] );
			if ( result.exitCode != 0 ) {
				return failWithManualSteps( "The push failed (#result.output#).", arguments.tagName, arguments.ghArgs );
			}

			result = variables.config.execNative( "git", [ "push", "origin", arguments.tagName ] );
			if ( result.exitCode != 0 ) {
				return failWithManualSteps( "Pushing the tag failed (#result.output#).", arguments.tagName, arguments.ghArgs );
			}
		} else {
			pushExistingTagIfMissing( arguments.tagName, arguments.ghArgs );
		}

		result = variables.config.execNative( "gh", arguments.ghArgs );
		if ( result.exitCode != 0 ) {
			return fail(
				"Creating the GitHub Release failed (#result.output#). The tag is already pushed.",
				[ "gh " & arrayToList( arguments.ghArgs, " " ) ],
				"Run this to finish"
			);
		}

		print
			.greenLine(
				arguments.existingTag
					? "Created the GitHub Release for existing tag #arguments.tagName#."
					: "Tagged #arguments.tagName# and created the GitHub Release."
			)
			.toConsole();
	}

	/**
	 * Existing-tag mode: pushes the tag when origin does not have it yet. This runs right before
	 * the GitHub Release, mirroring where the normal release pushes its own tag. The check is
	 * repeated here rather than reused from preflight because the github command also runs on
	 * its own to finish an interrupted release.
	 */
	private function pushExistingTagIfMissing( required string tagName, required array ghArgs ){
		var remoteTag = remoteTagState( arguments.tagName );
		if ( remoteTag.status == "unknown" ) {
			return failWithManualSteps(
				"Could not check origin for tag #arguments.tagName# (#remoteTag.output#).",
				arguments.tagName,
				arguments.ghArgs,
				false
			);
		}
		if ( remoteTag.status == "present" ) {
			if ( remoteTag.commit != headCommit() ) {
				return stop( "Tag #arguments.tagName# is on origin at a different commit. Refusing to publish the wrong source." );
			}
			return;
		}

		var result = variables.config.execNative( "git", [ "push", "origin", arguments.tagName ] );
		if ( result.exitCode != 0 ) {
			return failWithManualSteps( "Pushing the tag failed (#result.output#).", arguments.tagName, arguments.ghArgs, false );
		}
		print.greenLine( "Pushed tag #arguments.tagName# to origin." ).toConsole();
		warnIfBranchNotOnOrigin();
	}

	/**
	 * Pushing a tag sends its commit to origin, but not the production branch itself. A branch
	 * left behind is not a release problem, so this only warns.
	 */
	private void function warnIfBranchNotOnOrigin(){
		var branch  = variables.settings.branch;
		var unknown = "  warning  could not confirm #branch# is pushed to origin; push it if you have not.";

		var remoteBranch = variables.config.execNative( "git", [ "ls-remote", "origin", "refs/heads/" & branch ] );
		if ( remoteBranch.exitCode != 0 || !len( trim( remoteBranch.output ) ) ) {
			print.yellowLine( unknown ).toConsole();
			return;
		}

		var remoteCommit = listFirst( listFirst( remoteBranch.output, chr( 10 ) ), chr( 9 ) );
		var ancestry     = variables.config.execNative( "git", [ "merge-base", "--is-ancestor", "HEAD", remoteCommit ] );
		if ( ancestry.exitCode == 1 ) {
			print
				.yellowLine( "  warning  origin/#branch# does not contain this commit yet. Push the branch: git push origin #branch#" )
				.toConsole();
		} else if ( ancestry.exitCode != 0 ) {
			print.yellowLine( unknown ).toConsole();
		}
	}

	// OTHER RELEASE HELPERS

	/**
	 * Proves an existing lightweight or annotated tag resolves to the checked-out commit, so
	 * recovery commands cannot accidentally attach artifacts from a different commit.
	 */
	private function requireExistingTagAtHead( required string tagName ){
		var tagCheck = variables.config.execNative( "git", [ "rev-parse", "-q", "--verify", "refs/tags/" & arguments.tagName ] );
		if ( tagCheck.exitCode != 0 ) {
			return stop( "Existing-tag mode expected #arguments.tagName#, but that tag is not available in this checkout." );
		}

		var tagCommit = variables.config.execNative( "git", [ "rev-list", "-n", "1", "refs/tags/" & arguments.tagName ] );
		if ( tagCommit.exitCode != 0 || trim( tagCommit.output ) != headCommit() ) {
			return stop( "Tag #arguments.tagName# does not point at the checked-out commit. Refusing to publish the wrong source." );
		}
	}

	/**
	 * Asks origin about one tag without fetching anything. Returns a struct with status
	 * "present", "missing", or "unknown", and for a present tag the commit it points at.
	 *
	 * git ls-remote prints one line per match as "<sha><tab><ref>". An annotated tag adds a
	 * second line ending in ^{} whose sha is the tagged commit; a lightweight tag's sha already
	 * is the commit. Exit code 2 means origin answered but has no such tag. Anything else
	 * non-zero means origin could not be asked, which is a different problem.
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

	/** The checked-out commit's full sha. */
	private string function headCommit(){
		var head = variables.config.execNative( "git", [ "rev-parse", "HEAD" ] );
		if ( head.exitCode != 0 ) {
			return stop( "git could not identify the checked-out commit (#head.output#)." );
		}
		return trim( head.output );
	}

	/**
	 * Builds the package and stops the release if the build fails.
	 *
	 * @version   The version being built.
	 * @skipTests Skip the test suite.
	 * @buildID   Optional build identifier to pass through.
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
			return stop( "Stopping: the build failed, so nothing was published." );
		}
	}

	/**
	 * Fast-forwards the checked-out production branch, so the release includes remote work but
	 * never creates an accidental merge commit during publishing. Preflight has already proved
	 * this is the configured branch and nothing is uncommitted.
	 */
	private function syncWithRemote(){
		print.line().boldBlueLine( "=== Lining up with the remote ===" ).toConsole();

		var result = variables.config.execNative( "git", [ "pull", "--ff-only", "origin", variables.settings.branch ] );
		if ( result.exitCode != 0 ) {
			var guidance = [ result.output ];
			if ( result.output contains "publickey" ) {
				guidance.append( "" );
				guidance.append( "git cannot sign in to your remote. Either add your SSH key at" );
				guidance.append( "https://github.com/settings/ssh/new, or switch the remote to HTTPS:" );
				guidance.append( "" );
				guidance.append( "  git remote set-url origin https://github.com/<you>/<repo>.git" );
				guidance.append( "  gh auth setup-git" );
			}
			return fail( "git pull failed.", guidance, "What git said" );
		}
		print.greenLine( "Up to date with origin/#variables.settings.branch#." ).toConsole();
	}

	/**
	 * Publishes from the built folder rather than the project root.
	 *
	 * This matters. Publishing from the project root packages using .gitignore, and one broad
	 * ignore rule can quietly drop source folders from what people install. Publishing the
	 * folder the build produced sends exactly what the build checked.
	 *
	 * @version The version being published.
	 * @dryRun  Print what would run without doing it.
	 */
	private function publishToForgebox( required string version, boolean dryRun = false ){
		var slug       = variables.config.slug();
		var publishDir = variables.config.repoPath( "#variables.settings.stagingDir#/#slug#" );

		if ( arguments.dryRun ) {
			print
				.line()
				.boldYellowLine( "Dry run, would now publish to ForgeBox:" )
				.line( "  cd #publishDir#" )
				.line( "  publish" )
				.toConsole();
			return;
		}

		if ( !directoryExists( publishDir ) ) {
			return stop( "No built folder at #publishDir#. The build should have created it." );
		}

		print.line().boldBlueLine( "=== Publishing to ForgeBox ===" ).toConsole();

		// Remember where we were, so a failed publish cannot leave the shell inside the
		// staging folder.
		var originalDir = variables.shell.pwd();
		try {
			command( "publish" ).inWorkingDirectory( publishDir & "/" ).run();
		} catch ( any exception ) {
			return stop( "Publishing to ForgeBox failed (#exception.message#). Check you are signed in: box forgebox whoami" );
		} finally {
			variables.shell.cd( originalDir );
		}

		print.greenLine( "Published #slug# #arguments.version# to ForgeBox." ).toConsole();
	}

	/**
	 * Stops the release after the package may already be published, printing the exact commands
	 * that finish the job. Running the release again would refuse, because the version is out.
	 *
	 * @reason            What failed.
	 * @tagName           The tag for this release.
	 * @ghArgs            The arguments for the gh release command.
	 * @includeBranchPush List the branch push too. Existing-tag mode never pushes the branch.
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
			arguments.reason & " The package may already be published, so finish by hand rather than running the release again.",
			steps,
			"Run these to finish"
		);
	}

	/** Reads one version's release notes from the configured changelog. */
	private string function extractChangelogSection( required string version ){
		var changelogPath = variables.config.repoPath( variables.settings.changelog );
		if ( !fileExists( changelogPath ) ) {
			return stop( "No #variables.settings.changelog# in the project root. Create one before releasing." );
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
	 * A version with a hyphen, such as 1.0.0-beta.4, is a pre-release, so the GitHub Release
	 * is marked as one.
	 */
	private boolean function isPrerelease( required string version ){
		return find( "-", arguments.version ) > 0;
	}
}

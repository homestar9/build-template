/** Runs real release commands in temporary projects with local Git repositories. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "Release command integration", function(){
			beforeEach( function(){
				fixtureProcess = new tests.support.FixtureProcess( repoRoot() );
				fixtureRoot    = fixtureProcess.createProject();
				originRoot     = "";
			} );

			afterEach( function(){
				deleteDirectory( fixtureRoot );
				deleteDirectory( originRoot );
			} );

			it( "creates project settings without changing box.json scripts", function(){
				writeJSON(
					fixtureRoot & "/box.json",
					{
						name    : "Sample module",
						slug    : "sample-module",
						version : "1.0.0",
						type    : "commandbox-modules",
						testbox : { runner : "http://127.0.0.1:61000/tests/runner.cfm" },
						scripts : { "release" : "keep this command" }
					}
				);
				writeJSON( fixtureRoot & "/server-lucee@5.json", { app : { cfengine : "lucee@5" } } );

				var initResult = fixtureProcess.runKit( fixtureRoot, "release init" );
				expectCommand( initResult, "release init" );

				var packageData = deserializeJSON( fileRead( fixtureRoot & "/box.json" ) );
				var settings    = deserializeJSON( fileRead( fixtureRoot & "/build.json" ) );
				expect( packageData.scripts.release ).toBe( "keep this command" );
				expect( packageData.scripts ).notToHaveKey( "build:package" );
				expect( settings.projectType ).toBe( "module" );
				expect( settings.minimumKitVersion ).toBe( kitVersion() );
				expect( settings.testRunner ).toBe( "http://127.0.0.1:61000/tests/runner.cfm" );
				expect( settings.engines[ 1 ].name ).toBe( "Lucee 5" );
				expect( fileExists( fixtureRoot & "/CHANGELOG.md" ) ).toBeTrue();
				expect( fileExists( fixtureRoot & "/RELEASE.md" ) ).toBeFalse();

				var settingsBeforeSecondRun = fileRead( fixtureRoot & "/build.json" );
				expectCommand( fixtureProcess.runKit( fixtureRoot, "release init --docs" ), "the second release init" );
				expect( fileRead( fixtureRoot & "/build.json" ) ).toBe( settingsBeforeSecondRun );
				expect( fileExists( fixtureRoot & "/RELEASE.md" ) ).toBeTrue();

				writeJSON( fixtureRoot & "/build.json", { custom : true } );
				expectCommand( fixtureProcess.runKit( fixtureRoot, "release init --force" ), "the forced release init" );
				var forcedSettings = deserializeJSON( fileRead( fixtureRoot & "/build.json" ) );
				expect( forcedSettings ).toHaveKey( "projectType" );
				expect( forcedSettings ).notToHaveKey( "custom" );
			} );

			it( "shows a version change before applying the same change", function(){
				writeBasicProject( "1.2.3" );
				writeChangelog( true );
				var packageBefore   = fileRead( fixtureRoot & "/box.json" );
				var changelogBefore = fileRead( fixtureRoot & "/CHANGELOG.md" );

				var dryRun = fixtureProcess.runKit( fixtureRoot, "release bump patch --dryRun" );
				expectCommand( dryRun, "the version practice run" );
				expect( fileRead( fixtureRoot & "/box.json" ) ).toBe( packageBefore );
				expect( fileRead( fixtureRoot & "/CHANGELOG.md" ) ).toBe( changelogBefore );

				var bump = fixtureProcess.runKit( fixtureRoot, "release bump patch" );
				expectCommand( bump, "release bump patch" );
				expect( deserializeJSON( fileRead( fixtureRoot & "/box.json" ) ).version ).toBe( "1.2.4" );
				expect( fileRead( fixtureRoot & "/CHANGELOG.md" ) ).toInclude( versionHeading( "1.2.4" ) );
			} );

			it( "stops beta and alpha changes from changing an active prerelease target", function(){
				for ( var preid in [ "beta", "alpha" ] ) {
					writeBasicProject( "1.2.0-#preid#.3" );
					writeChangelog( true );
					var packageBefore = fileRead( fixtureRoot & "/box.json" );

					var guardedBump = fixtureProcess.runKit( fixtureRoot, "release bump preminor #preid#" );
					expect( guardedBump.exitCode ).notToBe( 0 );
					expect( guardedBump.output ).toInclude( "release bump prerelease" );
					expect( fileRead( fixtureRoot & "/box.json" ) ).toBe( packageBefore );
				}
			} );

			it( "changes a prerelease target when the flag allows it", function(){
				writeBasicProject( "1.2.0-rc.2" );
				writeChangelog( true );

				var guardedBump = fixtureProcess.runKit( fixtureRoot, "release bump preminor beta" );
				expect( guardedBump.exitCode ).notToBe( 0 );
				expect( guardedBump.output ).toInclude( "allowPrereleaseRetarget" );

				var allowedBump = fixtureProcess.runKit( fixtureRoot, "release bump preminor beta --allowPrereleaseRetarget" );
				expectCommand( allowedBump, "the allowed prerelease target change" );
				expect( deserializeJSON( fileRead( fixtureRoot & "/box.json" ) ).version ).toBe( "1.3.0-beta.1" );
			} );

			it( "starts a prerelease from a final version", function(){
				writeBasicProject( "1.0.0" );
				writeChangelog( true );
				var bump = fixtureProcess.runKit( fixtureRoot, "release bump preminor alpha" );
				expectCommand( bump, "the stable alpha bump" );
				expect( deserializeJSON( fileRead( fixtureRoot & "/box.json" ) ).version ).toBe( "1.1.0-alpha.1" );
			} );

			it( "builds and checks a zip with replaced values and excluded files", function(){
				writeBasicProject( "1.0.0" );
				fileWrite( fixtureRoot & "/version.txt", "@build.version@+@build.number@" );
				directoryCreate( fixtureRoot & "/tests", true, true );
				fileWrite( fixtureRoot & "/tests/not-shipped.txt", "excluded" );

				var buildResult = fixtureProcess.runKit(
					fixtureRoot,
					"release package projectName=sample version=1.0.0 buildID=abc1234 branch=master --skipTests"
				);
				expectCommand( buildResult, "release package" );

				var artifactRoot = fixtureRoot & "/.artifacts/sample/1.0.0";
				var zipPath      = artifactRoot & "/sample-1.0.0.zip";
				expect( fileExists( zipPath ) ).toBeTrue();
				expect( fileExists( zipPath & ".sha512" ) ).toBeTrue();
				expect( fileExists( zipPath & ".md5" ) ).toBeTrue();

				cfzip( action = "read", file = zipPath, entrypath = "version.txt", variable = "local.versionText" );
				expect( local.versionText ).toBe( "1.0.0+abc1234" );
				cfzip( action = "list", file = zipPath, name = "local.zipEntries" );
				var zipNames = valueArray( local.zipEntries.name ).toList( "," );
				expect( zipNames ).notToInclude( "tests/not-shipped.txt" );
				expect( zipNames ).notToInclude( "build.json" );
			} );

			it( "runs a release practice run without creating or pushing a tag", function(){
				writeBasicProject( "1.0.0", true );
				writeChangelog( false, "1.0.0" );
				fileWrite( fixtureRoot & "/source.txt", "release fixture" );
				createLocalGitRemote();

				var releaseResult = fixtureProcess.runKit( fixtureRoot, "release run version=1.0.0 --dryRun --skipTests" );
				expectCommand( releaseResult, "the release practice run" );
				expect( releaseResult.output ).toInclude( "Nothing will be published, tagged, or pushed" );
				expect( fixtureProcess.runGit( fixtureRoot, [ "tag", "--list" ] ).output ).toBe( "" );
				expect( fixtureProcess.runGit( originRoot, [ "tag", "--list" ] ).output ).toBe( "" );
			} );

			it( "finds the project when a command runs from a child folder", function(){
				writeBasicProject( "1.0.0" );
				directoryCreate( fixtureRoot & "/models", true, true );
				var checkResult = fixtureProcess.runKit( fixtureRoot & "/models", "release check" );
				expectCommand( checkResult, "release check from a subfolder" );
				expect( checkResult.output ).toInclude( "sample 1.0.0" );
			} );

			it( "practices an existing-tag release with a local-only tag", function(){
				writeTaggedReleaseProject();

				var releaseResult = runExistingTagDryRun();
				expectCommand( releaseResult, "the existing-tag practice run" );
				expect( releaseResult.output ).toInclude( "local only" );
				expect( releaseResult.output ).toInclude( "git push origin v1.0.0" );
				expect( fixtureProcess.runGit( originRoot, [ "tag", "--list" ] ).output ).toBe( "" );
			} );

			it( "reports when origin already has the existing tag", function(){
				writeTaggedReleaseProject();
				expectGit( fixtureProcess.runGit( fixtureRoot, [ "push", "origin", "v1.0.0" ] ) );

				var releaseResult = runExistingTagDryRun();
				expectCommand( releaseResult, "the existing-tag practice run" );
				expect( releaseResult.output ).toInclude( "is on origin" );
				expect( releaseResult.output ).notToInclude( "git push origin v1.0.0" );
			} );

			it( "stops when the existing tag points to another commit on origin", function(){
				writeTaggedReleaseProject();
				expectGit( fixtureProcess.runGit( fixtureRoot, [ "push", "origin", "v1.0.0" ] ) );
				fileWrite( fixtureRoot & "/later.txt", "a later commit" );
				expectGit( fixtureProcess.runGit( fixtureRoot, [ "add", "." ] ) );
				expectGit( fixtureProcess.runGit( fixtureRoot, [ "commit", "-m", "Later" ] ) );
				expectGit( fixtureProcess.runGit( fixtureRoot, [ "tag", "-f", "v1.0.0" ] ) );

				var releaseResult = runExistingTagDryRun();
				expect( releaseResult.exitCode ).notToBe( 0 );
				expect( releaseResult.output ).toInclude( "different commit" );
			} );

			// This command pushes the tag to the local bare origin. The next GitHub Release step
			// fails because gh is missing or no remote uses GitHub. The command stops there and
			// does not send data outside this computer.
			it( "pushes a local-only tag before it tries to create the GitHub Release", function(){
				writeTaggedReleaseProject();
				expectCommand( runExistingTagDryRun(), "the practice run that builds the zip" );

				var githubResult = fixtureProcess.runKit( fixtureRoot, "release github version=1.0.0 --existingTag" );
				expect( githubResult.exitCode ).notToBe( 0 );
				expect( githubResult.output ).toInclude( "Pushed tag v1.0.0 to origin" );
				expect( githubResult.output ).notToInclude( "git push origin master" );
				expect( fixtureProcess.runGit( originRoot, [ "tag", "--list" ] ).output ).toBe( "v1.0.0" );
			} );
		} );
	}

	private void function writeBasicProject( required string version, boolean publishGitHub = false ){
		fileWrite(
			fixtureRoot & "/box.json",
			'{"name":"Sample","slug":"sample","version":"#arguments.version#","type":"commandbox-modules"}'
		);
		writeJSON(
			fixtureRoot & "/build.json",
			{
				projectType     : "module",
				branch          : "master",
				changelog       : "CHANGELOG.md",
				testRunner      : "http://127.0.0.1:60299/tests/runner.cfm",
				runTests        : false,
				gitSync         : true,
				requireCleanTree: true,
				publish         : { forgebox : false, github : arguments.publishGitHub },
				excludes        : kit( "ProjectSettingsService" ).buildConfigDefaultExcludes(),
				excludesAdd     : [ "^build\.json$" ],
				engines         : []
			}
		);
	}

	private void function writeChangelog(
		boolean includeUnreleasedNote = false,
		string releasedVersion = ""
	){
		var lf      = chr( 10 );
		var heading = repeatString( chr( 35 ), 2 ) & " ";
		var content = heading & "[Unreleased]" & lf & lf;
		if ( arguments.includeUnreleasedNote ) {
			content &= "- Pending change" & lf & lf;
		}
		if ( len( arguments.releasedVersion ) ) {
			content &= heading & "[#arguments.releasedVersion#] - 2026-08-07" & lf & lf & "- Release notes" & lf;
		}
		fileWrite( fixtureRoot & "/CHANGELOG.md", content );
	}

	private string function versionHeading( required string version ){
		return repeatString( chr( 35 ), 2 ) & " [#arguments.version#]";
	}

	private void function writeTaggedReleaseProject(){
		writeBasicProject( "1.0.0", true );
		writeChangelog( false, "1.0.0" );
		fileWrite( fixtureRoot & "/source.txt", "release fixture" );
		createLocalGitRemote();
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "tag", "v1.0.0" ] ) );
	}

	private struct function runExistingTagDryRun(){
		return fixtureProcess.runKit( fixtureRoot, "release run version=1.0.0 --existingTag --dryRun --skipTests" );
	}

	private void function createLocalGitRemote(){
		originRoot = fixtureRoot & "-origin.git";
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "init" ] ) );
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "symbolic-ref", "HEAD", "refs/heads/master" ] ) );
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "config", "user.email", "tests@example.com" ] ) );
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "config", "user.name", "Build Kit Tests" ] ) );
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "add", "." ] ) );
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "commit", "-m", "Fixture" ] ) );
		directoryCreate( originRoot, true, true );
		expectGit( fixtureProcess.runGit( originRoot, [ "init", "--bare" ] ) );
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "remote", "add", "origin", originRoot ] ) );
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "push", "-u", "origin", "master" ] ) );
	}

	private void function expectGit( required struct result ){
		expectCommand( arguments.result, "Git" );
	}

	private void function expectCommand( required struct result, required string label ){
		if ( arguments.result.exitCode != 0 ) {
			throw(
				type    = "BuildKit.IntegrationCommand",
				message = "#arguments.label# failed with exit code #arguments.result.exitCode#.",
				detail  = arguments.result.output
			);
		}
	}
}

/** Runs public build tasks inside disposable projects and local Git repositories. */
component extends="testbox.system.BaseSpec" {

	function run(){
		describe( "Build task integration", function(){
			beforeEach( function(){
				fixtureProcess = new tests.support.FixtureProcess( findRepositoryRoot() );
				fixtureRoot    = fixtureProcess.createProject();
				originRoot     = "";
			} );

			afterEach( function(){
				deleteDirectory( fixtureRoot );
				deleteDirectory( originRoot );
			} );

			it( "installs detected settings without replacing an existing script", function(){
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

				var installResult = fixtureProcess.runBox(
					fixtureRoot,
					[ "task", "run", "taskFile=build/Install.cfc" ]
				);
				expectCommand( installResult, "Install.cfc" );

				var packageData = deserializeJSON( fileRead( fixtureRoot & "/box.json" ) );
				var settings    = deserializeJSON( fileRead( fixtureRoot & "/build/build.json" ) );
				expect( packageData.scripts.release ).toBe( "keep this command" );
				expect( packageData.scripts ).toHaveKey( "build:package" );
				expect( packageData.scripts ).toHaveKey( "build-kit:update" );
				expect( settings.templateVersion ).toBe( kitVersion() );
				expect( packageData.scripts[ "bump:beta" ] )
					.toBe( "task run taskFile=build/Bump.cfc :level=preminor :preid=beta" );
				expect( packageData.scripts[ "bump:alpha" ] )
					.toBe( "task run taskFile=build/Bump.cfc :level=preminor :preid=alpha" );
				expect( settings.projectType ).toBe( "module" );
				expect( settings.testRunner ).toBe( "http://127.0.0.1:61000/tests/runner.cfm" );
				expect( settings.engines[ 1 ].name ).toBe( "Lucee 5" );
				expect( fileExists( fixtureRoot & "/CHANGELOG.md" ) ).toBeTrue();
				expect( fileExists( fixtureRoot & "/RELEASE.md" ) ).toBeTrue();

				var settingsBeforeSecondRun = fileRead( fixtureRoot & "/build/build.json" );
				var secondRun = fixtureProcess.runBox(
					fixtureRoot,
					[ "task", "run", "taskFile=build/Install.cfc" ]
				);
				expectCommand( secondRun, "the second Install.cfc run" );
				expect( fileRead( fixtureRoot & "/build/build.json" ) ).toBe( settingsBeforeSecondRun );

				writeJSON( fixtureRoot & "/build/build.json", { custom : true } );
				var forcedRun = fixtureProcess.runBox(
					fixtureRoot,
					[ "task", "run", "taskFile=build/Install.cfc", ":force=true" ]
				);
				expectCommand( forcedRun, "the forced Install.cfc run" );
				var forcedSettings = deserializeJSON( fileRead( fixtureRoot & "/build/build.json" ) );
				expect( forcedSettings ).toHaveKey( "projectType" );
				expect( forcedSettings ).notToHaveKey( "custom" );
			} );

			it( "previews a bump without writing and then applies the same bump", function(){
				writeBasicProject( "1.2.3" );
				writeChangelog( true );
				var packageBefore   = fileRead( fixtureRoot & "/box.json" );
				var changelogBefore = fileRead( fixtureRoot & "/CHANGELOG.md" );

				var dryRun = fixtureProcess.runBox(
					fixtureRoot,
					[ "task", "run", "taskFile=build/Bump.cfc", ":level=patch", ":dryRun=true" ]
				);
				expectCommand( dryRun, "the Bump.cfc dry run" );
				expect( fileRead( fixtureRoot & "/box.json" ) ).toBe( packageBefore );
				expect( fileRead( fixtureRoot & "/CHANGELOG.md" ) ).toBe( changelogBefore );

				var bump = fixtureProcess.runBox(
					fixtureRoot,
					[ "task", "run", "taskFile=build/Bump.cfc", ":level=patch" ]
				);
				expectCommand( bump, "Bump.cfc" );
				expect( deserializeJSON( fileRead( fixtureRoot & "/box.json" ) ).version ).toBe( "1.2.4" );
				expect( fileRead( fixtureRoot & "/CHANGELOG.md" ) ).toInclude( versionHeading( "1.2.4" ) );
			} );

			it( "guards the beta and alpha preminor calls from retargeting an active prerelease", function(){
				for ( var preid in [ "beta", "alpha" ] ) {
					writeBasicProject( "1.2.0-#preid#.3" );
					writeChangelog( true );
					var packageBefore   = fileRead( fixtureRoot & "/box.json" );
					var changelogBefore = fileRead( fixtureRoot & "/CHANGELOG.md" );

					var guardedBump = fixtureProcess.runBox(
						fixtureRoot,
						[ "task", "run", "taskFile=build/Bump.cfc", ":level=preminor", ":preid=#preid#" ]
					);

					expect( guardedBump.exitCode ).notToBe( 0 );
					expect( guardedBump.output ).toInclude( "box run-script bump:prerelease" );
					expect( fileRead( fixtureRoot & "/box.json" ) ).toBe( packageBefore );
					expect( fileRead( fixtureRoot & "/CHANGELOG.md" ) ).toBe( changelogBefore );
				}
			} );

			it( "guards direct preminor calls and permits an explicit retarget", function(){
				writeBasicProject( "1.2.0-rc.2" );
				writeChangelog( true );
				var packageBefore   = fileRead( fixtureRoot & "/box.json" );
				var changelogBefore = fileRead( fixtureRoot & "/CHANGELOG.md" );

				var guardedBump = fixtureProcess.runBox(
					fixtureRoot,
					[ "task", "run", "taskFile=build/Bump.cfc", ":level=preminor", ":preid=beta" ]
				);
				expect( guardedBump.exitCode ).notToBe( 0 );
				expect( guardedBump.output ).toInclude( "allowPrereleaseRetarget=true" );
				expect( fileRead( fixtureRoot & "/box.json" ) ).toBe( packageBefore );
				expect( fileRead( fixtureRoot & "/CHANGELOG.md" ) ).toBe( changelogBefore );

				var allowedBump = fixtureProcess.runBox(
					fixtureRoot,
					[
						"task", "run", "taskFile=build/Bump.cfc", ":level=preminor", ":preid=beta",
						":allowPrereleaseRetarget=true"
					]
				);
				expectCommand( allowedBump, "the explicit prerelease retarget" );
				expect( deserializeJSON( fileRead( fixtureRoot & "/box.json" ) ).version )
					.toBe( "1.3.0-beta.1" );
			} );

			it( "starts beta and alpha prereleases from a stable version", function(){
				for ( var preid in [ "beta", "alpha" ] ) {
					writeBasicProject( "1.0.0" );
					writeChangelog( true );

					var bump = fixtureProcess.runBox(
						fixtureRoot,
						[ "task", "run", "taskFile=build/Bump.cfc", ":level=preminor", ":preid=#preid#" ]
					);
					expectCommand( bump, "the stable #preid# bump" );
					expect( deserializeJSON( fileRead( fixtureRoot & "/box.json" ) ).version )
						.toBe( "1.1.0-#preid#.1" );
				}
			} );

			it( "builds a checked ZIP with tokens and exclusions", function(){
				writeBasicProject( "1.0.0" );
				fileWrite( fixtureRoot & "/version.txt", "@build.version@+@build.number@" );
				directoryCreate( fixtureRoot & "/tests", true, true );
				fileWrite( fixtureRoot & "/tests/not-shipped.txt", "excluded" );

				var buildResult = fixtureProcess.runBox(
					fixtureRoot,
					[
						"task", "run", "taskFile=build/Build.cfc",
						":projectName=sample", ":version=1.0.0", ":buildID=abc1234",
						":branch=master", ":skipTests=true"
					]
				);
				expectCommand( buildResult, "Build.cfc" );

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
			} );

			it( "rehearses a release without creating or pushing a tag", function(){
				writeBasicProject( "1.0.0", true );
				writeChangelog( false, "1.0.0" );
				fileWrite( fixtureRoot & "/source.txt", "release fixture" );
				createLocalGitRemote();

				var releaseResult = fixtureProcess.runBox(
					fixtureRoot,
					[
						"task", "run", "taskFile=build/Release.cfc", "target=run",
						":version=1.0.0", ":dryRun=true", ":skipTests=true"
					]
				);
				expectCommand( releaseResult, "the Release.cfc dry run" );
				expect( releaseResult.output ).toInclude( "nothing will be published, tagged, or pushed" );
				expect( fixtureProcess.runGit( fixtureRoot, [ "tag", "--list" ] ).output ).toBe( "" );
				expect( fixtureProcess.runGit( originRoot, [ "tag", "--list" ] ).output ).toBe( "" );
			} );

			it( "rehearses an existing-tag release whose tag is only local", function(){
				writeTaggedReleaseProject();

				var releaseResult = runExistingTagDryRun();
				expectCommand( releaseResult, "the existing-tag dry run" );
				expect( releaseResult.output ).toInclude( "local only" );
				expect( releaseResult.output ).toInclude( "git push origin v1.0.0" );
				expect( fixtureProcess.runGit( originRoot, [ "tag", "--list" ] ).output ).toBe( "" );
			} );

			it( "reports an existing tag that origin already has", function(){
				writeTaggedReleaseProject();
				expectGit( fixtureProcess.runGit( fixtureRoot, [ "push", "origin", "v1.0.0" ] ) );

				var releaseResult = runExistingTagDryRun();
				expectCommand( releaseResult, "the existing-tag dry run" );
				expect( releaseResult.output ).toInclude( "is on origin" );
				expect( releaseResult.output ).notToInclude( "git push origin v1.0.0" );
			} );

			it( "refuses an existing tag that origin holds at a different commit", function(){
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

			// The github target really pushes the tag here, to the local bare origin. The GitHub
			// Release step after it cannot succeed: gh is either not installed or finds no GitHub
			// host among the remotes, so the run stops there and nothing leaves this machine.
			it( "pushes a local-only tag before creating the GitHub Release", function(){
				writeTaggedReleaseProject();
				expectCommand( runExistingTagDryRun(), "the dry run that builds the zip" );

				var githubResult = fixtureProcess.runBox(
					fixtureRoot,
					[
						"task", "run", "taskFile=build/Release.cfc", "target=github",
						":version=1.0.0", ":existingTag=true"
					]
				);
				expect( githubResult.exitCode ).notToBe( 0 );
				expect( githubResult.output ).toInclude( "Pushed tag v1.0.0 to origin" );
				expect( githubResult.output ).notToInclude( "git push origin master" );
				expect( fixtureProcess.runGit( originRoot, [ "tag", "--list" ] ).output ).toBe( "v1.0.0" );
			} );

			it( "updates the build kit from a local source without touching project settings", function(){
				writeBasicProject( "1.0.0" );
				var settings = deserializeJSON( fileRead( fixtureRoot & "/build/build.json" ) );
				settings[ "templateVersion" ] = "1.0.0";
				writeJSON( fixtureRoot & "/build/build.json", settings );

				var repositoryRoot = findRepositoryRoot();
				var doctorPath     = fixtureRoot & "/build/Doctor.cfc";
				fileWrite( doctorPath, fileRead( doctorPath ) & chr( 10 ) & "// tampered" );
				fileWrite( fixtureRoot & "/build/lib/Custom.cfc", "component {}" );
				var updateArguments = [ "task", "run", "taskFile=build/Update.cfc", ":source=" & repositoryRoot ];
				var dryRunArguments = duplicate( updateArguments );
				dryRunArguments.append( ":dryRun=true" );

				var dryRun = fixtureProcess.runBox( fixtureRoot, dryRunArguments );
				expectCommand( dryRun, "the Update.cfc dry run" );
				expect( dryRun.output ).toInclude( "update build/Doctor.cfc" );
				expect( fileRead( doctorPath ) ).toInclude( "// tampered" );

				var update = fixtureProcess.runBox( fixtureRoot, updateArguments );
				expectCommand( update, "Update.cfc" );
				expect( fileRead( doctorPath ) ).toBe( fileRead( repositoryRoot & "/build/Doctor.cfc" ) );
				expect( fileExists( fixtureRoot & "/build/lib/Custom.cfc" ) ).toBeTrue();
				expect( update.output ).toInclude( "1.0.0 -> " & kitVersion() );

				var updatedSettings = deserializeJSON( fileRead( fixtureRoot & "/build/build.json" ) );
				expect( updatedSettings.templateVersion ).toBe( kitVersion() );
				expect( updatedSettings.branch ).toBe( "master" );
				expect( updatedSettings.publish.forgebox ).toBeFalse();
				expect( deserializeJSON( fileRead( fixtureRoot & "/box.json" ) ).scripts ).toHaveKey( "build-kit:update" );

				var secondRun = fixtureProcess.runBox( fixtureRoot, updateArguments );
				expectCommand( secondRun, "the second Update.cfc run" );
				expect( secondRun.output ).toInclude( "already up to date" );
			} );
		} );
	}

	private string function kitVersion(){
		return deserializeJSON( fileRead( findRepositoryRoot() & "/build/build-kit.json" ) ).version;
	}

	private void function writeTaggedReleaseProject(){
		writeBasicProject( "1.0.0", true );
		writeChangelog( false, "1.0.0" );
		fileWrite( fixtureRoot & "/source.txt", "release fixture" );
		createLocalGitRemote();
		expectGit( fixtureProcess.runGit( fixtureRoot, [ "tag", "v1.0.0" ] ) );
	}

	private struct function runExistingTagDryRun(){
		return fixtureProcess.runBox(
			fixtureRoot,
			[
				"task", "run", "taskFile=build/Release.cfc", "target=run",
				":version=1.0.0", ":existingTag=true", ":dryRun=true", ":skipTests=true"
			]
		);
	}

	private string function findRepositoryRoot(){
		var buildPath = getComponentMetadata( "build.BuildConfig" ).path;
		return reReplace( reReplace( getDirectoryFromPath( buildPath ), "[\\/]$", "" ), "[\\/][^\\/]+$", "" );
	}

	private void function writeBasicProject( required string version, boolean publishGitHub = false ){
		fileWrite(
			fixtureRoot & "/box.json",
			'{"name":"Sample","slug":"sample","version":"#arguments.version#","type":"commandbox-modules"}'
		);
		writeJSON(
			fixtureRoot & "/build/build.json",
			{
				projectType     : "module",
				branch          : "master",
				changelog       : "CHANGELOG.md",
				testRunner      : "http://127.0.0.1:60299/tests/runner.cfm",
				runTests        : false,
				gitSync         : true,
				requireCleanTree: true,
				publish         : { forgebox : false, github : arguments.publishGitHub },
				excludes        : new build.lib.ProjectSettingsService().buildConfigDefaultExcludes(),
				excludesAdd     : [],
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
				message = "#arguments.label# returned exit code #arguments.result.exitCode#.",
				detail  = arguments.result.output
			);
		}
	}

	private void function writeJSON( required string path, required struct data ){
		fileWrite( arguments.path, serializeJSON( arguments.data ) );
	}

	/**
	 * Removes a fixture. On Windows, Dropbox and antivirus scanners briefly hold files that
	 * were just written, so the delete is retried and a leftover is tolerated: fixtures have
	 * unique names inside the ignored .test-work folder, so one left behind harms nothing.
	 */
	private void function deleteDirectory( required string path ){
		if ( !len( arguments.path ) || !directoryExists( arguments.path ) ) {
			return;
		}
		for ( var attempt = 1; attempt <= 5; attempt++ ) {
			try {
				directoryDelete( arguments.path, true );
				return;
			} catch ( any deleteFailure ) {
				sleep( 500 );
			}
		}
	}
}

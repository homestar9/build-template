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
		} );
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

	private void function deleteDirectory( required string path ){
		if ( len( arguments.path ) && directoryExists( arguments.path ) ) {
			directoryDelete( arguments.path, true );
		}
	}
}

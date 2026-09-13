/** Runs the migration command on a project that uses the 1.x layout. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "release migrate", function(){
			beforeEach( function(){
				fixtureProcess = new tests.support.FixtureProcess( repoRoot() );
				fixtureRoot    = fixtureProcess.createProject();
				new tests.support.LegacyKit().writeProject( fixtureRoot );
			} );

			afterEach( function(){
				deleteDirectory( fixtureRoot );
			} );

			it( "lists migration changes without applying them", function(){
				var dryRun = fixtureProcess.runKit( fixtureRoot, "release migrate --dryRun" );
				expectCommand( dryRun, "the migration practice run" );
				expect( dryRun.output ).toInclude( "build/build.json -> build.json" );
				expect( dryRun.output ).toInclude( "build/Release.cfc" );
				expect( dryRun.output ).toInclude( "scripts.release" );
				expect( fileExists( fixtureRoot & "/build.json" ) ).toBeFalse();
				expect( fileExists( fixtureRoot & "/build/Release.cfc" ) ).toBeTrue();
			} );

			it( "moves settings, removes old kit files, and updates scripts", function(){
				var migrate = fixtureProcess.runKit( fixtureRoot, "release migrate" );
				expectCommand( migrate, "release migrate" );

				var settings = deserializeJSON( fileRead( fixtureRoot & "/build.json" ) );
				expect( settings.minimumKitVersion ).toBe( kitVersion() );
				expect( settings ).notToHaveKey( "templateVersion" );
				expect( settings.branch ).toBe( "master" );
				expect( fileExists( fixtureRoot & "/build/build.json" ) ).toBeFalse();

				expect( fileExists( fixtureRoot & "/build/Release.cfc" ) ).toBeFalse();
				expect( fileExists( fixtureRoot & "/build/lib/VersionService.cfc" ) ).toBeFalse();
				expect( directoryExists( fixtureRoot & "/build/templates" ) ).toBeFalse();
				expect( fileExists( fixtureRoot & "/build/lib/Custom.cfc" ) ).toBeTrue();

				var scripts = deserializeJSON( fileRead( fixtureRoot & "/box.json" ) ).scripts;
				expect( scripts.release ).toBe( "release run" );
				expect( scripts[ "release:existing-tag" ] ).toBe( "release run --existingTag" );
				expect( scripts[ "release:check" ] ).toBe( "echo custom" );
				expect( scripts ).notToHaveKey( "build-kit:update" );

				var secondRun = fixtureProcess.runKit( fixtureRoot, "release migrate" );
				expectCommand( secondRun, "the second migrate" );
				expect( secondRun.output ).toInclude( "Nothing to migrate" );

				var check = fixtureProcess.runKit( fixtureRoot, "release check" );
				expectCommand( check, "release check after migrating" );
				expect( check.output ).toInclude( "settings: build.json" );
			} );
		} );
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

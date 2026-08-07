/** Tests setting defaults, overrides, validation, paths, and derived values. */
component extends="testbox.system.BaseSpec" {

	function run(){
		describe( "BuildConfig", function(){
			beforeEach( function(){
				fixtureRoot = createFixtureRoot();
			} );

			afterEach( function(){
				if ( directoryExists( fixtureRoot ) ) {
					directoryDelete( fixtureRoot, true );
				}
			} );

			it( "loads defaults and derives the test runner from box.json", function(){
				writePackage( { name : "Sample", slug : "sample", version : "1.2.3", testbox : { runner : "http://localhost:61000/tests" } } );
				writeSettings( {} );

				var config   = new build.BuildConfig( fixtureRoot & "/build" );
				var settings = config.getSettings();
				expect( settings.branch ).toBe( "main" );
				expect( settings.testRunner ).toBe( "http://localhost:61000/tests" );
				expect( config.slug() ).toBe( "sample" );
				expect( config.version() ).toBe( "1.2.3" );
				expect( config.probeUrl() ).toBe( "http://localhost:61000/" );
			} );

			it( "merges nested settings without losing sibling defaults", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { publish : { github : false }, excludesAdd : [ "^private$" ] } );

				var settings = new build.BuildConfig( fixtureRoot & "/build" ).getSettings();
				expect( settings.publish.github ).toBeFalse();
				expect( settings.publish.forgebox ).toBeTrue();
				expect( arrayToList( settings.excludesAdd ) ).toBe( "^private$" );
			} );

			it( "turns ForgeBox off by default for applications", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { projectType : "app" } );
				expect( new build.BuildConfig( fixtureRoot & "/build" ).getSettings().publish.forgebox )
					.toBeFalse();
			} );

			it( "keeps an explicit application ForgeBox choice", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { projectType : "app", publish : { forgebox : true } } );
				expect( new build.BuildConfig( fixtureRoot & "/build" ).getSettings().publish.forgebox )
					.toBeTrue();
			} );

			it( "rejects invalid settings with a direct message", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { projectType : "unknown" } );
				expect( function(){
					new build.BuildConfig( fixtureRoot & "/build" );
				} ).toThrow( type = "BuildConfig", regex = "projectType" );
			} );
		} );
	}

	private string function createFixtureRoot(){
		var root = getTempDirectory() & "build-template-tests-" & createUUID();
		directoryCreate( root & "/build", true, true );
		return root;
	}

	private void function writePackage( required struct packageData ){
		fileWrite( fixtureRoot & "/box.json", serializeJSON( arguments.packageData ) );
	}

	private void function writeSettings( required struct settings ){
		fileWrite( fixtureRoot & "/build/build.json", serializeJSON( arguments.settings ) );
	}
}

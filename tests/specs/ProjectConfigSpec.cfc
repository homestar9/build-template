/** Checks project setting defaults, overrides, errors, old files, and required kit versions. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "ProjectConfig", function(){
			beforeEach( function(){
				fixtureRoot = createTempProject();
			} );

			afterEach( function(){
				deleteDirectory( fixtureRoot );
			} );

			it( "loads defaults and reads the test runner from box.json", function(){
				writePackage( { name : "Sample", slug : "sample", version : "1.2.3", testbox : { runner : "http://localhost:61000/tests" } } );
				writeSettings( {} );

				var config   = kit( "ProjectConfig" ).load( fixtureRoot );
				var settings = config.getSettings();
				expect( settings.branch ).toBe( "main" );
				expect( settings.testRunner ).toBe( "http://localhost:61000/tests" );
				expect( config.slug() ).toBe( "sample" );
				expect( config.version() ).toBe( "1.2.3" );
				expect( config.probeUrl() ).toBe( "http://localhost:61000/" );
				expect( config.isLegacyLayout() ).toBeFalse();
				expect( config.configPath() ).toBe( fixtureRoot & "/build.json" );
			} );

			it( "keeps other defaults when one nested setting changes", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { publish : { github : false }, excludesAdd : [ "^private$" ] } );

				var settings = kit( "ProjectConfig" ).load( fixtureRoot ).getSettings();
				expect( settings.publish.github ).toBeFalse();
				expect( settings.publish.forgebox ).toBeTrue();
				expect( arrayToList( settings.excludesAdd ) ).toBe( "^private$" );
			} );

			it( "disables ForgeBox by default for applications", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { projectType : "app" } );
				expect( kit( "ProjectConfig" ).load( fixtureRoot ).getSettings().publish.forgebox ).toBeFalse();
			} );

			it( "keeps an application's explicit ForgeBox setting", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { projectType : "app", publish : { forgebox : true } } );
				expect( kit( "ProjectConfig" ).load( fixtureRoot ).getSettings().publish.forgebox ).toBeTrue();
			} );

			it( "reports invalid settings with a clear message", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { projectType : "unknown" } );
				expect( function(){
					kit( "ProjectConfig" ).load( fixtureRoot );
				} ).toThrow( type = "BuildConfig", regex = "projectType" );
			} );

			it( "reads and reports the old 1.x settings location", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				directoryCreate( fixtureRoot & "/build", true, true );
				fileWrite( fixtureRoot & "/build/build.json", serializeJSON( { branch : "master" } ) );

				var config = kit( "ProjectConfig" ).load( fixtureRoot );
				expect( config.getSettings().branch ).toBe( "master" );
				expect( config.isLegacyLayout() ).toBeTrue();
				expect( config.configPath() ).toBe( fixtureRoot & "/build/build.json" );
			} );

			it( "uses defaults when the project has no settings file", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				var config = kit( "ProjectConfig" ).load( fixtureRoot );
				expect( config.configPath() ).toBe( "" );
				expect( config.getSettings().projectType ).toBe( "module" );
			} );

			it( "stops when the project requires a newer kit", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { minimumKitVersion : "99.0.0" } );
				expect( function(){
					kit( "ProjectConfig" ).load( fixtureRoot );
				} ).toThrow( type = "BuildKit.KitTooOld", regex = "box update build-template" );

				writeSettings( { minimumKitVersion : "0.0.1" } );
				expect( kit( "ProjectConfig" ).load( fixtureRoot ).getSettings().minimumKitVersion ).toBe( "0.0.1" );
			} );

			it( "reads the installed kit version", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				expect( kit( "ProjectConfig" ).load( fixtureRoot ).kitVersion() ).toBe( kitVersion() );
			} );
		} );
	}

	private void function writePackage( required struct packageData ){
		fileWrite( fixtureRoot & "/box.json", serializeJSON( arguments.packageData ) );
	}

	private void function writeSettings( required struct settings ){
		fileWrite( fixtureRoot & "/build.json", serializeJSON( arguments.settings ) );
	}
}

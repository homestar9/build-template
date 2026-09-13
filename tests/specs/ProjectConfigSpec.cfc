/** Tests setting defaults, overrides, validation, the legacy location, and the kit version guard. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "ProjectConfig", function(){
			beforeEach( function(){
				fixtureRoot = createTempProject();
			} );

			afterEach( function(){
				deleteDirectory( fixtureRoot );
			} );

			it( "loads defaults and derives the test runner from box.json", function(){
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

			it( "merges nested settings without losing sibling defaults", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { publish : { github : false }, excludesAdd : [ "^private$" ] } );

				var settings = kit( "ProjectConfig" ).load( fixtureRoot ).getSettings();
				expect( settings.publish.github ).toBeFalse();
				expect( settings.publish.forgebox ).toBeTrue();
				expect( arrayToList( settings.excludesAdd ) ).toBe( "^private$" );
			} );

			it( "turns ForgeBox off by default for applications", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { projectType : "app" } );
				expect( kit( "ProjectConfig" ).load( fixtureRoot ).getSettings().publish.forgebox ).toBeFalse();
			} );

			it( "keeps an explicit application ForgeBox choice", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { projectType : "app", publish : { forgebox : true } } );
				expect( kit( "ProjectConfig" ).load( fixtureRoot ).getSettings().publish.forgebox ).toBeTrue();
			} );

			it( "rejects invalid settings with a direct message", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { projectType : "unknown" } );
				expect( function(){
					kit( "ProjectConfig" ).load( fixtureRoot );
				} ).toThrow( type = "BuildConfig", regex = "projectType" );
			} );

			it( "still reads the 1.x location and says so", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				directoryCreate( fixtureRoot & "/build", true, true );
				fileWrite( fixtureRoot & "/build/build.json", serializeJSON( { branch : "master" } ) );

				var config = kit( "ProjectConfig" ).load( fixtureRoot );
				expect( config.getSettings().branch ).toBe( "master" );
				expect( config.isLegacyLayout() ).toBeTrue();
				expect( config.configPath() ).toBe( fixtureRoot & "/build/build.json" );
			} );

			it( "works with no settings file at all", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				var config = kit( "ProjectConfig" ).load( fixtureRoot );
				expect( config.configPath() ).toBe( "" );
				expect( config.getSettings().projectType ).toBe( "module" );
			} );

			it( "refuses a project that needs a newer kit", function(){
				writePackage( { name : "Sample", version : "1.0.0" } );
				writeSettings( { minimumKitVersion : "99.0.0" } );
				expect( function(){
					kit( "ProjectConfig" ).load( fixtureRoot );
				} ).toThrow( type = "BuildKit.KitTooOld", regex = "box update build-template" );

				writeSettings( { minimumKitVersion : "0.0.1" } );
				expect( kit( "ProjectConfig" ).load( fixtureRoot ).getSettings().minimumKitVersion ).toBe( "0.0.1" );
			} );

			it( "knows its own version", function(){
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

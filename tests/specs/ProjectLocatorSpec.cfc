/** Tests how a command finds the project it should work on. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "ProjectLocator", function(){
			beforeEach( function(){
				fixtureRoot = createTempProject();
				locator     = kit( "ProjectLocator" );
			} );

			afterEach( function(){
				deleteDirectory( fixtureRoot );
			} );

			it( "finds the nearest folder with a box.json, from a subfolder too", function(){
				fileWrite( fixtureRoot & "/box.json", "{}" );
				directoryCreate( fixtureRoot & "/models/deep", true, true );

				expect( locator.findRoot( fixtureRoot ) ).toBe( fixtureRoot );
				expect( locator.findRoot( fixtureRoot & "/models/deep" ) ).toBe( fixtureRoot );
				expect( locator.findRoot( replace( fixtureRoot, "/", "\", "all" ) & "\" ) ).toBe( fixtureRoot );
			} );

			it( "stops at a repository root that has no box.json", function(){
				directoryCreate( fixtureRoot & "/.git", true, true );
				directoryCreate( fixtureRoot & "/src", true, true );
				expect( function(){
					locator.findRoot( fixtureRoot & "/src" );
				} ).toThrow( type = "BuildKit.NoProject" );
			} );

			it( "reports where the settings live", function(){
				expect( locator.configFile( fixtureRoot ).path ).toBe( "" );

				directoryCreate( fixtureRoot & "/build", true, true );
				fileWrite( fixtureRoot & "/build/build.json", "{}" );
				var legacy = locator.configFile( fixtureRoot );
				expect( legacy.legacy ).toBeTrue();
				expect( legacy.path ).toBe( fixtureRoot & "/build/build.json" );

				fileWrite( fixtureRoot & "/build.json", "{}" );
				var current = locator.configFile( fixtureRoot );
				expect( current.legacy ).toBeFalse();
				expect( current.path ).toBe( fixtureRoot & "/build.json" );
			} );
		} );
	}
}

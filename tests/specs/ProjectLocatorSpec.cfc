/** Checks how a command finds its project root and settings file. */
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

			it( "finds the nearest box.json from a child folder", function(){
				fileWrite( fixtureRoot & "/box.json", "{}" );
				directoryCreate( fixtureRoot & "/models/deep", true, true );

				expect( locator.findRoot( fixtureRoot ) ).toBe( fixtureRoot );
				expect( locator.findRoot( fixtureRoot & "/models/deep" ) ).toBe( fixtureRoot );
				expect( locator.findRoot( replace( fixtureRoot, "/", "\", "all" ) & "\" ) ).toBe( fixtureRoot );
			} );

			it( "stops at a Git root without box.json", function(){
				directoryCreate( fixtureRoot & "/.git", true, true );
				directoryCreate( fixtureRoot & "/src", true, true );
				expect( function(){
					locator.findRoot( fixtureRoot & "/src" );
				} ).toThrow( type = "BuildKit.NoProject" );
			} );

			it( "returns the current or old settings path", function(){
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

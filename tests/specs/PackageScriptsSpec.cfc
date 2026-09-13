/** Checks how migration changes 1.x box.json scripts to 2.0 commands. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "PackageScriptService", function(){
			beforeEach( function(){
				packageScripts = kit( "PackageScriptService" );
			} );

			it( "updates unchanged 1.x scripts and keeps project changes", function(){
				var scripts = packageScripts.legacyScripts();
				scripts[ "release:check" ] = "echo custom";
				var result = packageScripts.migrateScripts( { name : "Sample", scripts : scripts } );

				expect( result.packageData.scripts.release ).toBe( "release run" );
				expect( result.packageData.scripts[ "bump:beta" ] ).toBe( "release bump preminor beta" );
				expect( result.packageData.scripts[ "release:check" ] ).toBe( "echo custom" );
				expect( result.packageData.scripts ).notToHaveKey( "build-kit:update" );
				expect( result.rewritten ).toInclude( "release" );
				expect( result.rewritten ).notToInclude( "release:check" );
				expect( arrayToList( result.kept ) ).toBe( "release:check" );
				expect( arrayToList( result.removed ) ).toBe( "build-kit:update" );
			} );

			it( "does not report scripts that already use 2.0 commands", function(){
				var result = packageScripts.migrateScripts( { scripts : { "release" : "release run" } } );
				expect( result.packageData.scripts.release ).toBe( "release run" );
				expect( arrayLen( result.rewritten ) + arrayLen( result.removed ) + arrayLen( result.kept ) ).toBe( 0 );
			} );

			it( "removes 1.x scripts when requested", function(){
				var result = packageScripts.migrateScripts( { scripts : packageScripts.legacyScripts() }, true );
				expect( structCount( result.packageData.scripts ) ).toBe( 0 );
				expect( arrayLen( result.removed ) ).toBe( structCount( packageScripts.legacyScripts() ) );
			} );

			it( "handles box.json without scripts", function(){
				var result = packageScripts.migrateScripts( { name : "Sample" } );
				expect( result.packageData ).notToHaveKey( "scripts" );
				expect( arrayLen( result.rewritten ) ).toBe( 0 );
			} );
		} );
	}
}

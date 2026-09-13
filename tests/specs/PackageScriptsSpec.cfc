/** Tests how the 1.x box.json scripts are rewritten for 2.0. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "PackageScriptService", function(){
			beforeEach( function(){
				packageScripts = kit( "PackageScriptService" );
			} );

			it( "rewrites untouched 1.x scripts and keeps customised ones", function(){
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

			it( "leaves scripts that already hold the 2.0 commands out of every list", function(){
				var result = packageScripts.migrateScripts( { scripts : { "release" : "release run" } } );
				expect( result.packageData.scripts.release ).toBe( "release run" );
				expect( arrayLen( result.rewritten ) + arrayLen( result.removed ) + arrayLen( result.kept ) ).toBe( 0 );
			} );

			it( "removes the 1.x scripts when asked", function(){
				var result = packageScripts.migrateScripts( { scripts : packageScripts.legacyScripts() }, true );
				expect( structCount( result.packageData.scripts ) ).toBe( 0 );
				expect( arrayLen( result.removed ) ).toBe( structCount( packageScripts.legacyScripts() ) );
			} );

			it( "copes with a box.json that has no scripts", function(){
				var result = packageScripts.migrateScripts( { name : "Sample" } );
				expect( result.packageData ).notToHaveKey( "scripts" );
				expect( arrayLen( result.rewritten ) ).toBe( 0 );
			} );
		} );
	}
}

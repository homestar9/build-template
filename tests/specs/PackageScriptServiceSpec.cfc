/** Tests the box.json script list shared by the install and update tasks. */
component extends="testbox.system.BaseSpec" {

	function run(){
		describe( "PackageScriptService", function(){
			beforeEach( function(){
				packageScripts = new build.lib.PackageScriptService();
			} );

			it( "adds missing scripts without replacing an existing one", function(){
				var result = packageScripts.addMissingScripts( {
					name    : "Sample",
					scripts : { "release" : "keep this command" }
				} );

				expect( result.packageData.scripts.release ).toBe( "keep this command" );
				expect( result.packageData.scripts ).toHaveKey( "build-kit:update" );
				expect( result.packageData.scripts[ "build-kit:update" ] ).toBe( "task run taskFile=build/Update.cfc" );
				expect( arrayToList( result.existing ) ).toBe( "release" );
				expect( result.added ).notToInclude( "release" );
				expect( result.added ).toInclude( "release:existing-tag" );
			} );

			it( "creates the scripts block when box.json has none", function(){
				var result = packageScripts.addMissingScripts( { name : "Sample" } );
				expect( result.packageData ).toHaveKey( "scripts" );
				expect( arrayLen( result.added ) ).toBe( structCount( packageScripts.requiredScripts() ) );
				expect( arrayLen( result.existing ) ).toBe( 0 );
			} );

			it( "leaves the caller's struct unchanged", function(){
				var packageData = { name : "Sample" };
				packageScripts.addMissingScripts( packageData );
				expect( packageData ).notToHaveKey( "scripts" );
			} );
		} );
	}
}

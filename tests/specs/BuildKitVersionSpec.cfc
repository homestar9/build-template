/**
 * Keeps build/build-kit.json in step with box.json. The update task reports and stamps the
 * version from build-kit.json, so a forgotten bump would tell every project the wrong number.
 */
component extends="testbox.system.BaseSpec" {

	function run(){
		describe( "Build kit version", function(){
			it( "matches the box.json version", function(){
				var root           = repositoryRoot();
				var packageVersion = deserializeJSON( fileRead( root & "/box.json" ) ).version;
				var kitManifest    = deserializeJSON( fileRead( root & "/build/build-kit.json" ) );

				expect( kitManifest.version ).toBe( packageVersion );
				expect( kitManifest.repository ).toBe( "homestar9/build-template" );
			} );
		} );
	}

	private string function repositoryRoot(){
		var buildPath = getComponentMetadata( "build.BuildConfig" ).path;
		return reReplace( reReplace( getDirectoryFromPath( buildPath ), "[\\/]$", "" ), "[\\/][^\\/]+$", "" );
	}
}

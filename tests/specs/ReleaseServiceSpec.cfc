/** Checks how the release reads git's answer about a tag on origin, without touching a remote. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "Release remote tag state", function(){
			beforeEach( function(){
				release = prepareMock( kit( "ReleaseService" ) );
				config  = createStub();
				release.$property( propertyName = "config", propertyScope = "variables", mock = config );
				makePublic( release, "remoteTagState" );
			} );

			it( "reads the commit of a lightweight tag", function(){
				config.$( "execNative", { exitCode : 0, output : "abc123" & chr( 9 ) & "refs/tags/v1.0.0" } );
				var state = release.remoteTagState( "v1.0.0" );
				expect( state.status ).toBe( "present" );
				expect( state.commit ).toBe( "abc123" );
			} );

			it( "prefers the peeled commit of an annotated tag", function(){
				config.$(
					"execNative",
					{
						exitCode : 0,
						output   : "tag999" & chr( 9 ) & "refs/tags/v1.0.0" & chr( 10 )
							& "commit42" & chr( 9 ) & "refs/tags/v1.0.0^{}"
					}
				);
				expect( release.remoteTagState( "v1.0.0" ).commit ).toBe( "commit42" );
			} );

			it( "reports a tag origin does not have", function(){
				config.$( "execNative", { exitCode : 2, output : "" } );
				var state = release.remoteTagState( "v1.0.0" );
				expect( state.status ).toBe( "missing" );
				expect( state.commit ).toBe( "" );
			} );

			it( "reports when origin could not be asked", function(){
				config.$( "execNative", { exitCode : 128, output : "fatal: could not read from remote" } );
				var state = release.remoteTagState( "v1.0.0" );
				expect( state.status ).toBe( "unknown" );
				expect( state.output ).toInclude( "could not read" );
			} );
		} );
	}
}

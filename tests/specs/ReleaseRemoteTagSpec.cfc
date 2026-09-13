/** Checks how the tasks read git's tag listings, without touching a remote. */
component extends="testbox.system.BaseSpec" {

	function run(){
		describe( "Release remote tag state", function(){
			beforeEach( function(){
				task   = prepareMock( new build.Release() );
				config = createStub();
				task.$property( propertyName = "config", propertyScope = "variables", mock = config );
				makePublic( task, "remoteTagState" );
			} );

			it( "reads the commit of a lightweight tag", function(){
				config.$( "execNative", { exitCode : 0, output : "abc123" & chr( 9 ) & "refs/tags/v1.0.0" } );
				var state = task.remoteTagState( "v1.0.0" );
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
				expect( task.remoteTagState( "v1.0.0" ).commit ).toBe( "commit42" );
			} );

			it( "reports a tag origin does not have", function(){
				config.$( "execNative", { exitCode : 2, output : "" } );
				var state = task.remoteTagState( "v1.0.0" );
				expect( state.status ).toBe( "missing" );
				expect( state.commit ).toBe( "" );
			} );

			it( "reports when origin could not be asked", function(){
				config.$( "execNative", { exitCode : 128, output : "fatal: could not read from remote" } );
				var state = task.remoteTagState( "v1.0.0" );
				expect( state.status ).toBe( "unknown" );
				expect( state.output ).toInclude( "could not read" );
			} );
		} );

		describe( "Update tag selection", function(){
			beforeEach( function(){
				updateTask = prepareMock( new build.Update() );
				makePublic( updateTask, "parseTagListing" );
				makePublic( updateTask, "chooseTag" );
			} );

			it( "reads version tags and skips peeled and unrelated refs", function(){
				var listing = "a1" & chr( 9 ) & "refs/tags/v1.9.9" & chr( 10 )
					& "a2" & chr( 9 ) & "refs/tags/v1.10.0" & chr( 10 )
					& "a3" & chr( 9 ) & "refs/tags/v1.10.0^{}" & chr( 10 )
					& "a4" & chr( 9 ) & "refs/tags/v2.0.0-beta.1" & chr( 10 )
					& "a5" & chr( 9 ) & "refs/tags/nightly";
				var tags = updateTask.parseTagListing( listing );
				expect( arrayLen( tags ) ).toBe( 3 );
				expect( tags[ 2 ].tag ).toBe( "v1.10.0" );
				expect( tags[ 2 ].version ).toBe( "1.10.0" );
			} );

			it( "chooses the highest stable tag unless a version is requested", function(){
				var tags = [
					{ tag : "v1.9.9", version : "1.9.9" },
					{ tag : "v1.10.0", version : "1.10.0" },
					{ tag : "v2.0.0-beta.1", version : "2.0.0-beta.1" }
				];
				expect( updateTask.chooseTag( tags, "" ).tag ).toBe( "v1.10.0" );
				expect( updateTask.chooseTag( tags, "v1.9.9" ).tag ).toBe( "v1.9.9" );
				expect( updateTask.chooseTag( tags, "2.0.0-beta.1" ).tag ).toBe( "v2.0.0-beta.1" );
			} );
		} );
	}
}

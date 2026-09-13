/**
 * The base for every spec: finds kit components through WireBox, and knows where the
 * repository and a throwaway project live.
 *
 * tests/Run.cfc loads the checkout as the build-template module before any spec runs, so
 * "Name@build-template" resolves to the working copy.
 */
component extends="testbox.system.BaseSpec" {

	/** A kit component, wired up exactly as the commands get it. */
	function kit( required string name ){
		return application.wirebox.getInstance( arguments.name & "@build-template" );
	}

	/** Component metadata by path inside the kit, for example "commands.release.run". */
	struct function kitMeta( required string dotPath ){
		return getComponentMetadata( "build-template." & arguments.dotPath );
	}

	/** The repository root, with forward slashes and no trailing slash. */
	string function repoRoot(){
		return reReplace( replace( expandPath( "/build-template" ), "\", "/", "all" ), "/+$", "" );
	}

	/** The kit's own version from its box.json. */
	string function kitVersion(){
		return deserializeJSON( fileRead( repoRoot() & "/box.json" ) ).version;
	}

	/** Creates an empty folder under the ignored .test-work folder and returns its path. */
	string function createTempProject(){
		var root = repoRoot() & "/.test-work/build-template-spec-" & createUUID();
		directoryCreate( root, true, true );
		return root;
	}

	/**
	 * Removes a fixture. On Windows, Dropbox and antivirus scanners briefly hold files that
	 * were just written, so the delete is retried and a leftover is tolerated: fixtures have
	 * unique names inside the ignored .test-work folder, so one left behind harms nothing.
	 */
	void function deleteDirectory( required string path ){
		if ( !len( arguments.path ) || !directoryExists( arguments.path ) ) {
			return;
		}
		for ( var attempt = 1; attempt <= 5; attempt++ ) {
			try {
				directoryDelete( arguments.path, true );
				return;
			} catch ( any deleteFailure ) {
				sleep( 500 );
			}
		}
	}

	/** Writes a struct as JSON. */
	void function writeJSON( required string path, required struct data ){
		fileWrite( arguments.path, serializeJSON( arguments.data ) );
	}
}

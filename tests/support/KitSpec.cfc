/**
 * Provides shared setup for every test file. It gets kit components from WireBox and provides
 * paths for the repository and temporary projects.
 *
 * tests/Run.cfc loads this checkout as build-template before tests run. As a result,
 * "Name@build-template" refers to the working copy.
 */
component extends="testbox.system.BaseSpec" {

	/** Returns a kit component with the same WireBox setup used by commands. */
	function kit( required string name ){
		return application.wirebox.getInstance( arguments.name & "@build-template" );
	}

	/** Returns component metadata for a kit path, such as "commands.release.run". */
	struct function kitMeta( required string dotPath ){
		return getComponentMetadata( "build-template." & arguments.dotPath );
	}

	/** Returns the repository root with forward slashes and no final slash. */
	string function repoRoot(){
		return reReplace( replace( expandPath( "/build-template" ), "\", "/", "all" ), "/+$", "" );
	}

	/** Returns the kit version from its box.json. */
	string function kitVersion(){
		return deserializeJSON( fileRead( repoRoot() & "/box.json" ) ).version;
	}

	/** Creates an empty folder under .test-work and returns its path. */
	string function createTempProject(){
		var root = repoRoot() & "/.test-work/build-template-spec-" & createUUID();
		directoryCreate( root, true, true );
		return root;
	}

	/**
	 * Deletes a temporary project. Dropbox and antivirus programs can briefly lock new files on
	 * Windows, so this function tries the delete more than once. A remaining folder is safe
	 * because every test uses a unique name under the ignored .test-work folder.
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

	/** Writes a struct to a JSON file. */
	void function writeJSON( required string path, required struct data ){
		fileWrite( arguments.path, serializeJSON( arguments.data ) );
	}
}

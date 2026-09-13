/**
 * Finds the project a command should work on.
 *
 * Commands run from wherever the shell happens to be, which may be a subfolder of the
 * project. The project root is the nearest folder at or above the shell's folder that holds
 * a box.json. The search stops at a folder holding .git without a box.json, so a command run
 * inside some unrelated repository does not wander up into a parent project.
 */
component singleton {

	/**
	 * Returns the project root for a starting folder, with forward slashes and no trailing
	 * slash. Throws BuildKit.NoProject when there is none.
	 *
	 * @startDir The folder to start from, normally the shell's current folder.
	 */
	string function findRoot( required string startDir ){
		var current = normalise( arguments.startDir );

		while ( len( current ) ) {
			if ( fileExists( current & "/box.json" ) ) {
				return current;
			}
			if ( directoryExists( current & "/.git" ) ) {
				break;
			}
			var parent = reReplace( current, "[\\/][^\\/]*$", "" );
			if ( parent == current || !find( "/", parent ) ) {
				break;
			}
			current = parent;
		}

		throw(
			type    = "BuildKit.NoProject",
			message = "No box.json found in #arguments.startDir# or the folders above it. "
				& "Run this from inside a CommandBox project, or create one with: package init"
		);
	}

	/**
	 * Returns where a project's build settings live: { path, legacy }. The path is empty when
	 * the project has no settings file yet. Legacy is true when only the 1.x location,
	 * build/build.json, exists.
	 *
	 * @root The project root.
	 */
	struct function configFile( required string root ){
		var base = normalise( arguments.root );
		if ( fileExists( base & "/build.json" ) ) {
			return { path : base & "/build.json", legacy : false };
		}
		if ( fileExists( base & "/build/build.json" ) ) {
			return { path : base & "/build/build.json", legacy : true };
		}
		return { path : "", legacy : false };
	}

	/** Forward slashes, no trailing slash. */
	private string function normalise( required string path ){
		return reReplace( replace( arguments.path, "\", "/", "all" ), "/+$", "" );
	}
}

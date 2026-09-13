/**
 * Runs one release command in the current folder with the kit loaded from this checkout.
 *
 * The integration specs start a fresh `box` in a throwaway project and run this task there:
 *
 *   box task run taskFile=<repo>/tests/support/Invoke.cfc :line="release check"
 *
 * That exercises the real commands, in a real shell, against the working copy, without
 * installing anything into the developer's CommandBox. A non-zero exit from the command ends
 * the task with an error, so the spec sees the exit code.
 */
component {

	/**
	 * @line The command line to run, for example "release bump patch --dryRun". It is named
	 *       line rather than command because command() is the helper that runs it.
	 */
	function run( required string line ){
		var supportDir     = reReplace( getDirectoryFromPath( getCurrentTemplatePath() ), "[\\/]$", "" );
		var repositoryRoot = reReplace( reReplace( supportDir, "[\\/][^\\/]+$", "" ), "[\\/][^\\/]+$", "" );

		var moduleService = wirebox.getInstance( "moduleService" );
		if ( moduleService.isModuleRegistered( "build-template" ) ) {
			moduleService.unloadAndUnregisterModule( "build-template" );
		}
		loadModule( repositoryRoot );

		command( arguments.line ).run();
	}
}

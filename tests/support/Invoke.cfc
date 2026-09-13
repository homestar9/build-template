/**
 * Runs one release command in the current folder with this checkout loaded as the kit.
 *
 * Integration tests start a new `box` process in a temporary project and run this task:
 *
 *   box task run taskFile=<repo>/tests/support/Invoke.cfc :line="release check"
 *
 * This uses the real commands and working copy without installing the kit in the developer's
 * CommandBox. A nonzero command exit ends the task with an error. The test can then read that
 * exit code.
 */
component {

	/**
	 * @line The command line to run, such as "release bump patch --dryRun". The argument is
	 *       named line because command() is the function that runs it.
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

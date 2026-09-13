/**
 * Runs the build-kit TestBox suite inside CommandBox.
 *
 * Run `box run-script test` from the repository root. This runner does not need a web server.
 * It loads this checkout as the build-template module, so the specs exercise the code in the
 * working copy rather than any globally installed copy, then runs every spec and prints a
 * text report. It returns an error when a test fails.
 */
component {

	function run( string bundles = "" ){
		var repositoryRoot = reReplace(
			reReplace( getDirectoryFromPath( getCurrentTemplatePath() ), "[\\/]$", "" ),
			"[\\/][^\\/]+$",
			""
		);

		loadKit( repositoryRoot );
		fileSystemUtil.createMapping( "tests", repositoryRoot & "/tests" );
		fileSystemUtil.createMapping( "testbox", repositoryRoot & "/testbox" );

		var runnerArguments = { options : { coverage : { enabled : false } } };
		if ( len( trim( arguments.bundles ) ) ) {
			runnerArguments.bundles = arguments.bundles;
		} else {
			runnerArguments.directory = { mapping : "tests.specs", recurse : true };
		}
		var testRunner = new testbox.system.TestBox( argumentCollection = runnerArguments );
		var results = testRunner.runRaw();
		var reporter = new testbox.system.reports.TextReporter();
		var report   = reporter.runReport(
			results    = results,
			testbox    = testRunner,
			justReturn = true
		);
		print.line( report ).toConsole();

		var problemCount = results.getTotalFail() + results.getTotalError();
		if ( problemCount ) {
			return error( "#problemCount# build-kit test#( problemCount == 1 ? "" : "s" )# failed." );
		}
	}

	/**
	 * Registers this checkout as the build-template module. A copy installed globally under
	 * the same name is unloaded first; loadModule() does nothing when the name is taken, and
	 * the tests must run against the working copy.
	 */
	private void function loadKit( required string repositoryRoot ){
		var moduleService = wirebox.getInstance( "moduleService" );
		if ( moduleService.isModuleRegistered( "build-template" ) ) {
			moduleService.unloadAndUnregisterModule( "build-template" );
		}
		loadModule( arguments.repositoryRoot );
	}
}

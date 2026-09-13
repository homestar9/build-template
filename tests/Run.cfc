/**
 * Runs the build-template TestBox tests in CommandBox.
 *
 * Run `box run-script test` from the repository root. The tests do not need a web server. This
 * runner loads the current checkout as the build-template module. The tests use this working
 * copy instead of a globally installed copy. It runs all tests, prints a text report, and
 * returns an error when any test fails.
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
	 * Loads this checkout as the build-template module. It first unloads a global module with
	 * the same name. loadModule() will not replace a loaded module, and the tests must use this
	 * working copy.
	 */
	private void function loadKit( required string repositoryRoot ){
		var moduleService = wirebox.getInstance( "moduleService" );
		if ( moduleService.isModuleRegistered( "build-template" ) ) {
			moduleService.unloadAndUnregisterModule( "build-template" );
		}
		loadModule( arguments.repositoryRoot );
	}
}

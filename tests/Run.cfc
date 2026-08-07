/**
 * Runs the build-kit TestBox suite inside CommandBox.
 *
 * Run `box run-script test:build-kit` from the repository root. This runner does not need a
 * web server. It maps the source and test folders, runs every spec, prints a text report, and
 * returns an error when a test fails.
 */
component {

	function run( string bundles = "" ){
		var repositoryRoot = reReplace(
			reReplace( getDirectoryFromPath( getCurrentTemplatePath() ), "[\\/]$", "" ),
			"[\\/][^\\/]+$",
			""
		);

		fileSystemUtil.createMapping( "build", repositoryRoot & "/build" );
		fileSystemUtil.createMapping( "lib", repositoryRoot & "/build/lib" );
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
}

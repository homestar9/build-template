/**
 * Runs the project test suite on every configured CFML engine.
 *
 * `box release engines` needs the engine names and server JSON files in build.json. The
 * engines run one at a time because they share one port.
 *
 * It stops old servers, starts one engine, waits for the site, runs the suite, and stops that
 * engine. Every configured engine gets a turn even when an earlier engine fails. It reports
 * all results and stops with an error when any engine failed.
 */
component extends="build-template.models.BaseKitService" {

	/**
	 * Runs the suite on each engine in turn. Prints a line per engine at the end and stops with
	 * an error if any of them failed, so a failure still stops CI and the release. Leaves every
	 * server stopped either way.
	 */
	function run(){
		if ( !arrayLen( variables.settings.engines ) ) {
			return fail(
				"No engines are listed in build.json.",
				[
					'"engines": [',
					'    { "name": "Lucee 5",    "configFile": "server-lucee@5.json" },',
					'    { "name": "Adobe 2023", "configFile": "server-adobe@2023.json" }',
					']',
					"",
					"Each configFile is a server json file in your project root.",
					"Every engine you list is run, in the order you list them."
				],
				"Add them to build.json like this"
			);
		}

		var results = [];
		var started = getTickCount();

		// Only one server can hold the port, and we do not know which one is up.
		stopAllEngines();

		for ( var engine in variables.settings.engines ) {
			results.append( runEngine( engine ) );
		}

		return report( results, started );
	}

	// ENGINE WORKFLOW

	private struct function runEngine( required struct engine ){
		var engineName  = arguments.engine.name ?: arguments.engine.configFile;
		var engineStart = getTickCount();
		print.line().boldBlueLine( "=== #engineName# (#arguments.engine.configFile#) ===" ).toConsole();

		var startResult = startEngine( arguments.engine, engineName );
		if ( !startResult.ok ) {
			return recordFailure( engineName, engineStart, startResult.reason );
		}

		var warmUpResult = warmUp( arguments.engine, engineName );
		if ( !warmUpResult.ok ) {
			return recordFailure( engineName, engineStart, warmUpResult.reason );
		}

		var suiteFailed = runTestSuite( engineName );
		stopEngine( arguments.engine.configFile );
		if ( suiteFailed ) {
			return recordFailure( engineName, engineStart, "the suite failed" );
		}

		return recordSuccess( engineName, engineStart );
	}

	private boolean function runTestSuite( required string engineName ){
		print.blueLine( "Running the suite on #arguments.engineName#..." ).toConsole();
		try {
			command( "testbox run" )
				.params( runner = variables.settings.testRunner, verbose = false )
				.run();
			return variables.shell.getExitCode() != 0;
		} catch ( any ignoredException ) {
			return true;
		}
	}

	/**
	 * Starts one engine's server. Returns { ok, reason } rather than stopping the run, so the
	 * sweep can record the failure and move on to the next engine.
	 */
	private struct function startEngine( required struct engine, required string engineName ){
		// Make sure the port is actually free first. Stopping a server returns before the old
		// process lets go of the port, and starting the next one then fails for a reason that
		// has nothing to do with the engine.
		waitForPortToFree( arguments.engineName );

		var startFailed = false;
		var startError  = "";
		try {
			command( "server start" )
				.params( serverConfigFile = arguments.engine.configFile )
				.run();
			startFailed = ( variables.shell.getExitCode() != 0 );
		} catch ( any exception ) {
			startFailed = true;
			startError  = exception.message;
		}
		if ( startFailed ) {
			print
				.line()
				.boldLine( "Why a server will not start, usually:" )
				.yellowLine( "  the file is missing from your project root" )
				.yellowLine( "  another server still holds the port" )
				.yellowLine( "  the engine could not be downloaded" )
				.line()
				.boldLine( "Try it by hand to see the real reason:" )
				.yellowLine( "  box server start serverConfigFile=#arguments.engine.configFile#" )
				.line()
				.toConsole();
			// The start may have got far enough to hold the port. Clear it, or the next
			// engine in the sweep fails for a reason that has nothing to do with it.
			stopEngine( arguments.engine.configFile );
			return {
				"ok"     : false,
				"reason" : "would not start" & ( len( startError ) ? ": " & startError : "" )
			};
		}

		return { "ok" : true, "reason" : "" };
	}

	/**
	 * Waits until nothing answers on the test port, so the next engine is not started while the
	 * last one is still letting go of it. Gives up after a short wait and lets the start attempt
	 * produce the real error.
	 */
	private function waitForPortToFree( required string engineName ){
		var probeUrl = variables.config.probeUrl();
		for ( var attempt = 1; attempt <= 12; attempt++ ) {
			if ( probe( probeUrl, 5 ) == 0 ) {
				return;
			}
			if ( attempt == 1 ) {
				print.yellowLine( "Waiting for the previous server to release the port..." ).toConsole();
			}
			sleep( 5000 );
		}
		print
			.yellowLine( "Something still answers on the port. Starting #arguments.engineName# anyway." )
			.toConsole();
	}

	/**
	 * Waits until the site answers, so the suite never runs against a server that is still
	 * starting up. A half-started app produces failures that look real but are not. Returns
	 * { ok, reason } so the sweep can record the failure and move on to the next engine.
	 */
	private struct function warmUp( required struct engine, required string engineName ){
		var attempts     = variables.settings.warmup.attempts;
		var delaySeconds = variables.settings.warmup.delaySeconds;
		var probeUrl     = variables.config.probeUrl();

		print.blueLine( "Waiting for #arguments.engineName# (up to #attempts * delaySeconds# seconds)..." ).toConsole();
		var lastStatus = 0;
		for ( var attempt = 1; attempt <= attempts; attempt++ ) {
			lastStatus = probe( probeUrl, 60 );
			// Anything in the 200s or 300s means the site answered.
			if ( lastStatus >= 200 && lastStatus < 400 ) {
				print.greenLine( "#arguments.engineName# is up (status #lastStatus#)." ).toConsole();
				return { "ok" : true, "reason" : "" };
			}
			sleep( delaySeconds * 1000 );
		}

		stopEngine( arguments.engine.configFile );
		print
			.line()
			.yellowLine(
				"A repeating 500 usually means the app will not start on this engine. Start it by hand and read the log:"
			)
			.yellowLine( "  box server start serverConfigFile=#arguments.engine.configFile#" )
			.line()
			.toConsole();

		return { "ok" : false, "reason" : "never answered (last status: #lastStatus#)" };
	}

	/**
	 * Stops every listed engine, ignoring failures. At most one is running, and stopping one
	 * that is not running only prints a complaint.
	 */
	private function stopAllEngines(){
		print.blueLine( "Stopping any running server..." ).toConsole();
		for ( var engine in variables.settings.engines ) {
			stopEngine( engine.configFile );
		}
	}

	/**
	 * Stops one server quietly. A failure here never matters: either it was not running, or
	 * the next start will complain about the port anyway.
	 */
	private function stopEngine( required string configFile ){
		try {
			command( "server stop" ).params( serverConfigFile = arguments.configFile ).run();
		} catch ( any ignoredException ) {
			// Not running, nothing to do.
		}
	}

	private struct function recordFailure( required string engineName, required numeric engineStart, required string reason ){
		var minutes = numberFormat( ( getTickCount() - arguments.engineStart ) / 60000, "0.9" );
		print.boldRedLine( "#arguments.engineName#: FAILED after #minutes# min -- #arguments.reason#" ).toConsole();
		return {
			"name"    : arguments.engineName,
			"passed"  : false,
			"minutes" : minutes,
			"reason"  : arguments.reason
		};
	}

	private struct function recordSuccess( required string engineName, required numeric engineStart ){
		var minutes = numberFormat( ( getTickCount() - arguments.engineStart ) / 60000, "0.9" );
		print.boldGreenLine( "#arguments.engineName#: passed in #minutes# min." ).toConsole();
		return {
			"name"    : arguments.engineName,
			"passed"  : true,
			"minutes" : minutes,
			"reason"  : ""
		};
	}

	/**
	 * Prints a line per engine and ends the run. Stops with an error when any engine failed, so
	 * the exit code still says the sweep was not clean.
	 */
	private function report( required array results, required numeric started ){
		var totalMinutes  = numberFormat( ( getTickCount() - arguments.started ) / 60000, "0.9" );
		var failedResults = arguments.results.filter( function( result ){
			return !result.passed;
		} );

		print.line().boldLine( "Results (#totalMinutes# min total):" ).toConsole();
		for ( var result in arguments.results ) {
			if ( result.passed ) {
				print.greenLine( "  PASSED  #result.name# (#result.minutes# min)" ).toConsole();
			} else {
				print.redLine( "  FAILED  #result.name# (#result.minutes# min) -- #result.reason#" ).toConsole();
			}
		}
		print.line().toConsole();

		if ( !failedResults.len() ) {
			print.boldGreenLine( "All #arguments.results.len()# engines passed." ).toConsole();
			return;
		}

		var failedNames = failedResults.map( function( result ){
			return result.name;
		} );

		return stop(
			"#failedResults.len()# of #arguments.results.len()# engines failed: "
			& failedNames.toList( ", " ) & "."
		);
	}
}

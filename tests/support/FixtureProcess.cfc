/**
 * Creates disposable projects and runs commands in them for the integration specs.
 *
 * Every process runs inside a path supplied by the test. The helper captures combined output
 * and returns the exit code. It does not use a shell, so arguments are passed without quoting.
 */
component {

	function init( required string repositoryRoot ){
		variables.repositoryRoot = arguments.repositoryRoot;
		variables.processRunner  = application.wirebox.getInstance( "ProcessRunner@build-template" );
		return this;
	}

	/** Creates an empty temporary project folder. */
	string function createProject(){
		var projectRoot = variables.repositoryRoot & "/.test-work/build-template-integration-" & createUUID();
		directoryCreate( projectRoot, true, true );
		return projectRoot;
	}

	/**
	 * Runs one release command inside a disposable project, through a fresh CommandBox that
	 * loads the kit from this checkout. See tests/support/Invoke.cfc.
	 *
	 * @projectRoot The project to run in.
	 * @line        The command line, for example "release bump patch --dryRun".
	 */
	struct function runKit( required string projectRoot, required string line ){
		// No quotes around the value: the argument is passed to the process as one item, and
		// Java quotes it for Windows itself. Literal quotes would be split apart instead.
		return runBox(
			arguments.projectRoot,
			[
				"task", "run",
				"taskFile=" & variables.repositoryRoot & "/tests/support/Invoke.cfc",
				":line=" & arguments.line
			]
		);
	}

	/** Runs CommandBox inside a disposable project. */
	struct function runBox( required string projectRoot, required array args ){
		return runProcess(
			workingDirectory = arguments.projectRoot,
			executable       = variables.processRunner.findBinary( "box" ),
			args             = arguments.args
		);
	}

	/** Runs Git inside a disposable project. */
	struct function runGit( required string projectRoot, required array args ){
		return runProcess(
			workingDirectory = arguments.projectRoot,
			executable       = variables.processRunner.findBinary( "git" ),
			args             = arguments.args
		);
	}

	/** Runs one executable and returns its exit code and combined output. */
	struct function runProcess(
		required string workingDirectory,
		required string executable,
		array args = []
	){
		var processArguments = createObject( "java", "java.util.ArrayList" ).init();
		processArguments.add( javaCast( "string", arguments.executable ) );
		for ( var processArgument in arguments.args ) {
			processArguments.add( javaCast( "string", processArgument ) );
		}

		var processBuilder = createObject( "java", "java.lang.ProcessBuilder" ).init( processArguments );
		processBuilder.directory( createObject( "java", "java.io.File" ).init( arguments.workingDirectory ) );
		processBuilder.redirectErrorStream( javaCast( "boolean", true ) );

		var process = processBuilder.start();
		var reader  = createObject( "java", "java.io.BufferedReader" ).init(
			createObject( "java", "java.io.InputStreamReader" ).init( process.getInputStream() )
		);
		var output = createObject( "java", "java.lang.StringBuilder" ).init();
		var line   = reader.readLine();
		while ( !isNull( line ) ) {
			output.append( line ).append( chr( 10 ) );
			line = reader.readLine();
		}
		reader.close();

		return {
			exitCode : process.waitFor(),
			output   : trim( output.toString() )
		};
	}
}

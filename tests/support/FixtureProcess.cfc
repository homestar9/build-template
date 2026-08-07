/**
 * Creates disposable projects and runs local commands for integration specs.
 *
 * Every process runs inside a path supplied by the test. The helper captures combined output
 * and returns the exit code. It does not use a shell, so arguments are passed without quoting.
 */
component {

	function init( required string repositoryRoot ){
		variables.repositoryRoot = arguments.repositoryRoot;
		variables.config         = new build.BuildConfig( variables.repositoryRoot & "/build" );
		return this;
	}

	/** Creates an empty temporary project with a copy of the build kit. */
	string function createProject(){
		var projectRoot = variables.repositoryRoot & "/.test-work/build-template-integration-" & createUUID();
		directoryCreate( projectRoot, true, true );
		directoryCopy( variables.repositoryRoot & "/build", projectRoot & "/build", true );
		if ( !fileExists( projectRoot & "/build/Build.cfc" ) ) {
			throw(
				type    = "BuildKit.FixtureCopy",
				message = "The build kit was not copied into the integration fixture."
			);
		}
		return projectRoot;
	}

	/** Runs CommandBox inside a disposable project. */
	struct function runBox( required string projectRoot, required array args ){
		return runProcess(
			workingDirectory = arguments.projectRoot,
			executable       = variables.config.findBinary( "box" ),
			args             = arguments.args
		);
	}

	/** Runs Git inside a disposable project. */
	struct function runGit( required string projectRoot, required array args ){
		return runProcess(
			workingDirectory = arguments.projectRoot,
			executable       = variables.config.findBinary( "git" ),
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

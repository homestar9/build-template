/**
 * Runs outside programs such as git and gh and returns their exit code and text output.
 *
 * It never throws, so the caller decides what a failure means. That matters for checks such
 * as `git rev-parse --verify`, where a non-zero exit is the answer we want.
 *
 * Arguments are passed as a list rather than one long string. The program gets each one
 * exactly as written, so a file path containing spaces needs no quoting and cannot be split
 * in the wrong place.
 *
 * This runs the program directly through Java instead of through CommandBox, so there are no
 * shell features: no pipes, no redirection, no wildcards. Every call is one program with
 * plain arguments, which is all a release needs.
 */
component singleton {

	function init(){
		variables.binaryCache = {};
		return this;
	}

	/**
	 * Runs one program and returns { exitCode, output }. Error output is folded into the
	 * normal output, because a program's complaint is usually the most useful part of it.
	 *
	 * @name             The program name, for example "git".
	 * @args             The arguments, for example [ "status", "--porcelain" ].
	 * @workingDirectory The folder to run it in, normally the project root.
	 */
	struct function run( required string name, array args = [], required string workingDirectory ){
		var binary  = findBinary( arguments.name );
		var argList = createObject( "java", "java.util.ArrayList" ).init();
		argList.add( javaCast( "string", binary ) );
		for ( var arg in arguments.args ) {
			argList.add( javaCast( "string", arg ) );
		}

		try {
			var builder = createObject( "java", "java.lang.ProcessBuilder" ).init( argList );
			builder.directory( createObject( "java", "java.io.File" ).init( arguments.workingDirectory ) );
			builder.redirectErrorStream( javaCast( "boolean", true ) );

			var process = builder.start();
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

			return { exitCode : process.waitFor(), output : trim( output.toString() ) };
		} catch ( any exception ) {
			// Reaching here almost always means the program is not installed. 127 is the
			// shell's own "command not found" code, so callers can spot that case.
			return {
				exitCode : 127,
				output   : "Could not run '#arguments.name#': #exception.message#"
			};
		}
	}

	/**
	 * Reports whether a program can be found and run at all.
	 *
	 * @name The program name, for example "gh".
	 */
	boolean function commandExists( required string name ){
		// A found program has a full path; a missing one falls back to the bare name.
		return findBinary( arguments.name ) != arguments.name;
	}

	/**
	 * Finds a program and returns its full path, for example
	 * C:\Program Files\Git\cmd\git.exe. Returns the bare name when nothing is found, which
	 * lets the system try its own lookup and produces a readable error if the tool is missing.
	 *
	 * It searches PATH first, then a list of usual install folders. That second pass matters:
	 * a terminal opened before you installed a tool keeps its old PATH until you open a new
	 * one, so a program that works in a fresh window can look missing here.
	 *
	 * Results are remembered for the life of the shell.
	 *
	 * @name The program name, for example "git", "gh".
	 */
	string function findBinary( required string name ){
		if ( structKeyExists( variables.binaryCache, arguments.name ) ) {
			return variables.binaryCache[ arguments.name ];
		}

		var jFile     = createObject( "java", "java.io.File" );
		var separator = jFile.separator;
		var resolved  = arguments.name;
		// The empty extension covers Mac and Linux; the rest are the Windows launchers.
		var extensions = [ "", ".exe", ".cmd", ".bat" ];

		var searchDirs = [];
		var pathEnv    = createObject( "java", "java.lang.System" ).getenv( "PATH" );
		if ( !isNull( pathEnv ) ) {
			searchDirs.append( listToArray( pathEnv, jFile.pathSeparator ), true );
		}
		searchDirs.append( wellKnownDirs(), true );

		for ( var searchDirectory in searchDirs ) {
			if ( !len( trim( searchDirectory ) ) ) {
				continue;
			}
			for ( var extension in extensions ) {
				var candidate = reReplace( searchDirectory, "[\\/]$", "" ) & separator & arguments.name & extension;
				if ( fileExists( candidate ) ) {
					resolved = candidate;
					break;
				}
			}
			if ( resolved != arguments.name ) {
				break;
			}
		}

		variables.binaryCache[ arguments.name ] = resolved;
		return resolved;
	}

	/**
	 * The usual install folders to check when PATH does not turn up a program.
	 */
	private array function wellKnownDirs(){
		var system      = createObject( "java", "java.lang.System" );
		var directories = [];

		var programFiles    = system.getenv( "ProgramFiles" );
		var programFilesX86 = system.getenv( "ProgramFiles(x86)" );
		var localAppData    = system.getenv( "LOCALAPPDATA" );

		if ( !isNull( programFiles ) ) {
			directories.append( programFiles & "\GitHub CLI" );
			directories.append( programFiles & "\Git\cmd" );
			directories.append( programFiles & "\Git\bin" );
			directories.append( programFiles & "\nodejs" );
		}
		if ( !isNull( programFilesX86 ) ) {
			directories.append( programFilesX86 & "\GitHub CLI" );
			directories.append( programFilesX86 & "\Git\cmd" );
		}
		if ( !isNull( localAppData ) ) {
			directories.append( localAppData & "\Programs\GitHub CLI" );
			directories.append( localAppData & "\Microsoft\WinGet\Links" );
			directories.append( localAppData & "\Programs\Git\cmd" );
		}

		directories.append( "/usr/local/bin" );
		directories.append( "/usr/bin" );
		directories.append( "/bin" );
		directories.append( "/opt/homebrew/bin" );
		directories.append( "/opt/local/bin" );
		directories.append( "/snap/bin" );

		return directories;
	}
}

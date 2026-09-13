/**
 * Provides the shared setup and error handling for each `release` command.
 *
 * It finds the project, loads its settings, and starts the requested model component. It also
 * converts expected model exceptions into command errors.
 *
 * CommandBox keeps command components between runs. The component stores only the injected
 * project locator. Each command run creates a new ProjectConfig.
 */
component {

	property name="locator" inject="ProjectLocator@build-template";

	/**
	 * Finds the project root from the current folder.
	 */
	string function projectRoot(){
		return runKit( function(){
			return variables.locator.findRoot( getCWD() );
		} );
	}

	/**
	 * Loads the current project and prints its name, version, and root folder.
	 */
	any function loadProject(){
		return runKit( function(){
			var config = getInstance( "ProjectConfig@build-template" ).load( variables.locator.findRoot( getCWD() ) );
			print.line( "Project: #config.slug()# #config.version()# at #config.getRoot()#" ).toConsole();
			if ( config.isLegacyLayout() ) {
				print
					.yellowLine( "Using the old 1.x settings at build/build.json. Move them to 2.0 with: box release migrate" )
					.toConsole();
			}
			return config;
		} );
	}

	/**
	 * Creates a model component that uses this command's print buffer.
	 *
	 * @name   The component name, such as "ReleaseService".
	 * @config The loaded project when the component needs project settings.
	 */
	any function kit( required string name, any config ){
		var service = getInstance( arguments.name & "@build-template" ).usePrinter( print );
		if ( !isNull( arguments.config ) ) {
			service.forProject( arguments.config );
		}
		return service;
	}

	/**
	 * Runs a function and reports an expected kit exception without a stack trace.
	 * It throws unexpected exceptions again so CommandBox can show the full stack trace.
	 *
	 * @work The function to run.
	 */
	any function runKit( required any work ){
		try {
			return arguments.work();
		} catch ( any exception ) {
			if ( isKitStop( exception ) ) {
				return error( exception.message );
			}
			rethrow;
		}
	}

	/**
	 * Returns true for an expected kit error or a failed nested command. These errors already
	 * contain a message that explains the problem.
	 */
	private boolean function isKitStop( required any exception ){
		var type = arguments.exception.type ?: "";
		return left( type, 9 ) == "BuildKit."
			|| type == "BuildConfig"
			|| left( type, 15 ) == "BuildChangelog."
			|| left( type, 13 ) == "BuildVersion."
			|| type == "commandException";
	}
}

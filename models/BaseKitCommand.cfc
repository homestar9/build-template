/**
 * What every `release` command has in common: find the project, load its settings, hand the
 * work to a component in models/, and turn that component's stop into a command error.
 *
 * Commands are singletons that CommandBox keeps between runs, so nothing is stored in
 * variables apart from the injected locator. Each run loads a fresh ProjectConfig.
 */
component {

	property name="locator" inject="ProjectLocator@build-template";

	/**
	 * The root of the project the shell is in, found from the current folder.
	 */
	string function projectRoot(){
		return runKit( function(){
			return variables.locator.findRoot( getCWD() );
		} );
	}

	/**
	 * Loads the project the shell is in and says which one it is, so a command run from the
	 * wrong folder is obvious straight away.
	 */
	any function loadProject(){
		return runKit( function(){
			var config = getInstance( "ProjectConfig@build-template" ).load( variables.locator.findRoot( getCWD() ) );
			print.line( "Project: #config.slug()# #config.version()# at #config.getRoot()#" ).toConsole();
			if ( config.isLegacyLayout() ) {
				print
					.yellowLine( "Settings were read from build/build.json, the 1.x layout. Move to 2.0 with: box release migrate" )
					.toConsole();
			}
			return config;
		} );
	}

	/**
	 * Creates a workflow component that prints through this command.
	 *
	 * @name   The component, for example "ReleaseService".
	 * @config The loaded project, when the workflow needs one.
	 */
	any function kit( required string name, any config ){
		var service = getInstance( arguments.name & "@build-template" ).usePrinter( print );
		if ( !isNull( arguments.config ) ) {
			service.forProject( arguments.config );
		}
		return service;
	}

	/**
	 * Runs the work and reports a kit stop as a plain command error, without a stack trace.
	 * Anything unexpected is rethrown so the real trace is not hidden.
	 *
	 * @work A closure doing the work.
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
	 * Whether an exception is one of ours or a failed nested command, both of which already
	 * carry a message written for people.
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

/**
 * The helpers every workflow component shares.
 *
 * A component in models/ is not a command, so CommandBox does not hand it print, shell, or
 * command(). This base injects those from WireBox and adds the small things the workflows
 * need: stopping with a readable message, finding the kit's own files, running other
 * CommandBox commands, and probing a URL.
 *
 * Workflow components never call error(). They throw a BuildKit exception, and the command
 * that called them turns it into error(), so the same components can be tested without a
 * running command.
 */
component {

	property name="shell"          inject="shell";
	property name="print"          inject="PrintBuffer";
	property name="wirebox"        inject="wirebox";
	property name="fileSystemUtil" inject="FileSystem";
	property name="formatterUtil"  inject="Formatter";

	/**
	 * Attaches the loaded project so the workflow knows its root and settings.
	 *
	 * @config A loaded ProjectConfig.
	 */
	function forProject( required any config ){
		variables.config   = arguments.config;
		variables.settings = arguments.config.getSettings();
		variables.root     = arguments.config.getRoot();
		return this;
	}

	/**
	 * Uses the caller's print buffer instead of a fresh one, so output from several components
	 * comes out in order and nothing is left unflushed when the command ends.
	 *
	 * @printer A CommandBox print buffer.
	 */
	function usePrinter( required any printer ){
		variables.print = arguments.printer;
		return this;
	}

	/**
	 * Creates another workflow component for the same project, sharing this one's printer.
	 *
	 * @name The component name, for example "PackageBuilder".
	 */
	function kitService( required string name ){
		var service = variables.wirebox.getInstance( arguments.name & "@build-template" ).usePrinter( variables.print );
		if ( structKeyExists( variables, "config" ) ) {
			service.forProject( variables.config );
		}
		return service;
	}

	/**
	 * Starts a CommandBox command the same way a command would: command( "publish" ).run().
	 *
	 * @name The command, for example "testbox run".
	 */
	function command( required string name ){
		return variables.wirebox.getInstance( name = "CommandDSL", initArguments = { name : arguments.name } );
	}

	/**
	 * A full path inside the installed kit, for example kitPath( "templates/RELEASE.md" ).
	 *
	 * @relative A path relative to the kit's own folder.
	 */
	string function kitPath( string relative = "" ){
		return expandPath( "/build-template/" & arguments.relative );
	}

	/** The installed kit's own version, from its box.json. Empty when it cannot be read. */
	string function kitVersion(){
		try {
			return trim( deserializeJSON( fileRead( kitPath( "box.json" ) ) ).version ?: "" );
		} catch ( any ignoredException ) {
			return "";
		}
	}

	/**
	 * Stops the workflow with one readable line. The calling command reports it as an error.
	 *
	 * @message What went wrong.
	 * @type    The exception type; anything starting with BuildKit. is reported without a trace.
	 */
	function stop( required string message, string type = "BuildKit.Stop" ){
		throw( type = arguments.type, message = arguments.message );
	}

	/**
	 * Stops the workflow, printing guidance that spans several lines first.
	 *
	 * CommandBox's error() removes line breaks from its message, so anything longer than a
	 * sentence arrives as one run-together block. The guidance is printed first, where it keeps
	 * its shape, and the error is left with the single line that says what went wrong.
	 *
	 * @summary One line saying what went wrong.
	 * @detail  Lines of guidance to print first.
	 * @heading A short label for the guidance.
	 */
	function fail( required string summary, array detail = [], string heading = "What to do" ){
		if ( arrayLen( arguments.detail ) ) {
			variables.print.line().boldLine( arguments.heading & ":" ).toConsole();
			for ( var line in arguments.detail ) {
				variables.print.yellowLine( "  " & line ).toConsole();
			}
			variables.print.line().toConsole();
		}
		return stop( arguments.summary );
	}

	/**
	 * Turns a struct into readable JSON, using CommandBox's formatter when available so the
	 * result matches how it writes box.json.
	 *
	 * @data The struct to write.
	 */
	string function formatJSON( required struct data ){
		var json = serializeJSON( arguments.data );
		try {
			return variables.formatterUtil.formatJSON( json );
		} catch ( any ignoredException ) {
			return json;
		}
	}

	/**
	 * Asks a URL for its status code without following redirects. Returns 0 when nothing
	 * answers, so callers can treat "no server" and "server error" differently.
	 *
	 * @url     The address to ask.
	 * @timeout Seconds to wait.
	 */
	numeric function probe( required string url, numeric timeout = 15 ){
		var httpResult = "";
		try {
			cfhttp(
				url          = arguments.url,
				method       = "GET",
				timeout      = arguments.timeout,
				throwonerror = false,
				redirect     = false,
				result       = "local.httpResult"
			);
		} catch ( any ignoredException ) {
			return 0;
		}
		return val( httpResult.statuscode ?: "0" );
	}
}

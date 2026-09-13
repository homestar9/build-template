/**
 * Sets up a project for build-template.
 *
 * `box release init` creates build.json with settings found in the project. It also creates a
 * changelog when the project does not have one. `--docs` copies the RELEASE.md guide.
 * `--ci` copies the GitHub Actions workflow.
 *
 * It keeps existing files unless you use `--force`. It finds default settings in box.json,
 * Git, and server JSON files in the project root.
 */
component extends="build-template.models.BaseKitService" {

	property name="projectSettings" inject="ProjectSettingsService@build-template";
	property name="processRunner"   inject="ProcessRunner@build-template";

	/**
	 * Runs the setup steps and prints the detected settings.
	 *
	 * @root  The project root folder.
	 * @force Replaces files that already exist.
	 * @docs  Copies the RELEASE.md guide to the project root.
	 * @ci    Copies the GitHub Actions workflow to .github/workflows/release.yml.
	 */
	function run( required string root, boolean force = false, boolean docs = false, boolean ci = false ){
		variables.root = reReplace( replace( arguments.root, "\", "/", "all" ), "/+$", "" );

		print.line().boldLine( "Setting up build-template" ).line( repeatString( "-", 60 ) ).toConsole();

		if ( !fileExists( variables.root & "/box.json" ) ) {
			return stop( "No box.json file was found at #variables.root#. Run this command inside a CommandBox package." );
		}

		writeBuildJSON( arguments.force );
		writeChangelog( arguments.force );
		if ( arguments.docs ) {
			copyTemplate( "RELEASE.md", "RELEASE.md", arguments.force );
		}
		if ( arguments.ci ) {
			copyTemplate( "github-release.yml", ".github/workflows/release.yml", arguments.force );
		}

		print
			.line( repeatString( "-", 60 ) )
			.boldGreenLine( "Setup complete." )
			.line()
			.boldLine( "Next steps:" )
			.line( "  1. Review build.json and correct any wrong settings." )
			.line( "  2. Check the project:     box release check" )
			.line( "  3. Practice a release:    box release run --dryRun" )
			.toConsole();
		if ( !arguments.docs ) {
			print.line().line( "Run box release help for the full process. Use --docs to copy RELEASE.md." ).toConsole();
		}
	}

	// SETUP STEPS

	/**
	 * Creates build.json and fills in settings found in the project.
	 */
	private function writeBuildJSON( required boolean force ){
		var path = variables.root & "/build.json";
		if ( fileExists( path ) && !arguments.force ) {
			print.yellowLine( "  skip  build.json already exists. Use --force to replace it." ).toConsole();
			return;
		}

		var packageData = deserializeJSON( fileRead( variables.root & "/box.json" ) );
		var projectType = variables.projectSettings.detectProjectType( packageData );
		var settings = {
			"minimumKitVersion" : kitVersion(),
			"projectType"       : projectType,
			"branch"            : detectBranch(),
			"changelog"         : detectChangelogName(),
			"testRunner"        : variables.projectSettings.detectTestRunner( packageData ),
			"runTests"          : true,
			"publish"           : {
				"forgebox" : projectType == "module",
				"github"   : true
			},
			"excludes"    : variables.projectSettings.installerDefaultExcludes( projectType ),
			"excludesAdd" : [],
			"engines"     : detectEngines()
		};

		fileWrite( path, formatJSON( settings ) );
		print.greenLine( "  create  build.json" ).toConsole();
		print.line( "        project type:   #settings.projectType#" ).toConsole();
		print.line( "        release branch: #settings.branch#" ).toConsole();
		print.line( "        test runner:    #settings.testRunner#" ).toConsole();
		print.line( "        engines found:  #arrayLen( settings.engines )#" ).toConsole();
	}

	/**
	 * Creates a changelog with an [Unreleased] section.
	 */
	private function writeChangelog( required boolean force ){
		var name = detectChangelogName();
		var path = variables.root & "/" & name;

		if ( fileExists( path ) && !arguments.force ) {
			print.yellowLine( "  skip  #name# already exists." ).toConsole();
			return;
		}

		var template = kitPath( "templates/CHANGELOG.md" );
		if ( fileExists( template ) ) {
			fileCopy( template, path );
		} else {
			fileWrite( path, defaultChangelog() );
		}
		print.greenLine( "  create  #name#" ).toConsole();
	}

	/**
	 * Copies one template from the kit into the project.
	 *
	 * @templateName The filename under templates/.
	 * @relative     The destination path relative to the project root.
	 * @force        Replaces the destination when it already exists.
	 */
	private function copyTemplate( required string templateName, required string relative, required boolean force ){
		var source = kitPath( "templates/" & arguments.templateName );
		var target = variables.root & "/" & arguments.relative;

		if ( !fileExists( source ) ) {
			return;
		}
		if ( fileExists( target ) && !arguments.force ) {
			print.yellowLine( "  skip  #arguments.relative# already exists." ).toConsole();
			return;
		}
		var targetDir = getDirectoryFromPath( target );
		if ( !directoryExists( targetDir ) ) {
			directoryCreate( targetDir, true, true );
		}
		fileCopy( source, target );
		print.greenLine( "  create  #arguments.relative#" ).toConsole();
	}

	// PROJECT DETECTION

	/**
	 * Returns Gitflow's production branch when it is configured. Otherwise, it asks Git for the
	 * current branch. This works in linked worktrees. It returns main for a detached checkout
	 * or when Git cannot provide a branch.
	 */
	private string function detectBranch(){
		var production = variables.processRunner.run( "git", [ "config", "--get", "gitflow.branch.master" ], variables.root );
		if ( production.exitCode == 0 && len( trim( production.output ) ) ) {
			return trim( production.output );
		}

		var current = variables.processRunner.run( "git", [ "symbolic-ref", "--quiet", "--short", "HEAD" ], variables.root );
		if ( current.exitCode == 0 && len( trim( current.output ) ) ) {
			return trim( current.output );
		}
		return "main";
	}

	/**
	 * Returns the exact filename of an existing changelog. It returns CHANGELOG.md when no
	 * changelog exists.
 *
	 * It reads the directory instead of checking possible names with fileExists(). Windows and
	 * macOS may report that changelog.md exists when the real name is CHANGELOG.md. That wrong
	 * letter case can fail on Linux.
	 */
	private string function detectChangelogName(){
		for ( var name in directoryList( variables.root, false, "name", "*.md" ) ) {
			if ( reFindNoCase( "^changelog\.md$", name ) ) {
				return name;
			}
		}
		return "CHANGELOG.md";
	}

	/**
	 * Finds server JSON files in the project root and creates an engine entry for each file.
	 */
	private array function detectEngines(){
		var engines = [];
		var files   = directoryList( variables.root, false, "name", "*.json" )
			.filter( function( file ){
				return reFindNoCase( "^server(?:-.*)?\.json$", file );
			} );
		files.sort( "textnocase" );

		for ( var file in files ) {
			engines.append( { "name" : engineName( file ), "configFile" : file } );
		}
		return engines;
	}

	/**
	 * Reads one server file and gets its display name from ProjectSettingsService. An invalid
	 * server file still gets an entry with a name based on its filename.
	 */
	private string function engineName( required string file ){
		var serverSettings = {};
		try {
			var parsedSettings = deserializeJSON( fileRead( variables.root & "/" & arguments.file ) );
			serverSettings = isStruct( parsedSettings ) ? parsedSettings : {};
		} catch ( any ignoredException ) {
			// The server command will report the invalid JSON when it starts this server.
		}

		return variables.projectSettings.engineName( arguments.file, serverSettings );
	}

	/**
	 * Returns a basic changelog when the template file is missing.
	 */
	private string function defaultChangelog(){
		var lf = chr( 10 );
		// Build Markdown headings with chr( 35 ). A # starts a CFML variable, so a literal # in
		// a string must be doubled. chr( 35 ) makes the number of heading marks clear.
		var h1 = repeatString( chr( 35 ), 1 ) & " ";
		var h2 = repeatString( chr( 35 ), 2 ) & " ";
		var h3 = repeatString( chr( 35 ), 3 ) & " ";

		return h1 & "Changelog" & lf & lf
			& "This file lists the important changes to this project." & lf & lf
			& "The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)." & lf
			& "Version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html)." & lf & lf
			& h2 & "[Unreleased]" & lf & lf
			& h3 & "Added" & lf & lf
			& "- Add changes here while you work." & lf;
	}
}

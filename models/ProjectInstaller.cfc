/**
 * Sets a project up for the build kit.
 *
 * `box release init` writes build.json with settings detected from the project and creates a
 * changelog when the project has none. With `--docs` it copies the RELEASE.md guide into the
 * project, and with `--ci` the GitHub Actions workflow.
 *
 * It keeps existing files unless `--force` is passed. It detects useful defaults from
 * box.json, Git, and root-level server JSON files.
 */
component extends="build-template.models.BaseKitService" {

	property name="projectSettings" inject="ProjectSettingsService@build-template";
	property name="processRunner"   inject="ProcessRunner@build-template";

	/**
	 * Runs each setup step and prints the detected settings.
	 *
	 * @root  The project root.
	 * @force Overwrite files that already exist.
	 * @docs  Copy RELEASE.md, the release guide, into the project root.
	 * @ci    Copy the GitHub Actions release workflow to .github/workflows/release.yml.
	 */
	function run( required string root, boolean force = false, boolean docs = false, boolean ci = false ){
		variables.root = reReplace( replace( arguments.root, "\", "/", "all" ), "/+$", "" );

		print.line().boldLine( "Setting up the build kit" ).line( repeatString( "-", 60 ) ).toConsole();

		if ( !fileExists( variables.root & "/box.json" ) ) {
			return stop( "No box.json found at #variables.root#. Run this from a CommandBox package." );
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
			.boldGreenLine( "Done." )
			.line()
			.boldLine( "Next steps:" )
			.line( "  1. Look through build.json and adjust anything that is wrong." )
			.line( "  2. Check you are ready:   box release check" )
			.line( "  3. Rehearse a release:    box release run --dryRun" )
			.toConsole();
		if ( !arguments.docs ) {
			print.line().line( "For the full routine, run: box release help   (or add --docs to copy RELEASE.md in)" ).toConsole();
		}
	}

	// SETUP STEPS

	/**
	 * Writes build.json, filling in what it can work out from the project.
	 */
	private function writeBuildJSON( required boolean force ){
		var path = variables.root & "/build.json";
		if ( fileExists( path ) && !arguments.force ) {
			print.yellowLine( "  skip  build.json already exists (use --force to replace it)" ).toConsole();
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
		print.greenLine( "  made  build.json" ).toConsole();
		print.line( "        project type:   #settings.projectType#" ).toConsole();
		print.line( "        release branch: #settings.branch#" ).toConsole();
		print.line( "        test runner:    #settings.testRunner#" ).toConsole();
		print.line( "        engines:        #arrayLen( settings.engines )# found" ).toConsole();
	}

	/**
	 * Creates a changelog with an [Unreleased] section when the project has none.
	 */
	private function writeChangelog( required boolean force ){
		var name = detectChangelogName();
		var path = variables.root & "/" & name;

		if ( fileExists( path ) && !arguments.force ) {
			print.yellowLine( "  skip  #name# already exists" ).toConsole();
			return;
		}

		var template = kitPath( "templates/CHANGELOG.md" );
		if ( fileExists( template ) ) {
			fileCopy( template, path );
		} else {
			fileWrite( path, defaultChangelog() );
		}
		print.greenLine( "  made  #name#" ).toConsole();
	}

	/**
	 * Copies one of the kit's templates into the project.
	 *
	 * @templateName The file under templates/.
	 * @relative     Where it goes, relative to the project root.
	 * @force        Overwrite an existing file.
	 */
	private function copyTemplate( required string templateName, required string relative, required boolean force ){
		var source = kitPath( "templates/" & arguments.templateName );
		var target = variables.root & "/" & arguments.relative;

		if ( !fileExists( source ) ) {
			return;
		}
		if ( fileExists( target ) && !arguments.force ) {
			print.yellowLine( "  skip  #arguments.relative# already exists" ).toConsole();
			return;
		}
		var targetDir = getDirectoryFromPath( target );
		if ( !directoryExists( targetDir ) ) {
			directoryCreate( targetDir, true, true );
		}
		fileCopy( source, target );
		print.greenLine( "  made  #arguments.relative#" ).toConsole();
	}

	// PROJECT DETECTION

	/**
	 * Uses Gitflow's configured production branch when present. Otherwise reads the current
	 * symbolic branch through git, which also works in linked worktrees, and falls back to main
	 * for a detached checkout or a folder without usable git metadata.
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
	 * Returns the name of the changelog the project already has, spelled exactly as it is on
	 * disk. Falls back to CHANGELOG.md, which is the usual spelling.
	 *
	 * It reads the real directory listing rather than testing names one at a time. On Windows
	 * and macOS, fileExists( "changelog.md" ) is true even when the file is really called
	 * CHANGELOG.md, and a wrong spelling would work locally while failing on Linux.
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
	 * Finds the server json files in the project root and turns them into engine entries, with
	 * a readable name worked out from each file name.
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
	 * Reads one server file and asks ProjectSettingsService to choose its display name.
	 * A malformed file still appears in the generated settings with a name based on its file.
	 */
	private string function engineName( required string file ){
		var serverSettings = {};
		try {
			var parsedSettings = deserializeJSON( fileRead( variables.root & "/" & arguments.file ) );
			serverSettings = isStruct( parsedSettings ) ? parsedSettings : {};
		} catch ( any ignoredException ) {
			// The server command will report invalid JSON when someone starts this server.
		}

		return variables.projectSettings.engineName( arguments.file, serverSettings );
	}

	/**
	 * The starter changelog, used when the templates folder is missing.
	 */
	private string function defaultChangelog(){
		var lf = chr( 10 );
		// Build the markdown headings from chr( 35 ) rather than writing hashes in the string.
		// A # starts a variable in CFML, so hashes have to be doubled, and counting them for a
		// three-hash heading is a good way to write a bug.
		var h1 = repeatString( chr( 35 ), 1 ) & " ";
		var h2 = repeatString( chr( 35 ), 2 ) & " ";
		var h3 = repeatString( chr( 35 ), 3 ) & " ";

		return h1 & "Changelog" & lf & lf
			& "All notable changes to this project are written down here." & lf & lf
			& "The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)," & lf
			& "and the version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html)." & lf & lf
			& h2 & "[Unreleased]" & lf & lf
			& h3 & "Added" & lf & lf
			& "- Write your changes here as you go." & lf;
	}
}

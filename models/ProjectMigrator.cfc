/**
 * Moves a project from the 1.x vendored kit to the 2.0 module.
 *
 * `box release migrate` moves build/build.json to build.json, deletes the kit's own files from
 * build/ (only the files 1.x shipped; anything else there is kept), and rewrites the box.json
 * scripts that pointed at those files so `box run-script release` keeps working. It prints
 * every change first, and with `--dryRun` it stops there.
 */
component extends="build-template.models.BaseKitService" {

	property name="packageScripts" inject="PackageScriptService@build-template";

	/**
	 * Plans and applies the migration.
	 *
	 * @root          The project root.
	 * @dryRun        List the changes without making them.
	 * @removeScripts Delete the 1.x box.json scripts instead of rewriting them.
	 */
	function run( required string root, boolean dryRun = false, boolean removeScripts = false ){
		variables.root = reReplace( replace( arguments.root, "\", "/", "all" ), "/+$", "" );

		print.line().boldLine( "Migrating to build-template 2.0" ).line( repeatString( "-", 60 ) ).toConsole();
		if ( arguments.dryRun ) {
			print.boldYellowLine( "DRY RUN: nothing will be changed." ).toConsole();
		}

		var steps = plan( variables.root, arguments.removeScripts );
		if ( !steps.filter( function( step ){ return listFindNoCase( "move,delete,prune,rewrite,remove", step.action ) > 0; } ).len() ) {
			print.greenLine( "Nothing to migrate: this project already uses the 2.0 layout." ).toConsole();
			printNotes( steps );
			return;
		}

		warnIfDirty();
		for ( var step in steps ) {
			if ( step.action != "note" ) {
				print.line( "  " & lJustify( step.action, 8 ) & step.path & ( len( step.detail ) ? "  (" & step.detail & ")" : "" ) ).toConsole();
			}
		}

		if ( arguments.dryRun ) {
			print.line().yellowLine( "Dry run: nothing was changed." ).toConsole();
			printNotes( steps );
			return;
		}

		apply( steps );
		printNotes( steps );
		print
			.line()
			.boldGreenLine( "Migrated. Review with: git status  and  git diff" )
			.line( "Then commit, and run: box release check" )
			.toConsole();
	}

	/**
	 * Works out every change without making any. Each entry is { action, path, detail }.
	 *
	 * @root          The project root.
	 * @removeScripts Delete the 1.x scripts instead of rewriting them.
	 */
	array function plan( required string root, boolean removeScripts = false ){
		var base  = reReplace( replace( arguments.root, "\", "/", "all" ), "/+$", "" );
		var steps = [];

		planSettings( base, steps );
		planKitFiles( base, steps );
		planScripts( base, steps, arguments.removeScripts );
		planNotes( base, steps );
		return steps;
	}

	// PLANNING

	private void function planSettings( required string base, required array steps ){
		var legacy = arguments.base & "/build/build.json";
		var target = arguments.base & "/build.json";
		if ( !fileExists( legacy ) ) {
			return;
		}
		if ( fileExists( target ) ) {
			return stop(
				"Both build.json and build/build.json exist. Keep the one you want as build.json, "
				& "delete the other, and run this again."
			);
		}
		arguments.steps.append( { action : "move", path : "build/build.json -> build.json", detail : "adds minimumKitVersion, drops templateVersion" } );
	}

	private void function planKitFiles( required string base, required array steps ){
		var buildDir = arguments.base & "/build";
		if ( !directoryExists( buildDir ) ) {
			return;
		}

		var shipped = {};
		for ( var relative in kitFiles() ) {
			shipped[ lCase( relative ) ] = true;
			if ( fileExists( buildDir & "/" & relative ) ) {
				arguments.steps.append( { action : "delete", path : "build/" & relative, detail : "" } );
			}
		}

		for ( var path in directoryList( buildDir, true, "path", "", "", "file" ) ) {
			var relative = relativeTo( buildDir, path );
			if ( relative == "build.json" || structKeyExists( shipped, lCase( relative ) ) ) {
				continue;
			}
			arguments.steps.append( { action : "keep", path : "build/" & relative, detail : "not part of the kit, left alone" } );
		}

		for ( var folder in [ "build/lib", "build/templates", "build" ] ) {
			if ( directoryExists( arguments.base & "/" & folder ) && willBeEmpty( arguments.base & "/" & folder, arguments.steps ) ) {
				arguments.steps.append( { action : "prune", path : folder & "/", detail : "empty afterwards" } );
			}
		}
	}

	private void function planScripts( required string base, required array steps, required boolean removeScripts ){
		var packagePath = arguments.base & "/box.json";
		if ( !fileExists( packagePath ) ) {
			return;
		}
		var outcome = variables.packageScripts.migrateScripts( deserializeJSON( fileRead( packagePath ) ), arguments.removeScripts );
		var modern  = variables.packageScripts.modernScripts();
		for ( var name in outcome.rewritten ) {
			arguments.steps.append( { action : "rewrite", path : "box.json scripts." & name, detail : modern[ name ] } );
		}
		for ( var name in outcome.removed ) {
			arguments.steps.append( { action : "remove", path : "box.json scripts." & name, detail : len( modern[ name ] ) ? "" : "use: box update build-template --system" } );
		}
		for ( var name in outcome.kept ) {
			arguments.steps.append( { action : "keep", path : "box.json scripts." & name, detail : "customised, left alone" } );
		}
	}

	private void function planNotes( required string base, required array steps ){
		var releaseDoc = arguments.base & "/RELEASE.md";
		if ( fileExists( releaseDoc ) && fileRead( releaseDoc ) contains "taskFile=build/" ) {
			arguments.steps.append( {
				action : "note",
				path   : "RELEASE.md",
				detail : "RELEASE.md describes the 1.x commands. Refresh it with: box release init --docs --force"
			} );
		}

		var workflowDir = arguments.base & "/.github/workflows";
		if ( directoryExists( workflowDir ) ) {
			for ( var file in directoryList( workflowDir, false, "name", "*.yml" ) ) {
				if ( fileRead( workflowDir & "/" & file ) contains "taskFile=build/Release.cfc" ) {
					arguments.steps.append( {
						action : "note",
						path   : ".github/workflows/" & file,
						detail : "Replace the release step with: box install build-template  then  "
							& "box release run version=$(box package show version) existingTag=${{ github.ref_type == 'tag' }} buildID=${{ github.run_number }}"
					} );
				}
			}
		}
	}

	// APPLYING

	private void function apply( required array steps ){
		for ( var step in arguments.steps ) {
			switch ( step.action ) {
				case "move":
					moveSettings();
					break;
				case "delete":
					fileDelete( variables.root & "/" & step.path );
					break;
			}
		}
		// Prune innermost first; the plan lists lib and templates before build.
		for ( var step in arguments.steps ) {
			if ( step.action == "prune" ) {
				var folder = variables.root & "/" & reReplace( step.path, "/$", "" );
				if ( directoryExists( folder ) && !arrayLen( directoryList( folder, true, "path" ) ) ) {
					directoryDelete( folder );
				}
			}
		}
		if ( arguments.steps.filter( function( step ){ return listFindNoCase( "rewrite,remove", step.action ) > 0; } ).len() ) {
			applyScripts( arguments.steps );
		}
	}

	/**
	 * Writes the settings to build.json without the two 1.x keys, and records the kit version
	 * so future machines are told when they need a newer kit.
	 */
	private void function moveSettings(){
		var legacy   = variables.root & "/build/build.json";
		var settings = deserializeJSON( fileRead( legacy ) );
		if ( !isStruct( settings ) ) {
			return stop( "build/build.json does not hold a JSON object, so it was not moved." );
		}
		structDelete( settings, "templateVersion" );
		structDelete( settings, "_installerSeed" );
		if ( !len( trim( settings.minimumKitVersion ?: "" ) ) ) {
			settings[ "minimumKitVersion" ] = kitVersion();
		}
		fileWrite( variables.root & "/build.json", formatJSON( settings ) );
		fileDelete( legacy );
	}

	private void function applyScripts( required array steps ){
		var packagePath = variables.root & "/box.json";
		var remove      = arguments.steps.filter( function( step ){ return step.action == "remove" && !len( step.detail ); } ).len() > 0
			&& !arguments.steps.filter( function( step ){ return step.action == "rewrite"; } ).len();
		var outcome     = variables.packageScripts.migrateScripts( deserializeJSON( fileRead( packagePath ) ), remove );
		fileWrite( packagePath, formatJSON( outcome.packageData ) );
	}

	// HELPERS

	/** The files the 1.x kit placed inside build/, relative to that folder. */
	private array function kitFiles(){
		return [
			"Release.cfc", "Build.cfc", "Bump.cfc", "Doctor.cfc", "TestEngines.cfc", "Install.cfc", "Update.cfc", "BuildConfig.cfc",
			"lib/ChangelogService.cfc", "lib/VersionService.cfc", "lib/ProjectSettingsService.cfc", "lib/PackageScriptService.cfc",
			"templates/CHANGELOG.md", "templates/RELEASE.md", "templates/github-release.yml",
			"build-kit.json"
		];
	}

	/** Whether a folder holds nothing but files the plan deletes (and folders that empty out). */
	private boolean function willBeEmpty( required string folder, required array steps ){
		var deleting = {};
		for ( var step in arguments.steps ) {
			if ( listFindNoCase( "delete,move", step.action ) ) {
				deleting[ lCase( replace( variables.root & "/" & listFirst( step.path, " " ), "\", "/", "all" ) ) ] = true;
			}
		}
		for ( var path in directoryList( arguments.folder, true, "path", "", "", "file" ) ) {
			if ( !structKeyExists( deleting, lCase( replace( path, "\", "/", "all" ) ) ) ) {
				return false;
			}
		}
		return true;
	}

	private void function printNotes( required array steps ){
		for ( var step in arguments.steps ) {
			if ( step.action == "note" ) {
				print.line().yellowLine( "Note: " & step.detail ).toConsole();
			}
		}
	}

	private void function warnIfDirty(){
		var status = variables.wirebox.getInstance( "ProcessRunner@build-template" ).run( "git", [ "status", "--porcelain" ], variables.root );
		if ( status.exitCode == 0 && len( trim( status.output ) ) ) {
			print.yellowLine( "You have uncommitted changes. The migration is easiest to review from a clean tree, but it will go ahead." ).toConsole();
		}
	}

	/** The part of a path below a base folder, with forward slashes. */
	private string function relativeTo( required string base, required string path ){
		var normalisedBase = reReplace( replace( arguments.base, "\", "/", "all" ), "/$", "" );
		var normalisedPath = replace( arguments.path, "\", "/", "all" );
		return mid( normalisedPath, len( normalisedBase ) + 2, len( normalisedPath ) - len( normalisedBase ) - 1 );
	}
}

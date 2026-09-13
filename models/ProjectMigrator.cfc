/**
 * Moves a project from the copied 1.x kit to the 2.0 module.
 *
 * `box release migrate` moves build/build.json to build.json. It deletes only the files that
 * the 1.x kit added under build/. It keeps every other file. It updates old box.json scripts
 * so `box run-script release` still works. It lists all changes first. `--dryRun` stops after
 * printing the list.
 */
component extends="build-template.models.BaseKitService" {

	property name="packageScripts" inject="PackageScriptService@build-template";

	/**
	 * Lists and applies the migration changes.
	 *
	 * @root          The project root folder.
	 * @dryRun        Lists changes without applying them.
	 * @removeScripts Deletes 1.x box.json scripts instead of updating them.
	 */
	function run( required string root, boolean dryRun = false, boolean removeScripts = false ){
		variables.root = reReplace( replace( arguments.root, "\", "/", "all" ), "/+$", "" );

		print.line().boldLine( "Migrating to build-template 2.0" ).line( repeatString( "-", 60 ) ).toConsole();
		if ( arguments.dryRun ) {
			print.boldYellowLine( "PRACTICE RUN: No files will change." ).toConsole();
		}

		var steps = plan( variables.root, arguments.removeScripts );
		if ( !steps.filter( function( step ){ return listFindNoCase( "move,delete,prune,rewrite,remove", step.action ) > 0; } ).len() ) {
			print.greenLine( "Nothing to migrate. This project already uses the 2.0 layout." ).toConsole();
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
			print.line().yellowLine( "Practice run complete. No files changed." ).toConsole();
			printNotes( steps );
			return;
		}

		apply( steps );
		printNotes( steps );
		print
			.line()
			.boldGreenLine( "Migration complete. Review the changes with git status and git diff." )
			.line( "Commit the changes, and then run: box release check" )
			.toConsole();
	}

	/**
	 * Returns every planned change without applying it. Each item contains action, path, and
	 * detail values.
	 *
	 * @root          The project root folder.
	 * @removeScripts Deletes 1.x scripts instead of updating them.
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
				"Both build.json and build/build.json exist. Choose the settings that you want to keep. "
				& "Save them in build.json, delete build/build.json, and run this command again."
			);
		}
		arguments.steps.append( { action : "move", path : "build/build.json -> build.json", detail : "adds minimumKitVersion and removes templateVersion" } );
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
			arguments.steps.append( { action : "keep", path : "build/" & relative, detail : "not part of the kit; no change" } );
		}

		for ( var folder in [ "build/lib", "build/templates", "build" ] ) {
			if ( directoryExists( arguments.base & "/" & folder ) && willBeEmpty( arguments.base & "/" & folder, arguments.steps ) ) {
				arguments.steps.append( { action : "prune", path : folder & "/", detail : "empty after migration" } );
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
			arguments.steps.append( { action : "keep", path : "box.json scripts." & name, detail : "project changed this script; no change" } );
		}
	}

	private void function planNotes( required string base, required array steps ){
		var releaseDoc = arguments.base & "/RELEASE.md";
		if ( fileExists( releaseDoc ) && fileRead( releaseDoc ) contains "taskFile=build/" ) {
			arguments.steps.append( {
				action : "note",
				path   : "RELEASE.md",
				detail : "RELEASE.md contains 1.x commands. Replace it with: box release init --docs --force"
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
		// Delete inner folders first. The plan lists lib and templates before build.
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
	 * Moves the settings to build.json and removes two 1.x keys. It also records the current kit
	 * version so other computers can report when their kit is too old.
	 */
	private void function moveSettings(){
		var legacy   = variables.root & "/build/build.json";
		var settings = deserializeJSON( fileRead( legacy ) );
		if ( !isStruct( settings ) ) {
			return stop( "build/build.json must contain a JSON object. The file was not moved." );
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

	/** Returns the files that the 1.x kit added under build/. */
	private array function kitFiles(){
		return [
			"Release.cfc", "Build.cfc", "Bump.cfc", "Doctor.cfc", "TestEngines.cfc", "Install.cfc", "Update.cfc", "BuildConfig.cfc",
			"lib/ChangelogService.cfc", "lib/VersionService.cfc", "lib/ProjectSettingsService.cfc", "lib/PackageScriptService.cfc",
			"templates/CHANGELOG.md", "templates/RELEASE.md", "templates/github-release.yml",
			"build-kit.json"
		];
	}

	/** Returns true when the migration will leave a folder empty. */
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
			print.yellowLine( "You have uncommitted changes. The migration will continue, but a clean Git checkout is easier to review." ).toConsole();
		}
	}

	/** Returns the part of a path below a base folder and uses forward slashes. */
	private string function relativeTo( required string base, required string path ){
		var normalisedBase = reReplace( replace( arguments.base, "\", "/", "all" ), "/$", "" );
		var normalisedPath = replace( arguments.path, "\", "/", "all" );
		return mid( normalisedPath, len( normalisedBase ) + 2, len( normalisedPath ) - len( normalisedBase ) - 1 );
	}
}

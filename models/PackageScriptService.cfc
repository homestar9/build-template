/**
 * Stores the box.json scripts created by the 1.x kit and their 2.0 replacements. The migrate
 * command uses these lists to update project scripts.
 *
 * This component only works with structs. ProjectMigrator reads and writes box.json.
 */
component singleton {

	/**
	 * Returns the exact scripts written by the 1.x installer. A matching value means that the
	 * project did not change the script.
	 */
	struct function legacyScripts(){
		return {
			"release"              : "task run taskFile=build/Release.cfc target=run :version=`package show version`",
			"release:check"        : "task run taskFile=build/Doctor.cfc",
			"release:dryrun"       : "task run taskFile=build/Release.cfc target=run :version=`package show version` :dryRun=true",
			"release:existing-tag" : "task run taskFile=build/Release.cfc target=run :version=`package show version` :existingTag=true",
			"release:skip-tests"   : "task run taskFile=build/Release.cfc target=run :version=`package show version` :skipTests=true",
			"release:hotfix"       : "task run taskFile=build/Release.cfc target=run :version=`package show version` :skipTests=true",
			"test:engines"         : "task run taskFile=build/TestEngines.cfc",
			"bump:major"           : "task run taskFile=build/Bump.cfc :level=major",
			"bump:minor"           : "task run taskFile=build/Bump.cfc :level=minor",
			"bump:patch"           : "task run taskFile=build/Bump.cfc :level=patch",
			"bump:prerelease"      : "task run taskFile=build/Bump.cfc :level=prerelease",
			"bump:beta"            : "task run taskFile=build/Bump.cfc :level=preminor :preid=beta",
			"bump:alpha"           : "task run taskFile=build/Bump.cfc :level=preminor :preid=alpha",
			"build:package"        : "task run taskFile=build/Build.cfc :projectName=`package show slug` :version=`package show version`",
			"build-kit:update"     : "task run taskFile=build/Update.cfc"
		};
	}

	/**
	 * Returns the 2.0 replacement for each 1.x script. An empty value removes the script because
	 * it has no replacement. The kit update command is now `box update build-template --system`.
	 */
	struct function modernScripts(){
		return {
			"release"              : "release run",
			"release:check"        : "release check",
			"release:dryrun"       : "release run --dryRun",
			"release:existing-tag" : "release run --existingTag",
			"release:skip-tests"   : "release run --skipTests",
			"release:hotfix"       : "release run --skipTests",
			"test:engines"         : "release engines",
			"bump:major"           : "release bump major",
			"bump:minor"           : "release bump minor",
			"bump:patch"           : "release bump patch",
			"bump:prerelease"      : "release bump prerelease",
			"bump:beta"            : "release bump preminor beta",
			"bump:alpha"           : "release bump preminor alpha",
			"build:package"        : "release package",
			"build-kit:update"     : ""
		};
	}

	/**
	 * Updates 1.x scripts in a copy of the package data. An unchanged 1.x script gets its 2.0
	 * command. A script that already uses the 2.0 command stays unchanged. Any other value is a
	 * project change, so the function keeps it.
 *
	 * The result contains the new package data and sorted lists of updated, removed, and kept
	 * script names.
	 *
	 * @packageData The parsed box.json data.
	 * @remove      Deletes 1.x scripts instead of updating them.
	 */
	struct function migrateScripts( required struct packageData, boolean remove = false ){
		var result    = duplicate( arguments.packageData );
		var rewritten = [];
		var removed   = [];
		var kept      = [];

		if ( !structKeyExists( result, "scripts" ) || !isStruct( result.scripts ) ) {
			return { packageData : result, rewritten : rewritten, removed : removed, kept : kept };
		}

		var legacy = legacyScripts();
		var modern = modernScripts();
		for ( var scriptName in legacy ) {
			if ( !structKeyExists( result.scripts, scriptName ) ) {
				continue;
			}
			var current = result.scripts[ scriptName ];
			if ( !isSimpleValue( current ) ) {
				kept.append( scriptName );
				continue;
			}
			if ( compare( current, modern[ scriptName ] ) == 0 ) {
				// The script already uses the current command.
				continue;
			}
			if ( compare( current, legacy[ scriptName ] ) != 0 ) {
				kept.append( scriptName );
				continue;
			}
			if ( arguments.remove || !len( modern[ scriptName ] ) ) {
				structDelete( result.scripts, scriptName );
				removed.append( scriptName );
			} else {
				result.scripts[ scriptName ] = modern[ scriptName ];
				rewritten.append( scriptName );
			}
		}
		rewritten.sort( "text" );
		removed.sort( "text" );
		kept.sort( "text" );

		return { packageData : result, rewritten : rewritten, removed : removed, kept : kept };
	}
}

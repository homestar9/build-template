/**
 * Knows the box.json scripts the 1.x kit wrote into projects, and what each one becomes in
 * 2.0. The migrate command uses this to rewrite a project's scripts.
 *
 * This component works with structs only. ProjectMigrator reads and writes box.json.
 */
component singleton {

	/**
	 * The scripts the 1.x installer wrote, exactly as it wrote them. A project whose script
	 * still holds one of these values has not customised it.
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
	 * The 2.0 command each 1.x script becomes. An empty value means the script has no
	 * replacement and is removed; updating the kit is now `box update build-template --system`.
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
	 * Rewrites the 1.x scripts in a copy of the package data. A script whose value is exactly
	 * what 1.x wrote becomes its 2.0 command; one that already holds the 2.0 command is left
	 * as it is; anything else was customised by the project and is kept untouched.
	 *
	 * Returns the new package data plus the sorted script names that were rewritten, removed,
	 * and kept.
	 *
	 * @packageData The parsed box.json.
	 * @remove      Delete the 1.x scripts instead of rewriting them.
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
				// Already migrated.
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

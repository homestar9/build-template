/**
 * Knows which box.json scripts the build kit provides.
 *
 * This component works with structs only. Install.cfc and Update.cfc read and write box.json,
 * so both add the same scripts and neither replaces one a project has changed.
 */
component {

	/**
	 * The scripts every project using the kit should have, keyed by script name.
	 */
	struct function requiredScripts(){
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
	 * Adds every missing kit script to a copy of the package data. A script that already
	 * exists is left exactly as it is, even when its command differs from the kit's.
	 *
	 * Returns the new package data plus the sorted names that were added and left alone.
	 *
	 * @packageData The parsed box.json.
	 */
	struct function addMissingScripts( required struct packageData ){
		var result = duplicate( arguments.packageData );
		if ( !structKeyExists( result, "scripts" ) || !isStruct( result.scripts ) ) {
			result[ "scripts" ] = {};
		}

		var added    = [];
		var existing = [];
		var required = requiredScripts();
		for ( var scriptName in required ) {
			if ( structKeyExists( result.scripts, scriptName ) ) {
				existing.append( scriptName );
			} else {
				result.scripts[ scriptName ] = required[ scriptName ];
				added.append( scriptName );
			}
		}
		added.sort( "text" );
		existing.sort( "text" );

		return { packageData : result, added : added, existing : existing };
	}
}

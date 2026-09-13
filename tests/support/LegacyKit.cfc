/**
 * Writes a project shaped the way the 1.5.0 installer left it: a copied build folder with
 * the kit's files, build/build.json, and the box.json scripts. The migrate specs start from
 * this and check what 2.0 does with it.
 */
component {

	/**
	 * @root The empty project folder to fill.
	 */
	void function writeProject( required string root ){
		var scripts = application.wirebox.getInstance( "PackageScriptService@build-template" ).legacyScripts();
		scripts[ "release:check" ] = "echo custom";
		fileWrite(
			arguments.root & "/box.json",
			serializeJSON( { "name" : "Sample", "slug" : "sample", "version" : "1.0.0", "type" : "commandbox-modules", "scripts" : scripts } )
		);

		directoryCreate( arguments.root & "/build/lib", true, true );
		directoryCreate( arguments.root & "/build/templates", true, true );
		fileWrite(
			arguments.root & "/build/build.json",
			serializeJSON( {
				"templateVersion" : "1.5.0",
				"projectType"     : "module",
				"branch"          : "master",
				"changelog"       : "CHANGELOG.md",
				"testRunner"      : "http://127.0.0.1:60299/tests/runner.cfm",
				"runTests"        : false,
				"publish"         : { "forgebox" : false, "github" : true },
				"excludes"        : [ "^build$", "^tests$" ],
				"excludesAdd"     : [],
				"engines"         : []
			} )
		);

		for ( var name in [ "Release", "Build", "Bump", "Doctor", "TestEngines", "Install", "Update", "BuildConfig" ] ) {
			fileWrite( arguments.root & "/build/" & name & ".cfc", "component {}" );
		}
		for ( var name in [ "ChangelogService", "VersionService", "ProjectSettingsService", "PackageScriptService" ] ) {
			fileWrite( arguments.root & "/build/lib/" & name & ".cfc", "component {}" );
		}
		for ( var name in [ "CHANGELOG.md", "RELEASE.md", "github-release.yml" ] ) {
			fileWrite( arguments.root & "/build/templates/" & name, "template" );
		}
		fileWrite( arguments.root & "/build/build-kit.json", serializeJSON( { "version" : "1.5.0", "repository" : "homestar9/build-template" } ) );

		// Not part of the kit; must survive the migration.
		fileWrite( arguments.root & "/build/lib/Custom.cfc", "component {}" );
		fileWrite( arguments.root & "/CHANGELOG.md", repeatString( chr( 35 ), 2 ) & " [Unreleased]" & chr( 10 ) );
	}
}

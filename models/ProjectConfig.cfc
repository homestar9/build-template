/**
 * Loads and checks one project's build settings.
 *
 * A command finds the project root and calls load( root ). This component reads build.json or
 * the old 1.x file at build/build.json. It applies project values over the defaults. It fills
 * settings that can be found in box.json and checks each final value. It also provides project
 * paths and access to git and gh commands.
 *
 * Projects change release behavior through build.json. They do not need to edit the kit.
 */
component {

	property name="locator"         inject="ProjectLocator@build-template";
	property name="processRunner"   inject="ProcessRunner@build-template";
	property name="versionService"  inject="VersionService@build-template";
	property name="projectSettings" inject="ProjectSettingsService@build-template";

	function init(){
		variables.root         = "";
		variables.configPath   = "";
		variables.legacyLayout = false;
		variables.touchedKeys  = {};
		variables.settings     = {};
		return this;
	}

	/**
	 * Reads and checks the settings for one project.
	 *
	 * @root The project root folder that contains box.json.
	 */
	function load( required string root ){
		variables.root = reReplace( replace( arguments.root, "\", "/", "all" ), "/+$", "" );

		var located            = variables.locator.configFile( variables.root );
		variables.configPath   = located.path;
		variables.legacyLayout = located.legacy;
		variables.touchedKeys  = {};
		variables.settings     = loadSettings();
		return this;
	}

	/** Returns all project settings. */
	struct function getSettings(){
		return variables.settings;
	}

	/**
	 * Returns one project setting.
	 *
	 * @key          The setting name, such as "branch".
	 * @defaultValue The value to return when the setting is missing.
	 */
	function get( required string key, defaultValue = "" ){
		return structKeyExists( variables.settings, arguments.key ) ? variables.settings[ arguments.key ] : arguments.defaultValue;
	}

	/**
	 * Converts a project-relative path to a full path.
	 *
	 * @relative A project-relative path, such as "CHANGELOG.md".
	 */
	string function repoPath( required string relative ){
		return variables.root & "/" & arguments.relative;
	}

	/** Returns the full project root path. */
	string function getRoot(){
		return variables.root;
	}

	/** Returns the settings file path or an empty string when no file exists. */
	string function configPath(){
		return variables.configPath;
	}

	/** Returns true when the settings came from the old build/build.json location. */
	boolean function isLegacyLayout(){
		return variables.legacyLayout;
	}

	/** Returns the installed kit version or an empty string when it cannot be read. */
	string function kitVersion(){
		try {
			return trim( deserializeJSON( fileRead( expandPath( "/build-template/box.json" ) ) ).version ?: "" );
		} catch ( any ignoredException ) {
			return "";
		}
	}

	/** Reads and returns the project's box.json data. */
	struct function boxJSON(){
		var path = repoPath( "box.json" );
		if ( !fileExists( path ) ) {
			throw( type = "BuildConfig", message = "No box.json file was found at #path#. Run release commands inside a CommandBox project." );
		}
		return deserializeJSON( fileRead( path ) );
	}

	/** Returns the box.json slug. It uses the package name when the slug is missing. */
	string function slug(){
		var box = boxJSON();
		return box.slug ?: ( box.name ?: "package" );
	}

	/** Returns the version from box.json. */
	string function version(){
		return boxJSON().version ?: "0.0.0";
	}

	/**
	 * Runs git, gh, or another program in the project root. It returns the exit code and output
	 * instead of throwing an exception. See ProcessRunner.
	 *
	 * @name The program name, such as "git".
	 * @args The argument list, such as [ "status", "--porcelain" ].
	 */
	struct function execNative( required string name, array args = [] ){
		return variables.processRunner.run( arguments.name, arguments.args, variables.root );
	}

	/** Returns true when a program can be found and started. */
	boolean function commandExists( required string name ){
		return variables.processRunner.commandExists( arguments.name );
	}

	/** Returns a program's full path or its original name when no file is found. */
	string function findBinary( required string name ){
		return variables.processRunner.findBinary( arguments.name );
	}

	/** Returns the main exclusion list followed by the entries in excludesAdd. */
	array function allExcludes(){
		var result = duplicate( variables.settings.excludes );
		result.append( variables.settings.excludesAdd, true );
		return result;
	}

	/**
	 * Returns the site root URL used to check the test server. It does not return the test
	 * runner URL because requesting that URL would start all tests.
	 */
	string function probeUrl(){
		return reReplaceNoCase( variables.settings.testRunner, "^(https?://[^/]+).*$", "\1" ) & "/";
	}

	// SETTINGS

	/**
	 * Creates the final settings. It starts with defaults, applies file values, and checks the
	 * result.
	 */
	private struct function loadSettings(){
		var result   = defaults();
		var fileName = variables.legacyLayout ? "build/build.json" : "build.json";

		if ( len( variables.configPath ) && fileExists( variables.configPath ) ) {
			var settingsText = trim( fileRead( variables.configPath ) );
			if ( len( settingsText ) ) {
				var userSettings = "";
				try {
					userSettings = deserializeJSON( settingsText );
				} catch ( any exception ) {
					throw(
						type    = "BuildConfig",
						message = "#fileName# contains invalid JSON (#exception.message#). "
							& "Check for values without quotes and single backslashes. "
							& "JSON requires two backslashes, so a regular expression looks like ""\\.avif$""."
					);
				}
				if ( !isStruct( userSettings ) ) {
					throw( type = "BuildConfig", message = "#fileName# must contain a JSON object, such as { ""branch"": ""main"" }." );
				}
				result = merge( result, userSettings );
			}
		}

		applyProjectTypeDefaults( result );
		fillDerivedDefaults( result );
		validate( result );
		return result;
	}

	/**
	 * Returns the settings used when build.json does not provide a value.
	 */
	private struct function defaults(){
		return {
			"minimumKitVersion" : "",
			"projectType"       : "module",
			"branch"            : "main",
			"changelog"         : "CHANGELOG.md",
			// An empty value uses testbox.runner from box.json or the default local URL.
			"testRunner"        : "",
			"runTests"          : true,
			"gitSync"           : true,
			"requireCleanTree"  : true,
			"coldboxMapping"    : "test-harness/coldbox",
			"stagingDir"        : ".tmp",
			"artifactsDir"      : ".artifacts",
			"tagPrefix"         : "v",
			"publish"           : { "forgebox" : true, "github" : true },
			"excludes"          : variables.projectSettings.buildConfigDefaultExcludes(),
			"excludesAdd"       : [],
			"engines"           : [],
			"warmup"            : { "attempts" : 60, "delaySeconds" : 5 }
		};
	}

	/**
	 * Changes defaults for the project type. An application does not publish to ForgeBox by
	 * default. build.json can still enable ForgeBox publishing.
	 */
	private void function applyProjectTypeDefaults( required struct settings ){
		if ( lCase( arguments.settings.projectType ) == "app" && !userTouched( "publish.forgebox" ) ) {
			arguments.settings.publish.forgebox = false;
		}
	}

	/**
	 * Fills settings that can be read from the project. The current derived setting is the test
	 * runner URL from testbox.runner in box.json.
	 */
	private void function fillDerivedDefaults( required struct settings ){
		if ( len( trim( arguments.settings.testRunner ) ) ) {
			return;
		}
		var packageData = {};
		try {
			packageData = boxJSON();
		} catch ( any ignoredException ) {
			packageData = {};
		}
		arguments.settings.testRunner = variables.projectSettings.detectTestRunner( packageData );
	}

	/**
	 * Applies one struct over another. It combines nested structs one key at a time. For example,
	 * setting only publish.github keeps the default publish.forgebox value. An array replaces
	 * the full default array so settings do not contain an unexpected mix of both lists.
	 */
	private struct function merge( required struct base, required struct overlay ){
		var result = duplicate( arguments.base );
		for ( var key in arguments.overlay ) {
			var incoming = arguments.overlay[ key ];
			if (
				structKeyExists( result, key )
				&& isStruct( result[ key ] )
				&& isStruct( incoming )
			) {
				result[ key ] = merge( result[ key ], incoming );
				for ( var sub in incoming ) {
					variables.touchedKeys[ key & "." & sub ] = true;
				}
			} else {
				result[ key ] = incoming;
				variables.touchedKeys[ key ] = true;
			}
		}
		return result;
	}

	/** Returns true when the settings file provided a key. */
	private boolean function userTouched( required string key ){
		return structKeyExists( variables.touchedKeys, arguments.key );
	}

	/** Checks every setting after defaults and project values are applied. */
	private void function validate( required struct settings ){
		validateProjectSettings( arguments.settings );
		validatePublishSettings( arguments.settings );
		validatePackageSettings( arguments.settings );
		validateEngineSettings( arguments.settings );
		validateWarmupSettings( arguments.settings );
		validateTestRunner( arguments.settings );
		validateKitVersion( arguments.settings );
	}

	private void function validateProjectSettings( required struct settings ){
		if ( !listFindNoCase( "module,app", arguments.settings.projectType ) ) {
			throw(
				type    = "BuildConfig",
				message = "build.json projectType must be ""module"" or ""app"", "
					& "not ""#arguments.settings.projectType#""."
			);
		}
		if ( !len( trim( arguments.settings.branch ) ) ) {
			throw( type = "BuildConfig", message = "build.json branch cannot be empty. Enter the release branch, such as ""main""." );
		}
		if ( !len( trim( arguments.settings.changelog ) ) ) {
			throw( type = "BuildConfig", message = "build.json changelog cannot be empty. Enter the changelog filename, such as ""CHANGELOG.md""." );
		}
		if ( !isBoolean( arguments.settings.runTests ) ) {
			throw( type = "BuildConfig", message = "build.json runTests must be true or false." );
		}
	}

	private void function validatePublishSettings( required struct settings ){
		if (
			!isStruct( arguments.settings.publish )
			|| !structKeyExists( arguments.settings.publish, "forgebox" )
			|| !structKeyExists( arguments.settings.publish, "github" )
		) {
			throw( type = "BuildConfig", message = "build.json publish must look like { ""forgebox"": true, ""github"": true }." );
		}
		if ( !isBoolean( arguments.settings.publish.forgebox ) || !isBoolean( arguments.settings.publish.github ) ) {
			throw( type = "BuildConfig", message = "build.json publish.forgebox and publish.github must be true or false." );
		}
	}

	private void function validatePackageSettings( required struct settings ){
		if ( !isArray( arguments.settings.excludes ) || !isArray( arguments.settings.excludesAdd ) ) {
			throw( type = "BuildConfig", message = "build.json excludes and excludesAdd must be arrays of regular expressions." );
		}
	}

	private void function validateEngineSettings( required struct settings ){
		if ( !isArray( arguments.settings.engines ) ) {
			throw(
				type    = "BuildConfig",
				message = "build.json engines must be an array like "
					& "[ { ""name"": ""Lucee 5"", ""configFile"": ""server-lucee@5.json"" } ]."
			);
		}
		for ( var engine in arguments.settings.engines ) {
			if ( !isStruct( engine ) || !structKeyExists( engine, "configFile" ) ) {
				throw(
					type    = "BuildConfig",
				message = "Each build.json engine needs a configFile, such as "
						& "{ ""name"": ""Lucee 5"", ""configFile"": ""server-lucee@5.json"" }."
				);
			}
		}
	}

	private void function validateWarmupSettings( required struct settings ){
		if (
			!isStruct( arguments.settings.warmup )
			|| !isNumeric( arguments.settings.warmup.attempts ?: "" )
			|| !isNumeric( arguments.settings.warmup.delaySeconds ?: "" )
		) {
			throw( type = "BuildConfig", message = "build.json warmup must look like { ""attempts"": 60, ""delaySeconds"": 5 }." );
		}
	}

	private void function validateTestRunner( required struct settings ){
		if ( !reFindNoCase( "^https?://", arguments.settings.testRunner ) ) {
			throw(
				type    = "BuildConfig",
				message = "build.json testRunner must be a full URL, such as "
					& """http://127.0.0.1:60310/tests/runner.cfm""."
			);
		}
	}

	/**
	 * Stops when minimumKitVersion requires a newer kit. This check keeps release behavior the
	 * same on every computer used for the project.
	 */
	private void function validateKitVersion( required struct settings ){
		var required  = trim( arguments.settings.minimumKitVersion ?: "" );
		var installed = kitVersion();
		if ( !len( required ) || !len( installed ) ) {
			return;
		}
		if ( variables.versionService.compareVersions( installed, required ) < 0 ) {
			throw(
				type    = "BuildKit.KitTooOld",
				message = "This project requires build-template #required# or newer. The installed version is #installed#. "
					& "Run: box update build-template --system"
			);
		}
	}
}

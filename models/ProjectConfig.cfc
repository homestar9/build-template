/**
 * Loads and validates one project's build settings.
 *
 * A command finds the project root, then calls load( root ). This reads the project's
 * build.json (or build/build.json from the 1.x layout), lays it over the defaults, works out
 * anything derivable from box.json, and checks the result makes sense. It also offers the
 * project paths and the git/gh runner every workflow uses.
 *
 * Projects configure this through build.json. A project should never need to edit the kit.
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
	 * Reads the settings for one project.
	 *
	 * @root The project root, the folder that holds box.json.
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

	/** Returns the whole settings struct. */
	struct function getSettings(){
		return variables.settings;
	}

	/**
	 * Returns one setting.
	 *
	 * @key          The setting name, for example "branch".
	 * @defaultValue What to return when the setting is missing.
	 */
	function get( required string key, defaultValue = "" ){
		return structKeyExists( variables.settings, arguments.key ) ? variables.settings[ arguments.key ] : arguments.defaultValue;
	}

	/**
	 * Turns a path relative to the project root into a full path.
	 *
	 * @relative A path relative to the project root, for example "CHANGELOG.md".
	 */
	string function repoPath( required string relative ){
		return variables.root & "/" & arguments.relative;
	}

	/** The full path of the project root. */
	string function getRoot(){
		return variables.root;
	}

	/** The settings file that was read, or an empty string when the project has none. */
	string function configPath(){
		return variables.configPath;
	}

	/** Whether the settings came from build/build.json, the layout before 2.0. */
	boolean function isLegacyLayout(){
		return variables.legacyLayout;
	}

	/** The installed kit's own version. Empty when it cannot be read. */
	string function kitVersion(){
		try {
			return trim( deserializeJSON( fileRead( expandPath( "/build-template/box.json" ) ) ).version ?: "" );
		} catch ( any ignoredException ) {
			return "";
		}
	}

	/** Reads and returns the project's box.json. */
	struct function boxJSON(){
		var path = repoPath( "box.json" );
		if ( !fileExists( path ) ) {
			throw( type = "BuildConfig", message = "No box.json found at #path#. Run release commands from a CommandBox project." );
		}
		return deserializeJSON( fileRead( path ) );
	}

	/** The package slug from box.json, falling back to the package name. */
	string function slug(){
		var box = boxJSON();
		return box.slug ?: ( box.name ?: "package" );
	}

	/** The version from box.json. */
	string function version(){
		return boxJSON().version ?: "0.0.0";
	}

	/**
	 * Runs git, gh, or another program in the project root and returns its exit code and
	 * output. Never throws; see ProcessRunner.
	 *
	 * @name The program name, for example "git".
	 * @args The arguments, for example [ "status", "--porcelain" ].
	 */
	struct function execNative( required string name, array args = [] ){
		return variables.processRunner.run( arguments.name, arguments.args, variables.root );
	}

	/** Whether a program can be found and run at all. */
	boolean function commandExists( required string name ){
		return variables.processRunner.commandExists( arguments.name );
	}

	/** The full path of a program, or its bare name when it cannot be found. */
	string function findBinary( required string name ){
		return variables.processRunner.findBinary( arguments.name );
	}

	/** The exclude list the build actually uses: the base list plus anything in excludesAdd. */
	array function allExcludes(){
		var result = duplicate( variables.settings.excludes );
		result.append( variables.settings.excludesAdd, true );
		return result;
	}

	/**
	 * The address to check when asking "is the test server up?". It is the site root, not the
	 * test runner: asking for the runner would start the whole suite.
	 */
	string function probeUrl(){
		return reReplaceNoCase( variables.settings.testRunner, "^(https?://[^/]+).*$", "\1" ) & "/";
	}

	// SETTINGS

	/**
	 * Builds the settings struct: start with the defaults, lay the settings file over the top,
	 * then check the result makes sense.
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
						message = "#fileName# is not valid JSON (#exception.message#). "
							& "Two common causes are an unquoted value and a single backslash. "
							& "Backslashes must be doubled in JSON, so a regular expression looks like ""\\.avif$""."
					);
				}
				if ( !isStruct( userSettings ) ) {
					throw( type = "BuildConfig", message = "#fileName# must hold a JSON object, for example { ""branch"": ""main"" }." );
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
	 * The settings used when build.json does not say otherwise.
	 */
	private struct function defaults(){
		return {
			"minimumKitVersion" : "",
			"projectType"       : "module",
			"branch"            : "main",
			"changelog"         : "CHANGELOG.md",
			// Empty means "work it out": box.json's testbox.runner, or the fallback below.
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
	 * Adjusts defaults to suit the project type. An app has nowhere to publish on ForgeBox, so
	 * that step is off unless build.json turns it back on.
	 */
	private void function applyProjectTypeDefaults( required struct settings ){
		if ( lCase( arguments.settings.projectType ) == "app" && !userTouched( "publish.forgebox" ) ) {
			arguments.settings.publish.forgebox = false;
		}
	}

	/**
	 * Works out the settings that can be read from the project itself, so build.json can stay
	 * short. Right now that is the test runner URL, taken from box.json's testbox.runner.
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
	 * Lays one struct over another. Nested structs are merged key by key so a build.json that
	 * sets only publish.github keeps the default for publish.forgebox. Arrays replace whatever
	 * they land on, because a half-replaced exclude list would be a puzzle to debug.
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

	/** Whether the settings file set a key, so dependent defaults do not overwrite a choice. */
	private boolean function userTouched( required string key ){
		return structKeyExists( variables.touchedKeys, arguments.key );
	}

	/** Runs each group of validation rules after all defaults are applied. */
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
			throw( type = "BuildConfig", message = "build.json branch cannot be empty. Use the branch you release from, for example ""main""." );
		}
		if ( !len( trim( arguments.settings.changelog ) ) ) {
			throw( type = "BuildConfig", message = "build.json changelog cannot be empty. Name your changelog file, for example ""CHANGELOG.md""." );
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
					message = "Every entry in build.json engines needs a configFile, for example "
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
				message = "build.json testRunner must be a full URL, for example "
					& """http://127.0.0.1:60310/tests/runner.cfm""."
			);
		}
	}

	/**
	 * A project can insist on a newer kit with minimumKitVersion. Every machine that releases
	 * the project then gets the same behaviour, or a clear message to update.
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
				message = "This project needs build-template #required# or newer, but #installed# is installed. "
					& "Run: box update build-template --system"
			);
		}
	}
}

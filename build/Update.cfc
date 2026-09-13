/**
 * Brings a project's copy of the build kit up to date.
 *
 * Run `box run-script build-kit:update` from the project root. The task downloads the latest
 * build-template release from GitHub, replaces the kit's own files under build/, adds any new
 * scripts to box.json, and records the kit version in build/build.json. It never changes the
 * settings in build/build.json and never deletes a file the kit does not ship.
 *
 * Pass `:source=` with a folder or zip to update from a local copy instead, `:version=` to
 * choose a release, and `:dryRun=true` to see what would change without writing anything.
 */
component {

	/**
	 * Works out the project paths. It deliberately does not load build/build.json, so a broken
	 * settings file can still be repaired by an update.
	 */
	function init(){
		variables.buildDir          = getDirectoryFromPath( getCurrentTemplatePath() );
		variables.root              = reReplace( reReplace( variables.buildDir, "[\\/]$", "" ), "[\\/][^\\/]+$", "" );
		variables.stagingDir        = variables.root & "/.tmp/build-kit-update";
		variables.defaultRepository = "homestar9/build-template";

		variables.versionService   = new lib.VersionService();
		variables.changelogService = new lib.ChangelogService();
		variables.packageScripts   = new lib.PackageScriptService();
		return this;
	}

	/**
	 * Updates the kit files and reports what changed.
	 *
	 * @source  A folder or zip holding a build-template checkout, or its build folder. Leave
	 *          empty to download a release from GitHub.
	 * @version The release to download, for example 1.5.0. Leave empty for the latest.
	 * @dryRun  List what would change without writing anything.
	 */
	function run( string source = "", string version = "", boolean dryRun = false ){
		print.line().boldLine( "Updating the build kit" ).line( repeatString( "-", 60 ) ).toConsole();

		if ( !fileExists( variables.root & "/box.json" ) ) {
			return error(
				"No box.json found at #variables.root#. Run this from your project root, "
				& "the folder that holds the build folder."
			);
		}
		if ( arguments.dryRun ) {
			print.boldYellowLine( "DRY RUN: nothing will be written." ).toConsole();
		}

		try {
			var kit        = resolveSource( arguments.source, arguments.version );
			var newVersion = readKitVersion( kit.kitDir );
			var oldVersion = currentTemplateVersion();
			var changes    = planChanges( kit.kitDir );

			printChanges( oldVersion, newVersion, changes );

			if ( arguments.dryRun ) {
				print
					.line()
					.yellowLine(
						"Dry run: nothing was written. A real run also adds missing box.json scripts "
						& "and sets templateVersion to #newVersion#."
					)
					.toConsole();
				return;
			}

			applyChanges( changes );
			patchBoxJSON();
			stampTemplateVersion( newVersion );
			printChangelogSince( kit.changelogPath, oldVersion, newVersion );
			printFinish( newVersion, changes );
		} finally {
			cleanupStaging();
		}
	}

	// FINDING THE NEW KIT

	/**
	 * Turns the source argument into a kit folder. Returns the kit's build folder and, when the
	 * source is a whole checkout, the path of its changelog.
	 *
	 * @source  The folder or zip given by the caller, or empty to download.
	 * @version The requested release, or empty for the latest.
	 */
	private struct function resolveSource( required string source, required string version ){
		if ( !len( trim( arguments.source ) ) ) {
			return downloadRelease( arguments.version );
		}

		var path = absolutePath( trim( arguments.source ) );
		if ( fileExists( path ) && reFindNoCase( "\.zip$", path ) ) {
			print.line( "Source: #path#" ).toConsole();
			return locateKit( extractArchive( path ) );
		}
		if ( directoryExists( path ) ) {
			print.line( "Source: #path#" ).toConsole();
			return locateKit( path );
		}
		return error( "Could not find a folder or zip at #path#." );
	}

	/**
	 * Downloads a tagged release from GitHub and returns its kit folder.
	 *
	 * The tag list comes from git rather than the GitHub API, so it works without a token and
	 * sees every release tag, whether or not a GitHub Release was written for it.
	 *
	 * @version The requested release, or empty for the highest stable version.
	 */
	private struct function downloadRelease( required string version ){
		var repository = kitRepository();
		var config     = requireConfigForGit();

		var listing = config.execNative( "git", [ "ls-remote", "--tags", "https://github.com/#repository#.git" ] );
		if ( listing.exitCode == 127 ) {
			return error( "Could not find git, which is used to list releases. Install it, or pass :source=<folder or zip>." );
		}
		if ( listing.exitCode != 0 ) {
			return error(
				"Could not list releases from GitHub (#listing.output#). "
				& "Check your connection, or pass :source=<folder or zip> to update from a local copy."
			);
		}

		var chosen = chooseTag( parseTagListing( listing.output ), arguments.version, repository );
		print.line( "Source: #repository# #chosen.tag#" ).toConsole();

		return locateKit( extractArchive( downloadArchive( repository, chosen.tag ) ) );
	}

	/**
	 * Loads BuildConfig for its process helper. Only the download needs it, and a project whose
	 * build.json will not load can still update from a local copy.
	 */
	private any function requireConfigForGit(){
		try {
			return new BuildConfig( variables.buildDir );
		} catch ( any exception ) {
			return error(
				"Downloading needs build/build.json to load, but it did not (#exception.message#). "
				& "Fix it, or pass :source=<folder or zip> to update from a local copy."
			);
		}
	}

	/**
	 * Reads git's tag listing into an array of { tag, version } for the tags that look like
	 * versions. Lines are "<sha><tab>refs/tags/<name>"; the "^{}" lines git adds for annotated
	 * tags are skipped.
	 *
	 * @output The text printed by git ls-remote --tags.
	 */
	private array function parseTagListing( required string output ){
		var tags   = [];
		var prefix = "refs/tags/";
		for ( var line in listToArray( arguments.output, chr( 10 ) ) ) {
			var ref   = trim( listLast( line, chr( 9 ) ) );
			var match = reFind( "^refs/tags/(v?)(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)$", ref, 1, true );
			if ( arrayLen( match.pos ) < 3 || match.pos[ 1 ] == 0 ) {
				continue;
			}
			tags.append( {
				tag     : mid( ref, len( prefix ) + 1, len( ref ) - len( prefix ) ),
				version : mid( ref, match.pos[ 3 ], match.len[ 3 ] )
			} );
		}
		return tags;
	}

	/**
	 * Picks the tag to download: the requested version, or the highest stable one.
	 *
	 * @tags       The parsed tag listing.
	 * @version    The requested version, with or without a leading v, or empty.
	 * @repository The repository name, for messages.
	 */
	private struct function chooseTag( required array tags, required string version, string repository = "" ){
		var versions = [];
		for ( var entry in arguments.tags ) {
			versions.append( entry.version );
		}

		var wanted = reReplace( trim( arguments.version ), "^v", "" );
		if ( !len( wanted ) ) {
			wanted = variables.versionService.highestVersion( versions );
		}
		if ( !len( wanted ) ) {
			return error( "No release versions were found for #arguments.repository#." );
		}
		for ( var entry in arguments.tags ) {
			if ( entry.version == wanted ) {
				return entry;
			}
		}
		return error(
			"Version #wanted# is not a release of #arguments.repository#. "
			& "Available: #arrayToList( versions, ", " )#"
		);
	}

	/**
	 * Downloads the source zip GitHub serves for a tag into the staging folder.
	 *
	 * @repository The owner/name of the repository.
	 * @tag        The tag to download.
	 */
	private string function downloadArchive( required string repository, required string tag ){
		// Not named "url": that is a CFML scope, and #url# would read the scope instead.
		var archiveUrl = "https://github.com/#arguments.repository#/archive/refs/tags/#arguments.tag#.zip";
		print.line( "Downloading #archiveUrl#" ).toConsole();

		prepareStaging();
		var download = "";
		try {
			cfhttp(
				url          = archiveUrl,
				method       = "GET",
				getAsBinary  = "yes",
				redirect     = true,
				timeout      = 120,
				throwOnError = false,
				result       = "local.download"
			);
		} catch ( any exception ) {
			return error( "The download failed (#exception.message#). Check your connection, or pass :source=<folder or zip>." );
		}
		var statusCode = download.statusCode ?: "unknown";
		if ( val( statusCode ) != 200 ) {
			return error( "The download failed (status #statusCode#). Check your connection, or pass :source=<folder or zip>." );
		}

		var zipPath = variables.stagingDir & "/build-kit.zip";
		fileWrite( zipPath, download.fileContent );
		return zipPath;
	}

	/**
	 * Unzips an archive into the staging folder and returns the folder it landed in.
	 *
	 * @zipPath The zip file to open.
	 */
	private string function extractArchive( required string zipPath ){
		// Only the extract folder is refreshed here. The zip may sit in the staging folder too,
		// when it has just been downloaded, so the whole folder must not be cleared.
		var extractDir = variables.stagingDir & "/extracted";
		if ( directoryExists( extractDir ) ) {
			directoryDelete( extractDir, true );
		}
		directoryCreate( extractDir, true, true );
		cfzip( action = "unzip", file = arguments.zipPath, destination = extractDir, overwrite = true );
		return extractDir;
	}

	/**
	 * Finds the kit inside a folder. GitHub's zip wraps everything in a folder named after the
	 * tag, so one level of nesting is looked into as well.
	 *
	 * @folder A checkout, its build folder, or a folder holding one of those.
	 */
	private struct function locateKit( required string folder ){
		var candidates = [ reReplace( arguments.folder, "[\\/]$", "" ) ];
		candidates.append( directoryList( candidates[ 1 ], false, "path", "", "", "dir" ), true );

		for ( var candidate in candidates ) {
			var kitRoot = reReplace( candidate, "[\\/]$", "" );
			if ( fileExists( kitRoot & "/build/Install.cfc" ) ) {
				return { kitDir : kitRoot & "/build", changelogPath : kitRoot & "/CHANGELOG.md" };
			}
			if ( fileExists( kitRoot & "/Install.cfc" ) ) {
				return { kitDir : kitRoot, changelogPath : "" };
			}
		}
		return error( "No build kit found in #arguments.folder#. Expected build/Install.cfc, as in a build-template download." );
	}

	/**
	 * Reads the version the new kit says it is.
	 *
	 * @kitDir The new kit's build folder.
	 */
	private string function readKitVersion( required string kitDir ){
		var manifest = readManifest( arguments.kitDir & "/build-kit.json" );
		if ( !len( trim( manifest.version ?: "" ) ) ) {
			return error(
				"That source is not a build kit this task can use: no readable build-kit.json in #arguments.kitDir#. "
				& "It needs build-template 1.5.0 or later."
			);
		}
		return trim( manifest.version );
	}

	/**
	 * The repository to download from, taken from the project's own kit manifest so a fork can
	 * point at itself.
	 */
	private string function kitRepository(){
		var manifest = readManifest( variables.buildDir & "build-kit.json" );
		return len( trim( manifest.repository ?: "" ) ) ? trim( manifest.repository ) : variables.defaultRepository;
	}

	/** Reads a build-kit.json, returning an empty struct when it is missing or broken. */
	private struct function readManifest( required string path ){
		try {
			var manifest = deserializeJSON( fileRead( arguments.path ) );
			return isStruct( manifest ) ? manifest : {};
		} catch ( any ignoredException ) {
			return {};
		}
	}

	/**
	 * The kit version the project is on now. Projects installed before the version was stamped
	 * count as 1.0.0. An unreadable build.json gives an empty string, which skips the changelog.
	 */
	private string function currentTemplateVersion(){
		try {
			var settings = deserializeJSON( fileRead( variables.buildDir & "build.json" ) );
			if ( isStruct( settings ) && len( trim( settings.templateVersion ?: "" ) ) ) {
				return trim( settings.templateVersion );
			}
			return "1.0.0";
		} catch ( any ignoredException ) {
			return "";
		}
	}

	// PLANNING AND APPLYING CHANGES

	/**
	 * Lists the files a kit ships, relative to its build folder: the task components, the lib
	 * and templates folders, and the manifest. build.json is the project's, never the kit's.
	 *
	 * @kitDir The build folder to read.
	 */
	private array function kitManifest( required string kitDir ){
		var files = directoryList( arguments.kitDir, false, "name", "*.cfc", "", "file" );
		if ( fileExists( arguments.kitDir & "/build-kit.json" ) ) {
			files.append( "build-kit.json" );
		}
		for ( var sub in [ "lib", "templates" ] ) {
			var subDir = arguments.kitDir & "/" & sub;
			if ( !directoryExists( subDir ) ) {
				continue;
			}
			for ( var path in directoryList( subDir, true, "path", "", "", "file" ) ) {
				files.append( sub & "/" & relativeTo( subDir, path ) );
			}
		}
		return files;
	}

	/**
	 * Compares the new kit with the project's copy. Each entry names the file, what will
	 * happen to it, and where it comes from and goes to. Files the project has that the kit
	 * does not ship are listed as "keep" so nobody wonders about them.
	 *
	 * @kitDir The new kit's build folder.
	 */
	private array function planChanges( required string kitDir ){
		var changes = [];
		var shipped = {};
		for ( var relative in kitManifest( arguments.kitDir ) ) {
			var sourcePath = arguments.kitDir & "/" & relative;
			var targetPath = variables.buildDir & relative;
			var action     = "same";
			if ( !fileExists( targetPath ) ) {
				action = "add";
			} else if ( !sameContent( sourcePath, targetPath ) ) {
				action = "update";
			}
			shipped[ lCase( relative ) ] = true;
			changes.append( { relative : relative, action : action, source : sourcePath, target : targetPath } );
		}

		for ( var relative in kitManifest( reReplace( variables.buildDir, "[\\/]$", "" ) ) ) {
			if ( !structKeyExists( shipped, lCase( relative ) ) ) {
				changes.append( { relative : relative, action : "keep", source : "", target : variables.buildDir & relative } );
			}
		}
		return changes;
	}

	/**
	 * Copies every added or changed file into place. Update.cfc itself goes last: Lucee has
	 * already compiled the running copy, and nothing here reads the file again.
	 *
	 * @changes The plan from planChanges().
	 */
	private void function applyChanges( required array changes ){
		var pending = arguments.changes.filter( function( change ){
			return listFindNoCase( "add,update", change.action ) > 0;
		} );
		pending.sort( function( first, second ){
			var firstIsSelf  = first.relative == "Update.cfc";
			var secondIsSelf = second.relative == "Update.cfc";
			if ( firstIsSelf == secondIsSelf ) {
				return compareNoCase( first.relative, second.relative );
			}
			return firstIsSelf ? 1 : -1;
		} );

		for ( var change in pending ) {
			var targetDir = getDirectoryFromPath( change.target );
			if ( !directoryExists( targetDir ) ) {
				directoryCreate( targetDir, true, true );
			}
			fileCopy( change.source, change.target );
		}
	}

	/**
	 * Adds missing build-kit scripts to box.json. It never replaces an existing script.
	 */
	private void function patchBoxJSON(){
		var packagePath = variables.root & "/box.json";
		var result      = variables.packageScripts.addMissingScripts( deserializeJSON( fileRead( packagePath ) ) );

		if ( arrayLen( result.added ) ) {
			fileWrite( packagePath, formatJSON( result.packageData ) );
			var scriptCount = arrayLen( result.added );
			print
				.greenLine( "  added  #scriptCount# script#( scriptCount == 1 ? "" : "s" )# to box.json: #result.added.toList( ", " )#" )
				.toConsole();
		} else {
			print.line( "  box.json already has every script" ).toConsole();
		}
	}

	/**
	 * Writes the new kit version into build/build.json, changing only that one value so the
	 * project's settings keep their formatting. A build.json without the key gets it added at
	 * the top.
	 *
	 * @version The kit version to record.
	 */
	private void function stampTemplateVersion( required string version ){
		var path = variables.buildDir & "build.json";
		if ( !fileExists( path ) ) {
			print.yellowLine( "  skip   build/build.json is missing; run: box task run taskFile=build/Install.cfc" ).toConsole();
			return;
		}
		var text = fileRead( path );

		// Splice the text rather than using a replacement pattern, for the reason Bump.cfc gives:
		// "\1" placed before a value that starts with a digit reads as another group number.
		var match = reFind( '("templateVersion"\s*:\s*")([^"]*)(")', text, 1, true );
		if ( arrayLen( match.pos ) >= 3 && match.pos[ 1 ] > 0 ) {
			fileWrite(
				path,
				left( text, match.pos[ 3 ] - 1 )
					& arguments.version
					& mid( text, match.pos[ 3 ] + match.len[ 3 ], len( text ) )
			);
			print.greenLine( "  set    templateVersion to #arguments.version# in build/build.json" ).toConsole();
			return;
		}

		var brace = find( "{", text );
		if ( !brace ) {
			print.yellowLine( "  skip   build/build.json is not a JSON object, so templateVersion was not recorded" ).toConsole();
			return;
		}
		var after      = mid( text, brace + 1, len( text ) - brace );
		var whitespace = reFind( "^\s*", after, 1, true );
		var indent     = whitespace.len[ 1 ] ? mid( after, 1, whitespace.len[ 1 ] ) : "";
		var rest       = mid( after, len( indent ) + 1, len( after ) - len( indent ) );
		var entry      = '"templateVersion":"' & arguments.version & '"' & ( left( rest, 1 ) == "}" ? "" : "," );
		fileWrite( path, left( text, brace ) & indent & entry & indent & rest );
		print.greenLine( "  set    templateVersion to #arguments.version# in build/build.json" ).toConsole();
	}

	// OUTPUT

	/**
	 * Prints the version change and every file that will be added or replaced.
	 */
	private void function printChanges( required string oldVersion, required string newVersion, required array changes ){
		print
			.line()
			.boldLine( "Build kit: #( len( arguments.oldVersion ) ? arguments.oldVersion : "unknown" )# -> #arguments.newVersion#" )
			.toConsole();

		var unchanged = 0;
		var touched   = 0;
		for ( var change in arguments.changes ) {
			if ( change.action == "same" ) {
				unchanged++;
				continue;
			}
			if ( change.action == "keep" ) {
				print.line( "  keep   build/#change.relative# (not part of the kit, left alone)" ).toConsole();
				continue;
			}
			touched++;
			print.line( "  " & lJustify( change.action, 7 ) & "build/" & change.relative ).toConsole();
		}
		if ( !touched ) {
			print.greenLine( "  Every kit file is already up to date." ).toConsole();
		}
		if ( unchanged ) {
			print.line( "  #unchanged# file#( unchanged == 1 ? "" : "s" )# unchanged" ).toConsole();
		}
	}

	/**
	 * Prints the template's own changelog sections between the old and new kit versions, so
	 * the update explains itself.
	 *
	 * @changelogPath The new kit's CHANGELOG.md, or empty when the source had none.
	 * @oldVersion    The version the project was on.
	 * @newVersion    The version it is on now.
	 */
	private void function printChangelogSince(
		required string changelogPath,
		required string oldVersion,
		required string newVersion
	){
		if ( !len( arguments.oldVersion ) || !len( arguments.changelogPath ) || !fileExists( arguments.changelogPath ) ) {
			return;
		}
		var direction = variables.versionService.compareVersions( arguments.newVersion, arguments.oldVersion );
		if ( direction < 0 ) {
			print.line().yellowLine( "This moved the kit back from #arguments.oldVersion# to #arguments.newVersion#." ).toConsole();
			return;
		}
		if ( direction == 0 ) {
			return;
		}

		var content = fileRead( arguments.changelogPath );
		var heading = repeatString( chr( 35 ), 2 ) & " ";
		var printed = false;
		for ( var version in variables.changelogService.versionHeadings( content ) ) {
			if (
				variables.versionService.compareVersions( version, arguments.oldVersion ) <= 0
				|| variables.versionService.compareVersions( version, arguments.newVersion ) > 0
			) {
				continue;
			}
			var notes = "";
			try {
				notes = variables.changelogService.extractReleaseNotes( content, version );
			} catch ( any emptyOrMissingSection ) {
				continue;
			}
			if ( !printed ) {
				print.line().boldLine( "What changed in the kit since #arguments.oldVersion#:" ).toConsole();
				printed = true;
			}
			print.line().boldLine( heading & "[" & version & "]" ).line( notes ).toConsole();
		}
	}

	private void function printFinish( required string newVersion, required array changes ){
		var touched         = 0;
		var releaseDocMoved = false;
		for ( var change in arguments.changes ) {
			if ( listFindNoCase( "add,update", change.action ) ) {
				touched++;
				if ( change.relative == "templates/RELEASE.md" ) {
					releaseDocMoved = true;
				}
			}
		}

		print.line().line( repeatString( "-", 60 ) ).toConsole();
		if ( touched ) {
			print.boldGreenLine( "Updated the build kit to #arguments.newVersion#." ).toConsole();
		} else {
			print.boldGreenLine( "The build kit is already at #arguments.newVersion#." ).toConsole();
		}
		print.line( "Review the changes with: git diff build/ box.json" ).line( "Then commit them." ).toConsole();
		if ( releaseDocMoved ) {
			print
				.line( "build/templates/RELEASE.md changed. Copy it over RELEASE.md in the project root unless you have customised yours." )
				.toConsole();
		}
	}

	// HELPERS

	/**
	 * Makes a caller's path absolute against the shell's folder. CommandBox's own resolvePath()
	 * measures from the task file's folder, which is not what someone typing a path expects.
	 */
	private string function absolutePath( required string path ){
		if ( reFind( "^([a-zA-Z]:)?[\\/]", arguments.path ) ) {
			return arguments.path;
		}
		return reReplace( shell.pwd(), "[\\/]$", "" ) & "/" & arguments.path;
	}

	/** The part of a path below a base folder, with forward slashes. */
	private string function relativeTo( required string base, required string path ){
		var normalisedBase = reReplace( replace( arguments.base, "\", "/", "all" ), "/$", "" );
		var normalisedPath = replace( arguments.path, "\", "/", "all" );
		return mid( normalisedPath, len( normalisedBase ) + 2, len( normalisedPath ) - len( normalisedBase ) - 1 );
	}

	/**
	 * Whether two text files hold the same content. Line endings are ignored, so a checkout
	 * that git converted to CRLF is not reported as changed.
	 */
	private boolean function sameContent( required string first, required string second ){
		var crlf = chr( 13 ) & chr( 10 );
		return compare(
			replace( fileRead( arguments.first ), crlf, chr( 10 ), "all" ),
			replace( fileRead( arguments.second ), crlf, chr( 10 ), "all" )
		) == 0;
	}

	/** Creates an empty staging folder for downloads and extracted zips. */
	private void function prepareStaging(){
		cleanupStaging();
		directoryCreate( variables.stagingDir, true, true );
	}

	/** Removes the staging folder. A file Windows still holds open is not worth failing over. */
	private void function cleanupStaging(){
		try {
			if ( directoryExists( variables.stagingDir ) ) {
				directoryDelete( variables.stagingDir, true );
			}
		} catch ( any ignoredException ) {
			// Leftovers under .tmp are ignored by git and harmless.
		}
	}

	/**
	 * Turns a struct into readable JSON, using CommandBox's formatter when available so the
	 * result matches how it writes box.json.
	 */
	private string function formatJSON( required struct data ){
		var json = serializeJSON( arguments.data );
		try {
			return formatterUtil.formatJSON( json );
		} catch ( any ignoredException ) {
			return json;
		}
	}
}

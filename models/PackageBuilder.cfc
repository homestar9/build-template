/**
 * Builds and checks a package before publishing.
 *
 * `box release package` runs the tests and copies allowed source files into an empty temporary
 * folder. It replaces version placeholders, creates a zip file, checks its contents, and
 * writes checksum files.
 *
 * It writes build files under .artifacts/<slug>/<version>/. Use `--skipTests` only when the
 * same source code already passed the tests. Project settings come from build.json.
 */
component extends="build-template.models.BaseKitService" {

	/**
	 * Stores the project and its temporary and artifact folder paths. It does not change either
	 * folder until the first build step runs.
	 */
	function forProject( required any config ){
		super.forProject( arguments.config );
		variables.stagingRoot  = variables.root & "/" & variables.settings.stagingDir;
		variables.artifactsDir = variables.root & "/" & variables.settings.artifactsDir;
		variables.prepared     = false;
		return this;
	}

	/**
	 * Runs tests, builds the package, and writes checksum files.
	 *
	 * @projectName The package folder and zip filename. The default is the box.json slug.
	 * @version     The version to build. The default is the box.json version.
	 * @buildID     The build ID. The default is the short Git commit hash.
	 * @branch      The branch to build. The default is the current branch.
	 * @skipTests   Skips tests for this run and prints a warning. Use it only after this version
	 *              has passed its tests.
	 */
	function run(
		string projectName = "",
		string version     = "",
		string buildID     = "",
		string branch      = "",
		boolean skipTests  = false
	){
		prepare();
		fillDefaults( arguments );

		if ( arguments.skipTests || !variables.settings.runTests ) {
			var reason = arguments.skipTests ? "requested with skipTests" : "disabled in build.json";
			print
				.line()
				.boldYellowLine( "WARNING: This build skipped the tests (#reason#)." )
				.yellowLine( "This build did not test the package." )
				.line()
				.toConsole();
		} else {
			ensureTestRunnerReachable();
			runTests();
		}

		// Add a mapping so build steps can load components from the project.
		variables.fileSystemUtil.createMapping( arguments.projectName, variables.root );

		buildSource( argumentCollection = arguments );
		buildChecksums();

		print.line().boldMagentaLine( "Build complete. Package files are in #variables.exportsDir#" ).toConsole();
	}

	/**
	 * Runs the tests and stops the build when they fail.
	 */
	function runTests(){
		print.blueLine( "Running the tests..." ).toConsole();

		try {
			command( "testbox run" )
				.params( runner = variables.settings.testRunner, verbose = false )
				.run();
		} catch ( any exception ) {
			return stop( "The tests failed. Fix them, or use --skipTests to build without running them." );
		}
	}

	/**
	 * Creates and checks the source package without running tests.
	 *
	 * @projectName The package folder and zip filename.
	 * @version     The version to build.
	 * @buildID     The build ID.
	 * @branch      The branch to build.
	 * @skipTests   Allows this function to accept the same arguments as run().
	 */
	function buildSource(
		string projectName = "",
		string version     = "",
		string buildID     = "",
		string branch      = "",
		boolean skipTests  = false
	){
		prepare();
		fillDefaults( arguments );

		print
			.line()
			.boldMagentaLine(
				"Building #arguments.projectName# #arguments.version#+#arguments.buildID# from branch #arguments.branch#."
			)
			.toConsole();

		ensureExportDir( arguments.projectName, arguments.version );

		variables.projectBuildDir = variables.stagingRoot & "/#arguments.projectName#";
		directoryCreate( variables.projectBuildDir, true, true );

		copySourceToStaging();
		writeBuildMarker( argumentCollection = arguments );
		replaceBuildTokens( argumentCollection = arguments );

		var zipPath = createPackageZip( arguments.projectName, arguments.version );
		verifyZip( zipPath );
		copyPackageManifest();
	}

	// BUILD STEPS

	/** Empties and creates the temporary and artifact folders once for each build. */
	private void function prepare(){
		if ( variables.prepared ) {
			return;
		}
		for ( var directoryPath in [ variables.stagingRoot, variables.artifactsDir ] ) {
			if ( directoryExists( directoryPath ) ) {
				directoryDelete( directoryPath, true );
			}
			directoryCreate( directoryPath, true, true );
		}
		configureColdBoxMapping();
		variables.prepared = true;
	}

	private void function configureColdBoxMapping(){
		if ( !len( trim( variables.settings.coldboxMapping ) ) ) {
			return;
		}

		var coldboxPath = variables.root & "/" & variables.settings.coldboxMapping;
		if ( directoryExists( coldboxPath ) ) {
			variables.fileSystemUtil.createMapping( "coldbox", coldboxPath );
		}
	}

	private void function copySourceToStaging(){
		print.blueLine( "Copying source files to the temporary build folder..." ).toConsole();
		copy( variables.root, variables.projectBuildDir );
	}

	private void function writeBuildMarker(
		required string projectName,
		required string version,
		required string buildID
	){
		fileWrite(
			"#variables.projectBuildDir#/#arguments.projectName#-#arguments.version#+#arguments.buildID#",
			"Built from commit #arguments.buildID# at #dateTimeFormat( now(), "full" )#"
		);
	}

	private void function replaceBuildTokens(
		required string version,
		required string buildID,
		required string branch
	){
		print.greenLine( "Adding version #arguments.version#" ).toConsole();
		command( "tokenReplace" )
			.params(
				path        = "#variables.projectBuildDir#/**",
				token       = "@build.version@",
				replacement = arguments.version
			)
			.run();

		var isReleaseBranch = arguments.branch == variables.settings.branch;
		print.greenLine( "Adding build ID #arguments.buildID#" ).toConsole();
		command( "tokenReplace" )
			.params(
				path        = "#variables.projectBuildDir#/**",
				token       = isReleaseBranch ? "@build.number@" : "+@build.number@",
				replacement = isReleaseBranch ? arguments.buildID : "-snapshot"
			)
			.run();
	}

	private string function createPackageZip( required string projectName, required string version ){
		var zipPath = "#variables.exportsDir#/#arguments.projectName#-#arguments.version#.zip";
		print.greenLine( "Creating zip file #zipPath#" ).toConsole();
		cfzip(
			action    = "zip",
			file      = zipPath,
			source    = variables.projectBuildDir,
			overwrite = true,
			recurse   = true
		);
		return zipPath;
	}

	private void function copyPackageManifest(){
		// Copy box.json next to the zip so people can read package details without opening it.
		fileCopy( "#variables.projectBuildDir#/box.json", variables.exportsDir );
	}

	// SHARED HELPERS

	/**
	 * Fills blank arguments with project values. The slug and version come from box.json. The
	 * branch and commit come from Git. Both public entry points use these same defaults.
	 */
	private void function fillDefaults( required struct args ){
		if ( !len( trim( arguments.args.projectName ?: "" ) ) ) {
			arguments.args.projectName = variables.config.slug();
		}
		if ( !len( trim( arguments.args.version ?: "" ) ) ) {
			arguments.args.version = variables.config.version();
		}
		if ( !len( trim( arguments.args.branch ?: "" ) ) ) {
			arguments.args.branch = getCurrentBranch();
		}
		if ( !len( trim( arguments.args.buildID ?: "" ) ) ) {
			arguments.args.buildID = getCurrentCommit();
		}
	}

	/**
	 * Reads the current branch directly from .git/HEAD without running Git. It returns the
	 * release branch from build.json when .git/HEAD cannot be read. This fallback supports
	 * source copies that do not include a .git folder.
	 */
	private string function getCurrentBranch(){
		var headFile = variables.root & "/.git/HEAD";
		if ( !fileExists( headFile ) ) {
			return variables.settings.branch;
		}
		var head = trim( fileRead( headFile ) );
		if ( left( head, 16 ) == "ref: refs/heads/" ) {
			return replace( head, "ref: refs/heads/", "" );
		}
		// A detached HEAD contains a commit hash instead of a branch name.
		return variables.settings.branch;
	}

	/**
	 * Reads the short commit hash directly from the .git folder without running Git. It returns
	 * "nocommit" when the source does not contain a readable commit.
	 */
	private string function getCurrentCommit(){
		var headFile = variables.root & "/.git/HEAD";
		if ( !fileExists( headFile ) ) {
			return "nocommit";
		}
		var head       = trim( fileRead( headFile ) );
		var commitHash = "";

		if ( left( head, 5 ) == "ref: " ) {
			// HEAD usually names a branch. Its commit hash is in .git/<ref> or in
			// .git/packed-refs after Git combines reference files.
			var gitReference  = trim( mid( head, 6, len( head ) ) );
			var referenceFile = variables.root & "/.git/" & gitReference;
			if ( fileExists( referenceFile ) ) {
				commitHash = trim( fileRead( referenceFile ) );
			} else {
				var packedFile = variables.root & "/.git/packed-refs";
				if ( fileExists( packedFile ) ) {
					for ( var packedReferenceLine in listToArray( fileRead( packedFile ), chr( 10 ) ) ) {
						var line = trim( packedReferenceLine );
						// Each line uses "<hash> <ref>". Ignore comments and resolved tag lines.
						if ( len( line ) && left( line, 1 ) != "##" && left( line, 1 ) != "^" && right( line, len( gitReference ) ) == gitReference ) {
							commitHash = listFirst( line, " " );
							break;
						}
					}
				}
			}
		} else {
			// A detached HEAD contains the commit hash directly.
			commitHash = head;
		}

		return len( commitHash ) ? left( commitHash, 7 ) : "nocommit";
	}

	/**
	 * Stops the build when the test server does not answer. This separate check reports a server
	 * problem instead of incorrectly reporting a test failure.
	 */
	private function ensureTestRunnerReachable(){
		var probeUrl   = variables.config.probeUrl();
		var statusCode = probe( probeUrl, 15 );
		// Any status from 200 through 399 means that the site answered.
		if ( statusCode < 200 || statusCode >= 400 ) {
			return stop(
				"The test server at #probeUrl# did not answer (status #statusCode#). "
				& "Start the server, and then run this command again. "
				& "Use --skipTests to build without running tests."
			);
		}
	}

	/**
	 * Writes SHA-512 and MD5 files next to the zip. These checksums can show whether a download
	 * changed or became damaged.
	 */
	private function buildChecksums(){
		print.greenLine( "Writing checksum files" ).toConsole();
		command( "checksum" )
			.params(
				path      = "#variables.exportsDir#/*.zip",
				algorithm = "SHA-512",
				extension = "sha512",
				write     = true
			)
			.run();
		command( "checksum" )
			.params(
				path      = "#variables.exportsDir#/*.zip",
				algorithm = "md5",
				extension = "md5",
				write     = true
			)
			.run();
	}

	/**
	 * Stops the build when the zip and temporary folder contain different numbers of files.
 *
	 * This check counts files but does not identify the missing file. It catches any rule that
	 * removes source files from the zip. This check was added after an ignore rule removed
	 * required folders from a published module.
	 */
	private function verifyZip( required string zipPath ){
		cfzip( action = "list", file = arguments.zipPath, name = "local.zipEntries" );

		var stagedCount = directoryList( variables.projectBuildDir, true, "path" )
			.filter( function( item ){
				return fileExists( item );
			} )
			.len();

		// A zip also lists folder entries. Count only file entries.
		var zippedCount = 0;
		for ( var row in local.zipEntries ) {
			if ( row.type == "file" ) {
				zippedCount++;
			}
		}

		if ( zippedCount != stagedCount ) {
			return stop(
				"The zip is incomplete. The temporary folder has #stagedCount# files, but the zip has #zippedCount#. "
				& "Check .gitignore and the build.json exclusion rules for a rule that matches source files. "
				& "Temporary folder: #variables.projectBuildDir#"
			);
		}

		print.greenLine( "Zip check passed. It contains all #zippedCount# temporary files." ).toConsole();
	}

	/**
	 * Copies the project into the temporary folder and skips matching exclusion rules. This
	 * custom copy is needed because a filtered directoryCopy is unreliable on Lucee.
 *
	 * It checks only top-level names. When a folder is allowed, it copies every file inside
	 * that folder. These rules cannot exclude one nested file from an allowed folder.
	 */
	private function copy( required string src, required string target ){
		var excludes = variables.config.allExcludes();
		// Store these values outside the functions below. Inside those functions, "arguments"
		// refers to the inner function and does not contain target.
		var targetDir = arguments.target;
		var printer   = variables.print;

		directoryList(
			arguments.src,
			false,
			"path",
			function( path ){
				var isExcluded = false;
				var name       = relativeName( path );
				excludes.each( function( pattern ){
					if ( name.reFindNoCase( pattern ) ) {
						isExcluded = true;
					}
				} );
				return !isExcluded;
			}
		).each( function( item ){
			var name = relativeName( item );
			if ( fileExists( item ) ) {
				printer.blueLine( "  copy #name#" ).toConsole();
				fileCopy( item, targetDir );
			} else {
				printer.greenLine( "  copy folder #name#" ).toConsole();
				directoryCopy( item, targetDir & "/" & name, true );
			}
		} );
	}

	/**
	 * Returns a path relative to the project root, such as "models" or "box.json".
 *
	 * It changes both paths to use forward slashes before comparing them. directoryList uses
	 * the operating system's separator. Paths with different separators would not match.
	 */
	private string function relativeName( required string path ){
		var normalisedPath = replace( arguments.path, "\", "/", "all" );
		var normalisedRoot = replace( variables.root, "\", "/", "all" );

		var name = replaceNoCase( normalisedPath, normalisedRoot, "", "one" );
		// Remove any separators left at the start or end.
		return reReplace( reReplace( name, "^[\\/]+", "" ), "[\\/]+$", "" );
	}

	/**
	 * Creates .artifacts/<name>/<version>/ and stores its path for the current build.
	 */
	private function ensureExportDir( required string projectName, required string version ){
		if ( structKeyExists( variables, "exportsDir" ) && directoryExists( variables.exportsDir ) ) {
			return;
		}
		variables.exportsDir = variables.artifactsDir & "/#arguments.projectName#/#arguments.version#";
		directoryCreate( variables.exportsDir, true, true );
	}
}

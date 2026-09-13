/**
 * Checks, builds, and publishes the current version of the project in this folder.
 * .
 * The release checks the repository first, fast-forwards the production branch, runs the
 * tests and builds a verified zip, publishes to ForgeBox when enabled, then creates the Git
 * tag and GitHub Release when enabled. Nothing permanent happens until every check passes.
 * .
 * {code:bash}
 * release run
 * release run --dryRun
 * release run --existingTag
 * release run version=1.2.0 buildID=7 --skipTests
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @version     The version to release. Defaults to the box.json version.
	 * @dryRun      Do everything except publish, tag, and push. Prints what it would have run.
	 * @skipTests   Skip the test suite. Use only when the current version has already been tested.
	 * @existingTag Publish a tag that already exists at HEAD, such as one made by a Gitflow finish.
	 *              The tag is pushed first if origin does not have it yet.
	 * @buildID     Optional build identifier stamped into the package. CI uses its run number.
	 */
	function run(
		string version      = "",
		boolean dryRun      = false,
		boolean skipTests   = false,
		boolean existingTag = false,
		string buildID      = ""
	){
		var config = loadProject();
		var args   = arguments;
		runKit( function(){
			kit( "ReleaseService", config ).run( argumentCollection = args );
		} );
	}
}

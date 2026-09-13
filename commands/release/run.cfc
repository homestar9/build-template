/**
 * Checks, builds, and publishes the current project version.
 * .
 * It checks the repository before making changes. It updates the production branch with a
 * fast-forward, runs the tests, and builds a checked zip file. It publishes to ForgeBox when
 * enabled. It then creates the Git tag and GitHub Release when enabled. It does not publish,
 * tag, or push anything until every check passes.
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
	 * @version     The version to release. The default is the version in box.json.
	 * @dryRun      Performs all safe steps. It prints but does not run publish, tag, or push steps.
	 * @skipTests   Skips the tests. Use only when the current version was already tested.
	 * @existingTag Publishes a tag that already exists at HEAD, such as a tag from Gitflow. The
	 *              command pushes the tag when origin does not have it.
	 * @buildID     An optional build ID added to the package. CI uses its run number.
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

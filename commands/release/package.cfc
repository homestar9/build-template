/**
 * Builds and checks the package zip without publishing it.
 * .
 * Runs the tests, copies the allowed source into a staging folder, stamps the version
 * tokens, zips it under .artifacts/<slug>/<version>/, verifies the zip, and writes checksums.
 * .
 * {code:bash}
 * release package
 * release package --skipTests
 * release package version=1.2.0 buildID=7
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @projectName The name used for the package folder and zip. Defaults to the box.json slug.
	 * @version     The version being built. Defaults to the box.json version.
	 * @buildID     The build identifier. Defaults to the short git commit hash.
	 * @branch      The branch being built. Defaults to the checked-out branch.
	 * @skipTests   Skip the test suite for this build. It prints a warning.
	 */
	function run(
		string projectName = "",
		string version     = "",
		string buildID     = "",
		string branch      = "",
		boolean skipTests  = false
	){
		var config = loadProject();
		var args   = arguments;
		runKit( function(){
			kit( "PackageBuilder", config ).run( argumentCollection = args );
		} );
	}
}

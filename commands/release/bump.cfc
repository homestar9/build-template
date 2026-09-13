/**
 * Raises the version in box.json and moves the [Unreleased] changelog notes into a dated
 * section for it. Nothing is committed, tagged, or published.
 * .
 * {code:bash}
 * release bump patch
 * release bump minor --dryRun
 * release bump preminor beta
 * release bump prerelease
 * release bump none
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @level  How much to raise. major, minor, and patch raise the version; prerelease steps a
	 *         prerelease forward; premajor, preminor, and prepatch start one; none keeps the
	 *         version and only dates the changelog.
	 * @level.options major,minor,patch,prerelease,premajor,preminor,prepatch,none
	 * @preid  The prerelease label, such as beta or alpha. Defaults to beta when starting one.
	 * @dryRun Show what would change without writing anything.
	 * @allowPrereleaseRetarget Let preminor move an active prerelease to the next minor version.
	 */
	function run(
		string level = "patch",
		string preid = "",
		boolean dryRun = false,
		boolean allowPrereleaseRetarget = false
	){
		var config = loadProject();
		var args   = arguments;
		runKit( function(){
			kit( "VersionBumper", config ).run( argumentCollection = args );
		} );
	}
}

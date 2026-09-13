/**
 * Sets the project in this folder up for the build kit.
 * .
 * Writes build.json with settings detected from box.json, Git, and the server json files in
 * the project root, and creates CHANGELOG.md when the project has none. Existing files are
 * kept unless --force is given.
 * .
 * {code:bash}
 * release init
 * release init --docs --ci
 * release init --force
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @force Overwrite files that already exist.
	 * @docs  Copy the RELEASE.md guide into the project root.
	 * @ci    Copy the GitHub Actions release workflow to .github/workflows/release.yml.
	 */
	function run( boolean force = false, boolean docs = false, boolean ci = false ){
		var root = projectRoot();
		var args = arguments;
		runKit( function(){
			kit( "ProjectInstaller" ).run( root = root, force = args.force, docs = args.docs, ci = args.ci );
		} );
	}
}

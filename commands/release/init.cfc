/**
 * Sets up the current project for build-template.
 * .
 * Creates build.json from settings found in box.json, Git, and server JSON files in the
 * project root. It creates CHANGELOG.md when the project does not have one. It keeps existing
 * files unless you use --force.
 * .
 * {code:bash}
 * release init
 * release init --docs --ci
 * release init --force
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @force Replaces files that already exist.
	 * @docs  Copies the RELEASE.md guide to the project root.
	 * @ci    Copies the GitHub Actions workflow to .github/workflows/release.yml.
	 */
	function run( boolean force = false, boolean docs = false, boolean ci = false ){
		var root = projectRoot();
		var args = arguments;
		runKit( function(){
			kit( "ProjectInstaller" ).run( root = root, force = args.force, docs = args.docs, ci = args.ci );
		} );
	}
}

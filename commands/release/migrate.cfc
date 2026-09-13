/**
 * Moves a project from the 1.x vendored kit (a copied build folder) to the 2.0 module.
 * .
 * Moves build/build.json to build.json, deletes the kit's own files from build/ while keeping
 * anything else there, and rewrites the box.json scripts that pointed at those files so
 * `box run-script release` keeps working. Every change is listed first.
 * .
 * {code:bash}
 * release migrate --dryRun
 * release migrate
 * release migrate --removeScripts
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @dryRun        List the changes without making them.
	 * @removeScripts Delete the 1.x box.json scripts instead of rewriting them to the new commands.
	 */
	function run( boolean dryRun = false, boolean removeScripts = false ){
		var root = projectRoot();
		var args = arguments;
		runKit( function(){
			kit( "ProjectMigrator" ).run( root = root, dryRun = args.dryRun, removeScripts = args.removeScripts );
		} );
	}
}

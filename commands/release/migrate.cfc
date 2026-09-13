/**
 * Moves a project from the copied 1.x build kit to the 2.0 module.
 * .
 * It moves build/build.json to build.json. It deletes only the files that the kit added under
 * build/. It keeps all other files. It updates the old box.json scripts so
 * `box run-script release` still works. It lists every change before applying it.
 * .
 * {code:bash}
 * release migrate --dryRun
 * release migrate
 * release migrate --removeScripts
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @dryRun        Lists the changes without applying them.
	 * @removeScripts Deletes the 1.x box.json scripts instead of updating them.
	 */
	function run( boolean dryRun = false, boolean removeScripts = false ){
		var root = projectRoot();
		var args = arguments;
		runKit( function(){
			kit( "ProjectMigrator" ).run( root = root, dryRun = args.dryRun, removeScripts = args.removeScripts );
		} );
	}
}

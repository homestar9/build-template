/**
 * Finishes a release that stopped after publishing. It creates and pushes the tag. It then
 * creates a GitHub Release from the zip file under .artifacts.
 * .
 * Use --existingTag when another tool created the tag or when the failure message says that
 * the tag was already pushed.
 * .
 * {code:bash}
 * release github
 * release github version=1.2.0 --existingTag
 * release github --dryRun
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @version     The release version. The default is the version in box.json.
	 * @dryRun      Shows the commands without running them.
	 * @existingTag Uses a tag that already exists at HEAD. The command pushes the tag when it is
	 *              missing from origin.
	 */
	function run( string version = "", boolean dryRun = false, boolean existingTag = false ){
		var config = loadProject();
		var args   = arguments;
		runKit( function(){
			kit( "ReleaseService", config ).github(
				version     = args.version,
				dryRun      = args.dryRun,
				existingTag = args.existingTag
			);
		} );
	}
}

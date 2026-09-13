/**
 * Finishes a release that stopped after publishing: tags, pushes, and creates the GitHub
 * Release from the zip already built under .artifacts.
 * .
 * Use --existingTag when the failure message said the tag was already pushed, or when another
 * tool created the tag.
 * .
 * {code:bash}
 * release github
 * release github version=1.2.0 --existingTag
 * release github --dryRun
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @version     The version being released. Defaults to the box.json version.
	 * @dryRun      Print what would run without doing it.
	 * @existingTag The tag already exists at HEAD. It is pushed only if origin lacks it.
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

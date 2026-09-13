/**
 * Prints the release notes a version would get, taken from its changelog section.
 * .
 * {code:bash}
 * release notes
 * release notes 1.2.0
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	/**
	 * @version The version whose notes to show. Defaults to the box.json version.
	 */
	function run( string version = "" ){
		var config    = loadProject();
		var requested = arguments.version;
		runKit( function(){
			kit( "ReleaseService", config ).notes( requested );
		} );
	}
}

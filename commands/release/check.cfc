/**
 * Reports whether the project in this folder is ready for a release.
 * .
 * It checks the installed kit, the settings, the Git repository, the changelog, the required
 * tools, and the test server, and lists every problem it finds. It changes nothing.
 * .
 * {code:bash}
 * release check
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	function run(){
		var root = projectRoot();
		runKit( function(){
			kit( "ReadinessCheck" ).run( root );
		} );
	}
}

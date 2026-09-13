/**
 * Reports whether the current project is ready for a release.
 * .
 * It checks the installed kit, project settings, Git repository, changelog, required tools,
 * and test server. It lists every problem that it finds. It does not change anything.
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

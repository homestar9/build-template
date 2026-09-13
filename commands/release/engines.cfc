/**
 * Runs the project tests on each CFML engine listed in build.json.
 * .
 * The command starts, prepares, tests, and stops one engine at a time. A failed engine does
 * not stop the remaining engines. The command returns an error when any engine fails.
 * .
 * {code:bash}
 * release engines
 * {code}
 */
component extends="build-template.models.BaseKitCommand" {

	function run(){
		var config = loadProject();
		runKit( function(){
			kit( "EngineRunner", config ).run();
		} );
	}
}

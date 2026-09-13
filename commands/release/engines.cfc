/**
 * Runs the project's test suite on every CFML engine listed in build.json, one at a time.
 * .
 * Each engine is started from its server json file, warmed up, tested, and stopped. Every
 * engine gets its turn even when an earlier one fails, and the command ends with an error
 * when any of them failed.
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

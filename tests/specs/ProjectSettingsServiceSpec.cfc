/** Checks project defaults and display values without reading files. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "ProjectSettingsService", function(){
			beforeEach( function(){
				projectSettings = kit( "ProjectSettingsService" );
			} );

			it( "gets the project type from the package type", function(){
				expect( projectSettings.detectProjectType( { type : "commandbox-modules" } ) ).toBe( "module" );
				expect( projectSettings.detectProjectType( { type : "mvc" } ) ).toBe( "app" );
				expect( projectSettings.detectProjectType( {} ) ).toBe( "app" );
			} );

			it( "reads test runner settings in each supported format", function(){
				expect( projectSettings.detectTestRunner( { testbox : { runner : "http://one/tests" } } ) )
					.toBe( "http://one/tests" );
				expect( projectSettings.detectTestRunner( { testbox : { runner : [ "http://two/tests" ] } } ) )
					.toBe( "http://two/tests" );
				expect( projectSettings.detectTestRunner( { testbox : { runner : { local : "http://three/tests" } } } ) )
					.toBe( "http://three/tests" );
				expect( projectSettings.detectTestRunner( {} ) )
					.toBe( "http://127.0.0.1:60299/tests/runner.cfm" );
			} );

			it( "uses different exclusion rules for modules and applications", function(){
				var moduleExcludes = projectSettings.installerDefaultExcludes( "module" );
				var appExcludes    = projectSettings.installerDefaultExcludes( "app" );

				expect( arrayToList( moduleExcludes ) ).toInclude( "^modules$" );
				expect( arrayToList( appExcludes ) ).notToInclude( "^modules$" );
				expect( arrayToList( appExcludes ) ).toInclude( "well-known" );
			} );

			it( "gets engine names from cfengine, server name, or filename", function(){
				expect( projectSettings.engineName( "server-lucee.json", { app : { cfengine : "lucee@5" } } ) )
					.toBe( "Lucee 5" );
				expect( projectSettings.engineName( "server-local.json", { name : "Local Adobe" } ) )
					.toBe( "Local Adobe" );
				expect( projectSettings.engineName( "server-boxlang-cfml@1.json" ) )
					.toBe( "Boxlang 1" );
			} );
		} );
	}
}

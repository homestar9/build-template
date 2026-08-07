/** Tests project defaults and display values without reading the filesystem. */
component extends="testbox.system.BaseSpec" {

	function run(){
		describe( "ProjectSettingsService", function(){
			beforeEach( function(){
				projectSettings = new build.lib.ProjectSettingsService();
			} );

			it( "detects modules and applications from the package type", function(){
				expect( projectSettings.detectProjectType( { type : "commandbox-modules" } ) ).toBe( "module" );
				expect( projectSettings.detectProjectType( { type : "mvc" } ) ).toBe( "app" );
				expect( projectSettings.detectProjectType( {} ) ).toBe( "app" );
			} );

			it( "reads string, array, and named test runners", function(){
				expect( projectSettings.detectTestRunner( { testbox : { runner : "http://one/tests" } } ) )
					.toBe( "http://one/tests" );
				expect( projectSettings.detectTestRunner( { testbox : { runner : [ "http://two/tests" ] } } ) )
					.toBe( "http://two/tests" );
				expect( projectSettings.detectTestRunner( { testbox : { runner : { local : "http://three/tests" } } } ) )
					.toBe( "http://three/tests" );
				expect( projectSettings.detectTestRunner( {} ) )
					.toBe( "http://127.0.0.1:60299/tests/runner.cfm" );
			} );

			it( "keeps module and application exclusion policies separate", function(){
				var moduleExcludes = projectSettings.installerDefaultExcludes( "module" );
				var appExcludes    = projectSettings.installerDefaultExcludes( "app" );

				expect( arrayToList( moduleExcludes ) ).toInclude( "^modules$" );
				expect( arrayToList( appExcludes ) ).notToInclude( "^modules$" );
				expect( arrayToList( appExcludes ) ).toInclude( "well-known" );
			} );

			it( "names engines from cfengine, server name, or filename", function(){
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

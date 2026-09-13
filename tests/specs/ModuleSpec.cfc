/** Checks the module name, package exclusions, and registered commands. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "Module", function(){
			it( "uses its package slug as the CommandBox module name", function(){
				var packageData  = deserializeJSON( fileRead( repoRoot() & "/box.json" ) );
				var moduleConfig = createObject( "component", "build-template.ModuleConfig" );

				expect( packageData.type ).toBe( "commandbox-modules" );
				expect( packageData.slug ).toBe( "build-template" );
				expect( moduleConfig.cfmapping ).toBe( packageData.slug );
				expect( moduleConfig.modelNamespace ).toBe( packageData.slug );
			} );

			it( "excludes tests and temporary files from the package", function(){
				var ignore = arrayToList( deserializeJSON( fileRead( repoRoot() & "/box.json" ) ).ignore );
				expect( ignore ).toInclude( "/tests/" );
				expect( ignore ).toInclude( "/testbox/" );
				expect( ignore ).toInclude( "/.test-work/" );
			} );

			it( "registers all release commands", function(){
				var hierarchy = application.wirebox.getInstance( "CommandService" ).getCommandHierarchy();
				expect( hierarchy ).toHaveKey( "release" );

				var names = [];
				for ( var key in hierarchy.release ) {
					if ( left( key, 1 ) != "$" ) {
						names.append( key );
					}
				}
				names.sort( "textnocase" );
				expect( arrayToList( names ) ).toBe( "bump,check,engines,github,help,init,migrate,notes,package,run" );
			} );
		} );
	}
}

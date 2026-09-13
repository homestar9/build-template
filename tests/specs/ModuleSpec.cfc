/** Checks the module is declared and registered the way the docs and installer expect. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "Module", function(){
			it( "is a CommandBox module named after its package slug", function(){
				var packageData  = deserializeJSON( fileRead( repoRoot() & "/box.json" ) );
				var moduleConfig = createObject( "component", "build-template.ModuleConfig" );

				expect( packageData.type ).toBe( "commandbox-modules" );
				expect( packageData.slug ).toBe( "build-template" );
				expect( moduleConfig.cfmapping ).toBe( packageData.slug );
				expect( moduleConfig.modelNamespace ).toBe( packageData.slug );
			} );

			it( "keeps the tests and fixtures out of the package", function(){
				var ignore = arrayToList( deserializeJSON( fileRead( repoRoot() & "/box.json" ) ).ignore );
				expect( ignore ).toInclude( "/tests/" );
				expect( ignore ).toInclude( "/testbox/" );
				expect( ignore ).toInclude( "/.test-work/" );
			} );

			it( "registers every release command", function(){
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

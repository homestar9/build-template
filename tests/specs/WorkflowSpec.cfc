/** Uses MockBox to check the engine sweep without starting servers. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "Engine runner workflow", function(){
			it( "runs every configured engine before it reports results", function(){
				var runner = prepareMock( kit( "EngineRunner" ) );
				runner.$property(
					propertyName  = "settings",
					propertyScope = "variables",
					mock          = {
						engines : [
							{ name : "First", configFile : "server-first.json" },
							{ name : "Second", configFile : "server-second.json" }
						]
					}
				);
				runner.$( "stopAllEngines" );
				runner.$( "runEngine" ).$results(
					{ name : "First", passed : false, minutes : "0.1", reason : "failed" },
					{ name : "Second", passed : true, minutes : "0.1", reason : "" }
				);
				runner.$( "report" );

				runner.run();
				expect( runner.$count( "runEngine" ) ).toBe( 2 );
				expect( runner.$count( "report" ) ).toBe( 1 );
			} );

			it( "stops an engine after its suite fails", function(){
				var runner  = prepareMock( kit( "EngineRunner" ) );
				var printer = createPrinterStub();
				runner.$property( propertyName = "print", propertyScope = "variables", mock = printer );
				runner.$( "startEngine", { ok : true, reason : "" } );
				runner.$( "warmUp", { ok : true, reason : "" } );
				runner.$( "runTestSuite", true );
				runner.$( "stopEngine" );
				runner.$( "recordFailure", { name : "Lucee", passed : false, minutes : "0.1", reason : "the suite failed" } );
				makePublic( runner, "runEngine" );

				var result = runner.runEngine( { name : "Lucee", configFile : "server-lucee.json" } );
				expect( result.passed ).toBeFalse();
				expect( runner.$count( "stopEngine" ) ).toBe( 1 );
				expect( runner.$count( "recordFailure" ) ).toBe( 1 );
			} );
		} );
	}

	private any function createPrinterStub(){
		var printer = createStub();
		printer.$( "line", printer );
		printer.$( "boldBlueLine", printer );
		printer.$( "toConsole", printer );
		return printer;
	}
}

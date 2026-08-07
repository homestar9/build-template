/** Uses MockBox to check task orchestration without starting servers or publishing. */
component extends="testbox.system.BaseSpec" {

	function run(){
		describe( "Task workflows", function(){
			it( "runs every configured engine before it reports results", function(){
				var task = prepareMock( new build.TestEngines() );
				task.$property(
					propertyName  = "settings",
					propertyScope = "variables",
					mock          = {
						engines : [
							{ name : "First", configFile : "server-first.json" },
							{ name : "Second", configFile : "server-second.json" }
						]
					}
				);
				task.$( "stopAllEngines" );
				task.$( "runEngine" ).$results(
					{ name : "First", passed : false, minutes : "0.1", reason : "failed" },
					{ name : "Second", passed : true, minutes : "0.1", reason : "" }
				);
				task.$( "report" );

				task.run();
				expect( task.$count( "runEngine" ) ).toBe( 2 );
				expect( task.$count( "report" ) ).toBe( 1 );
			} );

			it( "stops an engine after its suite fails", function(){
				var task    = prepareMock( new build.TestEngines() );
				var printer = createPrinterStub();
				task.$property( propertyName = "print", propertyScope = "variables", mock = printer );
				task.$( "startEngine", { ok : true, reason : "" } );
				task.$( "warmUp", { ok : true, reason : "" } );
				task.$( "runTestSuite", true );
				task.$( "stopEngine" );
				task.$( "recordFailure", { name : "Lucee", passed : false, minutes : "0.1", reason : "the suite failed" } );
				makePublic( task, "runEngine" );

				var result = task.runEngine( { name : "Lucee", configFile : "server-lucee.json" } );
				expect( result.passed ).toBeFalse();
				expect( task.$count( "stopEngine" ) ).toBe( 1 );
				expect( task.$count( "recordFailure" ) ).toBe( 1 );
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

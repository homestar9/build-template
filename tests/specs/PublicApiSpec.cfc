/** Locks the public task names and argument names used by scripts and documentation. */
component extends="testbox.system.BaseSpec" {

	function run(){
		describe( "Public task API", function(){
			it( "keeps every existing public function", function(){
				var expectedFunctions = {
					"build.Build"       : "buildSource,init,run,runTests",
					"build.BuildConfig" : "allExcludes,boxJSON,buildPath,commandExists,execNative,findBinary,get,getRoot,getSettings,init,probeUrl,repoPath,slug,version",
					"build.Bump"        : "init,run",
					"build.Doctor"      : "init,run",
					"build.Install"     : "run",
					"build.Release"     : "github,init,preflight,run",
					"build.TestEngines" : "init,run"
				};

				for ( var componentName in expectedFunctions ) {
					expect( publicFunctionNames( componentName ) ).toBe( expectedFunctions[ componentName ] );
				}
			} );

			it( "keeps the public task argument names", function(){
				expect( functionArgumentNames( "build.Build", "run" ) )
					.toBe( "projectName,version,buildID,branch,skipTests" );
				expect( functionArgumentNames( "build.Build", "buildSource" ) )
					.toBe( "projectName,version,buildID,branch,skipTests" );
				expect( functionArgumentNames( "build.Bump", "run" ) ).toBe( "level,preid,dryRun" );
				expect( functionArgumentNames( "build.Install", "run" ) ).toBe( "force" );
				expect( functionArgumentNames( "build.Release", "run" ) )
					.toBe( "version,dryRun,skipTests,existingTag,buildID" );
				expect( functionArgumentNames( "build.Release", "preflight" ) )
					.toBe( "version,dryRun,existingTag" );
				expect( functionArgumentNames( "build.Release", "github" ) )
					.toBe( "version,notesOnly,dryRun,existingTag" );
			} );

			it( "keeps every existing public argument default", function(){
				expectStringDefaults(
					"build.Build",
					[ "run", "buildSource" ],
					[ "projectName", "version", "buildID", "branch" ],
					""
				);
				expect( argumentDefault( "build.Build", "run", "skipTests" ) ).toBeFalse();
				expect( argumentDefault( "build.Build", "buildSource", "skipTests" ) ).toBeFalse();

				expect( argumentDefault( "build.BuildConfig", "get", "defaultValue" ) ).toBe( "" );
				// Lucee records expression defaults as this metadata marker. The source still uses [].
				expect( argumentDefault( "build.BuildConfig", "execNative", "args" ) )
					.toBe( "[runtime expression]" );

				expect( argumentDefault( "build.Bump", "run", "level" ) ).toBe( "patch" );
				expect( argumentDefault( "build.Bump", "run", "preid" ) ).toBe( "" );
				expect( argumentDefault( "build.Bump", "run", "dryRun" ) ).toBeFalse();
				expect( argumentDefault( "build.Install", "run", "force" ) ).toBeFalse();

				expectStringDefaults(
					"build.Release",
					[ "run" ],
					[ "version", "buildID" ],
					""
				);
				expectStringDefaults(
					"build.Release",
					[ "preflight", "github" ],
					[ "version" ],
					""
				);
				for ( var flag in [ "dryRun", "skipTests", "existingTag" ] ) {
					expect( argumentDefault( "build.Release", "run", flag ) ).toBeFalse();
				}
				for ( var flag in [ "dryRun", "existingTag" ] ) {
					expect( argumentDefault( "build.Release", "preflight", flag ) ).toBeFalse();
					expect( argumentDefault( "build.Release", "github", flag ) ).toBeFalse();
				}
				expect( argumentDefault( "build.Release", "github", "notesOnly" ) ).toBeFalse();
			} );
		} );
	}

	private void function expectStringDefaults(
		required string componentName,
		required array functionNames,
		required array argumentNames,
		required string expectedValue
	){
		for ( var functionName in arguments.functionNames ) {
			for ( var argumentName in arguments.argumentNames ) {
				expect( argumentDefault( arguments.componentName, functionName, argumentName ) )
					.toBe( arguments.expectedValue );
			}
		}
	}

	private string function publicFunctionNames( required string componentName ){
		var names = [];
		for ( var functionMetadata in getComponentMetadata( arguments.componentName ).functions ) {
			if ( ( functionMetadata.access ?: "public" ) == "public" ) {
				names.append( functionMetadata.name );
			}
		}
		names.sort( "textnocase" );
		return arrayToList( names );
	}

	private string function functionArgumentNames(
		required string componentName,
		required string functionName
	){
		for ( var functionMetadata in getComponentMetadata( arguments.componentName ).functions ) {
			if ( functionMetadata.name == arguments.functionName ) {
				var names = [];
				for ( var parameter in functionMetadata.parameters ) {
					names.append( parameter.name );
				}
				return arrayToList( names );
			}
		}
		return "";
	}

	private any function argumentDefault(
		required string componentName,
		required string functionName,
		required string argumentName
	){
		for ( var functionMetadata in getComponentMetadata( arguments.componentName ).functions ) {
			if ( functionMetadata.name != arguments.functionName ) {
				continue;
			}
			for ( var parameter in functionMetadata.parameters ) {
				if ( parameter.name == arguments.argumentName ) {
					return parameter.default;
				}
			}
		}
		throw(
			type    = "PublicApiSpec.MissingArgument",
			message = "Could not find #arguments.componentName#.#arguments.functionName# argument #arguments.argumentName#."
		);
	}
}

/** Checks command and model APIs used by scripts and documentation. */
component extends="tests.support.KitSpec" {

	function run(){
		describe( "Public API", function(){
			it( "keeps all command parameters", function(){
				var expectedParameters = {
					"run"     : "version,dryRun,skipTests,existingTag,buildID",
					"check"   : "",
					"bump"    : "level,preid,dryRun,allowPrereleaseRetarget",
					"package" : "projectName,version,buildID,branch,skipTests",
					"engines" : "",
					"init"    : "force,docs,ci",
					"notes"   : "version",
					"github"  : "version,dryRun,existingTag",
					"migrate" : "dryRun,removeScripts",
					"help"    : ""
				};
				for ( var commandName in expectedParameters ) {
					expect( functionArgumentNames( "commands.release." & commandName, "run" ) )
						.toBe( expectedParameters[ commandName ], "release " & commandName );
				}
			} );

			it( "keeps all command defaults", function(){
				expectStringDefaults( "commands.release.run", [ "version", "buildID" ], "" );
				for ( var flag in [ "dryRun", "skipTests", "existingTag" ] ) {
					expect( argumentDefault( "commands.release.run", "run", flag ) ).toBeFalse();
				}
				expect( argumentDefault( "commands.release.bump", "run", "level" ) ).toBe( "patch" );
				expect( argumentDefault( "commands.release.bump", "run", "preid" ) ).toBe( "" );
				expect( argumentDefault( "commands.release.bump", "run", "dryRun" ) ).toBeFalse();
				expect( argumentDefault( "commands.release.bump", "run", "allowPrereleaseRetarget" ) ).toBeFalse();
				expectStringDefaults( "commands.release.package", [ "projectName", "version", "buildID", "branch" ], "" );
				expect( argumentDefault( "commands.release.package", "run", "skipTests" ) ).toBeFalse();
				for ( var flag in [ "force", "docs", "ci" ] ) {
					expect( argumentDefault( "commands.release.init", "run", flag ) ).toBeFalse();
				}
				expect( argumentDefault( "commands.release.notes", "run", "version" ) ).toBe( "" );
				expect( argumentDefault( "commands.release.github", "run", "version" ) ).toBe( "" );
				expect( argumentDefault( "commands.release.github", "run", "dryRun" ) ).toBeFalse();
				expect( argumentDefault( "commands.release.github", "run", "existingTag" ) ).toBeFalse();
				expect( argumentDefault( "commands.release.migrate", "run", "dryRun" ) ).toBeFalse();
				expect( argumentDefault( "commands.release.migrate", "run", "removeScripts" ) ).toBeFalse();
			} );

			it( "keeps all public model functions", function(){
				var expectedFunctions = {
					"models.ProjectConfig"          : "allExcludes,boxJSON,commandExists,configPath,execNative,findBinary,get,getRoot,getSettings,init,isLegacyLayout,kitVersion,load,probeUrl,repoPath,slug,version",
					"models.ProjectLocator"         : "configFile,findRoot",
					"models.ProcessRunner"          : "commandExists,findBinary,init,run",
					"models.ReleaseService"         : "github,notes,preflight,run",
					"models.PackageBuilder"         : "buildSource,forProject,run,runTests",
					"models.VersionBumper"          : "run",
					"models.ReadinessCheck"         : "run",
					"models.EngineRunner"           : "run",
					"models.ProjectInstaller"       : "run",
					"models.ProjectMigrator"        : "plan,run",
					"models.PackageScriptService"   : "legacyScripts,migrateScripts,modernScripts",
					"models.VersionService"         : "compareVersions,highestVersion,nextVersion,parseVersion,supportedLevels",
					"models.ChangelogService"       : "extractReleaseNotes,moveUnreleasedNotes,versionHeadings",
					"models.ProjectSettingsService" : "buildConfigDefaultExcludes,detectProjectType,detectTestRunner,engineName,installerDefaultExcludes,readableEngineName"
				};
				for ( var componentPath in expectedFunctions ) {
					expect( publicFunctionNames( componentPath ) ).toBe( expectedFunctions[ componentPath ], componentPath );
				}
			} );
		} );
	}

	private void function expectStringDefaults(
		required string componentPath,
		required array argumentNames,
		required string expectedValue
	){
		for ( var argumentName in arguments.argumentNames ) {
			expect( argumentDefault( arguments.componentPath, "run", argumentName ) ).toBe( arguments.expectedValue );
		}
	}

	private string function publicFunctionNames( required string componentPath ){
		var names = [];
		for ( var functionMetadata in kitMeta( arguments.componentPath ).functions ) {
			if ( ( functionMetadata.access ?: "public" ) == "public" ) {
				names.append( functionMetadata.name );
			}
		}
		names.sort( "textnocase" );
		return arrayToList( names );
	}

	private string function functionArgumentNames( required string componentPath, required string functionName ){
		for ( var functionMetadata in kitMeta( arguments.componentPath ).functions ) {
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
		required string componentPath,
		required string functionName,
		required string argumentName
	){
		for ( var functionMetadata in kitMeta( arguments.componentPath ).functions ) {
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
			message = "Argument #arguments.argumentName# was not found on #arguments.componentPath#.#arguments.functionName#."
		);
	}
}

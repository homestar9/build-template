/**
 * Lists the available release commands. `release help` and `help release` show this text.
 */
component excludeFromHelp=true {

	function run(){
		print
			.line()
			.boldLine( "build-template: release CFML projects with CommandBox" )
			.line()
			.line( "Run these commands from any folder inside a project that has box.json." )
			.line()
			.boldLine( "Everyday commands" )
			.line( "  release check              find problems that would stop a release" )
			.line( "  release bump patch         change the version and date the release notes" )
			.line( "  release run --dryRun       practice a release without publishing" )
			.line( "  release run                build and publish the current version" )
			.line()
			.boldLine( "More" )
			.line( "  release run --existingTag  publish a tag created by Gitflow or GitKraken" )
			.line( "  release package            build and check the zip only" )
			.line( "  release engines            run tests on each configured CFML engine" )
			.line( "  release notes              show the release notes for the current version" )
			.line( "  release github             finish a release that stopped after publishing" )
			.line( "  release init               create build.json and CHANGELOG.md" )
			.line( "  release migrate            remove the copied 1.x build kit" )
			.line()
			.line( "Release settings are in build.json. Update the kit with:" )
			.line( "  box update build-template --system" )
			.line()
			.line( "Show all help for one command: help release run" )
			.line()
			.toConsole();
	}
}

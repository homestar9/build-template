/**
 * An overview of the release commands. Shown by `release help` and by the `help release`
 * listing.
 */
component excludeFromHelp=true {

	function run(){
		print
			.line()
			.boldLine( "build-template: release CFML projects from CommandBox" )
			.line()
			.line( "Run these from anywhere inside a project that has a box.json." )
			.line()
			.boldLine( "Everyday commands" )
			.line( "  release check              find anything that would stop a release" )
			.line( "  release bump patch         raise the version and date the changelog notes" )
			.line( "  release run --dryRun       rehearse a release without publishing" )
			.line( "  release run                build and publish the current version" )
			.line()
			.boldLine( "More" )
			.line( "  release run --existingTag  publish a tag Gitflow or GitKraken already created" )
			.line( "  release package            build and check the zip only" )
			.line( "  release engines            run the tests on every configured CFML engine" )
			.line( "  release notes              show the release notes for the current version" )
			.line( "  release github             finish a release that stopped after publishing" )
			.line( "  release init               set a project up: build.json and CHANGELOG.md" )
			.line( "  release migrate            move a project off the 1.x copied build folder" )
			.line()
			.line( "Settings live in build.json in the project root. Update the kit with:" )
			.line( "  box update build-template --system" )
			.line()
			.line( "Full help for a command: help release run" )
			.line()
			.toConsole();
	}
}

/**
 * CommandBox module configuration for the build kit.
 *
 * Installing this module gives CommandBox the `release` namespace: `box release run`,
 * `box release check`, `box release bump`, and the rest. Commands live in commands/release,
 * the work is done by the components in models/, and templates/ holds the files that
 * `release init` can copy into a project.
 *
 * The mapping and model namespace are pinned to the package slug so they stay the same
 * whether the module was installed from ForgeBox or loaded from a checkout by the tests.
 */
component {

	this.title          = "build-template";
	this.cfmapping      = "build-template";
	this.modelNamespace = "build-template";
	this.autoMapModels  = true;

	function configure(){
		settings = {};
	}
}

/**
 * Configures the build-template CommandBox module.
 *
 * This module adds commands under the `release` command group, also called a namespace.
 * Examples include `box release run`, `box release check`, and `box release bump`. The command entry points
 * are in commands/release. Components in models/ perform the work. The templates/ folder
 * contains files that `release init` can copy into a project.
 *
 * The mapping and model namespace always use the package slug. The names stay the same when
 * the module comes from ForgeBox or when the tests load this working copy.
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

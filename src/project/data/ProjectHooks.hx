package project.data;

import modules.entities.EntityTemplate;
import modules.entities.Entity;
import sys.io.File;
import js.node.vm.Script;

class ProjectHooks
{
	private var script: Script;
	private var beforeLoadLevelFn: (Project, Dynamic) -> Dynamic;
	private var beforeSaveLevelFn: (Project, Dynamic) -> Dynamic;
	private var beforeSaveProjectFn: (Project, Dynamic) -> Dynamic;

	private var entityHandlersMap: Map<String, EntityHandlerStruct>;

	public function new(scriptFile:String = '') {
		set(scriptFile);
	}

	public function set(scriptFile:String) {
		if (scriptFile.length <= 0) {
			return;
		}

		if (!sys.FileSystem.exists(scriptFile) || sys.FileSystem.isDirectory(scriptFile)) {
			return;
		}

		var contents:String = File.getContent(scriptFile);
		script = new Script(contents, {filename: scriptFile});
		var scriptObject:Dynamic = script.runInThisContext();

		if (js.Lib.typeof(scriptObject) != "object") {
			return;
		}

		beforeLoadLevelFn = js.Lib.typeof(scriptObject.beforeLoadLevel) == "function" ? scriptObject.beforeLoadLevel : null;
		beforeSaveLevelFn = js.Lib.typeof(scriptObject.beforeSaveLevel) == "function" ? scriptObject.beforeSaveLevel : null;
		beforeSaveProjectFn = js.Lib.typeof(scriptObject.beforeSaveProject) == "function" ? scriptObject.beforeSaveProject : null; 

		var entityHandlersObj = scriptObject.entityHandlers;
		if (js.Lib.typeof(entityHandlersObj) == "object")
		{
			entityHandlersMap = [];
			for (entityName in Reflect.fields(entityHandlersObj))
				entityHandlersMap.set(entityName, Reflect.field(entityHandlersObj, entityName));
		}
		else entityHandlersMap = null;
	}

	// - Level data management hooks

	public function beforeLoadLevel(project:Project, data:Dynamic):Dynamic {
		if (beforeLoadLevelFn == null) {
			return data;
		}

		return beforeLoadLevelFn(project, data);
	}

	public function beforeSaveLevel(project:Project, data:Dynamic):Dynamic {
		if (beforeSaveLevelFn == null) {
			return data;
		}

		return beforeSaveLevelFn(project, data);
	}

	// - Project data management hooks

	public function beforeSaveProject(project:Project, data:Dynamic):Dynamic {
		if (beforeSaveProjectFn == null) {
			return data;
		}

		return beforeSaveProjectFn(project, data);
	}

	// - Entity handling hooks

	public function getEntityHandler(template: EntityTemplate): EntityHandlerStruct
	{
		return (entityHandlersMap != null) ? entityHandlersMap.get(template.name) : null;
	}
}
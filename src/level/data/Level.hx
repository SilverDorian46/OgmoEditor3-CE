package level.data;

import rendering.Texture;
import js.Browser;
import util.Popup;
import electron.renderer.Remote;
import js.node.Path;
import io.FileSystem;
import io.Export;
import io.Imports;
import project.data.Project;
import util.Matrix;
import util.Rectangle;
import util.Vector;

class Level
{
	public var data:LevelData = new LevelData();
	public var layers:Array<Layer> = [];
	public var values:Array<Value> = [];

	//Not Exported
	public var path:String = null;
	public var lastSavedData:String = null;
	public var deleted:Bool = false;
	public var unsavedID:Int;
	public var stack:UndoStack;
	public var unsavedChanges:Bool = false;
	public var project:Project;

	public var safeToClose(get, null):Bool;
	public var displayName(get, null):String;
	public var displayNameNoStar(get, null):String;
	public var displayNameNoExtension(get, null):String;
	public var displayNameNoExtNoLvl_(get, null):String;
	public var managerPath(get, null):String;
	public var currentLayer(get, null):Layer;
	public var externallyDeleted(get, null):Bool;
	public var externallyModified(get, null):Bool;
	//public var zoom(get, null):Float;
	public var shouldWarnSize(get, null):Bool;

	public var levelTexture(default, set): Texture = null;
	public var isLoadingTexture: Bool = false;

	public static function isUnsavedPath(path:String):Bool
	{
		return path.charAt(0) == "#";
	}

	public function new(project:Project, ?data: Dynamic)
	{
		this.project = project;

		stack = new UndoStack(this);

		if (data == null)
		{
			var level_size = project.levelDefaultSize.clone();
			level_size.x = Calc.clamp(level_size.x, OGMO.project.levelMinSize.x, OGMO.project.levelMaxSize.x);
			level_size.y = Calc.clamp(level_size.y, OGMO.project.levelMinSize.y, OGMO.project.levelMaxSize.y);

			level_size.clone(this.data.size);

			values = [];
			for (lv in OGMO.project.levelValues) values.push(new Value(lv));
			initLayers();
		}
		else load(data);
		
		//centerCamera();
	}
	
	public function initLayers():Void
	{
		layers = [];
		for (i in 0...project.layers.length) layers.push(project.layers[i].createLayer(this, i));
	}
	
	public function load(data:Dynamic):Level
	{
		data = this.project.projectHooks.beforeLoadLevel(this.project, data);

		this.data.loadFrom(data);
		values = Imports.values(data, OGMO.project.levelValues);
		
		initLayers();
		var layers = Imports.contentsArray(data, "layers");
		for (i in 0...layers.length)
		{
			var layerData = layers[i];

			var layer = getLayerByExportID(layerData._eid);
			if (layer == null) layer = getLayerByName(layerData.name);
			if (layer != null) layer.load(layerData);
		}

		return this;
	}

	public function storeUndoThenLoad(data:Dynamic):Void
	{
		storeFull(false, false, "Reload from File");
		load(data);
	}

	public function save():Dynamic
	{
		unsavedChanges = false;

		var data:Dynamic = { };
		data._name = "level";
		data._contents = "layers";

		data.ogmoVersion = OGMO.version;

		this.data.saveInto(data);

		Export.values(data, values);

		data.layers = [];
		for (layer in layers)
			data.layers.push(layer.save());

		data = project.projectHooks.beforeSaveLevel(project, data);

		return data;
	}

	public function attemptClose(action:Void->Void):Void
	{
		if (!unsavedChanges)
		{
			action();
		}
		else
		{
			Popup.open("Close Level", "warning", "Save changes to <span class='monospace'>" + displayNameNoStar + "</span> before closing it?", ["Save and Close", "Discard", "Cancel"], function (i)
			{
				if (i == 0)
				{
					if (doSave())
						action();
				}
				else if (i == 1)
					action();
			});
		}
	}

	/*
		ACTUAL SAVING
	*/

	public function doSave(refresh:Bool = true):Bool
	{
		if (path == null)
			return doSaveAs();
		else
		{
			var exists = FileSystem.exists(path);

			Export.level(this, path);

			if (EDITOR.currentLevel == this)
				OGMO.updateWindowTitle();

			if (refresh) 
			{
				if (exists)
					EDITOR.levelsPanel.refreshLabelsAndIcons();
				else
					EDITOR.levelsPanel.refresh();
			}

			return true;
		}
	}

	public function doSaveAs():Bool
	{
		OGMO.resetKeys();

		// uncomment this and add back to dialog to re-enable xml export
		// var filters:Dynamic;
		// if (OGMO.project.defaultExportMode == ".xml")
		// 	filters = [
		// 		{ name: "XML Level", extensions: [ "xml" ]},
		// 		{ name: "JSON Level", extensions: [ "json" ] }
		// 	];
		// else
		// 	filters = [
		// 		{ name: "JSON Level", extensions: [ "json" ] },
		// 		{ name: "XML Level", extensions: [ "xml" ]}
		// 	];

		var file = Ogmo.dialog.showSaveDialogSync(Remote.getCurrentWindow(),
		{
			title: "Save Level As...",
			filters: [{ name: "JSON Level", extensions: [ "json" ] }],
			defaultPath: OGMO.project.lastSavePath
		});

		if (file != null)
		{
			OGMO.project.lastSavePath = Path.dirname(file);
			path = file;
			Export.level(this, file);

			if (EDITOR.currentLevel == this) OGMO.updateWindowTitle();
			EDITOR.levelsPanel.refresh();

			//Update project default export
			if (OGMO.project.defaultExportMode != Path.extname(file))
			{
				OGMO.project.defaultExportMode = Path.extname(file);
				Export.project(OGMO.project, OGMO.project.path);
			}

			return true;
		}
		else
			return false;
	}

	/*
		HELPERS
	*/

	public function getLayer(layerID: Int): Layer
	{
		return layers[layerID];
	}

	public function getLayerByExportID(exportID:String): Layer
	{
		if (exportID != null) for (layer in layers) if (layer.template.exportID == exportID) return layer;
		return null;
	}

	public function getLayerByName(name:String): Layer
	{
		if (name != null) for (layer in layers) if (layer.template.name == name) return layer;
		return null;
	}

	public function insideLevel(pos: Vector):Bool
	{
		return pos.x >= 0 && pos.x < data.size.x && pos.y >= 0 && pos.y < data.size.y;
	}

	/*
		UNDO STATE HELPERS
	*/

	public function store(description:String):Void
	{
		stack.store(description);
	}

	public function storeLevelData(description:String):Void
	{
		stack.storeLevelData(description);
	}

	public function storeFull(freezeRight:Bool, freezeBottom:Bool, description:String):Void
	{
		stack.storeFull(freezeRight, freezeBottom, description);
	}

	/*
		TRANSFORMATIONS
	*/

	public function resize(newSize: Vector, shift: Vector):Void
	{
		if (!data.size.equals(newSize))
		{
			for (layer in layers) layer.resize(newSize.clone(), shift.clone());
			data.size = newSize.clone();
		}
	}

	public function shift(amount: Vector):Void
	{
		for (layer in layers) layer.shift(amount.clone());
	}

	function get_safeToClose():Bool
	{
		return !unsavedChanges && stack.undoStates.length == 0 && stack.redoStates.length == 0 && path != null;
	}

	function get_displayName():String
	{
		var str = displayNameNoStar;
		if (unsavedChanges)
			str += "*";

		return str;
	}

	function get_displayNameNoStar():String
	{
		var str:String;
		if (path == null)
			str = "Unsaved Level " + (unsavedID + 1);
		else
			str = Path.basename(path);

		return str;
	}

	function get_displayNameNoExtension():String
	{
		var str:String = displayNameNoStar;
		str = Path.basename(str, Path.extname(str));

		return str;
	}

	function get_displayNameNoExtNoLvl_():String
	{
		var str:String = displayNameNoExtension;
		if (StringTools.startsWith(str, "lvl_"))
			str = str.substr(4);

		return str;
	}

	function get_managerPath():String
	{
		if (path == null)
			return "#" + unsavedID;
		else
			return path;
	}

	function get_currentLayer():Layer
	{
		return layers[EDITOR.currentLayerID];
	}

	function get_externallyDeleted():Bool
	{
		return path != null && !FileSystem.exists(path);
	}

	function get_externallyModified():Bool
	{
		return path != null && FileSystem.exists(path) && FileSystem.loadString(path) != lastSavedData;
	}

	function get_shouldWarnSize():Bool
	{
		return data.size.x < project.levelScreenSize.x || data.size.y < project.levelScreenSize.y;
	}

	function set_levelTexture(value: Texture): Texture
	{
		levelTexture = value;
		isLoadingTexture = false;
		return levelTexture;
	}
}
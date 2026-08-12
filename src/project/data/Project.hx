package project.data;

import rendering.Atlas;
import electron.renderer.Remote;
import js.lib.Date;
import js.node.Path;
import io.Export;
import io.Imports;
import project.data.value.ValueTemplate;
import modules.autotiler.AutotilerDefinition;
import modules.entities.EntityTemplate;
import modules.entities.EntityTemplateList;
import util.Color;
import util.Vector;

class Project
{
	public var name:String;
	public var levelPaths:Array<String> = [ '.' ];
	public var backgroundColor:Color = Color.fromHex("#282c34", 1);
	public var gridColor:Color = Color.fromHex("#3c4049", 0.8);
	public var anglesRadians:Bool = true;
	public var defaultExportMode:String = ".json";
	public var compactExport:Bool = false;
	public var externalScript:String;
	public var playCommand:String;
	public var directoryDepth:Int = 5;
	public var layerGridDefaultSize = new Vector(8, 8);

	public var levelScreenSize:Vector = new Vector(320, 240);

	public var levelDefaultSize:Vector = new Vector(320, 240);
	public var levelMinSize:Vector = new Vector(128, 128);
	public var levelMaxSize:Vector = new Vector(4096, 4096);
	public var levelValues:Array<ValueTemplate> = [];

	public var entities:EntityTemplateList = new EntityTemplateList();
	public var layers:Array<LayerTemplate> = [];
	public var tilesets:Array<Tileset> = [];
	public var autotilerDefinitions:Array<AutotilerDefinition> = [];

	//Not exported
	public var path:String;
	public var lastSavePath:String;
	public var _nextUnsavedLevelID:Int = 0;
	public var projectHooks:ProjectHooks;

	public var atlas: Atlas;

	inline function new() {}

	public static function createNew(path: String, onReturn: Project -> Void): Void
	{
		var self = new Project();

		self.name = "New Project";
		self.path = Path.resolve(path);
		self.projectHooks = new ProjectHooks();

		var rootdir = js.node.Path.dirname(path);
		var imageMap: Map<String, js.html.ImageElement> = [];
		function recursiveGetImages(dir: String, dirFromRoot: String)
		{
			for (filename in FileSystem.readDirectory(dir))
			{
				var filepath = js.node.Path.join(dir, filename);
				var pathFromRoot = FileSystem.normalize(js.node.Path.join(dirFromRoot, filename));
				if (!sys.FileSystem.isDirectory(filepath))
				{
					var ext = js.node.Path.extname(filepath);
					if (FileSystem.supportedImageExts.contains(ext))
					{
						var img = FileSystem.loadImage(FileSystem.normalize(filepath));
						if (img != null) imageMap.set(pathFromRoot.substr(0, pathFromRoot.length - ext.length), img);
					}
				}
				else recursiveGetImages(filepath, pathFromRoot);
			}
		}
		recursiveGetImages(rootdir, "");

		Atlas.generate(imageMap, rootdir, 4096, 4096, null, function(atlas)
		{
			self.atlas = atlas;

			var subtextureCount = 0;
			for (_ in atlas.subtextures.keys()) subtextureCount++;
			trace('atlas: { rootPath: ${atlas.rootPath}, subtexture count: ${subtextureCount} }');

			onReturn(self);
		});
	}
	
	public function unload()
	{
		for (layer in layers) layer.projectWasUnloaded();
		//for (tileset in tilesets) tileset.texture.dispose();

		atlas.dispose();
	}

	public function getEntityTemplate(id:Int):EntityTemplate
	{
		if (id >= 0 && id < entities.templates.length) return entities.templates[id];
		return null;
	}

	public function getEntityTemplateByExportID(exportID:String): EntityTemplate
	{
		for (entity in entities.templates) if (entity.exportID == exportID) return entity;
		return null;
	}
	
	public function getTileset(name:String):Tileset
	{
		for (tileset in tilesets) if (tileset.label == name) return tileset;
		if (tilesets.length > 0) return tilesets[0];
		return null;
	}

	public function getTilesetStrict(name:String):Tileset
	{
		for (tileset in tilesets) if (tileset.label == name) return tileset;
		return null;
	}

	public function getAutotilerDefinition(name:String):AutotilerDefinition
	{
		for (def in autotilerDefinitions) if (def.label == name) return def;
		return null;
	}

	public function getNextLayerTemplateExportID():String
	{
		return Std.string(new Date().getTime()).substring(4, 8) + Std.string(Math.random()).substring(2, 6);
	}

	public function getNextEntityTemplateExportID():String
	{
		return Std.string(new Date().getTime()).substring(4, 8) + Std.string(Math.random()).substring(2, 6);
	}

	public function getNextUnsavedLevelID():Int
	{
		return _nextUnsavedLevelID++;
	}

	/*
		LEVEL PATHS
	*/

	public function getAbsoluteLevelPath(path:String):String
	{
		return Path.resolve(Path.dirname(this.path), path);
	}

	public function getRelativeLevelPath(path:String):String
	{
		return Path.relative(Path.dirname(this.path), path);
	}

	public function getAbsoluteLevelDirectories():Array<String>
	{
		return [for (levelPath in levelPaths) getAbsoluteLevelPath(levelPath)];
	}

	public function getAbsoluteLevelPathIndex(path:String):Int
	{
		return getAbsoluteLevelDirectories().indexOf(path);
	}

	public function removeAbsoluteLevelPathAndSave(path:String)
	{
		var n = getAbsoluteLevelPathIndex(path);
		if (n == -1) return;
		levelPaths.splice(n, 1);
		Export.project(this, this.path);
	}

	public function renameAbsoluteLevelPathAndSave(path:String, renameTo:String)
	{
		var n = getAbsoluteLevelPathIndex(path);
		if (n == -1) return;
		levelPaths.splice(n, 1);
		levelPaths.insert(n, getRelativeLevelPath(renameTo));
		Export.project(this, this.path);
	}

	public function initLastSavePath()
	{
		lastSavePath = getAbsoluteLevelPath(levelPaths[0]);
	}

	/*
		SAVE AND LOAD
	*/

	public function load(data:ProjectSaveFile):Project
	{
		name = data.name;
		levelPaths = data.levelPaths;
		backgroundColor = Color.fromHexAlpha(data.backgroundColor);
		gridColor = Color.fromHexAlpha(data.gridColor);
		anglesRadians = data.anglesRadians;
		directoryDepth = data.directoryDepth;
		if (data.layerGridDefaultSize != null) layerGridDefaultSize = Vector.load(data.layerGridDefaultSize);
		if (data.levelScreenSize != null) levelScreenSize = Vector.load(data.levelScreenSize);
		if (data.levelDefaultSize != null) levelDefaultSize = Vector.load(data.levelDefaultSize);
		if (data.levelMinSize != null) levelMinSize = Vector.load(data.levelMinSize);
		if (data.levelMaxSize != null) levelMaxSize = Vector.load(data.levelMaxSize);
		levelValues = ValueTemplate.loadList(data.levelValues);
		defaultExportMode = Imports.string(data.defaultExportMode, ".json");
		compactExport = data.compactExport;
		externalScript = data.externalScript;
		playCommand = data.playCommand;

		// tilesets
		if (data.tilesets != null) for (tileset in data.tilesets) tilesets.push(Tileset.load(this, tileset));

		// autotiler
		if (data.autotiler != null) for (def in data.autotiler) autotilerDefinitions.push(AutotilerDefinition.load(this, def));

		//Layer Templates
		for (layerData in data.layers)
		{
			var definitionId = layerData.definition;
			var definition = LayerDefinition.getDefinitionById(definitionId);
			var exportID:String = layerData.exportID;

			var template = definition.loadTemplate(exportID, layerData);
			template.projectWasLoaded(this);
			layers.push(template);
		}

		//Entity Templates
		if (data.entityTags != null) for (tag in data.entityTags) entities.tags.push(tag);
		
		for (entity in data.entities) entities.templates.push(EntityTemplate.load(this, entity));
		entities.refreshTagLists();

		// load user project hooks
		var scriptLocation:String = externalScript != null ? getAbsoluteLevelPath(externalScript) : "";
		projectHooks.set(scriptLocation);

		initLastSavePath();
		return this;
	}

	public function save():ProjectSaveFile
	{
		var data:ProjectSaveFile = {
			name: name,
			ogmoVersion : OGMO.version,
			levelPaths: levelPaths,
			backgroundColor: backgroundColor.toHexAlpha(),
			gridColor: gridColor.toHexAlpha(),
			anglesRadians: anglesRadians,
			directoryDepth: directoryDepth,
			layerGridDefaultSize: layerGridDefaultSize.save(),
			levelScreenSize: levelScreenSize.save(),
			levelDefaultSize: levelDefaultSize.save(),
			levelMinSize: levelMinSize.save(),
			levelMaxSize: levelMaxSize.save(),
			levelValues: ValueTemplate.saveList(this.levelValues),
			defaultExportMode: defaultExportMode,
			compactExport: compactExport,
			externalScript: externalScript,
			playCommand: playCommand,
			entityTags: entities.tags,
			layers: [for (layer in layers) layer.save()],
			entities: [for (entity in entities.templates) entity.save()],
			tilesets: (tilesets.length > 0) ? [for (tileset in tilesets) tileset.save()] : null,
			autotiler: (autotilerDefinitions.length > 0) ? [for (def in autotilerDefinitions) def.save(this)] : null
		};

		data = projectHooks.beforeSaveProject(this, data);

		initLastSavePath();
		return data;
	}

	/*
		DEBUG
	*/

	public function logLayers()
	{
		for (layer in layers) trace(layer);
	}

	public static function createDebugProject(onReturn: Project -> Void): Void
	{
		return Imports.project(Path.join('.', 'debugProject', 'debug.ogmo'), onReturn);
	}
}

// TODO - I think some of these should be nullable -01010111
typedef ProjectSaveFile =
{
	name:String,
	ogmoVersion:String,
	levelPaths:Array<String>,
	backgroundColor:String,
	gridColor:String,
	anglesRadians:Bool,
	directoryDepth:Int,
	layerGridDefaultSize:{ x:Float, y:Float },
	levelScreenSize:{ x:Float, y:Float },
	levelDefaultSize:{ x:Float, y:Float },
	levelMinSize:{ x:Float, y:Float },
	levelMaxSize:{ x:Float, y:Float },
	levelValues:Array<Dynamic>, // TODO: do we need more specific than this? -01010111
	defaultExportMode:String,
	compactExport:Bool,
	externalScript:String,
	playCommand:String,
	entityTags:Array<String>,
	layers:Array<Dynamic>,
	entities:Array<Dynamic>,
	tilesets:Array<Dynamic>,
	autotiler:Array<Dynamic>
}

package level.editor;

import rendering.Texture;
import modules.decals.DecalLayerEditor;
import modules.entities.EntityLayerEditor;
import js.node.ChildProcess;
import haxe.io.Path;
import util.Matrix;
import io.Imports;
import util.Color;
import js.Browser;
import js.jquery.JQuery;
import js.Node.process;
import electron.renderer.Remote;
import io.LevelManager;
import level.data.Level;
import level.editor.ui.LayersPanel;
import level.editor.ui.LevelsPanel;
import level.editor.ui.PropertyDisplay.PropertyDisplayDropdown;
import level.editor.ui.StickerDropdown;
import rendering.GLRenderer;
import util.Vector;
import util.Keys;

import js.node.child_process.ChildProcess as ChildProcessObject;

class Editor
{	
	public var root: JQuery;
	public var draw: GLRenderer;
	public var overlay: GLRenderer;
	public var htmlOverlay: JQuery;
	public var htmlPropertyDisplayOverlay: JQuery;

	public var levelMap: Array<Level> = [];
	public var mapDirectory: String = null;
	public var currentLevel: Level;

	public var isEditingMap(get, never): Bool;

	public var layerEditors: Array<LayerEditor> = [];
	public var levelManager: LevelManager = new LevelManager();
	public var toolBelt: ToolBelt;
	public var stickerDropdown: StickerDropdown;
	public var layersPanel: LayersPanel = new LayersPanel();
	public var levelsPanel: LevelsPanel = new LevelsPanel();
	public var handles: LevelResizeHandles;
	public var active:Bool = false;
	public var locked:Bool = false;
	public var isDirty:Bool = false;
	public var isOverlayDirty:Bool = false;
	public var currentLayerEditor(get, null):LayerEditor;
	public var propertyDisplayDropdown: PropertyDisplayDropdown;

	public var currentLayerID:Int = 0;
	public var gridVisible:Bool = true;
	public var camera:Matrix = new Matrix();
	public var cameraInv:Matrix = new Matrix();
	public var zoomRect:Rectangle = null;
	public var zoomTimer:Int;

	public var zoom(get, null):Float;

	public var backdropPreview: CelesteBackdropPreview = null;
	public var previewingBackdrops(get, null):Bool;

	var lastArrows: Vector = new Vector();
	var mouseMoving:Bool = false;
	var mouseMovePos: Vector = new Vector();
	var lastMouseMovePos: Vector = new Vector();
	var mouseInside:Bool = false;
	var middleClickMove:Bool = false;
	var lastOverlayUpdate:Float = 0;
	var lastBackdropUpdate:Float = 0;
	var saveLevelAsImageRequested:Bool = false;

	var mousedMapLevel:Int = -1;

	var resizingLeft:Bool = false;
	var resizingRight:Bool = false;
	var resizingLayers:Bool = false;
	var resizingPalette:Bool = false;
	var lastPaletteHeight:Float = 0;
	var state:Null<EditorState>;

	var executingPlayCommand:Null<ChildProcessObject>;

	public function new()
	{
		EDITOR = this;

		draw = new GLRenderer("main", cast new JQuery(".editor_canvas#editor")[0]);
		overlay = new GLRenderer("overlay", cast new JQuery(".editor_canvas#overlay")[0]);
		overlay.clearColor = Color.transparent;
		root = new JQuery(".editor");
		htmlOverlay = new JQuery(".editor_html_overlay#html_overlay");
		htmlPropertyDisplayOverlay = new JQuery(".editor_html_property_display_overlay#html_property_display_overlay");
		stickerDropdown = new StickerDropdown();

		propertyDisplayDropdown = new PropertyDisplayDropdown(OGMO.settings.propertyDisplay);

		//Events
		{
			//Center Camera button
			new JQuery(".sticker-centercam").click(function (e)
			{
				if (EDITOR.currentLevel != null) EDITOR.centerCamera();
			});

			//Toggle Property Display
			new JQuery('.sticker-propertydisplay').click(function (e)
			{
				EDITOR.propertyDisplayDropdown.signal(EDITOR.stickerDropdown);
			});
			
			new JQuery(Browser.window).resize(function(e)
			{
				EDITOR.draw.updateCanvasSize();
				EDITOR.overlay.updateCanvasSize();
				EDITOR.dirty();
			});

			new JQuery(draw.canvas).mousedown(function (e)
			{
				var level = EDITOR.currentLevel;
				if (level != null)
				{
					if ((OGMO.keyCheckMap[Keys.Space] && e.which == Keys.MouseLeft) || e.which == Keys.MouseMiddle)
					{
						EDITOR.middleClickMove = true;
						EDITOR.mouseMoving = true;
						EDITOR.mouseMovePos = EDITOR.windowToCanvas(EDITOR.getEventPosition(e));
					}
					else
					{
						var pos = EDITOR.windowToLevel(EDITOR.getEventPosition(e));

						if (e.which == Keys.MouseLeft)
						{
							if (!EDITOR.handles.onMouseDown(level, pos) && !onMouseClickLevelMap(level, pos) && EDITOR.toolBelt.current != null)
								EDITOR.toolBelt.current.onMouseDown(globalToLevel(pos, level));
						}
						else if (e.which == Keys.MouseRight)
						{
							if (!EDITOR.handles.onRightDown(pos) && EDITOR.toolBelt.current != null)
								EDITOR.toolBelt.current.onRightDown(globalToLevel(pos, level));
						}
					}
				}
			});

			new JQuery(Browser.window).mouseup(function (e)
			{
				var level = EDITOR.currentLevel;
				if (level != null)
				{
					if (EDITOR.mouseMoving)
					{
						EDITOR.middleClickMove = false;
						EDITOR.mouseMoving = false;
					}
					else
					{
						var pos = EDITOR.windowToLevel(EDITOR.getEventPosition(e));

						if (e.which == Keys.MouseLeft)
						{
							if (!EDITOR.handles.onMouseUp(pos) && EDITOR.toolBelt.current != null)
								EDITOR.toolBelt.current.onMouseUp(globalToLevel(pos, level));
						}
						else if (e.which == Keys.MouseRight && !EDITOR.handles.resizing && !EDITOR.handles.repositioning)
						{
							if (!EDITOR.handles.onRightUp(pos) && EDITOR.toolBelt.current != null)
								EDITOR.toolBelt.current.onRightUp(globalToLevel(pos, level));
						}
					}
				}

				EDITOR.resizingPalette = false;
				EDITOR.resizingLayers = false;
				EDITOR.resizingLeft = false;
				EDITOR.resizingRight = false;
			});

			new JQuery(Browser.window).mousemove(function (e)
			{
				if (EDITOR.currentLevel != null)
					EDITOR.onMouseMove(EDITOR.getEventPosition(e));
				if (EDITOR.resizingPalette)
					new JQuery(".editor_palette").height(e.pageY);
				if (EDITOR.resizingLayers)
					new JQuery(".editor_layers").height(e.pageY);
				if (EDITOR.resizingLeft && e.pageX != null)
				{
					new JQuery(".editor_panel-left").width(e.pageX);
					EDITOR.draw.updateCanvasSize();
					EDITOR.overlay.updateCanvasSize();
					EDITOR.dirty();
				}
				if (EDITOR.resizingRight)
				{
					new JQuery(".editor_panel-right").width(new JQuery(Browser.window).width() - e.pageX);
					EDITOR.draw.updateCanvasSize();
					EDITOR.overlay.updateCanvasSize();
					EDITOR.dirty();
					if (EDITOR.currentLayerEditor != null && EDITOR.currentLayerEditor.palettePanel != null)
						EDITOR.currentLayerEditor.palettePanel.resize();
				}
			});

			new JQuery(draw.canvas).mouseenter(function (e)
			{
				var level = EDITOR.currentLevel;
				if (level != null)
				{
					EDITOR.mouseInside = true;
					var pos = EDITOR.windowToLevel(EDITOR.getEventPosition(e));
					if (EDITOR.toolBelt.current != null)
						EDITOR.toolBelt.current.onMouseEnter(globalToLevel(pos, level));
				}
			});

			new JQuery(draw.canvas).mouseleave(function (e)
			{
				if (EDITOR.currentLevel != null)
				{
					EDITOR.mouseInside = false;
					if (EDITOR.toolBelt.current != null)
						EDITOR.toolBelt.current.onMouseLeave();
				}
			});

			new JQuery(Browser.window).bind('mousewheel', function (e)
			{
				if (EDITOR.currentLevel != null && EDITOR.mouseInside && !EDITOR.middleClickMove)
				{
					var at = EDITOR.windowToCanvas(EDITOR.getEventPosition(e));

					if ((e.originalEvent).wheelDelta > 0)
						EDITOR.zoomCameraAt(1, at.x, at.y);
					else
						EDITOR.zoomCameraAt(-1, at.x, at.y);
				}
			});

			// Editor Project Button
			new JQuery(".edit-project").click(function(e)
			{
				setState();
				EDITOR.levelManager.closeAll(function ()
				{
					OGMO.gotoProjectPage();
				});
			});

			// Close Project Button
			new JQuery('.close-project').click(function(e)
			{
				EDITOR.levelManager.closeAll(function()
				{
					OGMO.project.unload();
					OGMO.gotoStartPage();
					OGMO.unsetProject();
				});
			});

			new JQuery('.refresh-project').click(function(e)
			{
				setState();
				
				EDITOR.levelManager.closeAll(function()
				{
					var path = OGMO.project.path;
					OGMO.project.unload();
					Imports.project(path, (proj) -> OGMO.setProject(proj, OGMO.gotoEditorPage));
				});
			});

			new JQuery('.play-command').click(function(e)
			{
				if (OGMO.project.playCommand.length == 0)
				{
					Popup.open('No Play Command Set', 'warning', 'No Play Command has been set for this Project.', ['Okay']);
					return;
				}
				
				if (executingPlayCommand == null)
				{
					js.Lib.require('fix-path')();
					executingPlayCommand = ChildProcess.spawn(OGMO.project.playCommand, {
						cwd: Path.directory(OGMO.project.path),
						shell: true
					});

					var err = '';
					var out = '';

					executingPlayCommand.stderr.on('data', (data) -> err += data.toString());
					executingPlayCommand.stdout.on('data', (data) -> out += data.toString());

					executingPlayCommand.on('exit', () -> {
						if (err.length > 0) Popup.open('Errored Play Command: "${OGMO.project.playCommand}"', 'warning', '${err}', ['Okay']);
						else Popup.open('Play Command: "${OGMO.project.playCommand}"', 'sparkle', 'Output: ${out}', ['Okay']);
						executingPlayCommand = null;
					});
				}
				Popup.open('Running Play Command', 'sparkle', 'Running Play Command from the Project Directory: "${OGMO.project.playCommand}"', ['Okay', 'Kill'], (i) -> if (i == 1) {
					executingPlayCommand.kill();
					executingPlayCommand = null;
				});
			});

			new JQuery('.sticker-zoom').click((e) -> {
				var zoom = (EDITOR.zoom.round() / EDITOR.zoom).max(1 / EDITOR.zoom);
				EDITOR.setZoom(zoom);
			});

			Remote.getCurrentWindow().on('focus', function (e)
			{
				EDITOR.levelManager.onGainFocus();
				EDITOR.levelsPanel.refresh();
				OGMO.updateWindowTitle();
			});

			// Resizers
			new JQuery(".editor_layers_resizer").on("mousedown", function() { EDITOR.resizingLayers = true; });
			new JQuery(".editor_palette_resizer").on("mousedown", function() { EDITOR.resizingPalette = true; });
			new JQuery(".editor_left_resizer").on("mousedown", function() { EDITOR.resizingLeft = true; });
			new JQuery(".editor_right_resizer").on("mousedown", function() { EDITOR.resizingRight = true; });
		}
	}

	public function onMouseMove(?pos: Vector):Void
	{
		if (pos == null)
			pos = lastMouseMovePos;
		else
			lastMouseMovePos = pos;

		var level = EDITOR.currentLevel;
		if (level != null)
		{
			if (EDITOR.mouseMoving)
			{
				var n = EDITOR.windowToCanvas(pos);
				EDITOR.moveCamera(EDITOR.mouseMovePos.x - n.x, EDITOR.mouseMovePos.y - n.y);
				EDITOR.mouseMovePos = n;
			}
			else
			{
				var n = EDITOR.windowToLevel(pos).round();
				EDITOR.handles.onMouseMove(level, n);
				//updateMousedSiblingLevel(n);
				updateMousedMapLevel(level, n);
				if (EDITOR.toolBelt.current != null)
					EDITOR.toolBelt.current.onMouseMove(globalToLevel(n, level));
			}

			updateMouseReadout();
		}
	}

	function updateMousedMapLevel(level: Level, pos: Vector): Void
	{
		var prev = mousedMapLevel;

		if (isEditingMap && !handles.currentlyMoused)
		{
			var offset = level.data.offset;
			var size = level.data.size;
			if (pos.x < offset.x || pos.y < offset.y || pos.x >= size.x + offset.x || pos.y >= size.y + offset.y)
			{
				var topLeft = getTopLeft();
				var bottomRight = getBottomRight();
				if (pos.x >= topLeft.x && pos.y >= topLeft.y && pos.x < bottomRight.x && pos.y < bottomRight.y)
				{
					var hoveringSomething = false;
					for (layerEd in layerEditors)
					{
						if (!layerEd.active)
							continue;

						if (layerEd.isOfType(EntityLayerEditor))
						{
							var entityLayerEd = (cast layerEd : EntityLayerEditor);
							if (entityLayerEd.hovered.amount > 0 || entityLayerEd.hoveredNode.isSet())
							{
								hoveringSomething = true;
								break;
							}
						}
						else if (layerEd.isOfType(DecalLayerEditor))
						{
							if ((cast layerEd : DecalLayerEditor).hovered.length > 0)
							{
								hoveringSomething = true;
								break;
							}
						}
					}

					if (!hoveringSomething) for (i in 0...levelMap.length)
					{
						var other = levelMap[i];
						if (other == level)
							continue;

						var left = other.data.offset.x;
						var top = other.data.offset.y;
						var size = other.data.size;
						if (pos.x >= left && pos.y >= top && pos.x < left + size.x && pos.y < top + size.y)
						{
							mousedMapLevel = i;
							if (mousedMapLevel != prev)
								dirty();
					
							return;
						}
					}
				}
			}
		}

		mousedMapLevel = -1;
		if (mousedMapLevel != prev)
			dirty();
	}

	function onMouseClickLevelMap(level: Level, pos: Vector): Bool
	{
		updateMousedMapLevel(level, pos);
		if (mousedMapLevel >= 0 && mousedMapLevel < levelMap.length)
		{
			var mousedLevel = levelMap[mousedMapLevel];
			setLevel(mousedLevel, null, false);
			return true;
		}

		return false;
	}

	public function updateZoomReadout():Void
	{
		var level = EDITOR.currentLevel;
		if (level != null)
		{
			var camera = camera;
			var str = Math.round(camera.a * 100) + "%";

			if (camera.a != 0)
			{
				str += " (" + Math.round((-camera.tx / camera.a))
					+ ", " + Math.round((-camera.ty / camera.a)) + " )";
			}

			new JQuery(".sticker-zoom_text").text(str);
		}
	}

	public function updateMouseReadout():Void
	{
		var level = EDITOR.currentLevel;
		if (level != null && level.currentLayer != null)
		{
			var global = EDITOR.windowToLevel(lastMouseMovePos);
			var lvl = new Vector(global.x - level.data.offset.x, global.y - level.data.offset.y);
			var grid = level.currentLayer.levelToGrid(lvl);

			var str = "( " + Math.round(lvl.x) + ", " + Math.round(lvl.y) + " )"
					+ " ( " + Math.round(grid.x) + ", " + Math.round(grid.y) + " )"
					+ " global ( " + Math.round(global.x) + ", " + Math.round(global.y) + " )";

			new JQuery(".sticker-mouse_text").text(str);
		}
	}

	public function setActive(set:Bool):Void
	{
		active = set;
		if (set)
		{
			root.css("display", "flex");

			levelManager.loadLevel((level) ->
			{
				Browser.window.setTimeout(function ()
				{
					if (state != null)
					{
						levelManager.open(state.level, (level) ->
						{
							camera = state.camera;
							setLayer(state.layer);
							zoomCameraAt(0, 0, 0);

							if (state.map != null) loadLevelMap(state.map, () ->
							{
								dirty();

								updateZoomReadout();
								handles.refresh();
								state = null;
							});
						});
					}
				}, 500);

				draw.updateCanvasSize();
				overlay.updateCanvasSize();
				updateZoomReadout();
			});
		}
		else
		{
			// clear and reset things
			EDITOR.levelManager.clear();
			currentLevel = null;
			mousedMapLevel = -1;
			clearLevelMap();
			backdropPreview = null;
			if (executingPlayCommand != null) executingPlayCommand.kill();
			executingPlayCommand = null;
			root.css("display", "none");
		}
	}

	public function setState():Void
	{
		var level = currentLevel;
		if (level != null && level.path != null) 
		{
			state = {
				level: level.path,
				map: mapDirectory,
				layer: currentLayerEditor.id,
				camera: camera.clone()
			};
		}
	}

	public function onSetProject(onLoaded: () -> Void):Void
	{
		layerEditors = [];
		for (i in 0...OGMO.project.layers.length)
			layerEditors.push(OGMO.project.layers[i].createEditor(i));

		layersPanel.populate(new JQuery(".editor_layers"));
		levelsPanel.populate(new JQuery(".editor_levels"));
		handles = new LevelResizeHandles();

		var level = currentLevel;
		if (level != null) levelManager.open(level.path);

		if (backdropPreview != null)
		{
			backdropPreview = CelesteBackdropPreview.loadFromPath(backdropPreview.path);
			dirty();
		}

		onLoaded();
	}

	public function setLevel(level: Level, onAfterSet: Void -> Void, doCenterCamera = true):Void
	{
		mousedMapLevel = -1;

		beforeSetLayer();

		this.currentLevel = level;
		if (level != null)
			setLayerUtil(currentLayerID, level);

		function refreshEditor()
		{
			if (doCenterCamera)
				centerCamera();
			
			updateZoomReadout();
			handles.refresh();
			levelsPanel.refreshLabelsAndIcons();
			OGMO.updateWindowTitle();
			dirty();
		}

		function clearLevelTexture()
		{
			if (level != null && level.levelTexture != null)
			{
				level.levelTexture.dispose();
				level.levelTexture = null;
			}
		}

		if (isEditingMap && !levelMap.contains(level))
		{
			var dir = (level != null && level.path != null) ? Path.directory(level.path) : "";
			if (dir.length > 0 && dir == mapDirectory) levelMap.push(level);
			else
			{
				levelManager.closeAll(() -> 
				{
					clearLevelMap();
					refreshEditor();
					clearLevelTexture();
					if (onAfterSet != null) onAfterSet();
				});
				return;
			}
		}

		refreshEditor();
		clearLevelTexture();
		if (onAfterSet != null) onAfterSet();
	}

	public function loadLevelMap(dir: String, onSuccess: Void -> Void): Void
	{
		mousedMapLevel = -1;
		levelManager.closeAll(() ->
		{
			clearLevelMap();

			var mapLevels: Array<Level> = [];
			for (file in sys.FileSystem.readDirectory(dir))
			{
				var levelPath = js.node.Path.join(dir, file);
				if (sys.FileSystem.isDirectory(levelPath))
					continue;

				var mapLevel = EDITOR.levelManager.get(levelPath);
				if (mapLevel == null)
				{
					try {
						mapLevel = Imports.level(levelPath);
					} catch (_) {
						continue;
					}

					EDITOR.levelManager.levels.push(mapLevel);
				}

				mapLevels.push(mapLevel);
			}

			if (mapLevels.length > 0)
			{
				setLevelMap(dir, mapLevels);
				if (!mapLevels.contains(currentLevel))
				{
					var closestToOrigin: Level = mapLevels[0];
					{
						var prevSqrLength: Null<Float> = null;
						for (lvl in mapLevels)
						{
							var offset = lvl.data.offset;
							if (offset.x == 0 && offset.y == 0)
							{
								closestToOrigin = lvl;
								break;
							}

							var sqrLength = offset.sqrLength;
							if (prevSqrLength == null || prevSqrLength > sqrLength)
							{
								closestToOrigin = lvl;
								prevSqrLength = sqrLength;
							}
						}
					}

					setLevel(closestToOrigin, () ->
					{
						if (onSuccess != null) onSuccess();
					});
					return;
				}
			}

			if (onSuccess != null) onSuccess();
		});
	}

	public function closeLevelMap(onSuccess: Void -> Void): Void
	{
		mousedMapLevel = -1;
		levelManager.closeAll(() ->
		{
			clearLevelMap();
			if (onSuccess != null) onSuccess();
		});
	}

	function setLevelMap(dir: String, levels: Array<Level>)
	{
		levelMap = levels;
		mapDirectory = dir;
	}

	function clearLevelMap()
	{
		while (levelMap.length > 0) levelMap.pop();
		mapDirectory = null;
	}

	public function onLevelDeleted(level: Level): Void
	{
		levelMap.remove(level);
	}

	function beforeSetLayer():Void
	{
		for (editor in layerEditors) editor.refresh();
		toolBelt.beforeSetLayer();
	}

	function setLayerUtil(id:Int, level:Level):Void
	{
		currentLayerID = id;
		toolBelt.afterSetLayer();

		EDITOR.dirty();
		updateMouseReadout();
		layersPanel.refresh();

		if (currentLayerEditor != null)
		{
			var paletteElement = new JQuery(".editor_palette");
			var selectionElement = new JQuery(".editor_selection");

			paletteElement.empty();
			if (currentLayerEditor.palettePanel != null)
				currentLayerEditor.palettePanel.populate(paletteElement);

			selectionElement.empty();
			if (currentLayerEditor.selectionPanel != null)
			{
				currentLayerEditor.selectionPanel.populate(selectionElement);
				if (!selectionElement.is(":visible"))
				{
					new JQuery(".editor_palette_resizer").show();
					paletteElement.height(lastPaletteHeight);
					selectionElement.show();
				}
			}
			else if (selectionElement.is(":visible"))
			{
				lastPaletteHeight = paletteElement.height();
				paletteElement.height("100%");
				selectionElement.hide();
				new JQuery(".editor_palette_resizer").hide();
			}
		}

		if (level != null)
			for (i in 0...level.layers.length)
				layerEditors[i].active = (i == id);
	}

	public function setLayer(id:Int):Bool
	{
		if (id >= 0 && id < OGMO.project.layers.length)
		{
			beforeSetLayer();
			setLayerUtil(id, EDITOR.currentLevel);
			return true;
		}
		else
			return false;
	}

	public function loop():Void
	{
		var level = currentLevel;

		if (level != null)
		{
			if (currentLayerEditor != null) currentLayerEditor.loop();
			updateArrowKeys();
			if (EDITOR.toolBelt.current != null) EDITOR.toolBelt.current.update();
		}

		if (previewingBackdrops)
		{
			final updateTime = 1 / 30;
			lastBackdropUpdate += OGMO.deltaTime;
			if (lastBackdropUpdate >= updateTime)
			{
				backdropPreview.update(updateTime);
				lastBackdropUpdate -= updateTime;
			}
		}
		else lastBackdropUpdate = 0;

		//Draw the level
		if (isDirty)
		{
			isDirty = false;
			draw.clear();

			if (level != null) drawLevels();
		}

		//Draw the overlay
		lastOverlayUpdate += OGMO.deltaTime;
		if (isOverlayDirty)// || lastOverlayUpdate >= 1 / 6) <-- Uncomment to re-enable overlay animation
		{
			isOverlayDirty = false;
			overlay.clear();

			if (level != null)
				drawOverlay(level);
			lastOverlayUpdate = 0;
		}
	}

	public function dirty():Void
	{
		isDirty = true;
		isOverlayDirty = true;
	}

	public function overlayDirty():Void
	{
		isOverlayDirty = true;
	}

	public function toggleLayerVisibility(id:Int):Bool
	{
		layerEditors[id].visible = !layerEditors[id].visible;
		if (isEditingMap) for (level in levelMap) if (level.levelTexture != null)
		{
			level.levelTexture.dispose();
			level.levelTexture = null;
		}
		EDITOR.dirty();
		return layerEditors[id].visible;
	}

	/*
		ACTUAL DRAWING
	*/

	public function drawLevels():Void
	{
		var level = EDITOR.currentLevel;

		// pre-draw level textures if currently editing a level map
		if (isEditingMap)
		{
			for (other in levelMap) if (other != level && other.levelTexture == null && !other.isLoadingTexture)
			{
				var camBackup = EDITOR.camera.clone();
				
				draw.setAlpha(1);
				draw.setupRenderTarget(other.data.size);

				var offsetBackup = other.data.offset;
				other.data.offset = new Vector();
					
				var i = other.layers.length - 1;
				while(i >= 0) 
				{
					if (EDITOR.layerEditors[i] != null && EDITOR.layerEditors[i].visible) EDITOR.layerEditors[i].drawNoHover(other);
					i--;
				}

				draw.finishDrawing();

				other.data.offset = offsetBackup;

				var pixels = draw.getRenderTargetPixels();

				var canvas = Browser.document.createCanvasElement();
				canvas.width = Math.floor(other.data.size.x);
				canvas.height = Math.floor(other.data.size.y);

				var ctx = canvas.getContext2d();
				ctx.imageSmoothingEnabled = false;

				var imageData = ctx.createImageData(canvas.width, canvas.height);
				for (i in 0...imageData.data.length)
					imageData.data[i] = pixels[i];
				ctx.putImageData(imageData, 0, 0);

				other.isLoadingTexture = true;
				Texture.loadFromData(canvas.toDataURL("image/png"), function(texture)
				{
					other.levelTexture = texture;
					other.isLoadingTexture = false;

					EDITOR.dirty();
				});

				canvas.remove();

				draw.doneRenderTarget();
				draw.destroyRenderTarget();

				EDITOR.camera = camBackup;
				EDITOR.updateCameraInverse();
			}
		}

		var offset, size;
		if (level != null)
		{
			offset = level.data.offset.clone();
			size = level.data.size.clone();
		}
		else
		{
			offset = new Vector();
			size = new Vector();
		}

		draw.setAlpha(1);

		// preview background style
		if (previewingBackdrops)
		{
			backdropPreview.drawBackgroundColor();
			CelesteBackdropPreview.draw(backdropPreview.Backgrounds, level);
		}

		// draw other levels if a map is open
		if (isEditingMap)
		{
			draw.setAlpha(1);

			if (!previewingBackdrops) for (other in levelMap) if (other != level)
			{
				draw.drawRect(other.data.offset.x, other.data.offset.y, other.data.size.x, other.data.size.y, other.project.backgroundColor);
			}

			draw.setAlpha(0.5);

			for (other in levelMap) if (other != level && other.levelTexture != null)
				draw.drawTexture(other.data.offset.x, other.data.offset.y, other.levelTexture);

			if (mousedMapLevel >= 0 && mousedMapLevel < levelMap.length)
			{
				var other = levelMap[mousedMapLevel];

				draw.setAlpha(1);
				draw.drawRect(other.data.offset.x, other.data.offset.y, other.data.size.x, other.data.size.y, Color.yellow.x(0.5));
			}
		}

		draw.setAlpha(1);

		// Draw the current level
		if (level != null)
		{
			//Background
			if (!previewingBackdrops)
			{
				draw.drawRect(offset.x + 12, offset.y + 12, size.x, size.y, Color.black.x(.5));
				draw.drawRect(offset.x - 1, offset.y - 1, size.x + 2, size.y + 2, Color.black);
				draw.drawRect(offset.x, offset.y, size.x, size.y, level.project.backgroundColor);
			}
			else
			{
				draw.drawRect(offset.x - 1, offset.y - 1, size.x + 2, 1, Color.black);
				draw.drawRect(offset.x - 1, offset.y, 1, size.y, Color.black);
				draw.drawRect(size.x, offset.y, 1, size.y, Color.black);
				draw.drawRect(offset.x - 1, size.y, size.x + 2, 1, Color.black);
			}

			//Draw the layers below and including the current one
			var i = level.layers.length - 1;
			while(i > currentLayerID) 
			{
				if (EDITOR.layerEditors[i] != null && EDITOR.layerEditors[i].visible) EDITOR.layerEditors[i].draw(level);
				i--;
			}

			if (EDITOR.layerEditors[currentLayerID] != null) EDITOR.layerEditors[currentLayerID].draw(level);

			//Draw the layers above the current one at half alpha
			if (currentLayerID > 0)
			{
				draw.setAlpha(0.5);
				var i = currentLayerID - 1;
				while (i >= 0)
				{
					if (EDITOR.layerEditors[i] != null && EDITOR.layerEditors[i].visible) EDITOR.layerEditors[i].draw(level);
					i--;
				}
				draw.setAlpha(1);
			}

			//Resize handles
			if (EDITOR.handles.canResize) EDITOR.handles.draw();

			//Grid
			var currentLayer = level.currentLayer;
			if (currentLayer != null && gridVisible) draw.drawGrid(currentLayer.template.gridSize, currentLayer.offset, size, offset, camera.a, level.project.gridColor);
		
			//Do the current layer's drawAbove
			if (EDITOR.layerEditors[currentLayerID] != null) EDITOR.layerEditors[currentLayerID].drawAbove(level);
		}

		if (previewingBackdrops)
		{
			CelesteBackdropPreview.draw(backdropPreview.Foregrounds, level);

			// test: screen view
			var zoom = camera.a;
			var screenSize = OGMO.project.levelScreenSize;
			var cameraCenter = new Vector(-camera.tx / zoom, -camera.ty / zoom);
			draw.drawRectLineQuads(new Rectangle(cameraCenter.x - (screenSize.x / 2), cameraCenter.y - (screenSize.y / 2), screenSize.x, screenSize.y), Color.white, zoom);
		}

		//Current Tool
		if (EDITOR.toolBelt.current != null) EDITOR.toolBelt.current.draw(level);

		//Check Tools availability
		EDITOR.toolBelt.checkAvailability();
		
		draw.finishDrawing();

		if (saveLevelAsImageRequested)
		{
			saveLevelAsImageRequested = false;
			var camBackup = EDITOR.camera.clone();

			draw.setAlpha(1);
			draw.setupRenderTarget(level.data.size);

			var offsetBackup = level.data.offset;
			level.data.offset = new Vector();

			var i = level.layers.length - 1;
			while(i >= 0) 
			{
				if (EDITOR.layerEditors[i] != null && EDITOR.layerEditors[i].visible) EDITOR.layerEditors[i].draw(level);
				i--;
			}

			level.data.offset = offsetBackup;

			draw.finishDrawing();

			var pixels = draw.getRenderTargetPixels();
			var path = FileSystem.chooseSaveFile("Level as image", [{ name: "Image", extensions: ["png"]}], level.displayNameNoExtension + ".png");
			if (path.length > 0)
				FileSystem.saveRGBAToPNG(pixels, Math.floor(level.data.size.x), Math.floor(level.data.size.y), path);

			draw.doneRenderTarget();
			draw.destroyRenderTarget();

			EDITOR.camera = camBackup;
			EDITOR.updateCameraInverse();
		}
	}

	public function drawOverlay(level: Level):Void
	{
		overlay.setAlpha(1);

		var offset = level.data.offset;

		//Current Layer Overlay
		if (EDITOR.layerEditors[currentLayerID] != null) EDITOR.layerEditors[currentLayerID].drawOverlay(level);

		//Current Tool Overlay
		if (EDITOR.toolBelt.current != null)
			EDITOR.toolBelt.current.drawOverlay(level);

		//Zoom Rect
		if (zoomRect != null)
			overlay.drawLineRect(zoomRect, Color.white);

		overlay.finishDrawing();
	}

	public function saveLevelAsImage():Void
	{
		saveLevelAsImageRequested = true;
		isDirty = true;
	}

	/*
		TRANSFORMATIONS
	*/

	public function windowToCanvas(pos: Vector, ?into: Vector): Vector
	{
		if (into == null) into = new Vector();

		into.x = pos.x - new JQuery(EDITOR.draw.canvas).offset().left - new JQuery(EDITOR.draw.canvas).width() * .5;
		into.y = pos.y - new JQuery(EDITOR.draw.canvas).offset().top - new JQuery(EDITOR.draw.canvas).height() * .5;

		return into;
	}

	public function windowToLevel(pos: Vector, ?into: Vector): Vector
	{
		if (into == null) into = new Vector();

		windowToCanvas(pos, into);
		canvasToLevel(into, into);

		return into;
	}

	public function levelToCanvas(pos: Vector, ?into: Vector): Vector
	{
		if (into == null) into = new Vector();

		camera.transformPoint(pos, into);

		return into;
	}

	public function canvasToLevel(pos: Vector, ?into: Vector): Vector
	{
		if (into == null) into = new Vector();

		cameraInv.transformPoint(pos, into);

		return into;
	}

	public function getTopLeft(): Vector
	{
		var v = new Vector(-draw.width/2, -draw.height/2);
		return canvasToLevel(v);
	}

	public function getBottomRight(): Vector
	{
		var v = new Vector(draw.width/2, draw.height/2);
		return canvasToLevel(v);
	}

	public function getEventPosition(e:Dynamic): Vector
	{
		return new Vector(e.pageX, e.pageY);
	}

	public function globalToLevel(pos: Vector, level: Level): Vector
	{
		return (level != null) ? pos.clone().sub(level.data.offset) : pos.clone();
	}

	public function levelToGlobal(pos: Vector, level: Level): Vector
	{
		return (level != null) ? pos.clone().add(level.data.offset) : pos.clone();
	}

	/*
		CAMERA
	*/

	public function updateCameraInverse():Void
	{
		camera.inverse(cameraInv);
	}

	public function centerCamera():Void
	{
		var level = EDITOR.currentLevel;

		var offset, size;
		if (level != null)
		{
			offset = level.data.offset.clone();
			size = level.data.size.clone();
		}
		else
		{
			offset = new Vector();
			size = new Vector();
		}

		camera.setIdentity();
		moveCamera(offset.x + size.x / 2, offset.y + size.y / 2);
		updateCameraInverse();
		EDITOR.dirty();

		EDITOR.updateZoomReadout();
		EDITOR.handles.refresh();
	}

	public function moveCamera(x:Float, y:Float):Void
	{
		if (x != 0 || y != 0)
		{
			camera.translate(-x, -y);
			updateCameraInverse();
			EDITOR.dirty();
			EDITOR.updateZoomReadout();
		}
	}

	public function zoomCamera(zoom:Float):Void
	{
		setZoomRect(zoom);

		camera.scale(1 + .1 * zoom, 1 + .1 * zoom);
		updateCameraInverse();
		EDITOR.dirty();

		EDITOR.updateZoomReadout();
		EDITOR.handles.refresh();
	}

	public function setZoom(zoom:Float) {
		camera.scale(zoom, zoom);
		updateCameraInverse();
		while (camera.a < 0.01 ) setZoom(0.01);
		while (camera.a > 32 ) setZoom(-0.001);
		EDITOR.dirty();

		EDITOR.updateZoomReadout();
		EDITOR.handles.refresh();
	}

	public function zoomCameraAt(zoom:Float, x:Float, y:Float):Void
	{
		setZoomRect(zoom);

		moveCamera(x, y);
		camera.scale(1 + .1 * zoom, 1 + .1 * zoom);
		moveCamera(-x, -y);
		updateCameraInverse();
		while (camera.a < 0.01 ) zoomCameraAt(0.01, x, y);
		while (camera.a > 32 ) zoomCameraAt(-0.001, x, y);
		EDITOR.dirty();

		EDITOR.updateZoomReadout();
		EDITOR.handles.refresh();
	}

	public function setZoomRect(zoom:Float):Void
	{
		if (zoom < 0 && zoomRect == null)
		{
			var topLeft = EDITOR.getTopLeft();
			var bottomRight = EDITOR.getBottomRight();
			zoomRect = new Rectangle(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);
		}

		if (zoomTimer != null) Browser.window.clearTimeout(zoomTimer);
		zoomTimer = Browser.window.setTimeout(clearZoomRect, 500);
	}

	public function clearZoomRect():Void
	{
		EDITOR.zoomRect = null;
		EDITOR.overlayDirty();
	}

	/*
		KEYBOARD
	*/

	public function keyPress(key:Int):Void
	{
		inline function dPress(key:Int) 
		{
			if (OGMO.ctrl) EDITOR.setLayer(key - Keys.D1);
				else EDITOR.toolBelt.setTool(key - Keys.D1);
		}

		switch (key)
		{
			default:
				defaultKeyPress(key);
			case Keys.Space:
				//Center Camera
				if (OGMO.ctrl) EDITOR.centerCamera();
			case Keys.G:
				//Toggle Grid
				if (OGMO.ctrl)
				{
					EDITOR.gridVisible = !EDITOR.gridVisible;
					EDITOR.dirty();
				}
			case Keys.T:
				//Toggle Property Display
				if (OGMO.ctrl)
				{
					OGMO.settings.propertyDisplay.visible = !OGMO.settings.propertyDisplay.visible;
					EDITOR.propertyDisplayDropdown.refresh(EDITOR.stickerDropdown);
					EDITOR.dirty();
				}
			case Keys.S:
				//Save Level
				if (OGMO.ctrl && !EDITOR.locked)
				{
					if (EDITOR.isEditingMap)
					{
						for (level in EDITOR.levelMap) level.doSave();
					}
					else
					{
						var level = EDITOR.currentLevel;
						if (level != null)
						{
							if (OGMO.shift) level.doSaveAs();
							else level.doSave();
						}
					}
				}
			case Keys.N:
				//New Level
				if (OGMO.ctrl && !EDITOR.locked) EDITOR.levelManager.create();
			//case Keys.W:
				// TO-DO: check if map is currently being edited
				//Close Level
				//if (OGMO.ctrl && EDITOR.currentLevel != null && !EDITOR.locked) EDITOR.levelManager.close(EDITOR.currentLevel);
			case Keys.D1:
				dPress(key);
			case Keys.D2:
				dPress(key);
			case Keys.D3:
				dPress(key);
			case Keys.D4:
				dPress(key);
			case Keys.D5:
				dPress(key);
			case Keys.D6:
				dPress(key);
			case Keys.D7:
				dPress(key);
			case Keys.D8:
				dPress(key);
			case Keys.D9:
				dPress(key);
			case Keys.D0:
				dPress(key);
			case Keys.Shift:
				if (EDITOR.currentLevel != null && !EDITOR.toolBelt.setKeyTool(key)) defaultKeyPress(key);
			case Keys.Ctrl:
				if (process.platform != 'darwin' && EDITOR.currentLevel != null && !EDITOR.toolBelt.setKeyTool(key)) defaultKeyPress(key);
			case Keys.Cmd:
				if (process.platform == 'darwin' && EDITOR.currentLevel != null && !EDITOR.toolBelt.setKeyTool(key)) defaultKeyPress(key);
			case Keys.Alt:
				if (EDITOR.currentLevel != null && !EDITOR.toolBelt.setKeyTool(key)) defaultKeyPress(key);
			case Keys.Up:
				if (OGMO.ctrl && EDITOR.currentLevel != null) EDITOR.setLayer(EDITOR.currentLayerID - 1);
			case Keys.Down:
				if (OGMO.ctrl && EDITOR.currentLevel != null) EDITOR.setLayer(EDITOR.currentLayerID + 1);
		}
	}

	public function keyRepeat(key:Int):Void
	{
		switch (key)
		{
			default:
				defaultKeyRepeat(key);
			case Keys.Plus:
				if (EDITOR.currentLevel != null) EDITOR.zoomCamera(1);
			case Keys.Minus:
				if (EDITOR.currentLevel != null) EDITOR.zoomCamera(-1);
			case Keys.Z:
				if (OGMO.ctrl && EDITOR.currentLevel != null && !EDITOR.locked) OGMO.shift ? EDITOR.currentLevel.stack.redo() : EDITOR.currentLevel.stack.undo();
			case Keys.Y:
				if (OGMO.ctrl && EDITOR.currentLevel != null && !EDITOR.locked) EDITOR.currentLevel.stack.redo();
		}
	}

	public function keyRelease(key:Int):Void
	{
		inline function unset(key:Int)
		{
			if (!EDITOR.toolBelt.unsetKeyTool(key)) defaultKeyRelease(key);
		}

		switch (key)
		{
			default:
				defaultKeyRelease(key);
			case Keys.Space:
				mouseMoving = false;
			case Keys.Shift:
				unset(key);
			case Keys.Ctrl:
				if (process.platform != 'darwin') unset(key);
			case Keys.Cmd:
				if (process.platform == 'darwin') unset(key);
			case Keys.Alt:
				unset(key);
		}
	}

	function defaultKeyPress(key:Int):Void
	{
		if (currentLevel != null && currentLayerEditor != null)
		{
			currentLayerEditor.keyPress(key);
			if (toolBelt.current != null) toolBelt.current.onKeyPress(key);
		}
	}

	function defaultKeyRepeat(key:Int):Void
	{
		if (currentLevel != null && currentLayerEditor != null)
		{
			currentLayerEditor.keyRepeat(key);
			if (toolBelt.current != null) toolBelt.current.onKeyRepeat(key);
		}
	}

	function defaultKeyRelease(key:Int):Void
	{
		if (currentLevel != null && currentLayerEditor != null)
		{
			currentLayerEditor.keyRelease(key);
			if (toolBelt.current != null) toolBelt.current.onKeyRelease(key);
		}
	}

	function updateArrowKeys():Void
	{
		var moveSpeed = 10;
		var moveDiag = Math.sqrt((moveSpeed * moveSpeed) * .5);

		//Left and Right
		{
			var left = OGMO.keyCheckMap[Keys.Left];
			var right = OGMO.keyCheckMap[Keys.Right];
			var leftP = OGMO.keyPressMap[Keys.Left];
			var rightP = OGMO.keyPressMap[Keys.Right];

			if (lastArrows.x > 0)
			{
				if (leftP) lastArrows.x = -1;
				else if (right) lastArrows.x = 1;
				else if (left) lastArrows.x = -1;
				else lastArrows.x = 0;
			}
			else if (lastArrows.x < 0)
			{
				if (rightP) lastArrows.x = 1;
				else if (left) lastArrows.x = -1;
				else if (right) lastArrows.x = 1;
				else lastArrows.x = 0;
			}
			else
			{
				if (left && !right) lastArrows.x = -1;
				else if (!left && right) lastArrows.x = 1;
				else lastArrows.x = 0;
			}
		}

		//Up and Down
		{
			var up = OGMO.keyCheckMap[Keys.Up];
			var down = OGMO.keyCheckMap[Keys.Down];
			var upP = OGMO.keyPressMap[Keys.Up];
			var downP = OGMO.keyPressMap[Keys.Down];

			if (lastArrows.y > 0)
			{
				if (upP) lastArrows.y = -1;
				else if (down) lastArrows.y = 1;
				else if (up) lastArrows.y = -1;
				else lastArrows.y = 0;
			}
			else if (lastArrows.y < 0)
			{
				if (downP) lastArrows.y = 1;
				else if (up) lastArrows.y = -1;
				else if (down) lastArrows.y = 1;
				else lastArrows.y = 0;
			}
			else
			{
				if (up && !down) lastArrows.y = -1;
				else if (!up && down) lastArrows.y = 1;
				else lastArrows.y = 0;
			}
		}

		//Ctrl cancels movement
		if (OGMO.ctrl)
		{
			lastArrows.x = 0;
			lastArrows.y = 0;
		}

		//Apply Change
		if (lastArrows.x != 0 || lastArrows.y != 0)
		{
			if (lastArrows.x != 0 && lastArrows.y != 0)
			{
				lastArrows.x *= moveDiag;
				lastArrows.y *= moveDiag;
			}
			else
			{
				lastArrows.x *= moveSpeed;
				lastArrows.y *= moveSpeed;
			}

			moveCamera(lastArrows.x, lastArrows.y);
			onMouseMove();
		}
	}

	function get_currentLayerEditor(): LayerEditor
	{
		return layerEditors[currentLayerID];
	}

	function get_zoom():Float
	{
		return camera.a;
	}

	function get_isEditingMap(): Bool
	{
		return mapDirectory != null;
	}

	function get_previewingBackdrops(): Bool
	{
		return backdropPreview != null;
	}
}

typedef EditorState = {
	level:String,
	map:Null<String>,
	layer:Int,
	camera:Matrix
}
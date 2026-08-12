package modules.grid;

import level.data.Layer;
import level.data.Level;
import modules.tiles.TileLayerEditor;
import modules.tiles.TileLayer;
import modules.tiles.TileLayerTemplate;
import modules.autotiler.Autotiler;
import level.editor.LayerEditor;

class GridLayerEditor extends LayerEditor
{
	public var brushLeft: String;
	public var brushRight: String;

	public var autotiler: Autotiler;
	public var overlayingTileLayerIdx: Int;

	public function new(id:Int)
	{
		super(id);

		var gridTemplate = (cast template : GridLayerTemplate);

		//Default brushes
		brushLeft = gridTemplate.firstSolid;
		brushRight = gridTemplate.transparent;

		autotiler = new Autotiler(gridTemplate);
		
		overlayingTileLayerIdx = -1;
		for (i in 0...OGMO.project.layers.length)
		{
			var layer = OGMO.project.layers[i];
			if (layer.isOfType(TileLayerTemplate) && layer.name == gridTemplate.overlaidBy)
			{
				overlayingTileLayerIdx = i;
				break;
			}
		}
	}

	override function draw(level: Level):Void
	{
		var layer = getLayer(level);

		var offx = level.data.offset.x + layer.offset.x;
		var offy = level.data.offset.y + layer.offset.y;

		var gridLayer = (cast layer : GridLayer);
		var gridTemplate = (cast template : GridLayerTemplate);
		var empty = gridTemplate.transparent;

		var overlayingLayer: TileLayer = null;
		if (overlayingTileLayerIdx >= 0)
		{
			var l = EDITOR.layerEditors[overlayingTileLayerIdx];
			if (l.isOfType(TileLayerEditor) && l.visible) overlayingLayer = (cast l.getLayer(level) : TileLayer);
		}

		if (gridLayer.shouldUpdateGeneratedTiles)
		{
			autotiler.seedForLevel(layer.level);
			gridLayer.generated = autotiler.generate(gridLayer.data, layer.gridCellsX, layer.gridCellsY);
			gridLayer.shouldUpdateGeneratedTiles = false;
		}

		var generated = gridLayer.generated;

		for (y in 0...gridLayer.data[0].length)
		{
			var last:String = null;
			var range:Int = 0;

			for (x in 0...gridLayer.data.length + 1)
			{
				var at:String = null;
				if (x < gridLayer.data.length) at = gridLayer.data[x][y];

				if (at != null && at != empty)
				{
					var genX = generated[x];
					if (genX != null)
					{
						var gen = genX[y];
						if (gen != null)
						{
							var overlaid = false;
							if (overlayingLayer != null)
							{
								var overX = overlayingLayer.data[x];
								if (overX != null)
								{
									var over = overX[y];
									if (over != null && !over.isEmptyTile())
										overlaid = true;
								}
							}

							if (!overlaid)
								EDITOR.draw.drawTile(
									offx + x * template.gridSize.x,
									offy + y * template.gridSize.y,
									gen.tileset,
									gen.data
								);

							at = null;
						}
					}
				}

				if (at != last)
				{
					if (range > 0 && last != null)
					{
						var startX = x - range;
						var c = gridTemplate.legend[last];
						if (c != null && !c.equals(Color.transparent))
							EDITOR.draw.drawRect(
								offx + startX * template.gridSize.x,
								offy + y * template.gridSize.y,
								template.gridSize.x * range,
								template.gridSize.y,
								c
							);
					}
					range = 0;
					last = at;
				}
				range++;
			}
		}
	}

	override function createPalettePanel()
	{
		return new GridPalettePanel(this);
	}

	override public function afterUndoRedo(level: Level)
	{
		EDITOR.toolBelt.current.activated();
	}
}

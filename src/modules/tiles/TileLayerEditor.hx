package modules.tiles;

import level.data.Level;
import modules.tiles.TileLayer.TileData;
import level.editor.LayerEditor;

class TileLayerEditor extends LayerEditor
{
	public var brush:Array<Array<TileData>> = [[new TileData(0)]];
	public var brushIsContiguous(get, never):Bool;
	public var brushRectangle(get, never):Rectangle;

	public function new(id:Int)
	{
		super(id);
	}

	override function draw(level: Level):Void
	{
		var layer = getLayer(level);

		var offx = level.data.offset.x + layer.offset.x;
		var offy = level.data.offset.y + layer.offset.y;
		for (x in 0...layer.gridCellsX) for (y in 0...layer.gridCellsY)
		{
			var l:TileLayer = cast layer;
			var tile = l.data[x][y];
			if (tile != null && !tile.isEmptyTile()) EDITOR.draw.drawTile(
				offx + x * l.template.gridSize.x,
				offy + y * layer.template.gridSize.y,
				l.tileset,
				tile
			);
		}
	}
	
	override function createPalettePanel()
	{
		return new TilePalettePanel(this);
	}
		
	public function moveBrush(x:Int, y:Int):Void
	{
		if (brushIsContiguous)
		{
			var layer:TileLayer = cast this.getLayerFromCurrentLevel();
			var atX = layer.tileset.getTileX(brush[0][0].idx);
			var atY = layer.tileset.getTileY(brush[0][0].idx);
			atX += x;
			atY += y;

			var w = brush.length;
			var h = brush[0].length;

			if (atX < 0)
				atX = layer.tileset.tileColumns - w;
			else if (atX > layer.tileset.tileColumns - w)
				atX = 0;

			if (atY < 0)
				atY = layer.tileset.tileRows - h;
			else if (atY > layer.tileset.tileRows - h)
				atY = 0;

			setBrushRect(layer.tileset.coordsToID(atX, atY));
			palettePanel.refresh();
			EDITOR.overlayDirty();
		}
	}

	public function flipBrush(horizontal:Bool):Void
	{
		var newBrush = Calc.createArray2D(brush.length, brush[0].length, new TileData());
		if (horizontal)
			for (x in 0...brush.length) for (y in 0...brush[x].length) newBrush[brush.length - 1 - x][y] = brush[x][y];
		else
			for (x in 0...brush.length) for (y in 0...brush[x].length) newBrush[x][brush[x].length - 1 - y] = brush[x][y];
		brush = newBrush;
	}

	public function rotateBrush(clockwise:Bool):Void
	{
		var newBrush = Calc.createArray2D(brush[0].length, brush.length, new TileData());
		if (clockwise)
			for (x in 0...brush.length) for (y in 0...brush[x].length) newBrush[brush[x].length - 1 - y][x] = brush[x][y];
		else
			for (x in 0...brush.length) for (y in 0...brush[x].length) newBrush[y][brush.length - 1 - x] = brush[x][y];
		brush = newBrush;
	}

	public function setBrushRect(topLeft:Int):Void
	{
		for (x in 0...brush.length) for (y in 0...brush[x].length) brush[x][y].idx = topLeft + x + y * (cast getLayerFromCurrentLevel() : TileLayer).tileset.tileColumns;
	}

	override function keyRepeat(key:Int):Void
	{
		if (OGMO.ctrl) return;
		switch (key) // WASD
		{
			case Keys.W:
				moveBrush(0, -1);
			case Keys.A:
				moveBrush(-1, 0);
			case Keys.D:
				moveBrush(1, 0);
			case Keys.S:
				moveBrush(0, 1);
		}
	}

	function get_brushIsContiguous():Bool
	{
		for (x in 0...brush.length) for (y in 0...brush[x].length)
		{
			if (brush[x][y].isEmptyTile() || brush[x][y].idx != brush[0][0].idx + x + y * (cast getLayerFromCurrentLevel() : TileLayer).tileset.tileColumns)
				return false;
		}
		return true;
	}
	
	function get_brushRectangle(): Rectangle
	{
		if (brushIsContiguous)
		{
			var first = brush[0][0].idx;
			var columns = (cast getLayerFromCurrentLevel() : TileLayer).tileset.tileColumns;
			return new Rectangle(first % columns, Math.floor(first / columns), brush.length, brush[0].length);
		}
		else return null;
	}

	override public function afterUndoRedo(level: Level)
	{
		EDITOR.toolBelt.current.activated();
	}
}

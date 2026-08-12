package modules.decals;

import level.data.Level;
import modules.decals.DecalLayerTemplate.PathTexturePair;
import level.editor.ui.SidePanel;
import rendering.Texture;
import level.editor.LayerEditor;

class DecalLayerEditor extends LayerEditor
{
	// public var brush:Texture;
	public var brush:PathTexturePair;
	public var selected:Array<Decal> = [];
	public var hovered:Array<Decal> = [];
	public var selectedChanged:Bool = true;

	public function toggleSelected(list:Array<Decal>):Void
	{
		var removing:Array<Decal> = [];
		for (decal in list)
		{
			if (selected.indexOf(decal) >= 0) removing.push(decal);
			else selected.push(decal);
		}
		for (decal in removing) selected.remove(decal);
		selectedChanged = true;
	}

	public function selectedContainsAny(list:Array<Decal>):Bool
	{
		for (decal in list) if (selected.indexOf(decal) >= 0) return true;
		return false;
	}

	public function remove(layer: DecalLayer, decal:Decal):Void
	{
		layer.decals.remove(decal);
		hovered.remove(decal);
		selected.remove(decal);
	}

	override function draw(level: Level): Void
	{
		drawDecals(level.data.offset.x, level.data.offset.y, getDecals(level));

		if (active) for (decal in hovered) decal.drawSelectionBox(level, false);
	}

	override function drawNoHover(level: Level)
	{
		drawDecals(level.data.offset.x, level.data.offset.y, getDecals(level));
	}

	function drawDecals(offx: Float, offy: Float, decals: Array<Decal>)
	{
		for (decal in decals)
		{
			if (decal.texture != null)
			{
				var originInPixels = new Vector(decal.width * decal.origin.x, decal.height * decal.origin.y);
				EDITOR.draw.drawSubtexture(offx + decal.position.x, offy + decal.position.y, decal.texture, originInPixels, decal.scale, decal.rotation, null, null, null, null, decal.color);
			}
			else
			{
				var zoom = EDITOR.camera.a;
				var ox = offx + decal.position.x;
				var oy = offy + decal.position.y;
				var w = decal.width;
				var h = decal.height;
				var originx = decal.origin.x * w;
				var originy = decal.origin.y * h;
				EDITOR.draw.drawRect(ox - originx, oy - originy, w, 1, Color.red);
				EDITOR.draw.drawRect(ox - originx, oy - originy, 1, h, Color.red);
				EDITOR.draw.drawRect(ox + originx - 1, oy - originy, 1, h, Color.red);
				EDITOR.draw.drawRect(ox - originx, oy + originy - 1, w, 1, Color.red);
				EDITOR.draw.drawLineQuads(new Vector(ox - originx, oy - originy), new Vector(ox + originx, oy + originy), Color.red, zoom);
				EDITOR.draw.drawLineQuads(new Vector(ox + originx, oy - originy), new Vector(ox - originx, oy + originy), Color.red, zoom);
			}
		}
	}
	
	override function drawOverlay(level: Level)
	{
		if (selected.length <= 0) return;
		for (decal in selected) decal.drawSelectionBox(level, true);
	}

	override function loop() {
		if (!selectedChanged) return;
		selectedChanged = false;
		selectionPanel.refresh();
		EDITOR.dirty();
	}

	override function refresh() {
		selected.resize(0);
		selectedChanged = true;
	}

	override function createPalettePanel():SidePanel
	{
		return new DecalPalettePanel(this);
	}

	override function createSelectionPanel():Null<SidePanel> 
	{
		return new DecalSelectionPanel(this);
	}

	override function afterUndoRedo(level: Level):Void
	{
		selected = [];
		hovered = [];
	}

	public function getDecals(level: Level): Array<Decal>
	{
		var dl: DecalLayer = cast getLayer(level);
		return dl.decals;
	}

	public function getDecalsFromCurrentLevel(): Array<Decal>
	{
		var dl: DecalLayer = cast getLayerFromCurrentLevel();
		return dl.decals;
	}
}

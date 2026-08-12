package modules.decals.tools;

import level.data.Level;

class DecalResizeTool extends DecalTool
{

	public var resizing:Bool = false;
	public var decals:Array<Decal>;
	public var lastPos:Vector = new Vector();
	public var start:Vector = new Vector();
	public var mousePos:Vector = new Vector();
	public var firstChange:Bool = false;
	public var canResizeX:Bool = false;
	public var canResizeY:Bool = false;

	override public function drawOverlay(level: Level)
	{
		if (!resizing) return;
		var offset = level.data.offset;
		var drawStart = start.clone().add(offset);
		var drawMouse = mousePos.clone().add(offset);
		var drawLast = lastPos.clone().add(offset);
		EDITOR.overlay.drawLine(drawStart, drawMouse, Color.white);
		EDITOR.overlay.drawLineNode(drawStart, 10 / EDITOR.zoom, Color.green);
		if (canResizeX) EDITOR.overlay.drawLine(drawStart, new Vector(drawLast.x, drawStart.y), Color.green);
		if (canResizeY) EDITOR.overlay.drawLine(drawStart, new Vector(drawStart.x, drawLast.y), Color.green);
	}

	override public function onMouseDown(pos:Vector)
	{
		decals = layerEditor.selected;

		if (decals.length == 0) return;
		pos.clone(mousePos);
		layer.snapToGrid(pos, pos);
		pos.clone(lastPos);
		pos.clone(start);
		
		resizing = true;
		firstChange = false;
		EDITOR.locked = true;
		EDITOR.overlayDirty();
	}

	override public function onMouseUp(pos:Vector)
	{
		if (!resizing) return;
		resizing = false;
		EDITOR.locked = false;
		EDITOR.overlayDirty();
	}

	override public function onRightDown(pos:Vector)
	{
		var changed = false;
		for (decal in layerEditor.selected) if (decal.scale.x != 1 || decal.scale.y != 1)
		{
			if (!changed)
			{
				EDITOR.currentLevel.store("resize decals");
				changed = true;
			}
			decal.scale.set(1, 1);
		}
		layerEditor.selectedChanged = true;
		EDITOR.dirty();
	}

	override public function onMouseMove(pos:Vector)
	{
		if (!resizing) return;
		if (!pos.equals(mousePos))
		{
			pos.clone(mousePos);
			EDITOR.overlayDirty();
		}

		if (!OGMO.ctrl) layer.snapToGrid(pos, pos);
		else layer.snapToPixel(pos, pos);

		if (!pos.equals(lastPos))
		{
			if (!firstChange)
			{
				firstChange = true;
				EDITOR.currentLevel.store("resize decals");
			}

			for (d in decals) d.resize(new Vector(pos.x - lastPos.x, pos.y - lastPos.y));

			layerEditor.selectedChanged = true;
			EDITOR.dirty();
			pos.clone(lastPos);
		}
	}

	override public function getIcon():String return "decal-scale";
	override public function getName():String return "Resize";
	override public function keyToolCtrl():Int return resizing ? -1 : 0;
	override public function keyToolAlt():Int return 1;
	override public function keyToolShift():Int return 3;
	override function isAvailable():Bool return (cast layerEditor.template : DecalLayerTemplate).scaleable && layerEditor.selected.length > 0;

}

package modules.entities.tools;

import level.data.Level;

class EntityResizeTool extends EntityTool
{

	public var resizing:Bool = false;
	public var entities:Array<Entity>;
	public var lastPos:Vector = new Vector();
	public var start:Vector = new Vector();
	public var mousePos:Vector = new Vector();
	public var firstChange:Bool = false;
	public var canResizeX:Bool = false;
	public var canResizeY:Bool = false;

	override public function drawOverlay(level: Level)
	{
		if (!resizing) return;

		var drawStart = EDITOR.levelToGlobal(start, level);
		var drawLast = EDITOR.levelToGlobal(lastPos, level);

		EDITOR.overlay.drawLine(drawStart, mousePos, Color.white);
		EDITOR.overlay.drawLineNode(drawStart, 10 / EDITOR.zoom, Color.green);
		if (canResizeX) EDITOR.overlay.drawLine(drawStart, new Vector(drawLast.x, drawStart.y), Color.green);
		if (canResizeY) EDITOR.overlay.drawLine(drawStart, new Vector(drawStart.x, drawLast.y), Color.green);
	}

	override public function onMouseDown(pos:Vector)
	{
		entities = layer.entities.getGroup(layerEditor.selection);

		if (entities.length == 0) return;
		pos.clone(mousePos);
		layer.snapToGrid(pos, pos);
		pos.clone(lastPos);
		pos.clone(start);

		canResizeX = false;
		canResizeY = false;
		for (e in entities)
		{
			e.anchorSize();
			if (e.template.resizeableX) canResizeX = true;
			if (e.template.resizeableY) canResizeY = true;
		}

		if (canResizeX || canResizeY)
		{
			resizing = true;
			firstChange = false;
			EDITOR.locked = true;
			EDITOR.overlayDirty();
		}
	}

	override public function onMouseUp(pos:Vector)
	{
		if (!resizing) return;
		layerEditor.selection.changed = true;
		resizing = false;
		EDITOR.locked = false;
		EDITOR.overlayDirty();
	}

	override public function onRightDown(pos:Vector)
	{
		var changed = false;
		for (entity in layer.entities.getGroup(layerEditor.selection)) if (!entity.size.equals(entity.template.size))
		{
			if (!changed)
			{
				EDITOR.currentLevel.store("resize entities");
				changed = true;
			}
			entity.resetSize();
		}
		layerEditor.selection.changed = true;
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
				EDITOR.currentLevel.store("resize entities");
			}

			var diff = new Vector(pos.x - start.x, pos.y - start.y);
			for (e in entities) e.resize(diff);

			layerEditor.selection.changed = true;
			EDITOR.dirty();
			pos.clone(lastPos);
		}
	}

	override public function getIcon():String return "entity-scale";
	override public function getName():String return "Resize";
	override public function keyToolCtrl():Int return 0;
	override public function keyToolAlt():Int return 1;
	override public function keyToolShift():Int return 3;
	override function isAvailable():Bool {
		for (entity in layerEditor.getEntitiesFromCurrentLevel().list) {
			for (e_id in layerEditor.selection.ids) if (entity.id == e_id && (entity.template.resizeableX || entity.template.resizeableY)) return true;
		}
		return false;
	}

}

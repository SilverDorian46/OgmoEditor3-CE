package modules.entities;

import level.data.Level;
import level.editor.ui.PropertyDisplay.PropertyDisplayMode;
import level.editor.ui.SidePanel;
import level.editor.LayerEditor;
import rendering.FloatingHTML.FloatingHTMLPropertyDisplay;
import rendering.FloatingHTML.PositionAlignV;
import rendering.FloatingHTML.PositionAlignH;

class EntityNodeID
{
	public static inline var ENTITY_NONE_ID:Int = -1;
	public static inline var ROOT_NODE_ID:Int = -1;

	public var entityID:Int;
	public var nodeIdx:Int;

	public function getNodePosition(entity:Entity):Vector
	{
		if (entityID == ENTITY_NONE_ID)
			return null;
		else if (nodeIdx == ROOT_NODE_ID)
			return entity.position;
		else if (nodeIdx >= entity.nodes.length)
			return null;
		else
			return entity.nodes[nodeIdx];
	}

	public function new()
	{
		entityID = ENTITY_NONE_ID;
		nodeIdx = ROOT_NODE_ID;
	}

	public function set(entityID:Int, nodeIdx:Int = ROOT_NODE_ID):Bool
	{
		var changed = this.entityID != entityID || this.nodeIdx != nodeIdx;
		this.entityID = entityID;
		this.nodeIdx = nodeIdx;

		return changed;
	}

	public function isSet():Bool
	{
		return entityID != ENTITY_NONE_ID;
	}

	public function isRoot(): Bool
	{
		return nodeIdx == ROOT_NODE_ID;
	}
}

class EntityLayerEditor extends LayerEditor
{
	public var selection:EntityGroup = new EntityGroup();
	public var hovered:EntityGroup = new EntityGroup();
	public var hoveredNode:EntityNodeID = new EntityNodeID();
	public var brush:Int = -1;
	//public var entities(get, never):EntityList;

	private var entityTexts = new Map<Int, FloatingHTMLPropertyDisplay>();

	public function new(id:Int)
	{
		super(id);
		brush = 0;
	}

	override function draw(level: Level)
	{
		var offx = level.data.offset.x;
		var offy = level.data.offset.y;

		var entities = getEntities(level);

		// Draw Hover
		if (active && hovered.amount > 0)
		{
			for (ent in entities.getGroup(hovered)) ent.drawHoveredBox(level);
		}
		if (active && hoveredNode.isSet())
		{
			var ent = entities.getByID(hoveredNode.entityID);
			if (ent != null)
			{
				var nodePos = hoveredNode.getNodePosition(ent);
				if (nodePos != null)
				{
					if (nodePos == ent.position) ent.drawHoveredBox(level, nodePos);
					else ent.drawHoveredNodeBox(level, nodePos);
				}
			}
		}

		drawEntities(offx, offy, entities);
	}

	override function drawNoHover(level: Level)
	{
		drawEntities(level.data.offset.x, level.data.offset.y, getEntities(level));
	}

	private function drawEntities(offx:Float, offy:Float, entities:EntityList)
	{
		// Draw Entities
		var hasNodes:Array<Entity> = [];
		for (ent in entities.list)
		{
			ent.drawOffset(offx, offy);
			if (!active && ent.canDrawNodes) hasNodes.push(ent);
		}

		// Draw node lines
		if (hasNodes.length > 0) for (ent in hasNodes) ent.drawNodeLinesOffset(offx, offy);

		// Draw entity property display texts
		{
			FloatingHTMLPropertyDisplay.visibleFade = EDITOR.zoom >= OGMO.settings.propertyDisplay.minimumZoom;
			FloatingHTMLPropertyDisplay.visible = OGMO.settings.propertyDisplay.visible;

			for (ent in entities.list)
			{
				if (!entityTexts.exists(ent.id))
					entityTexts.set(ent.id, new FloatingHTMLPropertyDisplay());
			}

			var toRemove = new Array<Int>();
			for (id => text in entityTexts)
			{
				if (OGMO.settings.propertyDisplay.mode == PropertyDisplayMode.ActiveLayer && !active)
				{
					text.setOpacity(0);
					continue;
				}

				var entity = entities.getByID(id);
				if (entity != null)
				{
					var offsetPos = new Vector(offx + entity.position.x, offy + entity.position.y);
					var corners = entity.getCorners(offsetPos, 8 / EDITOR.zoom);
					var avgX = (corners[0].x + corners[1].x + corners[2].x + corners[3].x) / 4.0;
					var minY = Math.min(Math.min(corners[0].y, corners[1].y), Math.min(corners[2].y, corners[3].y));

					text.setEntity(entity);
					text.setCanvasPosition(new Vector(avgX, minY), PositionAlignH.Left, PositionAlignV.Bottom);
					text.setOpacity(EDITOR.draw.getAlpha());
					text.setFontSize(0.75 * OGMO.settings.propertyDisplay.fontSize);
				}
				else
				{
					text.destroy();
					toRemove.push(id);
				}
			}

			for (id in toRemove)
				entityTexts.remove(id);
		}
	}

	override function drawAbove(level: Level)
	{
		// Draw Nodes
		for (ent in getEntities(level).list) if (ent.canDrawNodes) ent.drawNodeLines(level);
	}

	override function drawOverlay(level: Level)
	{
		if (selection.amount <= 0) return;
		for (entity in getEntities(level).getGroup(selection)) entity.drawSelectionBox(level);
	}

	override function loop()
	{
		if (!selection.changed) return;
		selection.changed = false;
		selectionPanel.refresh();
		EDITOR.dirty();
	}

	override function refresh() {
		selection.clear();
		for (text in entityTexts)
			text.destroy();
		entityTexts.clear();
	}

	override function createPalettePanel():SidePanel return new EntityPalettePanel(this);
	
	override function createSelectionPanel():SidePanel return new EntitySelectionPanel(this);

	override function afterUndoRedo(level: Level) selection.trim(getEntities(level));

	public var brushTemplate(get, never):EntityTemplate;
	function get_brushTemplate():EntityTemplate return OGMO.project.getEntityTemplate(brush);

	// region KEYBOARD

	override function keyPress(key:Int)
	{
		if (EDITOR.locked) return;
		switch (key)
		{
			case Keys.Backspace, Keys.Delete:
				if (selection.amount <= 0) return;
				EDITOR.currentLevel.store('delete entities');
				EDITOR.dirty();
				getEntitiesFromCurrentLevel().removeAndClearGroup(selection);
			case Keys.A:
				if (!OGMO.ctrl) return;
				selection.set(getEntitiesFromCurrentLevel().list);
				EDITOR.dirty();
			case Keys.D:
				if (!OGMO.ctrl || selection.amount <= 0) return;
				EDITOR.currentLevel.store('duplicate entities');
				var entities = getEntitiesFromCurrentLevel();
				var copies:Array<Entity> = [ for (e in entities.getGroup(selection)) e.duplicate(getLayerFromCurrentLevel().downcast(EntityLayer).nextID(), template.gridSize.x * 2, template.gridSize.y * 2) ];
				entities.addList(copies);
				if (OGMO.shift) selection.add(copies);
				else selection.set(copies);
				EDITOR.dirty();
			case Keys.F:
				// Swap selected entities' positions with their first nodes
				if (!OGMO.ctrl || !OGMO.shift || selection.amount <= 0) return;
				var entities = getEntitiesFromCurrentLevel();
				var swapped = false;
				for (e in entities.getGroup(selection))
				{
					if (!swapped)
					{
						swapped = true;
						EDITOR.currentLevel.store('swap entity and first node positions');
						EDITOR.dirty();
					}
					var temp = e.position;
					e.position = e.nodes[0];
					e.nodes[0] = temp;
				}
			case Keys.H:
				if (OGMO.ctrl || selection.amount <= 0) return;
				EDITOR.currentLevel.store("flip entity h");
				for (e in getEntitiesFromCurrentLevel().getGroup(selection)) if (e.template.canFlipX) e.flippedX = !e.flippedX;
				selection.changed = true;
				EDITOR.dirty();
			case Keys.V:
				if (OGMO.ctrl || selection.amount <= 0) return;
				EDITOR.currentLevel.store("flip entity v");
				for (e in getEntitiesFromCurrentLevel().getGroup(selection)) if (e.template.canFlipY) e.flippedY = !e.flippedY;
				selection.changed = true;
				EDITOR.dirty();
		}
	}

	// endregion

	public function getEntities(level: Level): EntityList
	{
		var el: EntityLayer = cast getLayer(level);
		return el.entities;
	}

	public function getEntitiesFromCurrentLevel(): EntityList
	{
		var el: EntityLayer = cast getLayerFromCurrentLevel();
		return el.entities;
	}

	/*inline function get_entities():EntityList {
		var el:EntityLayer = cast layer;
		return el.entities;
	}*/

	override  function set_visible(newVisible:Bool):Bool {
		if (!newVisible)
			for (text in entityTexts)
				text.setOpacity(0);
		return super.set_visible(newVisible);
	}
}
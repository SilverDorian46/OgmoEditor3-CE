package modules.entities;

import level.data.Level;
import rendering.Atlas;
import haxe.ds.Either;
import rendering.Subtexture;
import io.Imports;
import level.data.Value;
import project.data.value.TextValueTemplate;
import project.data.value.StringValueTemplate;
import project.data.value.IntegerValueTemplate;
import project.data.value.FloatValueTemplate;
import project.data.value.EnumValueTemplate;
import project.data.value.ColorValueTemplate;
import project.data.value.BoolValueTemplate;
import project.data.ValueDefinition.ValueDisplayType;
import rendering.Texture;
import util.Matrix;

class Entity
{
	public var id:Int;
	public var template:EntityTemplate;
	public var position:Vector;
	public var size:Vector;
	public var origin:Vector;
	public var rotation:Float;
	public var flippedX:Bool;
	public var flippedY:Bool;
	public var color:Color;
	public var nodes:Array<Vector>;
	public var values:Array<Value>;

	// Not Exported
	private var _matrix:Matrix = new Matrix();     //The collision matrix
	private var _tileMatrix:Matrix = new Matrix(); //The drawing matrix
	private var _points:Array<Vector> = [];
	private var _sizeAnchor:Vector;
	private var _rotationAnchor:Float;
	//private var _texture:Null<Texture>;
	private var _texture:Null<Subtexture>;

	private var handler: EntityHandlerStruct;

	private static var hoverColor:Color = new Color(1, 1, 1, 0.5);

	public static function create(id:Int, template:EntityTemplate, pos:Vector):Entity
	{
		var e = new Entity();

		e.id = id;
		e.template = template;
		e.position = pos.clone();
		e.size = template.size.clone();
		e.origin = template.origin.clone();
		e.rotation = 0;
		e.flippedX = false;
		e.flippedY = false;
		e.color = template.color;
		e.nodes = [];
		if (template.nodeMinimum > 0) for (i in 0...template.nodeMinimum)
			e.nodes.push(new Vector(pos.x + 16 * (i + 1), pos.y));
		e._texture = template.texture;
		e.values = [];
		for (value in template.values) e.values.push(new Value(value));

		e.handler = OGMO.project.projectHooks.getEntityHandler(template);

		e.updateMatrix();
		return e;
	}

	public static function load(data:Dynamic): Entity
	{
		var template = OGMO.project.getEntityTemplateByExportID(data._eid);
		if (template == null || data.id == null) return null;

		var e = new Entity();
		e.id = data.id;
		e.template = template;
		e.position = Imports.vector(data, "x", "y");
		e.size = Imports.vector(data, "width", "height", template.size);
		e.origin = Imports.vector(data, "originX", "originY", template.origin);
		e.rotation = Imports.float(data.rotation, 0) * (OGMO.project.anglesRadians ? Calc.RTD : 1);
		e.flippedX = Imports.bool(data.flippedX, false);
		e.flippedY = Imports.bool(data.flippedY, false);
		e.color = Imports.color(data.color, template.includeAlpha, template.color);
		e.nodes = Imports.nodes(data);
		e.values = Imports.values(data, template.values);

		e.handler = OGMO.project.projectHooks.getEntityHandler(template);

		e._texture = template.texture;

		e.updateMatrix();
		return e;
	}

	inline function new() {}

	public function save():Dynamic
	{
		var data:Dynamic = {};
		data.name = template.name;
		data.id = id;
		data._eid = template.exportID;
		position.saveInto(data, "x", "y");
		if (template.resizeableX) data.width = size.x;
		if (template.resizeableY) data.height = size.y;
		if (template.originAnchored) origin.saveInto(data, "originX", "originY");
		if (template.rotatable) data.rotation = OGMO.project.anglesRadians ? rotation * Calc.DTR : rotation;
		if (template.canFlipX) data.flippedX = flippedX;
		if (template.canFlipY) data.flippedY = flippedY;
		if (template.canSetColor) data.color = Export.color(color, template.includeAlpha, template.includeHashtag);
		Export.nodes(data, nodes);
		Export.values(data, values);

		return data;
	}

	public function clone(): Entity
	{
		var e = new Entity();

		e.id = id;
		e.template = template;
		e.position = position.clone();
		e.size = size.clone();
		e.origin = origin.clone();
		e.rotation = rotation;
		e.flippedX = flippedX;
		e.flippedY = flippedY;
		e.color = color.clone();
		e.nodes = [for (node in nodes) node.clone()];
		e._texture = _texture;
		e.values = [for (value in values) value.clone()];

		e.handler = OGMO.project.projectHooks.getEntityHandler(template);

		e.updateMatrix();
		return e;
	}

	public function duplicate(id:Int, addX:Float, addY:Float): Entity
	{
		var e = clone();

		e.id = id;
		e.move(new Vector(addX, addY));

		e.updateMatrix();
		return e;
	}

	/*
		TRANSFORMATIONS
	*/

	public function move(amount:Vector)
	{
		position.x += amount.x;
		position.y += amount.y;

		for (node in nodes)
		{
			node.x += amount.x;
			node.y += amount.y;
		}
	}

	public function anchorSize()
	{
		_sizeAnchor = size.clone();
	}

	public function resize(delta:Vector)
	{
		if (template.resizeableX)
		{
			size.x = Math.max(template.size.x, _sizeAnchor.x + delta.x);
			if (template.originAnchored)
				origin.x = (template.origin.x / template.size.x) * size.x;
		}

		if (template.resizeableY)
		{
			size.y = Math.max(template.size.y, _sizeAnchor.y + delta.y);
			if (template.originAnchored)
				origin.y = (template.origin.y / template.size.y) * size.y;
		}

		updateMatrix();
	}

	public function resetSize()
	{
		size.copy(template.size);
		if (template.originAnchored) origin.set(
			(template.origin.x / template.size.x) * size.x,
			(template.origin.y / template.size.y) * size.y
		);
		updateMatrix();
	}

	public function anchorRotation()
	{
		_rotationAnchor = rotation;
	}

	public function rotate(diff:Float)
	{
		if (template.rotatable)
		{
			rotation = _rotationAnchor + diff * Calc.RTD;
			rotation = Calc.snap(rotation, 360 / template.rotationDegrees);
			updateMatrix();
		}
	}

	public function resetRotation()
	{
		rotation = 0;
		updateMatrix();
	}

	/*
		MATRIX
	*/

	public function updateMatrix()
	{
		var tile = template.tileSize.clone();
		var orig = origin.clone();
		if (!template.tileX)
			tile.x = size.x;
		else
			orig.x = (orig.x / size.x) * tile.x;
		if (!template.tileY)
			tile.y = size.y;
		else
			orig.y = (orig.y / size.y) * tile.y;

		_matrix.entityTransform(origin, size, rotation * Calc.DTR);
		_tileMatrix.entityTransform(orig, tile, rotation * Calc.DTR);

		_points = template.shape.getPoints(_tileMatrix, origin, size, tile, flippedX, flippedY);
	}

	/*
		DRAWING
	*/

	public inline function draw(level: Level) drawOffset(level.data.offset.x, level.data.offset.y);

	public function drawOffset(offx: Float, offy: Float)
	{
		var hTexture: Subtexture = null;
		var hTextures: Array<Subtexture> = null;
		var hNodeTexture: Subtexture = null;
		if (handler != null)
		{
			var atlas = OGMO.project.atlas;
			hTexture = textureFromHandler(handler.texture, atlas);
			hTextures = texturesFromHandler(handler.textures, atlas);
			hNodeTexture = textureFromHandler(handler.nodeTexture, atlas);
		}

		function drawTexture(subtex: Subtexture, pos: Vector, color: Color)
		{
			var orig = origin.clone();
			if (flippedX) orig.x -= size.x;
			if (flippedY) orig.y -= size.y;
			orig.x = (orig.x / size.x) * subtex.width;
			orig.y = (orig.y / size.y) * subtex.height;
			var rot = rotation * Calc.DTR;
			orig.rotate(Math.sin(rot), Math.cos(rot));
			EDITOR.draw.drawSubtexture(offx + pos.x - orig.x, offy + pos.y - orig.y, subtex, null, new Vector(flippedX ? -1 : 1, flippedY ? -1 : 1), rot, null, null, null, null, color);
		}

		if (hTextures != null && hTextures.length > 0) for (tex in hTextures) drawTexture(tex, position, Color.white);
		else if (hTexture != null) drawTexture(hTexture, position, Color.white);
		else if (_texture != null)
		{
			var orig = origin.clone();
			if (flippedX) orig.x -= size.x;
			if (flippedY) orig.y -= size.y;
			var rot = rotation * Calc.DTR;
			orig.rotate(Math.sin(rot), Math.cos(rot));
			EDITOR.draw.drawSubtexture(offx + position.x - orig.x, offy + position.y - orig.y, _texture, null, size.clone().div(template.size).mult(new Vector(flippedX ? -1 : 1, flippedY ? -1 : 1)), rot);
		}
		else 
		{
			EDITOR.draw.drawTris(_points, new Vector(offx + position.x, offy + position.y), color);
		}

		//Draw Node Ghosts
		if (nodes.length > 0)
		{
			var handled = false;
			if (hNodeTexture != null)
			{
				handled = true;
				for (node in nodes) drawTexture(hNodeTexture, node, Color.white);
			}

			if (!handled)
			{
				if (template.nodePoint)
				{
					var nodeSize = template.nodePointSize;
					for (node in nodes)
					{
						EDITOR.draw.drawRect(offx + node.x - (nodeSize.x * 0.5), offy + node.y - (nodeSize.y * 0.5), nodeSize.x, nodeSize.y, color);
					}
				}

				if (template.nodeGhost)
				{
					var c = color.x(0.5);
					var texture_c = Color.white.x(.75);
					for (node in nodes)
					{
						if (hTextures != null && hTextures.length > 0) for (tex in hTextures) drawTexture(tex, node, texture_c);
						else if (hTexture != null) drawTexture(hTexture, node, texture_c);
						else if (_texture != null)
						{
							var orig = origin.clone();
							if (flippedX) orig.x -= size.x;
							if (flippedY) orig.y -= size.y;
							var rot = rotation * Calc.DTR;
							orig.rotate(Math.sin(rot), Math.cos(rot));
							EDITOR.draw.drawSubtexture(offx + node.x - orig.x, offy + node.y - orig.y, _texture, null, size.clone().div(template.size).mult(new Vector(flippedX ? -1 : 1, flippedY ? -1 : 1)), rot, null, null, null, null, texture_c);
						}
						else
						{
							EDITOR.draw.drawTris(_points, new Vector(offx + node.x, offy + node.y), c);
						}
					}
				}
			}
		}
	}

	public function drawHoveredBox(level: Level, ?position:Vector)
	{
		var pos = position == null ? this.position : position;
		var corners = getCorners(pos.clone().add(level.data.offset), 8 / EDITOR.zoom);
		EDITOR.draw.drawTri(corners[0], corners[1], corners[2], Entity.hoverColor);
		EDITOR.draw.drawTri(corners[1], corners[2], corners[3], Entity.hoverColor);
	}

	public function drawHoveredNodeBox(level: Level, nodePos:Vector)
	{
		var offset = level.data.offset;

		if (template.nodePoint)
		{
			var nodeSize = template.nodePointSize;
			var pad = 8 / EDITOR.zoom;
			EDITOR.draw.drawRect((nodePos.x + offset.x) - pad - (nodeSize.x * 0.5), (nodePos.y + offset.y) - pad - (nodeSize.y * 0.5), nodeSize.x + (pad * 2), nodeSize.y + (pad * 2), Entity.hoverColor);
		}
		else
		{
			var col = Entity.hoverColor.x(0.5);

			var corners = getCorners(nodePos.clone().add(offset), 8 / EDITOR.zoom);
			EDITOR.draw.drawTri(corners[0], corners[1], corners[2], col);
			EDITOR.draw.drawTri(corners[1], corners[2], corners[3], col);
		}
	}

	public function drawSelectionBox(level: Level, ?position:Vector)
	{
		var pos = position == null ? this.position : position;
		var corners = getCorners(pos.clone().add(level.data.offset), 8 / EDITOR.zoom);
		EDITOR.overlay.drawLine(corners[0], corners[1], Color.green);
		EDITOR.overlay.drawLine(corners[1], corners[3], Color.green);
		EDITOR.overlay.drawLine(corners[2], corners[3], Color.green);
		EDITOR.overlay.drawLine(corners[2], corners[0], Color.green);
	}

	/*
		NODES
	*/

	public function getNodeAt(pos:Vector):Int
	{
		if (template.nodePoint) for (i in 0...nodes.length)
		{
			var nodePos = nodes[i];
			if (checkNodePoint(pos, nodePos))
				return i;
		}
		else for (i in 0...nodes.length)
		{
			var nodePos = nodes[i];
			if (checkPoint(pos, nodePos))
				return i;
		}

		return null;
	}

	public var canAddNode(get, never):Bool;
	function get_canAddNode():Bool
	{
		return template.hasNodes && (template.nodeLimit <= 0 || nodes.length < template.nodeLimit);
	}

	public var canRemoveNode(get, never):Bool;
	function get_canRemoveNode():Bool
	{
		return nodes.length > template.nodeMinimum;
	}

	public function addNodeAt(pos:Vector):Vector
	{
		if (canAddNode)
		{
			var n = pos.clone();
			nodes.push(n);
			return n;
		}
		else
			return null;
	}

	public var canDrawNodes(get, never):Bool;
	function get_canDrawNodes():Bool
	{
		return template.nodeDisplay != NodeDisplayModes.NONE && nodes.length > 0;
	}

	public inline function drawNodeLines(level: Level) drawNodeLinesOffset(level.data.offset.x, level.data.offset.y);

	public function drawNodeLinesOffset(offx: Float, offy: Float)
	{
		switch (template.nodeDisplay)
		{
			case NodeDisplayModes.PATH:
				var zoom = EDITOR.camera.a;
				var prev:Vector = position;
				for (node in nodes)
				{
					EDITOR.draw.drawLineQuads(new Vector(offx + prev.x, offy + prev.y), new Vector(offx + node.x, offy + node.y), Color.white, zoom);
					prev = node;
				}
			case NodeDisplayModes.CIRCUIT:
				var zoom = EDITOR.camera.a;
				var prev:Vector = position;
				for (node in nodes)
				{
					EDITOR.draw.drawLineQuads(new Vector(offx + prev.x, offy + prev.y), new Vector(offx + node.x, offy + node.y), Color.white, zoom);
					prev = node;
				}

				if (nodes.length > 1) EDITOR.draw.drawLineQuads(new Vector(offx + prev.x, offy + prev.y), new Vector(offx + position.x, offy + position.y), Color.white, zoom);
			case NodeDisplayModes.FAN:
				for (node in nodes) EDITOR.draw.drawLineQuads(new Vector(offx + position.x, offy + position.y), new Vector(offx + node.x, offy + node.y), Color.white, EDITOR.camera.a);
			default:
		}
	}

	/*
		COLLISION CHECKS
	*/

	public function getCorners(offset:Vector, pad:Float):Array<Vector>
	{
		var padX:Float = 0;
		var padY:Float = 0;
		if (pad != 0)
		{
			padX = pad / (size.x * 0.5);
			padY = pad / (size.y * 0.5);
		}

		var corners:Array<Vector> = [
			new Vector(-1 - padX, -1 - padY),
			new Vector(1 + padX, -1 - padY),
			new Vector(-1 - padX, 1 + padY),
			new Vector(1 + padX, 1 + padY)
		];

		_matrix.transformPoints(corners);
		for (corner in corners)
		{
			corner.x += offset.x;
			corner.y += offset.y;
		}

		return corners;
	}

	public function checkPoint(pos:Vector, ?ownPos:Vector):Bool
	{
		var p = pos.clone();
		var entPos = ownPos == null ? position : ownPos;
		p.x -= entPos.x;
		p.y -= entPos.y;
		_matrix.inverseTransformPoint(p, p);

		var valX = 1 + (4 / (size.x * 0.5));
		var valY = 1 + (4 / (size.y * 0.5));

		return (p.x >= -valX && p.x < valX && p.y >= -valY && p.y < valY);
	}

	public function checkNodePoint(pos: Vector, nodePos: Vector): Bool
	{
		var p = pos.clone();
		p.x -= nodePos.x;
		p.y -= nodePos.y;

		var valX = 2 + (template.nodePointSize.x * 0.5);
		var valY = 2 + (template.nodePointSize.y * 0.5);

		return (p.x >= -valX && p.x < valX && p.y >= -valY && p.y < valY);
	}

	public function checkRect(rect:Rectangle, ?ownPos:Vector):Bool
	{
		//constraints: rect is AABB, this Entity's hitbox is a potentially-rotated rectangle

		//Check rect center against Entity
		var rectCenter = rect.center;
		if (checkPoint(rectCenter))
			return true;

		//Check Entity corner points against AABB
		var entPos = ownPos == null ? position : ownPos;
		var corners = getCorners(entPos, 4);
		for (corner in corners) if (rect.contains(corner)) return true;

		//Check Entity edges against AABB
		if (rect.intersectsLineNoContainsCheck(corners[0], corners[1]))
			return true;
		if (rect.intersectsLineNoContainsCheck(corners[1], corners[2]))
			return true;
		if (rect.intersectsLineNoContainsCheck(corners[2], corners[3]))
			return true;
		if (rect.intersectsLineNoContainsCheck(corners[3], corners[0]))
			return true;

		return false;
	}

	/*
	    SEARCH
	*/

	@:keep
	public function getValue(name: String): Null<Dynamic>
	{
		for (value in values) if (value.template.name == name) return value.value;
		return null;
	}

	/*
	    ENTITY HANDLER
	*/

	// string or string-returning function
	function textureFromHandler(texture: Dynamic, atlas: Atlas): Subtexture
	{
		if (texture == null) return null;
		return switch (js.Lib.typeof(texture))
		{
			case "string": atlas.get(texture);
			case "function": atlas.get(texture(this));
			default: null;
		}
	}

	// array of strings or array-of-strings-returning function
	function texturesFromHandler(textures: Dynamic, atlas: Atlas): Array<Subtexture>
	{
		if (textures == null) return null;
		var strs: Array<Dynamic> = switch (js.Lib.typeof(textures))
		{
			case "object": textures;
			case "function": textures(this);
			default: null;
		}
		if (strs == null) return null;
		trace(strs);
		var result = [];
		for (str in strs) if (js.Lib.typeof(str) == "string")
		{
			var tex = atlas.get(str);
			if (tex != null) result.push(tex);
		}
		return result;
	}
}

typedef EntityHandlerStruct = {
	var texture: Dynamic;
	var textures: Dynamic;
	var nodeTexture: Dynamic;
}

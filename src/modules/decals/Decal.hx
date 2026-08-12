package modules.decals;

import level.data.Level;
import rendering.Subtexture;
import level.data.Value;
import rendering.Texture;

class Decal
{
	public static var rotationSnap: Float = Math.PI / 180;

	public var position:Vector;
	public var scale:Vector;
	public var origin:Vector;
	public var rotation:Float;
	public var color:Color;
	//public var texture:Texture;
	public var texture:Subtexture;
	public var path:String;
	public var width(get, never):Int;
	public var height(get, never):Int;
	public var values:Array<Value>;

	public function new(position:Vector, path:String, texture:Subtexture, ?origin:Vector, ?scale:Vector, ?rotation:Float, ?color:Color, ?values:Array<Value>)
	{
		this.position = position.clone();
		this.texture = texture;
		this.path = path;
		this.scale = scale == null ? new Vector(1, 1) : scale.clone();
		this.rotation = rotation == null ? 0 : OGMO.project.anglesRadians ? rotation : rotation * Calc.DTR;
		this.color = color == null ? Color.white : color;
		this.values = values == null ? [] : values;
		this.origin = origin == null ? new Vector(0.5, 0.5) : origin.clone();
	}

	public function save(template:DecalLayerTemplate):Dynamic
	{
		var data:Dynamic = {};
		data._name = "decal";
		data.x = position.x;
		data.y = position.y;
		if (template.scaleable)
		{
			data.scaleX = scale.x;
			data.scaleY = scale.y;
		}
		if (template.rotatable) data.rotation = OGMO.project.anglesRadians ? rotation : rotation * Calc.RTD;
		if (template.canSetColor) data.color = template.includeAlpha ? color.toHexAlpha(template.includeHashtag) : color.toHex(template.includeHashtag);
		data.texture = FileSystem.normalize(path);
		data.originX = origin.x;
		data.originY = origin.y;
		Export.values(data, values);

		return data;
	}

	public function clone():Decal
	{
		return new Decal(position, path, texture, origin, scale, rotation, color, values);
	}

	function get_width():Int
	{
		return texture != null ? texture.width : 32;
	}

	function get_height():Int
	{
		return texture != null ? texture.height : 32;
	}

	public function rotate(diff:Float)
	{
		rotation = Calc.snap(rotation + diff, rotationSnap);
	}

	public function resize(diff:Vector)
	{
		diff.scale(0.1);

		scale.set(
			Calc.roundTo(scale.x + diff.x, 3),
			Calc.roundTo(scale.y + diff.y, 3)
		);
		// TODO - there's probably a more elegant way of doing this! -01010111
		if (OGMO.ctrl) return;
		scale.x = Calc.snap(scale.x, 1);
		scale.y = Calc.snap(scale.y, 1);
	}

	public function drawSelectionBox(level: Level, origin:Bool)
	{
		var corners = getCorners(2, level.data.offset);
		EDITOR.overlay.drawLine(corners[0], corners[1], Color.green);
		EDITOR.overlay.drawLine(corners[1], corners[3], Color.green);
		EDITOR.overlay.drawLine(corners[2], corners[3], Color.green);
		EDITOR.overlay.drawLine(corners[2], corners[0], Color.green);
		if (!origin) return;
		EDITOR.overlay.drawLine(
			Vector.midPoint(corners[0], corners[1]),
			Vector.midPoint(corners[2], corners[3]),
			Color.white
		);
		EDITOR.overlay.drawLine(
			Vector.midPoint(corners[0], corners[2]),
			Vector.midPoint(corners[1], corners[3]),
			Color.white
		);
		EDITOR.overlay.drawRect(position.x + level.data.offset.x - 2, position.y + level.data.offset.y - 2, 4, 4, Color.white);
	}

	public function getCorners(pad:Float, ?offset:Vector):Array<Vector>
	{
		if (offset == null) offset = new Vector(0, 0);

		var corners:Array<Vector> = [
			new Vector(-pad - width * origin.x * scale.x, -pad - height * origin.y * scale.y),
			new Vector(pad + width * (1-origin.x) * scale.x, -pad - height * origin.y * scale.y),
			new Vector(-pad - width * origin.x * scale.x, pad + height * (1-origin.y) * scale.y),
			new Vector(pad + width * (1-origin.x) * scale.x, pad + height * (1-origin.y) * scale.y)
		];

		for (corner in corners)
		{
			var x = corner.x;
			var y = corner.y;
			corner.x = x * rotation.cos() - y * rotation.sin();
			corner.y = x * rotation.sin() + y * rotation.cos();
		}
		for (corner in corners) corner.add(position).add(offset);

		return corners;
	}

}
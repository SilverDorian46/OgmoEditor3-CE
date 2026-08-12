package project.data;

import rendering.Subtexture;
import io.FileSystem;
import js.Browser;
import js.node.Path;
import js.html.ImageElement;
import rendering.Texture;

class Tileset
{
	public var label: String;
	public var path: String;
	//public var texture: Texture;
	public var texture: Subtexture;

	public var width(get, null):Int;
	public var height(get, null):Int;

	public var tileColumns(get, null):Int;
	public var tileRows(get, null):Int;
	public var tileWidth: Int;
	public var tileHeight: Int;
	public var tileSeparationX: Int;
	public var tileSeparationY: Int;
	public var tileMarginX: Int;
	public var tileMarginY: Int;

	public var brokenPath:Bool = false;
	public var brokenTexture:Bool = false;

	public var fallbackImage: ImageElement;

	public function new(project:Project, label:String, path:String, tileWidth:Int, tileHeight:Int, tileSepX:Int, tileSepY:Int, tileMargX:Int, tileMargY:Int, ?fallbackImage:ImageElement)
	{
		this.label = label;
		this.path = haxe.io.Path.normalize(path);
		this.tileWidth = tileWidth;
		this.tileHeight = tileHeight;
		this.tileSeparationX = tileSepX;
		this.tileSeparationY = tileSepY;
		this.tileMarginX = tileMargX;
		this.tileMarginY = tileMargY;

		var subtex = project.atlas.get(path);
		if (subtex != null)
		{
			texture = subtex;
			var texturePath = Path.join(Path.dirname(project.path), path);
			this.fallbackImage = (FileSystem.exists(texturePath)) ? FileSystem.loadImage(texturePath) : texture.extractImage();
		}
		else
		{
			var texturePath = Path.join(Path.dirname(project.path), path);
			if (FileSystem.exists(texturePath))
			{
				//texture = Texture.fromFile(texturePath);
				texture = Subtexture.fromFile(texturePath);
				this.fallbackImage = FileSystem.loadImage(texturePath);
			}
			else if (fallbackImage != null)
			{
				brokenPath = true;
				//texture = new Texture(fallbackImage);
				texture = new Subtexture(new Texture(fallbackImage));
				this.fallbackImage = fallbackImage;

			}
			else
			{
				brokenPath = true;
				brokenTexture = true;
				//texture = Texture.fromString("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAsklEQVRYhcVXQQ6AIAwrPmlv8Zm8xS/NgyERAgpj0CUkJtK14mAlAFAQ4wCAKLKd+M2pADSKaHpePQqu5osd5LmA1SIaubsnriCvC/AW8ZPLDPQg/xYwK6IT65bIinFPOCrY96sMq+W3tMZ6GQZUiSaK1QTKCGd2SkgqLJE62nld1hRPO2YH9ReYBFCLkLoNqQcR9SimNiNqO6YaEqolo5pSqi2nXkyoV7Od5KWIKT/gETfAGp5SxRHyngAAAABJRU5ErkJggg==");
				texture = new Subtexture(Texture.fromString("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAsklEQVRYhcVXQQ6AIAwrPmlv8Zm8xS/NgyERAgpj0CUkJtK14mAlAFAQ4wCAKLKd+M2pADSKaHpePQqu5osd5LmA1SIaubsnriCvC/AW8ZPLDPQg/xYwK6IT65bIinFPOCrY96sMq+W3tMZ6GQZUiSaK1QTKCGd2SkgqLJE62nld1hRPO2YH9ReYBFCLkLoNqQcR9SimNiNqO6YaEqolo5pSqi2nXkyoV7Od5KWIKT/gETfAGp5SxRHyngAAAABJRU5ErkJggg=="));
			}
		}
	}

	public function save():Dynamic
	{
		var data:Dynamic = {};
		data.label = label;
		data.path = path;
		//data.image = texture.image.src;
		if (fallbackImage != null) data.image = fallbackImage.src;
		data.tileWidth = tileWidth;
		data.tileHeight = tileHeight;
		data.tileSeparationX = tileSeparationX;
		data.tileSeparationY = tileSeparationY;
		data.tileMarginX = tileMarginX;
		data.tileMarginY = tileMarginY;
		return data;
	}

	public static function load(project:Project, data:Dynamic):Tileset
	{
		var img: ImageElement;
		if (data.image != null)
		{
			img = Browser.document.createImageElement();
			img.src = data.image;
		}
		else img = null;

		var marginX:Int = 0;
		if (Reflect.hasField(data, "tileMarginX"))
			marginX = data.tileMarginX;
		var marginY:Int = 0;
		if (Reflect.hasField(data, "tileMarginY"))
			marginY = data.tileMarginY;

		return new Tileset(project, data.label, data.path, data.tileWidth, data.tileHeight, data.tileSeparationX, data.tileSeparationY, marginX, marginY, img);
	}

	public static function clone(self:Tileset, project:Project):Tileset
	{
		//var img = Browser.document.createImageElement();
		//img.src = self.texture.image.src;

		var img: ImageElement;
		if (self.fallbackImage != null)
		{
			img = Browser.document.createImageElement();
			img.src = self.fallbackImage.src;
		}
		else img = null;

		return new Tileset(project, self.label + "_copy", self.path, self.tileWidth, self.tileHeight, self.tileSeparationX, self.tileSeparationY, self.tileMarginX, self.tileMarginY, img);
	}

	public inline function getTileX(id: Int):Int return id % tileColumns;

	public inline function getTileY(id: Int):Int return Math.floor(id / tileColumns);

	public inline function coordsToID(x: Float, y: Float):Int return Math.floor(x + y * tileColumns);

	inline function get_width():Int return texture.width;

	inline function get_height():Int return texture.height;

	inline function get_tileColumns():Int return Math.floor((width - tileSeparationX - tileMarginX - tileMarginX) / (tileWidth + tileSeparationX));

	inline function get_tileRows():Int return Math.floor((height - tileSeparationY - tileMarginY - tileMarginY) / (tileHeight + tileSeparationY));
}
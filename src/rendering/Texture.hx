package rendering;

import util.IntRectangle;
import haxe.io.Path;
import js.html.webgl.RenderingContext;
import js.Browser;
import js.html.ImageElement;
import io.FileSystem;
import util.Vector;

/*
	WARNING!
	We assume that all Textures are created AFTER ALL GL Renderers are created
	Also, all Textures are disposed BEFORE ALL GL Renderers are disposed
*/
class Texture
{
	public var path:String;
	public var image: ImageElement;
	public var textures:Map<String, js.html.webgl.Texture> = new Map();
	public var center:Vector;
	public var width(get, null):Int;
	public var height(get, null):Int;

	public var pixelRect: IntRectangle;

	public static function fromString(data: String): Texture
	{
		var image = Browser.document.createImageElement();
		image.src = haxe.io.Path.normalize(data);
		return new Texture(image);
	}
	
	public static function fromFile(path: String): Texture
	{
		path = haxe.io.Path.normalize(path);
		var img = FileSystem.loadImage(path);
		if (img != null)
		{
			var tex = new Texture(img);
			tex.path = path;
			return tex;
		}
		return null;
	}

	public static function fromRelativePath(path: String, relativeTo: String): Texture
	{
		if (relativeTo == null) relativeTo = js.node.Path.dirname(OGMO.project.path);
		var fullPath = js.node.Path.join(relativeTo, path);
		for (ext in FileSystem.supportedImageExts)
		{
			var texture = fromFile(fullPath + ext);
			if (texture != null) return texture;
		}
		return null;
	}

	public static function loadFromData(data: String, onLoad: (Texture) -> Void): Void
	{
		var image = Browser.document.createImageElement();
		image.src = data;
		if (image.width <= 0) image.onload = function() { onLoad(new Texture(image)); }
		else onLoad(new Texture(image));
	}
	
	public function new(image: ImageElement, ?onLoaded: Texture -> Void)
	{
		this.image = image;
		
		if (image.width <= 0) image.onload = function() { load(onLoaded); };
		else load(onLoaded);
	}

	function load(onLoaded: Texture -> Void):Void
	{
		center = new Vector(image.width / 2, image.height / 2);
		for (name in GLRenderer.renderers.keys())
		{
			if (GLRenderer.renderers[name].loadTextures)
			{
				var gl = GLRenderer.renderers[name].gl;
				var tex = gl.createTexture();
				
				gl.bindTexture(RenderingContext.TEXTURE_2D, tex);
				gl.texImage2D(RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, image);
				gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.NEAREST);
				gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.NEAREST);
				gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_S, RenderingContext.CLAMP_TO_EDGE);
				gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_T, RenderingContext.CLAMP_TO_EDGE);
				gl.bindTexture(RenderingContext.TEXTURE_2D, null);
				
				textures[name] = tex;
			}
		}

		if (onLoaded != null) onLoaded(this);
	}
	
	public inline function dispose(): Void
	{
		for (name in textures.keys()) GLRenderer.renderers[name].gl.deleteTexture(textures[name]);
		textures = new Map();
		pixelRect = null;
	}
	
	inline function get_width(): Int return image.width;
	
	inline function get_height(): Int return image.height;
}
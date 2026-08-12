package rendering;

import js.Browser;
import js.html.ImageElement;
import util.IntRectangle;

class Subtexture
{
    public var texture: Texture;
    public var sourceRect: IntRectangle;

    public var width(get, never): Int;
    inline function get_width() { return sourceRect.width; }

    public var height(get, never): Int;
    inline function get_height() { return sourceRect.height; }

    public var sourceX(get, never): Int;
    inline function get_sourceX() { return sourceRect.x; }

    public var sourceY(get, never): Int;
    inline function get_sourceY() { return sourceRect.y; }

    public var center(get, never): Vector;
    inline function get_center() { return new Vector(sourceRect.width / 2, sourceRect.height / 2); }

    public var sourceCenter(get, never): Vector;
    inline function get_sourceCenter() { return new Vector(sourceRect.x + (sourceRect.width / 2), sourceRect.y + (sourceRect.height / 2)); }

    public function new(texture: Texture, ?sourceRect: IntRectangle)
    {
        this.texture = texture;
        if (sourceRect != null) this.sourceRect = sourceRect.clone();
        else
        {
            this.sourceRect = new IntRectangle(0, 0, 0, 0);
            if (texture != null)
            {
                if (texture.width <= 0) texture.image.addEventListener("load", (e) ->
                    {
                        this.sourceRect.width = texture.width;
                        this.sourceRect.height = texture.height;
                    });
                else
                {
                    this.sourceRect.width = texture.width;
                    this.sourceRect.height = texture.height;
                }
            }
        }
    }

    public static function fromFile(path: String)
    {
        var texture = Texture.fromFile(path);
        return (texture != null) ? new Subtexture(texture) : null;
    }

    public static function fromRelativePath(path: String, relativeTo: String): Null<Subtexture>
    {
        var texture = Texture.fromRelativePath(path, relativeTo);
        return (texture != null) ? new Subtexture(texture) : null;
    }

    public function extractImageDataURL(): String
    {
        var canvas = Browser.document.createCanvasElement();
        canvas.width = width;
        canvas.height = height;

        var context = canvas.getContext2d();
        context.imageSmoothingEnabled = false;

        context.clearRect(0, 0, width, height);
        context.drawImage(texture.image, sourceX, sourceY, width, height, 0, 0, width, height);

        var dataURL = canvas.toDataURL("image/png");

        canvas.remove();

        return dataURL;
    }

    public function extractImage(): ImageElement
    {
        var dataURL = extractImageDataURL();

        var img = Browser.document.createImageElement();
        img.src = dataURL;

        return img;
    }
}

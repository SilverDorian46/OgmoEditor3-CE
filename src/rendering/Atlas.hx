package rendering;

import haxe.io.Path;
import js.Browser;
import util.IntRectangle;
import haxe.ds.ArraySort;
import js.html.ImageElement;

using StringTools;

typedef ImagePathDefinition = {
    var path: String;
    var img: ImageElement;
    var sourceRect: IntRectangle;
}

// multi-texture atlas
class Atlas
{
    public var textures: Array<Texture>;
    public var rootPath: String;

    public var subtextures: Map<String, Subtexture>;

    public function new(rootPath: String)
    {
        this.rootPath = rootPath;
        this.textures = [];
        this.subtextures = [];
    }

    public function get(path: String): Subtexture
    {
        path = Path.normalize(Path.withoutExtension(path));
        return subtextures[path];
    }

    /*public function getOrCreate(path: String): Subtexture
    {
        path = Path.normalize(Path.withoutExtension(path));
        var subtex = subtextures[path];
        return (subtex != null) ? subtex : Subtexture.fromRelativePath(path, rootPath);
    }*/

    public function getWithFullPath(path: String): Subtexture
    {
        path = Path.normalize(path);
        var subpath = Path.withoutExtension(js.node.Path.relative(rootPath, path));
        if (subpath.length > 0)
        {
            //var subtex = subtextures[subpath];
            //if (subtex != null) return subtex;
            return subtextures[subpath];
        }

        //return Subtexture.fromFile(path);
        return null;
    }

    public static function generate(imageMap: Map<String, ImageElement>, rootPath: String, width: Int, height: Int, into: Null<Atlas>, onReturn: Atlas -> Void): Void
    {
        // initialise new atlas if `into` hasn't been provided, otherwise reset the referenced atlas
        var atlas: Atlas;
        if (into == null) atlas = new Atlas(rootPath);
        else
        {
            atlas = into;
            atlas.rootPath = rootPath;
            while (atlas.textures.length > 0) atlas.textures.pop();
            atlas.subtextures.clear();
        }

        var isEmpty = true;

        // wait for all images to load
        for (_ => img in imageMap)
        {
            isEmpty = false;
            if (img.width <= 0)
            {
                img.onload = () -> generate(imageMap, rootPath, width, height, into, onReturn);
                return;
            }
        }

        // if empty, call onReturn early and do an early return - no images, nothing to process
        if (isEmpty)
        {
            onReturn(atlas);
            return;
        }

        // return if smaller than the margin - more on that further below
        if (width <= 2 || height <= 2) return;

        // initialise image path definitions
        var imageDefs: Array<ImagePathDefinition> = [];

        // ensure width and height constraints so that we won't potentially get stuck trying to fit a texture too big
        final maxWidth = width - 2;
        final maxHeight = height - 2;
        for (path => img in imageMap)
            if (img.width <= maxWidth && img.height <= maxHeight)
                imageDefs.push({ path: Path.normalize(path), img: img, sourceRect: new IntRectangle(0, 0, img.width, img.height) });

        // sort in descending height order
        // if height is the same, sort by width descending
        ArraySort.sort(imageDefs, function(a, b)
        {
            var compH = b.img.height - a.img.height;
            return (compH != 0) ? compH : b.img.width - a.img.width;
        });

        // initialise canvas and rendering context
        var canvas = Browser.document.createCanvasElement();
        canvas.width = width;
        canvas.height = height;

        var context = canvas.getContext2d();
        context.imageSmoothingEnabled = false;

        // initialise counter
        var count = imageDefs.length;
        var counter = 0;

        function recursiveGenerate(): Void
        {
            var generated: Array<ImagePathDefinition> = [];
            var pixelRect: IntRectangle = null;

            // introduce 1 px margin around the initial empty space
            // there will also be a 1 px gap between images in order to try to eliminate visual seams when drawing
            var emptySpace = [ new IntRectangle(1, 1, maxWidth, maxHeight) ];
            while (counter < count)
            {
                var imageRef: ImagePathDefinition = null;
                var imageIdx: Int = -1;
                for (emptyRect in emptySpace)
                {
                    for (i in 0...imageDefs.length)
                    {
                        var def = imageDefs[i];
                        if (emptyRect.canContainRect(def.sourceRect))
                        {
                            def.sourceRect.x = emptyRect.x;
                            def.sourceRect.y = emptyRect.y;
                            imageRef = def;
                            imageIdx = i;
                            break;
                        }
                    }
                    if (imageRef != null) break;
                }
                if (imageRef != null)
                {
                    // recalculate empty space, using a padded source rect
                    IntRectangle.subtractArray(imageRef.sourceRect.pad(1), emptySpace);
                    // sort in ascending y order
                    // if y is the same, sort by x ascending
                    ArraySort.sort(emptySpace, function(a, b)
                    {
                        var compY = a.y - b.y;
                        return (compY != 0) ? compY : a.x - b.x;
                    });

                    generated.push(imageRef);
                    imageDefs.splice(imageIdx, 1);

                    counter++;
                }
                else break; // can't fit any more images into this atlas
            }

            // TO-DO: could probably add some more checks to ensure there's always a pixel rect in the atlas texture
            for (emptyRect in emptySpace) if (emptyRect.width >= 3 && emptyRect.height >= 3)
            {
                pixelRect = new IntRectangle(emptyRect.x + 1, emptyRect.y + 1, 1, 1);
                break;
            }

            // clear and generate atlas image
            context.clearRect(0, 0, width, height);
            for (def in generated)
            {
                context.drawImage(def.img, def.sourceRect.x, def.sourceRect.y);
                // trace('generated: { path: ${def.path}, sourceRect: { ${def.sourceRect.x}, ${def.sourceRect.y}, ${def.sourceRect.width}, ${def.sourceRect.height} } }');
            }

            if (pixelRect != null)
            {
                context.fillStyle = "rgb(255, 255, 255)";
                context.fillRect(pixelRect.x - 1, pixelRect.y - 1, pixelRect.width + 2, pixelRect.height + 2);
                // trace('pixel rect at: { x: ${pixelRect.x - 1}, y: ${pixelRect.y - 1}, w: ${pixelRect.width + 2}, h: ${pixelRect.height + 2} }');
            }

            // - test: saving atlas -
            /*var savePath = FileSystem.chooseSaveFile("Level as image", [{ name: "Image", extensions: ["png"]}], "atlas.png");
            if (savePath.length > 0)
            {
                var nativeImage = js.Lib.require('electron').nativeImage;
                var saveImg = nativeImage.createFromDataURL(canvas.toDataURL("image/png"));
                js.node.Fs.writeFileSync(savePath, saveImg.toPNG());
            }*/

            /*var intersectCount = 0;
            for (i in 0...(generated.length - 1))
            {
                var current = generated[i];
                for (j in (i + 1)...generated.length)
                {
                    var next = generated[j];
                    if (current.sourceRect.intersects(next.sourceRect))
                    {
                        trace('Intersection found between ${current.path} and ${next.path}!');
                        intersectCount++;
                    }
                }
            }
            trace('Intersection count: $intersectCount');*/
            // - end test -

            Texture.loadFromData(canvas.toDataURL("image/png"), function(texture)
            {
                atlas.textures.push(texture);
                for (def in generated) atlas.subtextures.set(def.path, new Subtexture(texture, def.sourceRect));

                texture.pixelRect = pixelRect;

                // if there are still images, generate another atlas texture
                if (counter < count) recursiveGenerate();
                else
                {
                    canvas.remove();
                    onReturn(atlas);
                }
            });
        }

        recursiveGenerate();
    }

    public inline function dispose()
    {
        while (textures.length > 0) textures.pop().dispose();
        subtextures.clear();
    }
}

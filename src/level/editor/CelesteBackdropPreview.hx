package level.editor;

import rendering.Subtexture;
import js.html.ImageElement;
import rendering.Atlas;
import js.node.Path;
import level.data.Level;
import rendering.BlendState;
import rendering.Texture;

using StringTools;

typedef CelesteBackdropFadeSegment = {
    var positionFrom: Float;
    var positionTo: Float;
    var fadeFrom: Float;
    var fadeTo: Float;
}

class CelesteBackdropFader
{
    var segments: Array<CelesteBackdropFadeSegment> = [];

    inline function new() {}

    public static function parse(value: String): CelesteBackdropFader
    {
        // : separated list of positionFrom-positionTo,fadeFrom-fadeTo
        // where positionFrom and positionTo are integers, and fadeFrom and fadeTo are floats
        // n can be input before positionFrom and positionTo to indicate a negative number
        var fader = new CelesteBackdropFader();
        for (item in value.split(':'))
        {
            var args = item.split(',');
            if (args.length == 2)
            {
                var position = args[0].split('-');
                var fade = args[1].split('-');

                if (position.length >= 2 && fade.length >= 2)
                {
                    var positionFrom = position[0];
                    var positionTo = position[1];
                    var fadeFrom = fade[0];
                    var fadeTo = fade[1];

                    var signFrom: Int;
                    if (positionFrom.charAt(0) == 'n')
                    {
                        signFrom = -1;
                        positionFrom = positionFrom.substr(1);
                    }
                    else signFrom = 1;

                    var signTo: Int;
                    if (positionTo.charAt(0) == 'n')
                    {
                        signTo = -1;
                        positionTo = positionTo.substr(1);
                    }
                    else signTo = 1;

                    fader.add(signFrom * positionFrom.parseInt(), signTo * positionTo.parseInt(), fadeFrom.parseFloat(), fadeTo.parseFloat());
                }
            }
        }

        return fader;
    }

    public function add(positionFrom: Float, positionTo: Float, fadeFrom: Float, fadeTo: Float): Void
    {
        segments.push({
            positionFrom: positionFrom,
            positionTo: positionTo,
            fadeFrom: fadeFrom,
            fadeTo: fadeTo
        });
    }

    public function fadeValue(position: Float): Float
    {
        var result: Float = 1.0;
        for (s in segments) result *= Calc.clampMap(position, s.positionFrom, s.positionTo, s.fadeFrom, s.fadeTo);
        return result;
    }
}

abstract class CelesteBackdropLevelMatcher
{
    abstract function match(name: String): Bool;

    public static function matchList(matchers: Array<CelesteBackdropLevelMatcher>, name: String): Bool
    {
        for (matcher in matchers) if (matcher.match(name)) return true;
        return false;
    }
}

class CelesteBackdropLevelMatcherString extends CelesteBackdropLevelMatcher
{
    public var value: String;

    public function new(value: String) { this.value = value; }

    public function match(name: String): Bool { return name == value; }
}

class CelesteBackdropLevelMatcherRegex extends CelesteBackdropLevelMatcher
{
    public var regex: EReg;

    public function new (pattern: String) { this.regex = new EReg(pattern, "g"); }

    public function match(name: String): Bool { return regex.match(name); }
}

class CelesteBackdropData
{
    public var texture: Subtexture;
    public var position: Vector;
    public var scroll: Vector;
    public var speed: Vector;
    public var color: Color;
    public var loopx: Bool;
    public var loopy: Bool;
    public var flipx: Bool;
    public var flipy: Bool;
    public var exclude: Null<Array<CelesteBackdropLevelMatcher>>;
    public var only: Null<Array<CelesteBackdropLevelMatcher>>;
    public var fadex: Null<CelesteBackdropFader>;
    public var fadey: Null<CelesteBackdropFader>;
    public var blendmode: BlendState;

    //public var tempImg: ImageElement;
    //public var tempPath: String;

    inline function new() {}

    public static function loadList(data: Array<CelesteBackdropObjectData>): Array<CelesteBackdropData>
    {
        var backdrops: Array<CelesteBackdropData> = [];
        for (b in data)
        {
            if (b.apply != null)
            {
                for (child in b.apply) if (child.values != null)
                {
                    var parsed = parseValues(child.values, b.values);
                    if (parsed != null)
                        backdrops.push(parsed);
                }
            }
            else if (b.values != null)
            {
                var parsed = parseValues(b.values, null);
                if (parsed != null)
                    backdrops.push(parsed);
            }
        }

        return backdrops;
    }

    static function parseValues(data: CelesteBackdropValuesData, parent: Null<CelesteBackdropValuesData>): CelesteBackdropData
    {
        if (data.texture == null) return null;

        var backdrop = new CelesteBackdropData();
        //backdrop.texture = OGMO.project.atlas.getOrCreate(data.texture);
        backdrop.texture = OGMO.project.atlas.get(data.texture);

        var blendmode = data.blendmode;
        if (blendmode == null && parent != null) blendmode = parent.blendmode;
        backdrop.blendmode = (blendmode != null && blendmode.toLowerCase() == "additive") ? BlendState.additiveBlend : BlendState.alphaBlend;

        var x = data.x;
        if (x == null && parent != null) x = parent.x;
        var y = data.y;
        if (y == null && parent != null) y = parent.y;
        backdrop.position = new Vector((x != null) ? x : 0, (y != null) ? y : 0);

        var scrollx = data.scrollx;
        if (scrollx == null && parent != null) scrollx = parent.scrollx;
        var scrolly = data.scrolly;
        if (scrolly == null && parent != null) scrolly = parent.scrolly;
        backdrop.scroll = new Vector((scrollx != null) ? scrollx : 1, (scrolly != null) ? scrolly : 1);

        var speedx = data.speedx;
        if (speedx == null && parent != null) speedx = parent.speedx;
        var speedy = data.speedy;
        if (speedy == null && parent != null) speedy = parent.speedy;
        backdrop.speed = new Vector((speedx != null) ? speedx : 0, (speedy != null) ? speedy : 0);

        var color = data.color;
        if (color == null && parent != null) color = parent.color;
        backdrop.color = (color != null) ? Color.fromHex(color, 1) : Color.white.clone();

        var alpha = data.alpha;
        if (alpha == null && parent != null) alpha = parent.alpha;
        if (alpha != null) backdrop.color.x(alpha, backdrop.color);

        var flipx = data.flipx;
        if (flipx == null && parent != null) flipx = parent.flipx;
        backdrop.flipx = (flipx != null) ? flipx : false;

        var flipy = data.flipy;
        if (flipy == null && parent != null) flipy = parent.flipy;
        backdrop.flipy = (flipy != null) ? flipy : false;

        var loopx = data.loopx;
        if (loopx == null && parent != null) loopx = parent.loopx;
        backdrop.loopx = (loopx != null) ? loopx : true;

        var loopy = data.loopy;
        if (loopy == null && parent != null) loopy = parent.loopy;
        backdrop.loopy = (loopy != null) ? loopy : true;

        var exclude = data.exclude;
        if (exclude == null && parent != null) exclude = parent.exclude;
        if (exclude != null) backdrop.exclude = parseLevelMatchers(exclude);

        var only = data.only;
        if (only == null && parent != null) only = parent.only;
        if (only != null) backdrop.only = parseLevelMatchers(only);

        var fadex = data.fadex;
        if (fadex == null && parent != null) fadex = parent.fadex;
        if (fadex != null) backdrop.fadex = CelesteBackdropFader.parse(fadex);

        var fadey = data.fadey;
        if (fadey == null && parent != null) fadey = parent.fadey;
        if (fadey != null) backdrop.fadey = CelesteBackdropFader.parse(fadey);

        return backdrop;
    }

    static function parseLevelMatchers(list: String): Array<CelesteBackdropLevelMatcher>
    {
        var matchers: Array<CelesteBackdropLevelMatcher> = [];
        for (str in list.split(','))
        {
            if (str.contains('*'))
            {
                var pattern = "^" + EReg.escape(str).replace("\\*", ".*") + "$";
                matchers.push(new CelesteBackdropLevelMatcherRegex(pattern));
            }
            else matchers.push(new CelesteBackdropLevelMatcherString(str));
        }

        return matchers;
    }

    public function update(delta: Float): Bool
    {
        if (speed.x == 0 && speed.y == 0)
            return false;

        position.x += speed.x * delta;
        position.y += speed.y * delta;

        return true;
    }

    public function visible(level: Level): Bool
    {
        var name = level.displayNameNoExtNoLvl_;
        if (exclude != null && CelesteBackdropLevelMatcher.matchList(exclude, name)) return false;
        if (only != null && !CelesteBackdropLevelMatcher.matchList(only, name)) return false;
        return true;
    }
}

typedef CelesteBackdropValuesData = {
    var blendmode: String;
    var texture: String;
    var x: Float;
    var y: Float;
    var scrollx: Float;
    var scrolly: Float;
    var speedx: Float;
    var speedy: Float;
    var color: String;
    var alpha: Float;
    var flipx: Bool;
    var flipy: Bool;
    var loopx: Bool;
    var loopy: Bool;
    var exclude: String;
    var only: String;
    var fadex: String;
    var fadey: String;
    // TO-DO: set up flag variables and flag simulation
}

typedef CelesteBackdropObjectData = {
    var values: CelesteBackdropValuesData;
    var apply: Array<CelesteBackdropObjectData>;
}

typedef CelesteBackdropStyleData = {
    var color: String;
    var Backgrounds: Array<CelesteBackdropObjectData>;
    var Foregrounds: Array<CelesteBackdropObjectData>;
}

typedef CelesteBackdropStyleRootData = {
    var Style: CelesteBackdropStyleData;
}

class CelesteBackdropPreview
{
    public var color: Color;
    public var Backgrounds: Array<CelesteBackdropData>;
    public var Foregrounds: Array<CelesteBackdropData>;

    public var path: String;
    public var lastSavedData: String;

    public var externallyDeleted(get, null): Bool;
    function get_externallyDeleted():Bool
    {
        return path != null && !FileSystem.exists(path);
    }

    public var externallyModified(get, null): Bool;
    function get_externallyModified():Bool
    {
        return path != null && FileSystem.exists(path) && FileSystem.loadString(path) != lastSavedData;
    }

    inline function new() {}

    public static function loadFromPath(path: String): CelesteBackdropPreview
    {
        var dataString = FileSystem.loadString(path);
        var backdrops = load(FileSystem.stringToJSON(dataString));
        backdrops.path = path;
        backdrops.lastSavedData = dataString;

        return backdrops;
    }

    static function load(data: CelesteBackdropStyleRootData): CelesteBackdropPreview
    {
        if (data.Style == null) return null;
        var style = data.Style;

        var backdrops = new CelesteBackdropPreview();
        backdrops.color = (style.color != null) ? Color.fromHex(style.color, 1) : Color.black.clone();
        backdrops.Backgrounds = (style.Backgrounds != null) ? CelesteBackdropData.loadList(style.Backgrounds) : [];
        backdrops.Foregrounds = (style.Foregrounds != null) ? CelesteBackdropData.loadList(style.Foregrounds) : [];

        return backdrops;
    }

    public function update(delta: Float): Void
    {
        var dirty = false;
        for (bg in Backgrounds) if (bg.update(delta)) dirty = true;
        for (fg in Foregrounds) if (fg.update(delta)) dirty = true;

        if (dirty) EDITOR.dirty();
    }

    public static function draw(backdrops: Array<CelesteBackdropData>, level: Level): Void
    {
        if (backdrops.length <= 0) return;

        var zoom = EDITOR.camera.a;
        if (zoom == 0) return;

        var screenSize = OGMO.project.levelScreenSize;

        //var levelOffset = level.data.offset.clone();

		//var cameraCenter = new Vector((-EDITOR.camera.tx / zoom) + levelOffset.x, (-EDITOR.camera.ty / zoom) + levelOffset.y);
        var cameraCenter = new Vector(-EDITOR.camera.tx / zoom, -EDITOR.camera.ty / zoom);
        var cameraTopLeft = new Vector(cameraCenter.x - (screenSize.x / 2), cameraCenter.y - (screenSize.y / 2));

        var topLeft = EDITOR.getTopLeft();
        var bottomRight = EDITOR.getBottomRight();

        var prevBlendState = EDITOR.draw.getBlendState();
        try
        {
            for (b in backdrops)
            {
                if (!b.visible(level)) continue;
                if (b.texture == null) continue;

                EDITOR.draw.setBlendState(b.blendmode);

                var fade: Float = 1.0;
                if (b.fadex != null) fade *= b.fadex.fadeValue(cameraCenter.x);
                if (b.fadey != null) fade *= b.fadey.fadeValue(cameraCenter.y);

                var color = b.color.x(fade);
                if (color.a <= 0) continue;

                var drawAt = new Vector((b.position.x/* - levelOffset.x*/) - (cameraTopLeft.x * (b.scroll.x - 1)), (b.position.y/* - levelOffset.y*/) - (cameraTopLeft.y * (b.scroll.y - 1)));

                var width = b.texture.width;
                var height = b.texture.height;

                if (b.loopx)
                {
                    while (drawAt.x < topLeft.x) drawAt.x += width;
                    while (drawAt.x > topLeft.x) drawAt.x -= width;
                }
                if (b.loopy)
                {
                    while (drawAt.y < topLeft.y) drawAt.y += height;
                    while (drawAt.y > topLeft.y) drawAt.y -= height;
                }

                var origin = new Vector(0, 0);
                var scale = new Vector(1, 1);
                if (b.flipx)
                {
                    origin.x = width;
                    scale.x = -1;
                }
                if (b.flipy)
                {
                    origin.y = height;
                    scale.y = -1;
                }

                var atX = drawAt.x;
                while (atX < bottomRight.x)
                {
                    var atY = drawAt.y;
                    while (atY < bottomRight.y)
                    {
                        EDITOR.draw.drawSubtexture(atX, atY, b.texture, origin, scale, 0, null, null, null, null, color);
                        if (!b.loopy) break;
                        atY += height;
                    }
                    if (!b.loopx) break;
                    atX += width;
                }
            }
        }
        catch (e)
        {
            EDITOR.draw.setBlendState(prevBlendState);
            throw e;
        }

        EDITOR.draw.setBlendState(prevBlendState);
    }

    public function drawBackgroundColor(): Void
    {
        var topLeft = EDITOR.getTopLeft();
		var bottomRight = EDITOR.getBottomRight();
		EDITOR.draw.drawRect(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y, color);
    }
}

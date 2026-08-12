package modules.autotiler;

import util.Matrix;
import js.html.CanvasRenderingContext2D;
import js.html.CanvasElement;
import js.jquery.Event;
import js.Browser;
import util.RightClickMenu;
import util.ItemList;
import util.Fields;
import project.data.Tileset;

typedef AutotilerMaskTemplate =
{
    label: String,
    mask: Array<Int>,
    tiles: Array<Array<Int>>
}

class AutotilerMaskTemplateManager
{
    static inline final X: Int = -1;
    static inline final O: Int = 0;
    static inline final I: Int = 1;

    public static final maskPresets: Map<String, () -> Array<Int>> = [
        "Top Edge"             => function() { return [X,O,X,I,I,X,I,X]; },
        "Bottom Edge"          => function() { return [X,I,X,I,I,X,O,X]; },
        "Left Edge"            => function() { return [X,I,X,O,I,X,I,X]; },
        "Right Edge"           => function() { return [X,I,X,I,O,X,I,X]; },
        "Top Left Edge"        => function() { return [X,O,X,O,I,X,I,X]; },
        "Top Right Edge"       => function() { return [X,O,X,I,O,X,I,X]; },
        "Bottom Left Edge"     => function() { return [X,I,X,O,I,X,O,X]; },
        "Bottom Right Edge"    => function() { return [X,I,X,I,O,X,O,X]; },
        "Vertical"             => function() { return [X,I,X,O,O,X,I,X]; },
        "Vertical Top End"     => function() { return [X,O,X,O,O,X,I,X]; },
        "Vertical Bottom End"  => function() { return [X,I,X,O,O,X,O,X]; },
        "Horizontal"           => function() { return [X,O,X,I,I,X,O,X]; },
        "Horizontal Left End"  => function() { return [X,O,X,O,I,X,O,X]; },
        "Horizontal Right End" => function() { return [X,O,X,I,O,X,O,X]; },
        "Single Tile"          => function() { return [X,O,X,O,O,X,O,X]; },
        "Corner Bottom Right"  => function() { return [I,I,I,I,I,I,I,O]; },
        "Corner Top Right"     => function() { return [I,I,O,I,I,I,I,I]; },
        "Corner Bottom Left"   => function() { return [I,I,I,I,I,O,I,I]; },
        "Corner Top Left"      => function() { return [O,I,I,I,I,I,I,I]; },
        "Corner TR BR"         => function() { return [I,I,O,I,I,I,I,O]; },
        "Corner TL TR"         => function() { return [O,I,O,I,I,I,I,I]; },
        "Corner TL BL"         => function() { return [O,I,I,I,I,O,I,I]; },
        "Corner BL BR"         => function() { return [I,I,I,I,I,O,I,O]; },
        "Corner TR BL"         => function() { return [I,I,O,I,I,O,I,I]; },
        "Corner TL BR"         => function() { return [O,I,I,I,I,I,I,O]; },
        "Corner TL TR BR"      => function() { return [O,I,O,I,I,I,I,O]; },
        "Corner TL TR BL"      => function() { return [O,I,O,I,I,O,I,I]; },
        "Corner TL BL BR"      => function() { return [O,I,I,I,I,O,I,O]; },
        "Corner TR BL BR"      => function() { return [I,I,O,I,I,O,I,O]; },
        "Corner All"           => function() { return [O,I,O,I,I,O,I,O]; },
    ];

    public static final extendedMaskPresets: Map<String, () -> Array<Int>> = [
        "Top Edge"                 => function() { return [X,O,X,I,I,I,I,I]; },
        "Bottom Edge"              => function() { return [I,I,I,I,I,X,O,X]; },
        "Left Edge"                => function() { return [X,I,I,O,I,X,I,I]; },
        "Right Edge"               => function() { return [I,I,X,I,O,I,I,X]; },
        "Top Left Edge"            => function() { return [X,O,X,O,I,X,I,I]; },
        "Top Right Edge"           => function() { return [X,O,X,I,O,I,I,X]; },
        "Bottom Left Edge"         => function() { return [X,I,I,O,I,X,O,X]; },
        "Bottom Right Edge"        => function() { return [I,I,X,I,O,X,O,X]; },
        "Vertical"                 => function() { return [X,I,X,O,O,X,I,X]; },
        "Vertical Top End"         => function() { return [X,O,X,O,O,X,I,X]; },
        "Vertical Bottom End"      => function() { return [X,I,X,O,O,X,O,X]; },
        "Horizontal"               => function() { return [X,O,X,I,I,X,O,X]; },
        "Horizontal Left End"      => function() { return [X,O,X,O,I,X,O,X]; },
        "Horizontal Right End"     => function() { return [X,O,X,I,O,X,O,X]; },
        "Single Tile"              => function() { return [X,O,X,O,O,X,O,X]; },
        "Top Edge Corner BL"       => function() { return [X,O,X,I,I,O,I,I]; },
        "Top Edge Corner BR"       => function() { return [X,O,X,I,I,I,I,O]; },
        "Top Edge Corner BL BR"    => function() { return [X,O,X,I,I,O,I,O]; },
        "Bottom Edge Corner TL"    => function() { return [O,I,I,I,I,X,O,X]; },
        "Bottom Edge Corner TR"    => function() { return [I,I,O,I,I,X,O,X]; },
        "Bottom Edge Corner TL TR" => function() { return [O,I,O,I,I,X,O,X]; },
        "Left Edge Corner TR"      => function() { return [X,I,O,O,I,X,I,I]; },
        "Left Edge Corner BR"      => function() { return [X,I,I,O,I,X,I,O]; },
        "Left Edge Corner TR BR"   => function() { return [X,I,O,O,I,X,I,O]; },
        "Right Edge Corner TL"     => function() { return [O,I,X,I,O,I,I,X]; },
        "Right Edge Corner BL"     => function() { return [I,I,X,I,O,O,I,X]; },
        "Right Edge Corner TL BL"  => function() { return [O,I,X,I,O,O,I,X]; },
        "Top Left Edge Corner"     => function() { return [X,O,X,O,I,X,I,O]; },
        "Top Right Edge Corner"    => function() { return [X,O,X,I,O,O,I,X]; },
        "Bottom Left Edge Corner"  => function() { return [X,I,O,O,I,X,O,X]; },
        "Bottom Right Edge Corner" => function() { return [O,I,X,I,O,X,O,X]; },
        "Corner Bottom Right"      => function() { return [I,I,I,I,I,I,I,O]; },
        "Corner Top Right"         => function() { return [I,I,O,I,I,I,I,I]; },
        "Corner Bottom Left"       => function() { return [I,I,I,I,I,O,I,I]; },
        "Corner Top Left"          => function() { return [O,I,I,I,I,I,I,I]; },
        "Corner TR BR"             => function() { return [I,I,O,I,I,I,I,O]; },
        "Corner TL TR"             => function() { return [O,I,O,I,I,I,I,I]; },
        "Corner TL BL"             => function() { return [O,I,I,I,I,O,I,I]; },
        "Corner BL BR"             => function() { return [I,I,I,I,I,O,I,O]; },
        "Corner TR BL"             => function() { return [I,I,O,I,I,O,I,I]; },
        "Corner TL BR"             => function() { return [O,I,I,I,I,I,I,O]; },
        "Corner TL TR BR"          => function() { return [O,I,O,I,I,I,I,O]; },
        "Corner TL TR BL"          => function() { return [O,I,O,I,I,O,I,I]; },
        "Corner TL BL BR"          => function() { return [O,I,I,I,I,O,I,O]; },
        "Corner TR BL BR"          => function() { return [I,I,O,I,I,O,I,O]; },
        "Corner All"               => function() { return [O,I,O,I,I,O,I,O]; },
    ];

    public var element: JQuery;
    public var manager: JQuery;
    public var inspector: JQuery;

    public var buttons: JQuery;
    public var create: JQuery;

    public var maskPanel: JQuery;
    public var tilesetPanel: JQuery;

    public var list: JQuery;

    public var tileset: Tileset;

    public var canvas: CanvasElement;
    public var context: CanvasRenderingContext2D;
    public var spacing: Int = 1;
    public var matrix: Matrix;

    public var panningActive: Bool = false;
    public var panningOrigin: Vector;

    public var selectionActive: Bool = false;
    public var selectionStartTile: Array<Int> = null;
    public var selectionEndTile: Array<Int> = null;
    public var selectionRemoving: Bool = false;

    public var inspectingMaskIndex: Int;

    public var padding2D: Array<Array<Int>> = [];
    public var center2D: Array<Array<Int>> = [];
    public var masks2D: Array<AutotilerMaskTemplate> = [];

    public var currentTiles2D: Array<Array<Int>>;

    public var tileColumns: Int;
    public var tileRows: Int;

    public function new(into: JQuery)
    {
        // containing element
        element = new JQuery('<div class="valuetemplates" style="height: 600px;">');
        into.append(element);

        // manager & inspector
        manager = new JQuery('<div class="valuetemplates_manager">');
        element.append(manager);

        inspector = new JQuery('<div class="valuetemplates_inspector">');
        element.append(inspector);

        // manager containers for buttons and list
        buttons = new JQuery('<div class="valuetemplates_buttons">');
        manager.append(buttons);

        list = new JQuery('<div class="valuetemplates_list">');
        manager.append(list);

        // manager create mask button
        create = Fields.createButton("plus", "New Mask", buttons);
        create.on("click", function()
        {
            if (tileset == null)
                return;

            var newMask: AutotilerMaskTemplate = {
                label: "Custom",
                mask: [X,X,X,X,X,X,X,X],
                tiles: []
            }
            var len = masks2D.push(newMask);
            inspectMask(len - 1);
            refreshList();
        });
        create.prop("disabled", true);

        // initial matrix for tileset panel
        matrix = new Matrix();
        matrix.setScale(2, 2);
    }

    public function inspectTileset(definition: AutotilerDefinition, tileset: Tileset, ?saveOnChange: Bool): Void
    {
        if (saveOnChange == null || saveOnChange) save(definition);

        this.tileset = tileset;
        inspector.empty();
        list.empty();

        maskPanel = new JQuery('<div style="float: left; box-sizing: border-box; padding: 16px; width: 180px;">');
        inspector.append(maskPanel);

        tilesetPanel = new JQuery('<div style="float: left; width: 50%; height: 100%;">');
        inspector.append(tilesetPanel);

        if (tileset == null)
        {
            create.prop("disabled", true);
            inspectMask(-3);
            return;
        }

        create.prop("disabled", false);

        tileColumns = tileset.tileColumns;
        tileRows = tileset.tileRows;

        createTilePalette();

        padding2D = [];
        for (i in definition.padding) AutotilerMask.tryPushTileXY(padding2D, i, tileColumns, tileRows);
        sortTiles2D(padding2D);

        center2D = [];
        for (i in definition.center) AutotilerMask.tryPushTileXY(center2D, i, tileColumns, tileRows);
        sortTiles2D(center2D);

        masks2D = [];
        for (mask in definition.masks)
        {
            var mask2D: AutotilerMaskTemplate = {
                label: mask.label,
                mask: [],
                tiles: []
            };
            for (value in mask.mask) mask2D.mask.push(value);
            for (i in mask.tiles) AutotilerMask.tryPushTileXY(mask2D.tiles, i, tileColumns, tileRows);
            sortTiles2D(mask2D.tiles);
            masks2D.push(mask2D);
        }

        inspectMask(-3);
        refreshList();
    }

    // <= -3: none;  -2: padding;  -1: center;  >= 0: mask
    function inspectMask(maskIndex: Int): Void
    {
        maskPanel.empty();
        inspectingMaskIndex = maskIndex;

        if (maskIndex <= -3 || maskIndex >= masks2D.length)
        {
            currentTiles2D = null;
            refreshTilePalette();
            return;
        }

        var mask = (maskIndex >= 0) ? masks2D[maskIndex] : null;
        var label: String;
        var tiles2D: Array<Array<Int>>;
        if (mask != null)
        {
            label = mask.label;
            tiles2D = mask.tiles;
        }
        else if (maskIndex == -1)
        {
            label = "Center";
            tiles2D = center2D;
        }
        else
        {
            label = "Padding";
            tiles2D = padding2D;
        }

        var labelField = Fields.createField("Label", label);
        Fields.createSettingsBlock(maskPanel, labelField, SettingsBlock.Full, "Label", SettingsBlock.OverTitle);

        Fields.createLineBreak();

        if (mask != null)
        {
            labelField.on("input change", function()
            {
                mask.label = Fields.getField(labelField);
                refreshList();
            });

            function createMaskValueButton(i: Int): Void
            {
                function updateBackground(valueButton: JQuery, valueStr: String): Void
                {
                    var colorArgs = (valueStr == "0") ? "#aff, #a0c0f0" : (valueStr == "1") ? "#ea8, #e08070" : "#fdf, #d0c0f0";
                    valueButton.css("background", "linear-gradient(" + colorArgs + ")");
                }

                var valueStr = AutotilerMask.maskValueToString(mask.mask, i);
                var valueButton = Fields.createButton(null, valueStr);
                updateBackground(valueButton, valueStr);
                valueButton.on("click", function()
                {
                    var currentValue = mask.mask[i];
                    var nextValue = (currentValue < O) ? O : (currentValue == O) ? I : X;
                    mask.mask[i] = nextValue;
                    var nextStr = AutotilerMask.maskValueToString(mask.mask, i);
                    Fields.setButtonLabel(valueButton, AutotilerMask.maskValueToString(mask.mask, i));
                    updateBackground(valueButton, nextStr);
                });
                Fields.createSettingsBlock(maskPanel, valueButton, SettingsBlock.Third);
            }

            function createMaskCenterButton(): Void
            {
                var valueButton = Fields.createButton(null, "1");
                valueButton.css("background", "linear-gradient(#a87, #a06050)");
                valueButton.prop("disabled", true);
                Fields.createSettingsBlock(maskPanel, valueButton, SettingsBlock.Third);
            }

            for (i in 0...4) createMaskValueButton(i);
            createMaskCenterButton();
            for (i in 4...8) createMaskValueButton(i);
        }
        else labelField.prop("disabled", true);

        currentTiles2D = tiles2D;
        refreshTilePalette();
    }

    function createTilePalette(): Void
    {
        canvas = Browser.document.createCanvasElement();
        context = canvas.getContext2d();
        tilesetPanel.append(canvas);

        var intervalID: Int = 0;
        var mouseDown = false;
        new JQuery(canvas).on("mousedown", function(e:Event)
        {
            mouseDown = true;
            onTilePaletteMouseDown(e);
            intervalID = Browser.window.setInterval(function() { onTilePaletteMouseMove(null); }, 50);
        });

        new JQuery(Browser.window).on("mouseup", function(e:Event)
        {
            if (mouseDown)
            {
                mouseDown = false;
                onTilePaletteMouseUp(e);
                Browser.window.clearInterval(intervalID);
            }
        });

        new JQuery(canvas).on("mousewheel", function(e:Event) { onTilePaletteMouseWheel(e); });
    }

    public function getMouse(e:Event):Vector
    {
        var m:Vector = (e != null) ? new Vector(e.clientX, e.clientY) : OGMO.mouse;
        return new Vector(m.x - canvas.getBoundingClientRect().left, m.y - canvas.getBoundingClientRect().top);
    }

    public function getMouseTile(e: Event): Array<Int>
    {
        return getMouseTileFromMouse(getMouse(e));
    }

    public function getMouseTileFromMouse(mouse: Vector): Array<Int>
    {
        var tWidth = tileset.tileWidth + spacing;
        var tHeight = tileset.tileHeight + spacing;
        var m = matrix.inverseTransformPoint(mouse);
        return [Math.floor(m.x / tWidth), Math.floor(m.y / tHeight)];
    }

    public function getSelectedTiles(start: Array<Int>, end: Array<Int>): Array<Array<Int>>
    {
        var minX = Calc.clampInt(Calc.minInt(start[0], end[0]), 0, tileColumns - 1);
        var minY = Calc.clampInt(Calc.minInt(start[1], end[1]), 0, tileRows - 1);
        var maxX = Calc.clampInt(Calc.maxInt(start[0], end[0]), 0, tileColumns - 1) + 1;
        var maxY = Calc.clampInt(Calc.maxInt(start[1], end[1]), 0, tileRows - 1) + 1;

        var sel2D: Array<Array<Int>> = [];
        for (x in minX...maxX) for (y in minY...maxY) sel2D.push([x, y]);

        return sel2D;
    }

    function onTilePaletteMouseDown(e: Event): Void
    {
        if (OGMO.keyCheckMap[Keys.Space] || e.which == Keys.MouseMiddle)
        {
            panningActive = true;
            panningOrigin = getMouse(e);
        }
        else
        {
            selectionActive = true;
            selectionRemoving = e.which == Keys.MouseRight;
            selectionEndTile = selectionStartTile = getMouseTile(e);
            refreshTilePalette();
        }
    }

    function onTilePaletteMouseMove(e: Event): Void
    {
        var mouse = getMouse(e);

        if (selectionActive)
        {
            selectionEndTile = getMouseTileFromMouse(mouse);

            var step = 32;

            if (mouse.x > canvas.width - 16) matrix.translate(-step, 0);
            else if (mouse.x < 16) matrix.translate(step, 0);

            if (mouse.y > canvas.height - 16) matrix.translate(0, -step);
            else if (mouse.y < 16) matrix.translate(0, step);
        }
        else if (panningActive)
        {
            matrix.translate(mouse.x - panningOrigin.x, mouse.y - panningOrigin.y);
            panningOrigin = mouse;
        }

        clampTilePaletteCamera();
        refreshTilePalette();
    }

    function onTilePaletteMouseUp(e: Event): Void
    {
        if (tileset == null)
        {
            selectionActive = false;
            panningActive = false;
            return;
        }

        if (selectionActive)
        {
            selectionActive = false;
            selectionEndTile = getMouseTile(e);

            var sel2D = getSelectedTiles(selectionStartTile, selectionEndTile);
            if (selectionRemoving) for (sel in sel2D)
            {
                var matchIndex: Int = -1;
                for (i in 0...currentTiles2D.length)
                {
                    var current = currentTiles2D[i];
                    if (current[0] != sel[0] || current[1] != sel[1]) continue;
                    matchIndex = i;
                    break;
                }
                if (matchIndex >= 0) currentTiles2D.splice(matchIndex, 1);
            }
            else for (sel in sel2D)
            {
                var matched: Bool = false;
                for (current in currentTiles2D)
                {
                    if (current[0] != sel[0] || current[1] != sel[1]) continue;
                    matched = true;
                    break;
                }
                if (!matched) currentTiles2D.push(sel);
            }

            sortTiles2D(currentTiles2D);
        }

        panningActive = false;

        refreshTilePalette();
    }

    function onTilePaletteMouseWheel(e: Event): Void
    {
        var mouse = getMouse(e);
        // no idea which class the `originalEvent` field comes from, so cast to Dynamic
        var scroll: Int = (cast e : Dynamic).originalEvent.wheelDelta;

        var move = (scroll > 0 ? 1 : -1) * 0.25;

        matrix.translate(-mouse.x, -mouse.y);
        matrix.scale(1 + move, 1 + move);
        matrix.translate(mouse.x, mouse.y);

        clampTilePaletteCamera();
        refreshTilePalette();
    }

    function clampTilePaletteCamera(): Void
    {
        var m = new Matrix().scale(matrix.a, matrix.b);

        var vw = canvas.width;
        var vh = canvas.height;
        var tw = m.transformPoint(new Vector(tileColumns * (tileset.tileWidth + spacing), 0)).x;
        var th = m.transformPoint(new Vector(0, tileRows * (tileset.tileHeight + spacing))).y;

        matrix.tx = Math.min(8, Math.max(- (tw - vw) - 8, matrix.tx));
        matrix.ty = Math.min(8, Math.max(- (th - vh) - 8, matrix.ty));
    }

    function refreshTilePalette(): Void
    {
        if (canvas == null)
            return;

        // setup canvas dimensions
        canvas.width = tilesetPanel.width().floor() - 4;
        canvas.height = tilesetPanel.height().floor() - 40;
        canvas.style.width = canvas.width + "px";
        canvas.style.height = canvas.height + "px";

        if (context == null)
            return;

        // clear
        context.setTransform(0, 0, 0, 0, 0, 0);
        context.clearRect(0, 0, canvas.width, canvas.height);
        context.setTransform(matrix.a, matrix.b, matrix.c, matrix.d, matrix.tx, matrix.ty);
        context.imageSmoothingEnabled = false;

        if (tileset == null)
            return;

        var subtexture = tileset.texture;
        var image = subtexture.texture.image;
        if (image.width <= 0)
        {
            image.addEventListener("load", function (e) { refreshTilePalette(); }, { once: true });
            return;
        }

        // fill with a background colour
        context.fillStyle = "rgb(220, 220, 220)";
        context.fillRect(0, 0, canvas.width, canvas.height);

        var drawRectWidth = tileset.tileWidth + spacing;
        var drawRectHeight = tileset.tileHeight + spacing;

        // draw tiles, including transparent bg
        context.fillStyle = "rgb(200, 200, 200)";
        var tx = subtexture.sourceX + tileset.tileSeparationX + tileset.tileMarginX;
        var x = 0;
        while (tx < subtexture.sourceRect.right - tileset.tileMarginX)
        {
            var ty = subtexture.sourceY + tileset.tileSeparationY + tileset.tileMarginY;
            var y = 0;
            while (ty < subtexture.sourceRect.bottom - tileset.tileMarginY)
            {
                var drawX = x * drawRectWidth;
                var drawY = y * drawRectHeight;

                context.fillRect(drawX - spacing / 2, drawY - spacing / 2, drawRectWidth / 2, drawRectHeight / 2);
                context.fillRect(drawX + tileset.tileWidth / 2, drawY + tileset.tileHeight / 2, drawRectWidth / 2, drawRectHeight / 2);
                context.drawImage(image, tx, ty, tileset.tileWidth, tileset.tileHeight, drawX, drawY, tileset.tileWidth, tileset.tileHeight);

                ty += tileset.tileHeight + tileset.tileSeparationY;
                y++;
            }
            tx += tileset.tileWidth + tileset.tileSeparationX;
            x++;
        }

        // draw active tiles in current mask
        if (currentTiles2D != null)
        {
            context.fillStyle = "rgba(255,240,40,0.25)";
            context.strokeStyle = "rgba(255,240,40,1)";
            for (xy in currentTiles2D)
            {
                var rectX = xy[0] * drawRectWidth - spacing / 2;
                var rectY = xy[1] * drawRectHeight - spacing / 2;
                context.fillRect(rectX, rectY, drawRectWidth, drawRectHeight);
                context.strokeRect(rectX, rectY, drawRectWidth, drawRectHeight);
            }
        }

        // draw tile selection if any
        var sel2D: Array<Array<Int>> = (selectionActive) ? getSelectedTiles(selectionStartTile, selectionEndTile) : null;
        if (sel2D != null)
        {
            if (selectionRemoving)
            {
                context.fillStyle = "rgba(255,0,40,0.25)";
                context.strokeStyle = "rgba(255,0,40,1)";
            }
            else
            {
                context.fillStyle = "rgba(0,255,40,0.25)";
                context.strokeStyle = "rgba(0,255,40,1)";
            }

            for (xy in sel2D)
            {
                var rectX = xy[0] * drawRectWidth - spacing / 2;
                var rectY = xy[1] * drawRectHeight - spacing / 2;
                context.fillRect(rectX, rectY, drawRectWidth, drawRectHeight);
                context.strokeRect(rectX, rectY, drawRectWidth, drawRectHeight);
            }
        }
    }

    function sortTiles2D(tiles2D: Array<Array<Int>>): Void
    {
        tiles2D.sort(function (xy, zw)
        {
            var yComp = xy[1] - zw[1];
            return (yComp == 0) ? xy[0] - zw[0] : yComp;
        });
    }

    public function refreshList(): Void
    {
        list.empty();

        var itemList = new ItemList(list);
        for (i in -2...masks2D.length) // -2: padding; -1: center; >= 0: mask
        {
            var mask = (i >= 0) ? masks2D[i] : null;
            var label: String;
            var canRightClick: Bool;
            if (mask != null)
            {
                label = mask.label;
                canRightClick = true;
            }
            else
            {
                label = (i == -1) ? "Center" : "Padding";
                canRightClick = false;
            }
            var item = itemList.add(new ItemListItem(label, i));
            item.setKylesetIcon("layer-tiles");

            if (inspectingMaskIndex == i) item.selected = true;

            item.onclick = function(current)
            {
                inspectMask(current.data);
                refreshList();
            }

            if (canRightClick)
            {
                item.onrightclick = function(current)
                {
                    var menu = new RightClickMenu(OGMO.mouse);
                    menu.onClosed(function() { current.highlighted = false; });

                    menu.addOption("Delete", "trash", function()
                    {
                        Popup.open("Delete", "trash", "Permanently delete mask <span class='monospace'>" + label + "</span>?", ["Delete", "Cancel"], function(btn)
                        {
                            if (btn == 0)
                            {
                                var currentIndex: Int = cast current.data;
                                if (currentIndex >= 0) masks2D.splice(currentIndex, 1);
                                if (inspectingMaskIndex == currentIndex) inspectMask(-3);
                                refreshList();
                            }
                        });
                    });

                    current.highlighted = true;
                    menu.open();
                }
            }
        }
    }

    public function save(definition: AutotilerDefinition): Void
    {
        if (tileset == null)
            return;

        definition.tileColumns = tileColumns;
        definition.tileRows = tileRows;

        definition.padding = [];
        for (xy in padding2D) definition.padding.push(AutotilerMask.coordsArrayToID(xy, tileColumns, tileRows));

        definition.center = [];
        for (xy in center2D) definition.center.push(AutotilerMask.coordsArrayToID(xy, tileColumns, tileRows));

        definition.masks = [];
        for (mask2D in masks2D)
        {
            var mask = new AutotilerMask();
            mask.label = mask2D.label;
            for (value in mask2D.mask) mask.mask.push(value);
            for (xy in mask2D.tiles) mask.tiles.push(AutotilerMask.coordsArrayToID(xy, tileColumns, tileRows));
            definition.masks.push(mask);
        }
    }
}

package modules.autotiler;

import js.lib.Object;
import haxe.ds.Either;

using StringTools;

class AutotilerMask
{
    public static inline final ANY: Int = -1; // x
    public static inline final EMPTY: Int = 0; // 0
    public static inline final SOLID: Int = 1; // 1

    public var label: String;

    // 0 1 2
    // 3   4
    // 5 6 7
    public var mask: Array<Int> = [];
    public var tiles: Array<Int> = [];

    public function new() {}

    public function clone(): AutotilerMask
    {
        var copy = new AutotilerMask();

        copy.label = label;

        for (value in mask)
            copy.mask.push(value);

        for (tile in tiles)
            copy.tiles.push(tile);

        return copy;
    }

    public static function loadList(list: Array<Dynamic>): Array<AutotilerMask>
    {
        var masks: Array<AutotilerMask> = [];
        for (data in list)
        {
            var m = new AutotilerMask();
            m.label = data.label;
            m.mask = loadMask(Imports.string(data.mask, "xxx-x1x-xxx"));
            if (data.tiles != null) m.tiles = data.tiles;
            masks.push(m);
        }
        return masks;
    }

    public static function loadList2D(list: Array<Dynamic>, tileColumns: Int, tileRows: Int): Array<AutotilerMask>
    {
        var masks: Array<AutotilerMask> = [];
        for (data in list)
        {
            var m = new AutotilerMask();
            m.label = data.label;
            m.mask = loadMask(Imports.string(data.mask, "xxx-x1x-xxx"));
            if (data.tiles != null) m.tiles = importTilesFrom2D(data.tiles, tileColumns, tileRows);
            masks.push(m);
        }
        return masks;
    }

    public static function loadMask(str: String): Array<Int>
    {
        function parse(char: String): Int { return (char == "0") ? 0 : (char == "1") ? 1 : -1; }

        str = str.trim();
        var mask: Array<Int> = [];

        var center = false;
        for (i in 0...str.length)
        {
            if (!center && mask.length == 4) // the center of the mask is always 1
            {
                center = true;
                continue;
            }

            var char = str.charAt(i);
            if (char == "-")
                continue;

            mask.push(parse(char));
            if (mask.length >= 8)
                break;
        }

        while (mask.length < 8) // fill with -1 if there's not enough values
            mask.push(-1);

        return mask;
    }

    public static function importTilesFrom2D(coords: Array<Array<Int>>, tileColumns: Int, tileRows: Int): Array<Int>
    {
        var tiles: Array<Int> = [];
        for (c in coords)
        {
            if (c.length < 2)
                continue;

            var id = coordsToID(c[0], c[1], tileColumns, tileRows);
            if (id >= 0) tiles.push(id);
        }
        return tiles;
    }

    public static function saveList(list: Array<AutotilerMask>): Array<Dynamic>
    {
        var data: Array<Dynamic> = [];
        for (m in list) data.push({
            label: m.label,
            mask: saveMask(m.mask),
            tiles: m.tiles
        });
        return data;
    }

    public static function saveList2D(list: Array<AutotilerMask>,  tileColumns: Int, tileRows: Int): Array<Dynamic>
    {
        var data: Array<Dynamic> = [];
        for (m in list) data.push({
            label: m.label,
            mask: saveMask(m.mask),
            tiles: getTiles2D(m.tiles, tileColumns, tileRows)
        });
        return data;
    }

    public static function saveMask(mask: Array<Int>): String
    {
        inline function parse(at: Int): String { return maskValueToString(mask, at); }

        return parse(0) + parse(1) + parse(2) + "-" + parse(3) + "1" + parse(4) + "-" + parse(5) + parse(6) + parse(7);
    }

    public static function maskValueToString(mask: Array<Int>, at: Int): String
    {
        var value = mask[at];
        return (value == null || value < 0) ? "x" : (value > 0) ? "1" : "0";
    }

    public static function getTiles2D(tiles: Array<Int>,  tileColumns: Int, tileRows: Int): Array<Array<Int>>
    {
        var tiles2D: Array<Array<Int>> = [];
        for (i in tiles)
        {
            var xy = getTileXY(i, tileColumns, tileRows);
            if (xy != null) tiles2D.push(xy);
        }
        return tiles2D;
    }

    // from Tileset.coordsToID. returns -1 if outside the tileset
    public static function coordsToID(x: Int, y: Int, tileColumns: Int, tileRows: Int): Int
    {
        return (x < tileColumns && y < tileRows) ? x + y * tileColumns : -1;
    }

    public static function coordsArrayToID(xy: Array<Int>, tileColumns: Int, tileRows: Int): Int
    {
        return coordsToID(xy[0], xy[1], tileColumns, tileRows);
    }

    // from Tileset.getTileX and Tileset.getTileY. returns null if outside the tileset
    public static function getTileXY(i: Int, tileColumns: Int, tileRows: Int): Array<Int>
    {
        var y = Math.floor(i / tileColumns);
        return (y < tileRows) ? [i % tileColumns, y] : null;
    }

    public static function tryPushTileXY(into: Array<Array<Int>>, i: Int, tileColumns: Int, tileRows: Int): Void
    {
        var xy = AutotilerMask.getTileXY(i, tileColumns, tileRows);
        if (xy != null) into.push(xy);
    }
}

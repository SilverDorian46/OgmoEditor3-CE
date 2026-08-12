package modules.autotiler;

import modules.tiles.TileLayer.TileData;
import modules.grid.GridLayerTemplate;
import level.data.Level;
import project.data.Tileset;
import util.Random;

using StringTools;

class GeneratedTileDef
{
    public var tileset: Tileset;
    public var data: TileData;

    public function new(tileset: Tileset, index: Int)
    {
        this.tileset = tileset;
        data = new TileData(index);
    }
}

class Autotiler
{
    public var definitions: Map<String, AutotilerDefinition>;
    public var tilesets: Map<String, Tileset>;
    public var ignores: Map<String, Array<String>>;
    public var empty: String;

    public var random: Random = new Random();

    public function new(template: GridLayerTemplate)
    {
        definitions = new Map();
        for (key => auto in template.autotilings)
        {
            var def = OGMO.project.getAutotilerDefinition(auto);
            if (def != null) definitions.set(key, def);
        }

        tilesets = new Map();
        for (key => def in definitions)
        {
            var tileset = OGMO.project.getTilesetStrict(def.tileset);
            if (tileset != null) tilesets.set(key, tileset);
        }

        // To-do: set up ignored definitions
        ignores = new Map();

        empty = template.transparent;
    }

    public function seedForLevel(level: Level): Void
    {
        var value = 0;
        var name = level.displayNameNoExtension;
        for (i in 0...name.length)
            value += name.fastCodeAt(i);

        random.state = value;
    }

    public function generate(data: Array<Array<String>>, width: Int, height: Int): Array<Array<GeneratedTileDef>>
    {
        var hasDefinitions = false;
        for (_ in definitions.keys())
        {
            hasDefinitions = true;
            break;
        }
        if (!hasDefinitions) return [];

        function clampX(x: Int): Int { return Calc.clampInt(x, 0, width - 1); }
        function clampY(y: Int): Int { return Calc.clampInt(y, 0, height - 1); }

        function getMaskTiles(masks: Array<AutotilerMask>, adjacent: Array<Bool>): Array<Int>
        {
            for (m in masks)
            {
                var check = true;
                for (i in 0...m.mask.length)
                {
                    var value = m.mask[i];
                    if (value < 0) // x
                        continue;

                    if (adjacent[i] != (value > 0))
                    {
                        check = false;
                        break;
                    }
                }

                if (check)
                    return m.tiles;
            }

            return null;
        }

        function getTileSafe(data: Array<Array<String>>, x: Int, y: Int): String
        {
            var tileX = data[x];
            return (tileX != null) ? tileX[y] : null;
        }

        var generated: Array<Array<GeneratedTileDef>> = [];

        // 0 1 2
        // 3   4
        // 5 6 7
        var adjacent: Array<Bool> = [];
        for (x in 0...data.length) for (y in 0...data[x].length)
        {
            var tile = data[x][y];
            if (isEmpty(tile))
                continue;

            var definition = definitions.get(tile);
            var tileset = tilesets.get(tile);
            if (definition == null || tileset == null)
                continue;

            var adjIndex = 0;
            var surrounded = true;
            for (j in -1...2) for (i in -1...2)
            {
                if (i == 0 && j == 0)
                    continue;

                var checkX = clampX(x + i);
                var checkY = clampY(y + j);

                var flag = !isEmptyOrIgnored(tile, getTileSafe(data, checkX, checkY));
                if (!flag)
                    surrounded = false;

                adjacent[adjIndex++] = flag;
            }

            var maskTiles: Array<Int>;
            if (surrounded)
            {
                if (!isEmptyOrIgnored(tile, getTileSafe(data, clampX(x - 2), y)) && !isEmptyOrIgnored(tile, getTileSafe(data, clampX(x + 2), y)) && !isEmptyOrIgnored(tile, getTileSafe(data, x, clampY(y - 2))) && !isEmptyOrIgnored(tile, getTileSafe(data, x, clampY(y + 2))))
                    maskTiles = definition.center;
                else
                    maskTiles = definition.padding;
            }
            else maskTiles = getMaskTiles(definition.masks, adjacent);

            if (maskTiles == null || maskTiles.length <= 0)
                continue;

            if (generated[x] == null) generated[x] = [];
            generated[x][y] = new GeneratedTileDef(tileset, random.nextChoice(maskTiles));
        }

        return generated;
    }

    public function generateBlock(tiletype: String, width: Int, height: Int): Array<Array<GeneratedTileDef>>
    {
        var data: Array<Array<String>> = [];
        var arrayWidth = width + 2;
        var arrayHeight = height + 2;

        for (x in 0...arrayWidth)
        {
            var dataX = [];
            if (x <= 0 || x >= arrayWidth - 1)
                for (_ in 0...arrayHeight)
                    dataX.push(empty);
            else
                for (y in 0...arrayHeight)
                    dataX.push((y <= 0 || y >= arrayHeight - 1) ? empty : tiletype);

            data[x] = dataX;
        }

        return generate(data, arrayWidth, arrayHeight);
    }

    function isEmpty(tile: String): Bool
    {
        return tile == null || tile == empty;
    }

    function isEmptyOrIgnored(tile: String, targetTile: String): Bool
    {
        if (targetTile == null || targetTile == empty)
            return true;

        var ignoredTiles = ignores.get(tile);
        return ignoredTiles != null && ignoredTiles.contains(targetTile);
    }
}

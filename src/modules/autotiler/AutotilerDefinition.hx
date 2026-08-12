package modules.autotiler;

import project.data.Tileset;
import project.data.Project;

class AutotilerDefinition
{
    public var label: String;
    public var tileset: String;

    public var padding: Array<Int> = [];
    public var center: Array<Int> = [];

    public var masks: Array<AutotilerMask> = [];

    public var exportMode = TileExportModes.IDS;
    public var tileColumns: Int = 1;
    public var tileRows: Int = 1;

    inline function new() {}

    public static function create(label: String, tileset: Tileset): AutotilerDefinition
    {
        var def = new AutotilerDefinition();

        def.label = label;
        def.tileset = tileset.label;
        def.tileColumns = tileset.tileColumns;
        def.tileRows = tileset.tileRows;

        return def;
    }

    /*public function setTileset(tilesetObj: Tileset, updateTiles: Bool): Void
    {
        tileset = tilesetObj.label;

        var nextTileColumns = tilesetObj.tileColumns;
        var nextTileRows = tilesetObj.tileRows;
        if (updateTiles && (tileColumns != nextTileColumns || tileRows != nextTileRows))
        {
            var padding2D: Array<Array<Int>> = [];
            for (i in padding) AutotilerMask.tryPushTileXY(padding2D, i, tileColumns, tileRows);

            var center2D: Array<Array<Int>> = [];
            for (i in center) AutotilerMask.tryPushTileXY(center2D, i, tileColumns, tileRows);

            var tiles2D: Array<Array<Array<Int>>> = [];
            for (m in masks)
            {
                var t: Array<Array<Int>> = [];
                for (i in m.tiles) AutotilerMask.tryPushTileXY(t, i, tileColumns, tileRows);
                tiles2D.push(t);
            }

            tileColumns = nextTileColumns;
            tileRows = nextTileRows;

            padding = [];
            for (p in padding2D) padding.push(AutotilerMask.coordsArrayToID(p, tileColumns, tileRows));

            center = [];
            for (c in center2D) center.push(AutotilerMask.coordsArrayToID(c, tileColumns, tileRows));

            for (i in 0...tiles2D.length)
            {
                var tile2D = tiles2D[i];
                var mask = masks[i];
                mask.tiles = [];
                for (t in tile2D) mask.tiles.push(AutotilerMask.coordsArrayToID(t, tileColumns, tileRows));
            }
        }
        else
        {
            tileColumns = nextTileColumns;
            tileRows = nextTileRows;
        }
    }*/

    public static function clone(self: AutotilerDefinition): AutotilerDefinition
    {
        var copy = new AutotilerDefinition();

        copy.label = self.label + "_copy";
        copy.tileset = self.tileset;

        for (tile in self.padding)
            copy.padding.push(tile);

        for (tile in self.center)
            copy.center.push(tile);

        for (mask in self.masks)
            copy.masks.push(mask.clone());

        copy.exportMode = self.exportMode;
        copy.tileColumns = self.tileColumns;
        copy.tileRows = self.tileRows;

        return copy;
    }

    public static function load(project: Project, data: Dynamic): AutotilerDefinition
    {
        var def = new AutotilerDefinition();

        def.label = data.label;
        def.tileset = data.tileset;
        def.exportMode = Imports.integer(data.exportMode, TileExportModes.IDS);

        var tilesetObj = project.getTilesetStrict(def.tileset);
        var fallbackColumns: Int;
        var fallbackRows: Int;
        if (tilesetObj != null)
        {
            fallbackColumns = tilesetObj.tileColumns;
            fallbackRows = tilesetObj.tileRows;
        }
        else
        {
            fallbackColumns = 0;
            fallbackRows = 0;
        }

        def.tileColumns = Imports.integer(data.tileColumns, fallbackColumns);
        def.tileRows = Imports.integer(data.tileRows, fallbackRows);

        if (def.exportMode == TileExportModes.IDS)
        {
            if (data.padding != null) def.padding = data.padding;
            if (data.center != null) def.center = data.center;
            if (data.masks != null) def.masks = AutotilerMask.loadList(data.masks);
        }
        else
        {
            if (data.padding2D != null) def.padding = AutotilerMask.importTilesFrom2D(data.padding2D, def.tileColumns, def.tileRows);
            if (data.center2D != null) def.center = AutotilerMask.importTilesFrom2D(data.center2D, def.tileColumns, def.tileRows);
            if (data.masks2D != null) def.masks = AutotilerMask.loadList2D(data.masks2D, def.tileColumns, def.tileRows);
        }

        return def;
    }

    public function save(project: Project): Dynamic
    {
        var data: Dynamic = {
            label: label,
            tileset: tileset,
            exportMode: exportMode,
            tileColumns: tileColumns,
            tileRows: tileRows
        };

        if (exportMode == TileExportModes.IDS)
        {
            data.padding = padding;
            data.center = center;
            data.masks = AutotilerMask.saveList(masks);
        }
        else
        {
            data.padding2D = AutotilerMask.getTiles2D(padding, tileColumns, tileRows);
            data.center2D = AutotilerMask.getTiles2D(center, tileColumns, tileRows);
            data.masks2D = AutotilerMask.saveList2D(masks, tileColumns, tileRows);
        }

        return data;
    }
}

package modules.autotiler;

import project.data.Tileset;
import util.RightClickMenu;
import util.Fields;
import util.ItemList;
import project.editor.ProjectEditorPanel;

class ProjectAutotilerPanel extends ProjectEditorPanel
{
    public static function startup()
    {
        Ogmo.projectEditor.addPanel(new ProjectAutotilerPanel());
    }

    public var definitions: JQuery;
    public var buttons: JQuery;
    public var inspector: JQuery;
    public var definitionList: ItemList;

    public var inspecting: AutotilerDefinition;

    // fields
    public var defLabel: JQuery;
    public var defTileset: JQuery;
    public var exportMode: JQuery;

    // manager
    public var maskManager: AutotilerMaskTemplateManager;

    public function new()
    {
        super(5, "autotiler", "Autotiler", "layer-grid");

        // list of autotiler definitions on the left side
        definitions = new JQuery('<div class="project_tiles_list">');
        root.append(definitions);

        // create new definition button
        buttons = new JQuery('<div class="buttons">');
        definitions.append(buttons);

        var newDefinitionButton = Fields.createButton("plus", "New Definition", buttons);
        newDefinitionButton.on("click", function() { newDefinition(); });

        // list of definitions
        definitionList = new ItemList(definitions);

        // inspector
        inspector = new JQuery('<div class="project_tiles_inspector">');
        root.append(inspector);
    }

    public function newDefinition(): Void
    {
        if (OGMO.project.tilesets.length <= 0)
        {
            Popup.open('No Tilesets in Project', 'warning', 'The Project requires at least one Tileset in order to create Autotiler definitions.', ['Okay']);
            return;
        }

        Popup.openTextTwoDropdowns("Create New Autotiler Definition", "plus", "new_def", getTilesetLabels(), ["No Preset", "Standard Preset", "Extended Preset"], "Create", "Cancel", function(name, tilesetIdx, presetIdx)
        {
            if (name != null && name.length > 0 && tilesetIdx >= 0)
            {
                var tileset = OGMO.project.tilesets[tilesetIdx];
                if (tileset == null) tileset = OGMO.project.tilesets[0];

                var newDef = AutotilerDefinition.create(name, tileset);

                var presets: Map<String, () -> Array<Int>>;
                /*switch (presetIdx)
                {
                    case 1: presets = AutotilerMaskTemplateManager.maskPresets;
                    case 2: presets = AutotilerMaskTemplateManager.extendedMaskPresets;
                    default: presets = null;
                }*/
                // why does this work, but not the switch block?
                // and before anyone asks, there is no fall-through in Haxe's switch blocks
                if (presetIdx == 1) presets = AutotilerMaskTemplateManager.maskPresets;
                else if (presetIdx == 2) presets = AutotilerMaskTemplateManager.extendedMaskPresets;
                else presets = null;

                if (presets != null) for (preset => getMask in presets)
                {
                    var mask = new AutotilerMask();
                    mask.label = preset;
                    mask.mask = getMask();
                    newDef.masks.push(mask);
                }

                OGMO.project.autotilerDefinitions.push(newDef);
                refreshList();
                inspect(newDef);
            }
        });
    }

    public function getTilesetLabels(): Array<String>
    {
        var result: Array<String> = [];
        var tilesets = OGMO.project.tilesets;
        for (i in 0...tilesets.length) result[i] = tilesets[i].label;
        return result;
    }

    override function begin(reset: Bool = false): Void
    {
        if (reset) inspecting = null;
        refreshList();
        inspect(inspecting == null ? OGMO.project.autotilerDefinitions[0] : inspecting);
    }

    public function refreshList(): Void
    {
        var self = this;

        definitionList.empty();
        for (def in OGMO.project.autotilerDefinitions)
        {
            var item = definitionList.add(new ItemListItem(def.label, def));
            item.onclick = function(current) { self.inspect(current.data); };
            item.onrightclick = function(current)
            {
                var menu = new RightClickMenu(OGMO.mouse);
                menu.onClosed(function() { current.highlighted = false; });

                menu.addOption("delete", "trash", function()
                {
                    var n = OGMO.project.autotilerDefinitions.indexOf(current.data);
                    if (n >= 0)
                        OGMO.project.autotilerDefinitions.splice(n, 1);
                    if (self.inspecting == current.data)
                        self.inspect(null, false);
                    self.refreshList();
                });

                menu.addOption("duplicate", "new-file", function()
                {
                    var clone = AutotilerDefinition.clone(current.data);
                    OGMO.project.autotilerDefinitions.push(clone);
                    self.refreshList();
                    self.inspect(clone);
                });

                current.highlighted = true;
                menu.open();
            };
        }
    }

    public function inspect(definition: AutotilerDefinition, ?saveOnChange: Bool): Void
    {
        if (inspecting != null && (saveOnChange == null || saveOnChange)) save(inspecting);

        inspecting = definition;
        inspector.empty();

        if (definition == null)
        {
            maskManager = null;
            return;
        }

        definitionList.perform(function(item) { item.selected = (item.data == definition); });

        // label, tileset, export mode
        defLabel = Fields.createField("Label", definition.label);
        defLabel.on("input change keyup", function()
        {
            definitionList.perform(function(item) { if (item.data == definition) item.label = Fields.getField(defLabel); });
        });
        Fields.createSettingsBlock(inspector, defLabel, SettingsBlock.Third, "Label", SettingsBlock.InlineTitle);

        defTileset = new JQuery('<select>');
        var current = 0;
        var currentTileset = OGMO.project.getTileset(definition.tileset);
        for (i in 0...OGMO.project.tilesets.length)
        {
            var tileset = OGMO.project.tilesets[i];
            if (tileset == currentTileset) current = i;
            defTileset.append('<option value="' + i + '">' + tileset.label + '</option>');
        }
        defTileset.val(current.string());
        defTileset.on("change", function() { maskManager.inspectTileset(definition, OGMO.project.tilesets[Imports.integer(defTileset.val(), 0)]); });
        Fields.createSettingsBlock(inspector, defTileset, SettingsBlock.Third, "Tileset", SettingsBlock.InlineTitle);

        var exportOptions: Map<String, String> = [
            TileExportModes.IDS.string() => "IDs",
            TileExportModes.COORDS.string() => "Coords"
        ];
        exportMode = Fields.createOptions(exportOptions);
        exportMode.val(definition.exportMode);
        Fields.createSettingsBlock(inspector, exportMode, SettingsBlock.Third, "Export Mode", SettingsBlock.InlineTitle);

        maskManager = new AutotilerMaskTemplateManager(inspector);
        maskManager.inspectTileset(definition, currentTileset);
    }

    public function save(definition: AutotilerDefinition): Void
    {
        definition.label = Fields.getField(defLabel);
        var tileset = OGMO.project.tilesets[Imports.integer(defTileset.val(), 0)];
        definition.tileset = (tileset != null) ? tileset.label : null;
        definition.exportMode = Imports.integer(exportMode.val(), 0);

        if (maskManager != null) maskManager.save(definition);
    }

    override function end(): Void { if (inspecting != null) save(inspecting); }
}

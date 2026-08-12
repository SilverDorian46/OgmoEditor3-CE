package modules.grid;

import util.Fields;
import project.editor.LayerTemplateEditor;

using StringTools;

class GridLayerTemplateEditor extends LayerTemplateEditor
{
	public var arrayMode:JQuery;
	public var overlaidBy:JQuery;
	public var list:JQuery;

	override function importInto(into:JQuery)
	{
		super.importInto(into);

		var grid:GridLayerTemplate = cast template;

		// array mode
		var options = new Map();
		options.set(ArrayExportModes.ONE.string(), "1D");
		options.set(ArrayExportModes.TWO.string(), "2D");

		arrayMode = Fields.createOptions(options);
		arrayMode.val(grid.arrayMode);
		Fields.createSettingsBlock(into, arrayMode, SettingsBlock.Half, "Grid Array Mode", SettingsBlock.InlineTitle);

		// overlaid by which layer
		overlaidBy = Fields.createField("Overlaid By", grid.overlaidBy);
		Fields.createSettingsBlock(into, overlaidBy, SettingsBlock.Half, "Overlaying Tile Layer", SettingsBlock.InlineTitle);

		Fields.createLineBreak(into);

		// list
		list = new JQuery('<div class="gridlayer-legend-list">');
		into.append(list);

		// legend
		var index = 0;
		for (key in grid.legend.keys())
		{
			createLegendCharacter(key, grid.legend[key], index >= 2, index >= 1, grid.autotilings.get(key));
			index ++;
		}

		// plus button
		var newButton = Fields.createButton("plus", "...", into);
		newButton.on("click", function()
		{
			var nextChar = '0';
			for (i in 0...grid.legendchars.length)
			{
				var exists = false;
				for (key in grid.legend.keys())
					if (grid.legendchars.charAt(i) == key)
					{
						exists = true;
						break;
					}
				if (!exists)
				{
					nextChar = grid.legendchars.charAt(i);
					break;
				}
			}

			createLegendCharacter(nextChar, Color.black, true, true);
			save();
		});
		newButton.css("margin", "10px");
	}

	function createLegendCharacter(character:String, color:Color, trashable:Bool, canSetAutotiling:Bool, ?autotiling:String):Void
	{
		var holder = new JQuery('<div class="gridlayer-legend-item">');
		var colorbox = Fields.createColor("Grid Character Color", color, true, true, holder);
		var char = Fields.createField("-", character, holder);
		if (canSetAutotiling)
		{
			var auto = new JQuery('<select class="autotiling">');
			auto.append('<option value=""></option>');
			for (def in OGMO.project.autotilerDefinitions) auto.append('<option value="' + def.label + '">' + def.label + '</option>');
			if (autotiling != null) auto.val(autotiling);
			holder.append(auto);
		}
		if (trashable)
		{
			var trash = new JQuery('<div class="trash icon icon-trash">');
			trash.on('click', function()
			{
				holder.remove();
			});
			holder.append(trash);
		}
		list.append(holder);
	}

	override function save()
	{
		super.save();

		var grid:GridLayerTemplate = cast template;
		grid.legend = new Map();
		grid.autotilings = new Map();
		grid.arrayMode = Imports.integer(arrayMode.val(), 0);
		grid.overlaidBy = overlaidBy.val();

		into.find('.gridlayer-legend-item').each(function(i, e)
		{
			var id:String = new JQuery(e).find("input").val();
			var color = Fields.getColor(new JQuery(e).find(".color-box"));

			var autoID:String = null;
			var autoElement = new JQuery(e).find(".autotiling");
			if (autoElement != null) autoID = autoElement.val();

			if (id.length > 0)
			{
				id = id.substr(0, 1);
				grid.legend.set(id, color);
				if (autoID != null && autoID.length > 0) grid.autotilings.set(id, autoID);
			}
		});
	}
}

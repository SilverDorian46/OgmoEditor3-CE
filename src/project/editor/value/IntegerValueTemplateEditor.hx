package project.editor.value;

import js.jquery.JQuery;
import io.Imports;
import project.data.value.IntegerValueTemplate;
import util.Fields;

class IntegerValueTemplateEditor extends ValueTemplateEditor
{
	public var defaultField:JQuery;
	public var boundedMinField:JQuery;
	public var boundedMaxField:JQuery;
	public var minField:JQuery;
	public var maxField:JQuery;

	override function importInto(into:JQuery)
	{
		var intTemplate:IntegerValueTemplate = cast template;

		// default val
		defaultField = Fields.createField("Defualt", intTemplate.defaults.string());
		Fields.createSettingsBlock(into, defaultField, SettingsBlock.Half, "Default", SettingsBlock.InlineTitle);

		// min / max / bounded

		minField = Fields.createField("Min", intTemplate.min.string());
		Fields.createSettingsBlock(into, minField, SettingsBlock.Fourth, "Min", SettingsBlock.InlineTitle);

		boundedMinField = Fields.createCheckbox(intTemplate.boundedMin, "Clamp Min");
		Fields.createSettingsBlock(into, boundedMinField, SettingsBlock.Fourth);

		maxField = Fields.createField("Max", intTemplate.max.string());
		Fields.createSettingsBlock(into, maxField, SettingsBlock.Fourth, "Max", SettingsBlock.InlineTitle);

		boundedMaxField = Fields.createCheckbox(intTemplate.boundedMax, "Clamp Max");
		Fields.createSettingsBlock(into, boundedMaxField, SettingsBlock.Fourth);
	}

	override function save()
	{
		var intTemplate:IntegerValueTemplate = cast template;

		intTemplate.defaults = Imports.integer(Fields.getField(defaultField), 0);
		intTemplate.boundedMin = Fields.getCheckbox(boundedMinField);
		intTemplate.boundedMax = Fields.getCheckbox(boundedMaxField);
		intTemplate.min = Imports.integer(Fields.getField(minField), 0);
		intTemplate.max = Imports.integer(Fields.getField(maxField), 100);
	}
}

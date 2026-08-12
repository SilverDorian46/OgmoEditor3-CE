package project.editor.value;

import io.Imports;
import js.jquery.JQuery;
import project.data.value.FloatValueTemplate;
import util.Fields;

class FloatValueTemplateEditor extends ValueTemplateEditor
{
	public var defaultField:JQuery;
	public var boundedMinField:JQuery;
	public var boundedMaxField:JQuery;
	public var minField:JQuery;
	public var maxField:JQuery;

	override function importInto(into:JQuery)
	{
		var floatTemplate:FloatValueTemplate = cast template;

		// default val
		defaultField = Fields.createField("Default", floatTemplate.defaults.string());
		Fields.createSettingsBlock(into, defaultField, SettingsBlock.Half, "Default", SettingsBlock.InlineTitle);

		// min / max / bounded

		minField = Fields.createField("Min", floatTemplate.min.string());
		Fields.createSettingsBlock(into, minField, SettingsBlock.Fourth, "Min", SettingsBlock.InlineTitle);

		boundedMinField = Fields.createCheckbox(floatTemplate.boundedMin, "Clamp Min");
		Fields.createSettingsBlock(into, boundedMinField, SettingsBlock.Fourth);

		maxField = Fields.createField("Max", floatTemplate.max.string());
		Fields.createSettingsBlock(into, maxField, SettingsBlock.Fourth, "Max", SettingsBlock.InlineTitle);

		boundedMaxField = Fields.createCheckbox(floatTemplate.boundedMax, "Clamp Max");
		Fields.createSettingsBlock(into, boundedMaxField, SettingsBlock.Fourth);
	}

	override function save()
	{
		var floatTemplate:FloatValueTemplate = cast template;

		floatTemplate.defaults = Imports.float(Fields.getField(defaultField), 0);
		floatTemplate.boundedMin = Fields.getCheckbox(boundedMinField);
		floatTemplate.boundedMax = Fields.getCheckbox(boundedMaxField);
		floatTemplate.min = Imports.float(Fields.getField(minField), 0);
		floatTemplate.max = Imports.float(Fields.getField(maxField), 100);
	}
}

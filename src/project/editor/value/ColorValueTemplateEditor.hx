package project.editor.value;

import js.jquery.JQuery;
import project.data.value.ColorValueTemplate;
import util.Fields;

class ColorValueTemplateEditor extends ValueTemplateEditor
{
	public var defaultField:JQuery;
	public var alphaField:JQuery;
	public var hashtagField:JQuery;

	override function importInto(into:JQuery)
	{
		var colorTemplate:ColorValueTemplate = cast template;

		// default val
		defaultField = Fields.createColor("Default Color", colorTemplate.defaults, true, true);
		Fields.createSettingsBlock(into, defaultField, SettingsBlock.Half, "Default", SettingsBlock.InlineTitle);

		// include alpha
		alphaField = Fields.createCheckbox(colorTemplate.includeAlpha, "Include Alpha");
		Fields.createSettingsBlock(into, alphaField, SettingsBlock.Fourth);

		// include #
		hashtagField = Fields.createCheckbox(colorTemplate.includeHashtag, "Include #");
		Fields.createSettingsBlock(into, hashtagField, SettingsBlock.Fourth);
	}

	override function save()
	{
		var colorTemplate:ColorValueTemplate = cast template;

		colorTemplate.defaults = Fields.getColor(defaultField);
		colorTemplate.includeAlpha = Fields.getCheckbox(alphaField);
		colorTemplate.includeHashtag = Fields.getCheckbox(hashtagField);
	}
}

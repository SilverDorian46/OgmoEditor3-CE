package project.data.value;

import project.editor.value.FloatValueTemplateEditor;
import level.editor.value.FieldValueEditor;
import level.editor.value.ValueEditor;
import level.data.Value;

class FloatValueTemplate extends ValueTemplate
{
	public static function startup()
	{
		var n = new ValueDefinition(FloatValueTemplate, FloatValueTemplateEditor, "value-float", "Float");
		ValueDefinition.definitions.push(n);
	}

	public var defaults:Float = 0;
	public var boundedMin:Bool = false;
	public var boundedMax:Bool = false;
	public var min:Float = 0;
	public var max:Float = 100;

	override function getHashCode(): String
	{
		return name + ":fl" + (boundedMin ? (":" + min) : "") + (boundedMax ? (":" + max) : "");
	}

	override function getDefault():Float
	{
		return defaults;
	}

	override function validate(val:Dynamic):Float
	{
		var number = Imports.float(val, defaults);
		if (boundedMin && number < min)
			number = min;
		else if (boundedMax && number > max)
			number = max;
		return number;
	}

	override function createEditor(values:Array<Value>):ValueEditor
	{
		var editor = new FieldValueEditor();
		editor.load(this, values);
		return editor;
	}

	override function load(data:Dynamic):Void
	{
		super.load(data);
		defaults = data.defaults;
		if (data.bounded != null) boundedMax = boundedMin = Imports.bool(data.bounded, false); // legacy
		if (data.boundedMin != null) boundedMin = Imports.bool(data.boundedMin, false);
		if (data.boundedMax != null) boundedMax = Imports.bool(data.boundedMax, false);
		min = Imports.float(data.min, 0);
		max = Imports.float(data.max, 100);
	}

	override function save():Dynamic
	{
		var data:Dynamic = super.save();

		data.defaults = defaults;
		data.boundedMin = boundedMin;
		data.boundedMax = boundedMax;
		data.min = min;
		data.max = max;

		return data;
	}
}

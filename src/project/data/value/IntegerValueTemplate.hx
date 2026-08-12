package project.data.value;

import project.editor.value.IntegerValueTemplateEditor;
import level.editor.value.FieldValueEditor;
import level.editor.value.ValueEditor;
import level.data.Value;
import io.Imports;

class IntegerValueTemplate extends ValueTemplate
{
	public static function startup()
	{
		var n = new ValueDefinition(IntegerValueTemplate, IntegerValueTemplateEditor, "value-int", "Integer");
		ValueDefinition.definitions.push(n);
	}

	public var defaults:Int = 0;
	public var boundedMin:Bool = false;
	public var boundedMax:Bool = false;
	public var min:Int = 0;
	public var max:Int = 100;

	override function getHashCode():String
	{
		return name + ":in" + (boundedMin ? (":" + min) : "") + (boundedMax ? (":" + max) : "");
	}

	override function getDefault():Int
	{
		return defaults;
	}

	override function validate(val:Dynamic):Int
	{
		var number = Imports.integer(val, defaults);
		if (boundedMin && number < min)
			number = min;
		else if (boundedMax && number > max)
			number = max;
		return	number;
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
		min = Imports.integer(data.min, 0);
		max = Imports.integer(data.max, 100);
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

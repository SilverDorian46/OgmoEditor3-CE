package level.editor;

import level.data.Level;
import js.jquery.JQuery;
import util.Vector;
import util.Rectangle;

class LevelResizeHandles
{
	public var handles:Array<{ box: Rectangle, points: Array<Vector>, anchor: Vector }>;
	public var moused:Int = -1;
	public var positionHandles:Array<Rectangle>;
    public var positionHandleMoused:Bool = false;
	public var resizing:Bool = false;
	public var repositioning:Bool = false;
	public var firstChange:Bool = false;
	public var start:Vector = new Vector();
	public var startSize: Vector = new Vector();
    public var startOffset: Vector = new Vector();
	public var sticker:JQuery;

	public var canResize(get, never):Bool;
	public var canResizeX(get, never):Bool;
	public var canResizeY(get, never):Bool;
	public var canReposition(get, never):Bool;
    public var currentlyMoused(get, never):Bool;

	public function new()
	{
		handles = [];
		positionHandles = [];
		sticker = new JQuery(".sticker-size");

		var a = 0.5;
		var b = 0.8;

		if (canResizeX)
		{
			//Right
			handles.push({
				box: new Rectangle(),
				anchor: new Vector(0.0, 0.5),
				points: [ new Vector(1, 0), new Vector(-a, -1), new Vector(-a, 1) ]
			});

			//Left
			handles.push({
				box: new Rectangle(),
				anchor: new Vector(1.0, 0.5),
				points: [ new Vector(-1, 0), new Vector(a, -1), new Vector(a, 1) ]
			});
		}

		if (canResizeY)
		{
			//Down
			handles.push({
				box: new Rectangle(),
				anchor: new Vector(0.5, 0.0),
				points: [ new Vector(0, 1), new Vector(-1, -a), new Vector(1, -a) ]
			});

			//Up
			handles.push({
				box: new Rectangle(),
				anchor: new Vector(0.5, 1.0),
				points: [ new Vector(0, -1), new Vector(-1, a), new Vector(1, a) ]
			});
		}

		if (canResizeX && canResizeY)
		{
			//Bottom Right
			handles.push({
				box: new Rectangle(),
				anchor: new Vector(0.0, 0.0),
				points: [ new Vector(1, 1), new Vector(-b, 1), new Vector(1, -b) ]
			});

			//Bottom Left
			handles.push({
				box: new Rectangle(),
				anchor: new Vector(1.0, 0.0),
				points: [ new Vector(-1, 1), new Vector(b, 1), new Vector(-1, -b) ]
			});

			//Top Right
			handles.push({
				box: new Rectangle(),
				anchor: new Vector(0.0, 1.0),
				points: [ new Vector(1, -1), new Vector(-b, -1), new Vector(1, b) ]
			});

			//Top Left
			handles.push({
				box: new Rectangle(),
				anchor: new Vector(1.0, 1.0),
				points: [ new Vector(-1, -1), new Vector(b, -1), new Vector(-1, b) ]
			});
		}
	}

	public function refresh():Void
	{
		var level = EDITOR.currentLevel;
		if (level != null)
		{
			var zoom = EDITOR.zoom;

			var pad = 30 / zoom;
			var size = 15 / zoom;

			var lvlOffset = level.data.offset;
			var lvlSize = level.data.size;

			for (i in 0...handles.length)
			{
				var h = handles[i];
				h.box.width = h.box.height = size;

				if (h.anchor.x >= 1)
					h.box.centerX = lvlOffset.x - pad;
				else if (h.anchor.x <= 0)
					h.box.centerX = lvlOffset.x + lvlSize.x + pad;
				else
					h.box.centerX = lvlOffset.x + lvlSize.x * h.anchor.x;

				if (h.anchor.y >= 1)
					h.box.centerY = lvlOffset.y - pad;
				else if (h.anchor.y <= 0)
					h.box.centerY = lvlOffset.y + lvlSize.y + pad;
				else
					h.box.centerY = lvlOffset.y + lvlSize.y * h.anchor.y;
			}

			if (canReposition)
			{
                if (positionHandles.length <= 0)
                    for (i in 0...4)
                        positionHandles.push(new Rectangle());

				var pad2 = 10 / zoom;
				var size2 = 5 / zoom;

				var handle = positionHandles[0]; // top
				if (handle != null)
				{
					handle.x = lvlOffset.x - pad2 - size2;
					handle.y = lvlOffset.y - pad2 - size2;
					handle.width = lvlSize.x + ((pad2 + size2) * 2);
					handle.height = size2;

					handle = positionHandles[1]; // left
					if (handle != null)
					{
						handle.x = lvlOffset.x - pad2 - size2;
						handle.y = lvlOffset.y - pad2;
						handle.width = size2;
						handle.height = lvlSize.y + (pad2 * 2);

						handle = positionHandles[2]; // right
						if (handle != null)
						{
							handle.x = lvlOffset.x + lvlSize.x + pad2;
							handle.y = lvlOffset.y - pad2;
							handle.width = size2;
							handle.height = lvlSize.y + (pad2 * 2);

							handle = positionHandles[3]; // bottom
							if (handle != null)
							{
								handle.x = lvlOffset.x - pad2 - size2;
								handle.y = lvlOffset.y + lvlSize.y + pad2;
								handle.width = lvlSize.x + ((pad2 + size2) * 2);
								handle.height = size2;
							}
						}
					}
				}
			}
            else while (positionHandles.length > 0)
                positionHandles.pop();
		}
	}

	static var idleColor = Color.gray.x(0.5);
	static var hoverColor = Color.yellow.clone();
	static var dragColor = Color.green.clone();
	static var warningColor = Color.red.x(0.7);

	public function draw():Void
	{
		var level = EDITOR.currentLevel;
		if (level != null)
		{
            var shouldWarnSize = level.shouldWarnSize;

			for (handle in positionHandles)
            {
                var col: Color;
                if (positionHandleMoused)
                {
                    if (repositioning)
                        col = LevelResizeHandles.dragColor;
                    else
                        col = LevelResizeHandles.hoverColor;
                }
                else if (shouldWarnSize)
                    col = LevelResizeHandles.warningColor;
                else
                    col = LevelResizeHandles.idleColor;

                EDITOR.draw.drawRect(handle.x, handle.y, handle.width, handle.height, col);
            }

			for (i in 0...handles.length)
			{
				var h = handles[i];

				var col: Color;
				if (moused == i)
				{
					if (resizing)
						col = LevelResizeHandles.dragColor;
					else
						col = LevelResizeHandles.hoverColor;
				}
				else if (shouldWarnSize)
					col = LevelResizeHandles.warningColor;
				else
					col = LevelResizeHandles.idleColor;

				if (h.points.length >= 3)
				{
					var cX = h.box.centerX;
					var cY = h.box.centerY;
					var s = h.box.width * 0.5;

					EDITOR.draw.drawTriangle(
						cX + h.points[0].x * s, cY + h.points[0].y * s,
						cX + h.points[1].x * s, cY + h.points[1].y * s,
						cX + h.points[2].x * s, cY + h.points[2].y * s,
						col
					);
				}
			}
		}
	}

    public function updateMousedHandle(pos: Vector):Void
    {
        function getAt(pos: Vector):Int
	    {
		    for (i in 0...handles.length)
			    if (handles[i].box.contains(pos))
				    return i;
		    return -1;
	    }

        function atPositionHandle(pos: Vector):Bool
        {
            for (handle in positionHandles)
                if (handle.contains(pos))
                    return true;
            return false;
        }

        moused = getAt(pos);
        positionHandleMoused = moused == -1 && atPositionHandle(pos);
    }

	public function onMouseMove(level: Level, pos: Vector):Void
	{
		if (resizing)
		{
			var h = handles[moused];

			var currentLayer = level.currentLayer;

			//Figure out grid snap values
			var snap: Vector;
			if (OGMO.ctrl) snap = new Vector(1, 1);
			else snap = currentLayer.template.gridSize.clone();

			var snapOffset: Vector = new Vector(0, 0);
			if (!OGMO.ctrl)
			{
				if (h.anchor.x <= 0) snapOffset.x = currentLayer.offset.x;
				else if (h.anchor.x >= 1) snapOffset.x = currentLayer.leftoverX;

				if (h.anchor.y <= 0) snapOffset.y = currentLayer.offset.y;
				else if (h.anchor.y >= 1) snapOffset.y = currentLayer.leftoverY;
			}

			//Figure out drag direction stuff
			var pan: Vector = new Vector(0, 0);
			var mult: Vector = new Vector(1, 1);
			if (h.anchor.x >= 1)
			{
				mult.x = -1;
				pan.x = -1;
			}
			if (h.anchor.y >= 1)
			{
				mult.y = -1;
				pan.y = -1;
			}

			//Calculate the new size
			var newSize: Vector = new Vector(
				startSize.x + (pos.x - start.x) * mult.x,
				startSize.y + (pos.y - start.y) * mult.y
			);
			newSize.x = Calc.snap(newSize.x, snap.x, snapOffset.x);
			newSize.y = Calc.snap(newSize.y, snap.y, snapOffset.y);

			//Prevent resizing from edges
			if (h.anchor.x > 0 && h.anchor.x < 1)
				newSize.x = level.data.size.x;
			if (h.anchor.y > 0 && h.anchor.y < 1)
				newSize.y = level.data.size.y;

			//Clamp new size
			newSize.x = Calc.clamp(newSize.x, OGMO.project.levelMinSize.x, OGMO.project.levelMaxSize.x);
			newSize.y = Calc.clamp(newSize.y, OGMO.project.levelMinSize.y, OGMO.project.levelMaxSize.y);

			if (!level.data.size.equals(newSize))
			{
				//Pan the camera
				if (!EDITOR.isEditingMap)
				{
					pan.x *= (newSize.x - level.data.size.x);
					pan.y *= (newSize.y - level.data.size.y);
					start.x -= pan.x;
					start.y -= pan.y;
					pan.x *= EDITOR.camera.a;
					pan.y *= EDITOR.camera.d;
					EDITOR.moveCamera(-pan.x, -pan.y);
				}

				//Store undo
				if (!firstChange)
				{
					firstChange = true;
					level.storeFull(h.anchor.x >= 1, h.anchor.y >= 1, "resize level");
				}

                //Calc shift amount
                var shift = new Vector();
                if (h.anchor.x >= 1)
                    shift.x = newSize.x - level.data.size.x;
                if (h.anchor.y >= 1)
                    shift.y = newSize.y - level.data.size.y;

                //Do the resize
                level.resize(newSize, shift);

				//Shift level offset if currently editing map
				if (EDITOR.isEditingMap)
				{
					level.data.offset.x -= shift.x;
					level.data.offset.y -= shift.y;
				}

				//Refresh editor and handlers
				refresh();
				EDITOR.dirty();
				refreshSizeReadout(level);
            }
        }
		else if (repositioning)
		{
            var snap: Vector;
            if (OGMO.ctrl) snap = new Vector(1, 1);
            else snap = level.currentLayer.template.gridSize.clone();

            var snapOffset: Vector = new Vector(0, 0);
            if (!OGMO.ctrl)
            {
                snapOffset.x = Calc.mod(startOffset.x, snap.x);
                snapOffset.y = Calc.mod(startOffset.y, snap.y);
            }

            var newOffset: Vector = new Vector(
                startOffset.x + (pos.x - start.x),
                startOffset.y + (pos.y - start.y)
            );
            newOffset.x = Calc.snap(newOffset.x, snap.x, snapOffset.x);
            newOffset.y = Calc.snap(newOffset.y, snap.y, snapOffset.y);

            if (!level.data.offset.equals(newOffset))
            {
                //var pan: Vector = new Vector();
                //pan.x = (newOffset.x - level.data.offset.x);
                //pan.y = (newOffset.y - level.data.offset.y);
                //start.x -= pan.x;
                //start.y -= pan.y;
                //pan.x *= EDITOR.camera.a;
                //pan.y *= EDITOR.camera.d;
                //EDITOR.moveCamera(-pan.x, -pan.y);

                if (!firstChange)
                {
                    firstChange = true;
                    level.storeLevelData("reposition level");
                }

                level.data.offset = newOffset.clone();

                refresh();
                EDITOR.dirty();
                refreshOffsetReadout(level);
            }
		}
        else
        {
            var old = moused;
            var old2 = positionHandleMoused;
            updateMousedHandle(pos);

            if (old != moused || old2 != positionHandleMoused)
                EDITOR.dirty();
        }
    }

    public function onMouseDown(level: Level, pos: Vector):Bool
    {
        updateMousedHandle(pos);

        if (moused != -1)
        {
            resizing = true;
            firstChange = false;
            level.data.size.clone(startSize);
            pos.clone(start);
            EDITOR.locked = true;
            EDITOR.dirty();
            refreshSizeReadout(level);

            if (!sticker.hasClass("active"))
                sticker.addClass("active");

            return true;
        }
        else if (positionHandleMoused)
        {
            repositioning = true;
            firstChange = false;
            level.data.offset.clone(startOffset);
            pos.clone(start);
            EDITOR.locked = true;
            EDITOR.dirty();
            refreshOffsetReadout(level);

            if (!sticker.hasClass("active"))
                sticker.addClass("active");

            return true;
        }
        else
            return false;
    }

    public function refreshSizeReadout(level: Level):Void
    {
        sticker.text(level.data.size.x + " x " + level.data.size.y);
    }

	public function refreshOffsetReadout(level: Level):Void
    {
        sticker.text(level.data.offset.x + ", " + level.data.offset.y);
    }

    public function stopResizing():Void
    {
        resizing = false;
        EDITOR.locked = false;
        EDITOR.updateCameraInverse();
        EDITOR.dirty();

        if (sticker.hasClass("active")) sticker.removeClass("active");
    }

	public function stopRepositioning():Void
	{
		repositioning = false;
		EDITOR.locked = false;
		EDITOR.updateCameraInverse();
		EDITOR.dirty();

		if (sticker.hasClass("active")) sticker.removeClass("active");
	}

	public function onMouseUp(pos:Vector):Bool
	{
		if (resizing)
		{
			stopResizing();
			return true;
		}
		else if (repositioning)
		{
			stopRepositioning();
			return true;
		}
		else return false;
	}

	public function onRightDown(pos:Vector):Bool
	{
		if (resizing)
		{
			stopResizing();
			return true;
		}
		else if (repositioning)
		{
			stopRepositioning();
			return true;
		}
		else return false;
	}

    public function onRightUp(pos: Vector):Bool
    {
        return resizing || repositioning;
    }

    function get_canResize():Bool
    {
        return canResizeX || canResizeY;
    }

    function get_canResizeX():Bool
    {
        return OGMO.project.levelMinSize.x != OGMO.project.levelMaxSize.x;
    }

    function get_canResizeY():Bool
    {
        return OGMO.project.levelMinSize.y != OGMO.project.levelMaxSize.y;
    }

	function get_canReposition():Bool
	{
		return EDITOR.isEditingMap;
	}

    function get_currentlyMoused():Bool
    {
        return moused != -1 || positionHandleMoused;
    }
}

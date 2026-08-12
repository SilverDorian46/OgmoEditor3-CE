package util;

class IntRectangle
{
    public var x: Int;
    public var y: Int;
    public var width: Int;
    public var height: Int;

    public var left(get, set): Int;
    inline function get_left() { return x; }
    inline function set_left(value: Int) { return x = value; }

    public var right(get, set): Int;
    inline function get_right() { return x + width; }
    inline function set_right(value: Int) { return x = value - width; }

    public var top(get, set): Int;
    inline function get_top() { return y; }
    inline function set_top(value: Int) { return y = value; }
    
    public var bottom(get, set): Int;
    inline function get_bottom() { return y + height; }
    inline function set_bottom(value: Int) { return y = value - height; }

    public function new(x: Int, y: Int, width: Int, height: Int)
    {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }

    public function clone(): IntRectangle
    {
        return new IntRectangle(x, y, width, height);
    }

    public function equals(other: IntRectangle): Bool
    {
        return this.x == other.x && this.y == other.y && this.width == other.width && this.height == other.height;
    }

    public function containsRect(rect: IntRectangle): Bool
    {
        return rect.left >= left && rect.top >= top && rect.right <= right && rect.bottom <= bottom;
    }

    public function canContainRect(rect: IntRectangle): Bool
    {
        return rect.width <= width && rect.height <= height;
    }

    public function intersects(rect: IntRectangle): Bool
    {
        return rect.left < right && rect.right > left  && rect.top < bottom && rect.bottom > top;
    }

    public function pad(amount: Int): IntRectangle
    {
        var doubleAmount = amount * 2;
        return new IntRectangle(x - amount, y - amount, width + doubleAmount, height + doubleAmount);
    }

    static final rectsBuffer: Array<IntRectangle> = [];
    static final removeBuffer: Array<IntRectangle> = [];

    public static function subtractArray(rect: IntRectangle, array: Array<IntRectangle>): Void
    {
        while (array.length > 0)
        {
            var item = array.pop();
            if (!item.intersects(rect))
            {
                rectsBuffer.push(item.clone());
                continue;
            }

            var diff = rect.left - item.left;
            if (diff > 0) rectsBuffer.push(new IntRectangle(item.left, item.y, diff, item.height));

            diff = item.right - rect.right;
            if (diff > 0) rectsBuffer.push(new IntRectangle(rect.right, item.y, diff, item.height));

            diff = rect.top - item.top;
            if (diff > 0) rectsBuffer.push(new IntRectangle(item.x, item.top, item.width, diff));

            diff = item.bottom - rect.bottom;
            if (diff > 0) rectsBuffer.push(new IntRectangle(item.x, rect.bottom, item.width, diff));
        }

        //for (r in rectsBuffer) trace('calculated: { ${r.x}, ${r.y}, ${r.width}, ${r.height} }');

        // merge rectangles with the same x and width
        // merge rectangles with the same y and height
        // remove duplicate rectangles
        var bufferLength = rectsBuffer.length;
        for (i in 0...(bufferLength - 1))
        {
            var current = rectsBuffer[i];
            if (removeBuffer.contains(current)) continue;

            var verticalMerge: IntRectangle = null;
            var horizontalMerge: IntRectangle = null;
            for (j in (i + 1)...bufferLength)
            {
                var next = rectsBuffer[j];
                var equalXAndWidth = next.x == current.x && next.width == current.width;
                var equalYAndHeight = next.y == current.y && next.height == current.height;

                if (equalXAndWidth)
                {
                    // if x, width, y, and height are all equal, then this is a duplicate - no merging happens
                    if (equalYAndHeight) removeBuffer.push(next);
                    // else, check if the next rectangle is not disjoint
                    else if (next.top <= current.bottom && next.bottom >= current.top)
                    {
                        if (verticalMerge == null) verticalMerge = current.clone();
                        if (verticalMerge.top > next.top) verticalMerge.top = next.top;
                        if (verticalMerge.bottom < next.bottom) verticalMerge.bottom = next.bottom;
                    }
                }
                else if (equalYAndHeight && next.left <= current.right && next.right >= current.left)
                {
                    removeBuffer.push(next);
                    if (horizontalMerge == null) horizontalMerge = current.clone();
                    if (horizontalMerge.left > next.left) horizontalMerge.left = next.left;
                    if (horizontalMerge.right < next.right) horizontalMerge.right = next.right;
                }
            }

            // if merging, flag current rect for removal in order to replace with merged rect(s)
            var shouldRemoveThis: Bool = false;
            if (verticalMerge != null)
            {
                rectsBuffer.push(verticalMerge);
                shouldRemoveThis = true;
            }
            if (horizontalMerge != null)
            {
                rectsBuffer.push(horizontalMerge);
                shouldRemoveThis = true;
            }
            if (shouldRemoveThis) removeBuffer.push(current);
        }

        while (removeBuffer.length > 0) rectsBuffer.remove(removeBuffer.pop());
        while (rectsBuffer.length > 0) array.push(rectsBuffer.pop());
    }
}

package rendering;

import js.html.webgl.RenderingContext;

class BlendState
{
    // default blend mode used by Ogmo Editor
    public static var alphaBlend(get, null): BlendState;
    static function get_alphaBlend(): BlendState
    {
        return new BlendState(RenderingContext.SRC_ALPHA, RenderingContext.ONE_MINUS_SRC_ALPHA);
    }

    public static var additiveBlend(get, null): BlendState;
    static function get_additiveBlend(): BlendState
    {
        return new BlendState(RenderingContext.SRC_ALPHA, RenderingContext.ONE);
    }

    public var sfactor: Int;
    public var dfactor: Int;

    public function new(sfactor: Int, dfactor: Int)
    {
        this.sfactor = sfactor;
        this.dfactor = dfactor;
    }

    public function clone(): BlendState
    {
        return new BlendState(sfactor, dfactor);
    }

    public function equals(other: BlendState): Bool
    {
        return this.sfactor == other.sfactor && this.dfactor == other.dfactor;
    }
}

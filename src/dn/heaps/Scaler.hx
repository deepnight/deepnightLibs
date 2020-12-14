package dn.heaps;

class Scaler {
	/** Can be replaced with other methods to change how reference "viewport" width is determined **/
	public static dynamic function getViewportWidth() return hxd.Window.getInstance().width;

	/** Can be replaced with other methods to change how reference "viewport" height is determined **/
	public static dynamic function getViewportHeight() return hxd.Window.getInstance().height;


	/** Fit `wid`x`hei` in current viewport, optionally snapping to closest Integer scale value (for pixel perfect rendering) **/
	public static function fitInside(widPx:Int, heiPx:Int, integerScale=true) : Float {
		var sx = getViewportWidth()/widPx;
		var sy = getViewportHeight()/heiPx;
		if( integerScale ) {
			sx = M.floor(sx);
			sy = M.floor(sy);
		}
		return M.fmax(1, M.fmin(sx,sy) );
	}
}
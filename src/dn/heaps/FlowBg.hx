package dn.heaps;

class FlowBg extends h2d.Flow {
	var _bg : Null<h2d.ScaleGrid>;

	var bgTile : Null<h2d.Tile>;
	var bgBorderHorizontal : Int;
	var bgBorderVertical : Int;
	var bgColor : Col = 0;

	public var repeatBorders = true;
	public var repeatCenter = true;


	public function new(?bgTile:h2d.Tile, horizontalBorder=1, ?verticalBorder:Int, ?p:h2d.Object) {
		super(p);
		setBg(bgTile, horizontalBorder, verticalBorder);
	}

	public inline function setBg(t:h2d.Tile, horizontalBorder:Int, ?verticalBorder:Int) {
		bgTile = t;
		bgBorderHorizontal = horizontalBorder;
		bgBorderVertical = verticalBorder ?? horizontalBorder;
	}

	public inline function setBgBorder(horizontal:Int, ?vertical:Int) {
		bgBorderHorizontal = horizontal;
		bgBorderVertical = vertical!=null ? vertical : horizontal;
	}

	public inline function colorizeBg(c:Col, alpha=1.0) {
		bgColor = c.withAlpha(alpha);
	}

	override function sync(ctx:h2d.RenderContext) {
		super.sync(ctx);

		if( bgTile!=null ) {
			// Recreate bg if needed
			if( _bg==null || _bg.parent==null ) {
				_bg = new h2d.ScaleGrid(bgTile, 1,1);
				addChildAt(_bg, 0);
				getProperties(_bg).isAbsolute = true;
			}

			_bg.tile = bgTile;
			_bg.borderLeft = _bg.borderRight = bgBorderHorizontal;
			_bg.borderTop = _bg.borderBottom = bgBorderVertical;
			if( bgColor!=0 )
				_bg.color.setColor( bgColor.withAlphaIfMissing() );
			_bg.width = outerWidth;
			_bg.height = outerHeight;
			_bg.tileBorders = repeatBorders;
			_bg.tileCenter = repeatCenter;
		}
	}
}
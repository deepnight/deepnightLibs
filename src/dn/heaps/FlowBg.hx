package dn.heaps;

class FlowBg extends h2d.Flow {
	public var bg : h2d.ScaleGrid;

	public function new(?bgTile:h2d.Tile, horizontalBorder=1, ?verticalBorder:Int, ?p:h2d.Object) {
		super(p);

		bg = new h2d.ScaleGrid(bgTile, 1,1, this);
		getProperties(bg).isAbsolute = true;
		setBgBorder(horizontalBorder, verticalBorder);
	}

	public function setBg(t:h2d.Tile, horizontalBorder:Int, ?verticalBorder:Int) {
		bg.tile = t;
		setBgBorder(horizontalBorder, verticalBorder);
	}

	public inline function setBgBorder(horizontal:Int, ?vertical:Int) {
		bg.borderLeft = bg.borderRight = horizontal;
		bg.borderTop = bg.borderBottom = vertical!=null ? vertical : horizontal;
	}

	public inline function colorizeBg(c:UInt) {
		bg.color.setColor( dn.legacy.Color.addAlphaF(c) );
	}

	override function sync(ctx:h2d.RenderContext) {
		super.sync(ctx);
		bg.width = outerWidth;
		bg.height = outerHeight;
	}
}
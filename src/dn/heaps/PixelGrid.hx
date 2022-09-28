package dn.heaps;

#if !heaps
#error "Heaps is required"
#end

/**
	A fast display object containing a grid of colored squares
**/
class PixelGrid extends h2d.Object {
	/** Width in cells **/
	public var wid(default,null) : Int;

	/** Height in cells **/
	public var hei(default,null) : Int;

	public var gridSize(default,set) : Int;

	var tg : h2d.TileGroup;
	var pixelTile : h2d.Tile;
	var pixels : Map<Int,Col> = new Map();
	var invalidated = true;

	/** If TRUE, contiguous pixels sharing the same color+alpha will be rendered as single rectangles to reduce the amount of display objects. **/
	public var optimize = true;


	public function new(gridSize:Int, wid:Int, hei:Int, ?parent:h2d.Object) {
		super(parent);

		this.wid = wid;
		this.hei = hei;

		pixelTile = h2d.Tile.fromColor(0xffffff, 1, 1);
		tg = new h2d.TileGroup(pixelTile, this);

		this.gridSize = gridSize;
	}

	public inline function dispose() {
		pixels = null;
		tg = null;
		pixelTile = null;
		remove();
	}

	inline function isValid(x,y) return x>=0 && x<wid && y>=0 && y<hei;
	inline function coordId(x,y) return x + y*wid;


	/** Apply a color modifier to all the grid. This only modifies the underlying TileGroup color Vector.**/
	public inline function colorize(c:Col) {
		tg.color.setColor( c.withAlphaIfMissing() );
	}

	/** Fill a pixel using a 0xRRGGBB color, with optional alpha in a separate parameter **/
	public inline function setPixel(x:Int, y:Int, rgb:Col, alpha=1.0) {
		if( alpha>0 )
			setPixelMap(x,y, rgb.withAlpha(alpha));
		else
			removePixelMap(x,y);
	}

	/** Fill a pixel using a 0xAARRGGBB color **/
	public inline function setPixel24(x:Int, y:Int, argb:Col) {
		if( alpha>0 )
			setPixelMap(x,y, argb);
		else
			removePixelMap(x,y);
	}

	/** Clear a pixel **/
	public inline function removePixel(x:Int, y:Int) {
		removePixelMap(x,y);
	}

	/** Fill a rectangle **/
	public inline function fillRect(x, y, w:Int, h:Int, rgb:Col, alpha=1.0) {
		var c = rgb.withAlpha(alpha);
		for(y in y...y+h)
		for(x in x...x+w)
			if( alpha>0 )
				setPixelMap(x,y, c);
			else
				removePixelMap(x,y);
	}

	/** Draw a hollow rectangle **/
	public inline function lineRect(x, y, w:Int, h:Int, rgb:Col, alpha=1.0) {
		var c = rgb.withAlpha(alpha);
		line(x, y, x+w-1, y, rgb, alpha);
		line(x, y+h-1, x+w-1, y+h-1, rgb, alpha);
		line(x, y, x, y+h-1, rgb, alpha);
		line(x+w-1, y, x+w-1, y+h-1, rgb, alpha);
	}

	/** Fill all pixels **/
	public inline function fill(rgb:Col, alpha=1.0) {
		var c = rgb.withAlpha(alpha);
		for(y in 0...hei)
		for(x in 0...wid)
			if( alpha>0 )
				setPixelMap(x,y, c);
			else
				removePixelMap(x,y);
	}


	public inline function line(x1:Int, y1:Int, x2:Int, y2:Int, c:UInt, a=1.0) {
		Bresenham.iterateThinLine( x1,y1,x2,y2, (x,y)->setPixel(x,y, c, a) );
	}

	public function lines(pts:Array<{x:Int, y:Int}>, c:UInt, a=1.0, loop=false) {
		if( pts.length>=2 ) {
			for(i in 1...pts.length)
				line( pts[i-1].x, pts[i-1].y, pts[i].x, pts[i].y, c, a );

			if( loop )
				line( pts[0].x, pts[0].y, pts[pts.length-1].x, pts[pts.length-1].y, c, a );
		}
	}


	inline function set_gridSize(g:Int) {
		tg.scaleX = tg.scaleY = g;
		return gridSize = g;
	}

	/** Clear all pixels **/
	public function clear() {
		pixels = new Map();
		invalidated = true;
	}

	/** Return TRUE if any pixel is set here **/
	public inline function hasPixel(x:Int, y:Int) {
		return isValid(x,y) && pixels.exists( coordId(x,y) );
	}

	/** Return pixel color without alpha (`0xrrggbb`) **/
	public inline function getPixelRGB(x:Int, y:Int) : Col {
		return isValid(x,y) && pixels.exists( coordId(x,y) ) ? Col.removeAlpha( pixels.get( coordId(x,y) ) ) : 0x0;
	}

	/** Return pixel color including alpha (`0xaarrggbb`) **/
	public inline function getPixelARGB(x:Int, y:Int) : Col {
		return isValid(x,y) && pixels.exists( coordId(x,y) ) ? pixels.get( coordId(x,y) ) : 0x0;
	}


	inline function removePixelMap(x:Int, y:Int) {
		if( isValid(x,y) ) {
			invalidated = true;
			pixels.remove( coordId(x,y) );
		}
	}

	inline function setPixelMap(x:Int, y:Int, argb:Int) {
		if( isValid(x,y) ) {
			invalidated = true;
			pixels.set( coordId(x,y), argb );
		}
	}

	/** Optimize and render **/
	override function sync(ctx:h2d.RenderContext) {
		if( invalidated ) {
			invalidated = false;

			if( optimize ) {
				// Optimized render: contiguous identical pixels are grouped in rectangles
				tg.clear();
				var c = 0;
				var w = 0;
				var h = 0;
				var dx = 0;
				var dones = new Map();
				var same = true;
				for(y in 0...hei)
				for(x in 0...wid) {
					if( hasPixel(x,y) && !dones.exists( coordId(x,y) ) ) {
						dones.set( coordId(x,y), true );
						c = pixels.get( coordId(x,y) );
						w = 1;
						// Expand horizontally
						while( isValid(x+w,y) && getPixelARGB(x+w, y)==c && !dones.exists( coordId(x+w,y) ) ) {
							dones.set(coordId(x+w, y), true);
							w++;
						}
						// Expand vertically
						h = 1;
						while( isValid(x,y+h) && pixels.get(coordId(x,y+h))==c ) {
							dx = 0;
							same = true;
							while( dx<w && isValid(x+dx,y+h) ) {
								if( pixels.get(coordId(x+dx, y+h))!=c ) {
									same = false;
									break;
								}
								dx++;
							}

							if( same ) {
								for(x in x...x+w)
									dones.set(coordId(x, y+h), true);
								h++;
							}
							else
								break;
						}

						// Fill rect
						tg.setDefaultColor( c, Col.getAlphaf(c) );
						tg.addTransform( x, y, w, h, 0, pixelTile );
					}
				}
			}
			else {
				// Un-optimized render: 1 grid pixel => 1 tilegroup object
				tg.clear();
				var c = 0;
				for(y in 0...hei)
				for(x in 0...wid) {
					if( !hasPixel(x,y) )
						continue;
					c = getPixelARGB(x,y);
					tg.setDefaultColor( c, Col.getAlphaf(c) );
					tg.add(x,y, pixelTile);
				}
			}
		}

		super.sync(ctx);
	}
}
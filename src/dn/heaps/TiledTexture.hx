package dn.heaps;

class TiledTexture extends h2d.TileGroup {
	var invalidated = true;
	public var width(default,set) : Int;
	public var height(default,set) : Int;

	public var alignPivotX(default,set) = 0.;
	public var alignPivotY(default,set) = 0.;

	public var subTilePivotX(default,set) = 0.;
	public var subTilePivotY(default,set) = 0.;

	public function new(wid:Int, hei:Int, ?texTile:h2d.Tile, ?p:h2d.Object) {
		super(texTile, p);
		width = wid;
		height = hei;
	}

	inline function set_width(v) {  invalidated = true; return width = v;  }
	inline function set_height(v) {  invalidated = true; return height = v;  }
	inline function set_alignPivotX(v) {  invalidated = true; return alignPivotX = M.fclamp(v,0,1);  }
	inline function set_alignPivotY(v) {  invalidated = true; return alignPivotY = M.fclamp(v,0,1);  }
	inline function set_subTilePivotX(v) {  invalidated = true; return subTilePivotX = M.fclamp(v,0,1);  }
	inline function set_subTilePivotY(v) {  invalidated = true; return subTilePivotY = M.fclamp(v,0,1);  }

	public inline function resize(wid:Int,hei:Int) {
		width = wid;
		height = hei;
	}

	function build() {
		clear();
		if (tile == null) return;
		var initialX = width*alignPivotX - tile.width*alignPivotX;
		initialX -= M.ceil(initialX/tile.width)*tile.width;
		var initialY = height*alignPivotY - tile.height*alignPivotY;
		initialY -= M.ceil(initialY/tile.height)*tile.height;
		var x = initialX;
		var y = initialY;
		var ox = M.round( -subTilePivotX*width );
		var oy = M.round( -subTilePivotY*height );
		var w = Std.int( tile.width );
		var h = Std.int( tile.height );
		while( y<height) {
			final subX = x<0 ? -x : 0;
			final subY = y<0 ? -y : 0;
			add( x+ox+subX, y+oy+subY, tile.sub( subX, subY, M.fmin(width-x,tile.width-subX), M.fmin(height-y,tile.height-subY) ) );
			x += w;
			if( x>=width ) {
				x = initialX;
				y += h;
			}
		}
	}

	override function sync(ctx:h2d.RenderContext) {
		if( invalidated ) {
			invalidated = false;
			build();
		}
		super.sync(ctx);
	}

	override function drawTo(t:h3d.mat.Texture) {
		if (tile == null) return;

		var initialX = width*alignPivotX - tile.width*alignPivotX;
		initialX -= M.ceil(initialX/tile.width)*tile.width;
		var initialY = height*alignPivotY - tile.height*alignPivotY;
		initialY -= M.ceil(initialY/tile.height)*tile.height;
		var x = initialX;
		var y = initialY;
		var ox = M.round( -subTilePivotX*width );
		var oy = M.round( -subTilePivotY*height );
		var w = Std.int( tile.width );
		var h = Std.int( tile.height );
		while( y<height) {
			final subX = x<0 ? -x : 0;
			final subY = y<0 ? -y : 0;
			var bmp = new h2d.Bitmap( tile.sub( subX, subY, M.fmin(width-x,tile.width-subX), M.fmin(height-y,tile.height-subY) ) );
			bmp.x = x+ox+subX;
			bmp.y = y+oy+subY;
			bmp.drawTo(t);
			x += w;
			if( x>=width ) {
				x = initialX;
				y += h;
			}
		}
	}
}

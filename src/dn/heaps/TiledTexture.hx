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
		var initialX = width*alignPivotX - M.ceil(width/tile.width) * tile.width*alignPivotX;
		var x = initialX;
		var y = height*alignPivotY - M.ceil(height/tile.height) * tile.height*alignPivotY;
		var ox = M.round( -subTilePivotX*width );
		var oy = M.round( -subTilePivotY*height );
		var w = Std.int( tile.width );
		var h = Std.int( tile.height );
		while( y<height) {
			add( x+ox, y+oy, tile.sub( 0, 0, M.fmin(width-x,tile.width), M.fmin(height-y,tile.height) ) );
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

		var initialX = width*alignPivotX - M.ceil(width/tile.width) * tile.width*alignPivotX;
		var x = initialX;
		var y = height*alignPivotY - M.ceil(height/tile.height) * tile.height*alignPivotY;
		var ox = M.round( -subTilePivotX*width );
		var oy = M.round( -subTilePivotY*height );
		var w = Std.int( tile.width );
		var h = Std.int( tile.height );
		while( y<height) {
			var bmp = new h2d.Bitmap( tile.sub( 0, 0, M.fmin(width-x,tile.width), M.fmin(height-y,tile.height) ) );
			bmp.x = x+ox;
			bmp.y = y+oy;
			bmp.drawTo(t);
			x += w;
			if( x>=width ) {
				x = initialX;
				y += h;
			}
		}
	}
}

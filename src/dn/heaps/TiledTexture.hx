package dn.heaps;

class TiledTexture extends h2d.TileGroup {
	public function new(texTile:h2d.Tile, wid:Int, hei:Int, ?p:h2d.Object) {
		super(texTile, p);
		resize(wid,hei);
	}

	public function resize(wid:Int,hei:Int) {
		clear();
		var x = 0;
		var y = 0;
		while( y<hei) {
			add( x, y, tile.sub( 0, 0, M.fmin(wid-x,tile.width), M.fmin(hei-y,tile.height) ) );
			x += Std.int(tile.width);
			if( x>=wid ) {
				x = 0;
				y += Std.int(tile.height);
			}
		}

	}
}
package dn.heaps;

class TiledTexture extends h2d.TileGroup {
	public function new(texTile:h2d.Tile, wid:Int, hei:Int, ?p:h2d.Object) {
		super(texTile, p);
		var x = 0;
		var y = 0;
		while( y<hei) {
			add( x, y, texTile.sub( 0, 0, M.fmin(wid-x,texTile.width), M.fmin(hei-y,texTile.height) ) );
			x += Std.int(texTile.width);
			if( x>=wid ) {
				x = 0;
				y += Std.int(texTile.height);
			}
		}
	}
}
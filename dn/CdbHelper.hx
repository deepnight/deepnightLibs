package dn;

import cdb.Types;

/*
	EXAMPLE:

		var lvl = Data.level.get(Lab);

		for( l in lvl.layers ) {
			var tile = hxd.Res.load(l.data.file).toTile();
			var tileSet = lvl.props.getTileset(Data.level, l.data.file);

			for(t in CdbHelper.getAllTiles(l.data, tile, lvl.width, tileSet))
				trace(t);
		}

 */

private typedef CdbTile = {
	var cx : Int;
	var cy : Int;
	var x : Int;
	var y : Int;
	var t : Null<h2d.Tile>;
}

class CdbHelper {
	public static function getH2dTile(?sheet:h2d.Tile, t:TilePos) : h2d.Tile {
		if( sheet==null )
			sheet = hxd.Res.load(t.file).toTile();
		return sheet.sub( t.x*t.size, t.y*t.size, t.size, t.size );
	}

	public static function isTileLayer(l:TileLayer) return l.data.decode()[0]!=0xFFFF;
	public static function isObjectLayer(l:TileLayer) return l.data.decode()[0]==0xFFFF;

	public static function getLayerTiles(l:TileLayer, sheet:h2d.Tile, levelWid:Int, tileSetProps:cdb.Data.TilesetProps) : Array<CdbTile> {
		var lContent = l.data.decode();

		var tiles : Array<CdbTile> = [];
		if( lContent[0]==0xFFFF ) {
			// Object layer
			lContent.shift();
			for( i in 0...Std.int(lContent.length/3) ) {
				var x = lContent[i*3];
				var y = lContent[i*3+1];
				var id = lContent[i*3+2];
				tiles.push( {
					cx : Std.int(x/l.size),
					cy : Std.int(y/l.size),
					x : x,
					y : y,
					t : getObjectTile(sheet, l.size, tileSetProps, id),
				});
			}
		}
		else {
			// Tile layer
			for(i in 0...lContent.length) {
				if( lContent[i]>0 ) {
					var pt = idxToPt(i, levelWid);
					tiles.push( {
						cx : pt.x,
						cy : pt.y,
						x : pt.x*l.size,
						y : pt.y*l.size,
						t : getTile(sheet, l.size, lContent[i]-1),
					} );
				}
			}
		}
		return tiles;
	}

	public static function getLayerPoints(l:TileLayer, levelWid:Int) : Array<CdbTile> {
		var lContent = l.data.decode();

		var tiles : Array<CdbTile> = [];
		if( lContent[0]!=0xFFFF ) {
			// Tile layer
			for(i in 0...lContent.length) {
				if( lContent[i]>0 ) {
					var pt = idxToPt(i, levelWid);
					tiles.push( {
						cx : pt.x,
						cy : pt.y,
						x : pt.x*l.size,
						y : pt.y*l.size,
						t : null,
					} );
				}
			}
		}
		return tiles;
	}


	static function getTile(sheet:h2d.Tile, tileSize:Int, idx:Int) : h2d.Tile {
		var line = Std.int(sheet.width/tileSize);
		var y = Std.int(idx/line);
		return sheet.sub( (idx-y*line)*tileSize, y*tileSize, tileSize, tileSize );
	}

	static function getObjectTile(source:h2d.Tile, tileSize:Int, props:cdb.Data.TilesetProps, idx:Int) : h2d.Tile {
		var flip = false;
		if( idx&0x8000!=0 ) {
			idx-=0x8000;
			flip = true;
		}

		var line = Std.int(source.width/tileSize);
		var y = Std.int(idx/line);
		var x = (idx-y*line);

		var t = source.sub(x*tileSize, y*tileSize, tileSize,tileSize);

		// Apply object size
		for(s in props.sets)
			if( s.x==x && s.y==y ) {
				t.setSize(s.w*tileSize, s.h*tileSize);
				break;
			}

		if( flip ) {
			t.flipX();
			t.dx += t.width;
		}

		return t;
	}


	static inline function idxToPt(id:Int, wid:Int) return {
		x : idxToX(id,wid),
		y : idxToY(id,wid),
	}
	static inline function idxToX(id:Int, wid:Int) return id - idxToY(id,wid)*wid;
	static inline function idxToY(id:Int, wid:Int) return Std.int(id/wid);

}
package dn.heaps.slib.assets;

import dn.heaps.slib.SpriteLib;

class Atlas {
	static var CACHE_ANIMS : Array<Array<Int>> = [];
	public static var LOADING_TICK_FUN : Void -> Void;

	static function ltick(){
		if( LOADING_TICK_FUN != null )
			LOADING_TICK_FUN();
	}

	public static function load(atlasPath:String, ?onReload:Void->Void, ?notZeroBaseds:Array<String>, ?properties : Array<String>) : SpriteLib {
		var notZeroMap = new Map();
		if( notZeroBaseds!=null )
			for(id in notZeroBaseds) notZeroMap.set(id, true);

		var propertiesMap = new Map<String, Int>();
		if (properties != null)
			for (i in 0...properties.length) propertiesMap.set(properties[i], properties.length - 1 - i);

		var res = hxd.Res.load(atlasPath);
		var basePath = atlasPath.indexOf("/")<0 ? "" : atlasPath.substr(0, atlasPath.lastIndexOf("/")+1);

		// Load source image separately
		/*
		var r = ~/^([a-z0-9_\-]+)\.((png)|(jpg)|(jpeg)|(gif))/igm;
		var raw = res.toText();
		var bd : hxd.BitmapData = null;
		if( r.match(raw) ) {
			bd = hxd.Res.load(basePath + r.matched(0)).toBitmap();
		}
		*/

		// Create SLib
		var atlas = res.to(hxd.res.Atlas);
		var lib = convertToSlib(atlas, notZeroMap, propertiesMap, atlasPath);
		res.watch( function() {
			#if debug
			trace("Reloaded atlas.");
			#end
			convertToSlib(atlas, notZeroMap, propertiesMap, atlasPath);
			if( onReload!=null )
				onReload();
		});

		return lib;
	}

	static function convertToSlib(atlas:hxd.res.Atlas, notZeroBaseds:Map<String,Bool>, properties : Map<String, Int>, atlasName: String) {
		ltick();
		var contents = atlas.getContents();
		ltick();

		var bestVariants = new Map<String, { rawName : String, score : Int }>();

		var propertiesReg = ~/(.*)((\.[a-z_\-]+)+)$/gi;
		for (rawName in contents.keys()) {
			var groupName  = rawName;
			var groupProps = new Array<String>();
			if (propertiesReg.match(rawName)) {
				var str    = propertiesReg.matched(2).substr(1);
				groupProps = str.split(".");
				groupName  = propertiesReg.matched(1);
			}

			var score = 0;
			if (groupProps.length > 0) {
				for (i in 0...groupProps.length) {
					var prio = properties.get(groupProps[i]);
					if (prio != null) score |= 1 << prio;
				}
				if (score == 0) continue;
			}

			var e = bestVariants.get(groupName);
			if (e == null) {
				bestVariants.set(groupName, { rawName : rawName, score : score });
			} else if (score > e.score) {
				e.rawName = rawName;
				e.score = score;
			}
		}

		var pageMap = new Map<h3d.mat.Texture, Int>();
		var pages   = new Array<h2d.Tile>();

		for (group in contents)
		for (frame in group) {
			var tex  = frame.t.getTexture();
			var page = pageMap.get(tex);
			if (page == null) {
				pageMap.set(tex, pages.length);
				ltick();
				#if hl hl.Gc.enable(false); #end
				pages.push(h2d.Tile.fromTexture(tex));
				ltick();
				// Note: avoid gc_mark() before ltick (PNG read + gc_mark in the same frame)
				#if hl hl.Gc.enable(true); #end
			}
		}

		// load normals
		var nrmPages = [];
		for (i in 0...pages.length) {
			var name = pages[i].getTexture().name;
			var nrmName = name.substr(0, name.length - 4) + "_n.png";
			ltick();
			#if hl hl.Gc.enable(false); #end
			nrmPages[i] = hxd.res.Loader.currentInstance.exists(nrmName)
				? h2d.Tile.fromTexture(hxd.Res.load(nrmName).toTexture())
				: null;
			ltick();
			// Note: avoid gc_mark() before ltick (PNG read + gc_mark in the same frame)
			#if hl hl.Gc.enable(true); #end
		}

		var lib = new dn.heaps.slib.SpriteLib(pages, nrmPages);

		var frameReg = ~/(.*?)(_?)([0-9]+)$/gi;
		var numReg = ~/^[0-9]+$/;
		for( groupName in bestVariants.keys() ) {
			var rawName = bestVariants.get(groupName).rawName;

			var content = contents.get(rawName);
			if (content.length == 1) {
				var e = content[0];
				var page = pageMap.get(e.t.getTexture());

				// Parse terminal number
				var k = groupName;
				var f = 0;
				var regBoth = false;
				if( frameReg.match(k) ) {
					k = frameReg.matched(1);
					f = Std.parseInt(frameReg.matched(3));
					if( notZeroBaseds.exists(k) )
						f--;

					// register frameData under both names for 'idle0', not for 'idle_0'
					if( frameReg.matched(2).length == 0 ) regBoth = true;
					//regBoth = true;
				}

				var fd = lib.sliceCustom(
					k, page, f,
					e.t.x, e.t.y, e.t.width, e.t.height,
					-e.t.dx, -e.t.dy, e.width, e.height
				);

				if( regBoth )
					lib.resliceCustom(groupName, 0, fd);
			} else {
				var k = groupName;
				if( k.indexOf("/")>=0 ) k = k.substr( k.lastIndexOf("/")+1 );
				for (i in 0...content.length) {
					var e = content[i];
					var page = pageMap.get(e.t.getTexture());
					lib.sliceCustom(
						k, page, i,
						e.t.x, e.t.y, e.t.width, e.t.height,
						-e.t.dx, -e.t.dy, e.width, e.height
					);
				}
			}

		}

		ltick();

		@:privateAccess {
			for( id in lib.groups.keys() ){
				var nframes = lib.countFrames(id);
				var a = CACHE_ANIMS[nframes];
				if( a == null ) {
					a = [for(i in 0...nframes) i];
					if( nframes < 256 ) CACHE_ANIMS[nframes] = a;
				}
				lib.__defineAnim(id, a);

				var p = id.lastIndexOf("/");
				if( p >= 0 ){
					var id2 = id.substr(p+1);
					if( id2 != null && id2.length > 0 && !numReg.match(id2) ){
						if( lib.groups.exists(id2) )
							trace("Warning, duplicate short name: "+id2+" in "+atlasName+":"+id);
						lib.groups.set(id2, lib.groups.get(id));
					}
				}
			}
		}

		ltick();

		return lib;
	}
}

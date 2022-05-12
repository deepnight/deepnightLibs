package dn.heaps.slib;

import dn.M;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#else
import dn.heaps.slib.SpriteInterface;
import h2d.SpriteBatch;
#end

@:structInit
class FrameData {
	public var page    : Int;
	public var x       : Int;
	public var y       : Int;
	public var wid     : Int;
	public var hei     : Int;
	public var realX   : Int;
	public var realY   : Int;
	public var realWid : Int;
	public var realHei : Int;
	#if !macro
	public var tile    : Null<h2d.Tile>;
	#end

	@:keep
	public function toString() return 'P.$page $x,$y $wid x $hei (real: $realX,$realY $realWid x $realHei)';
}

@:structInit
class LibGroup {
	public var id		: String;
	public var maxWid	: Int;
	public var maxHei	: Int;
	public var frames	: Array<FrameData>;
	public var anim		: Array<Int>;
}

enum SLBError {
	NoGroupSelected;
	GroupAlreadyExists(g:String);
	InvalidFrameDuration(s:String);
	EndFrameLower(s:String);
	InvalidFrames(s:String);
	NoCurrentGroup;
	AnimFrameExceeds(id:String, anim:String, frame:Int);
	AssetImportFailed(e:Dynamic);
	NotSameSLBFromBatch;
}


/** LIBRARY ********************************************************************************************/

class SpriteLib {
	#if !macro

	@:noCompletion
	@:deprecated("NOT SUPPORTED ANYMORE, use \"tmod\" class field")
	public static var TMOD : Float = Math.NaN;

	public static var DISABLE_ANIM_UPDATES = false;

	var groups					: Map<String, LibGroup>;
	public var defaultCenterX(default, null)	: Float;
	public var defaultCenterY(default, null)	: Float;

	public var tmod = 1.0;

	// Slicer variables
	var currentGroup			: Null<LibGroup>;
	var gridX					: Int;
	var gridY					: Int;
	var children				: Array<SpriteInterface>;

	public var tile  (get,never)     : h2d.Tile;
	public var pages (default,null) : Array<h2d.Tile>;
	public var normalPages (default, null) : Array<h2d.Tile>;

	public function new(pages : Array<h2d.Tile>, ?normalPages : Array<h2d.Tile>) {
		groups = new Map();
		defaultCenterX = 0;
		defaultCenterY = 0;
		gridX = gridY = 16;
		children = [];

		this.pages = pages;
		this.normalPages = normalPages;
	}

	inline function get_tile() {
		if (pages.length > 1) throw "Cannot access tile when there is multiple pages";
		return pages[0];
	}

	public function reloadUsing(l:SpriteLib) {
		#if debug
		trace("old="+tile.width+"x"+tile.height);
		trace("new="+l.tile.width+"x"+l.tile.height);
		#end
		tile.switchTexture(l.tile);
		groups = l.groups;
		currentGroup = null;

		for(s in children) {
			if( !exists(s.groupName) )
				throw "Group "+s.groupName+" is missing from the target SLib";
			s.set(this, s.groupName, s.frame>=countFrames(s.groupName) ? 0 : s.frame, false);
			//trace(s);
			if( s.anim.hasAnim() )
				s.anim.getCurrentAnim().frames = getGroup(s.groupName).anim;
		}
	}


	public function destroy() {
		while( children.length>0 )
			children[0].remove();

		while( pages.length > 0 ){
			var p = pages.shift();
			p.dispose();
		}

		if( normalPages != null ){
			while( normalPages.length > 0 ){
				var p = normalPages.shift();
				if( p != null )
					p.dispose();
			}
			normalPages = null;
		}
	}

	public inline function isDestroyed(){
		return pages == null || pages.length == 0;
	}

	public function preventAutoDispose(){
		for( p in pages )
			p.getTexture().preventAutoDispose();

		if( normalPages != null ){
			for( p in normalPages ){
				if( p != null )
					p.getTexture().preventAutoDispose();
			}
		}
	}

	public function ensureTexturesAllocated() @:privateAccess {
		for( p in pages ){
			var t = p.getTexture();
			if( t.t == null && t.realloc != null ) t.realloc();
		}

		if( normalPages != null ){
			for( p in normalPages ){
				if( p == null ) continue;
				var t = p.getTexture();
				if( t.t == null && t.realloc != null ) t.realloc();
			}
		}
	}

	public inline function sameTile(t:h2d.Tile) {
		return tile.getTexture().id == t.getTexture().id;
	}


	public inline function setDefaultCenterRatio(rx:Float,ry:Float) {
		defaultCenterX = rx;
		defaultCenterY = ry;
	}

	public inline function setSliceGrid(w,h) {
		gridX = w;
		gridY = h;
	}

	public inline function getGroup(?k:String) {
		return
			if(k==null )
				currentGroup;
			else
				groups.get(k);
	}

	public inline function getGroups() {
		return groups;
	}

	public inline function getAnim(k) {
		return getGroup(k).anim;
	}

	public inline function getAnimDurationF(k) {
		return getAnim(k).length;
	}

	public function createGroup(k:String) {
		if( groups.exists(k) )
			throw SLBError.GroupAlreadyExists(k);
		groups.set(k, {
			id		: k,
			maxWid	: 0,
			maxHei	: 0,
			frames	: new Array(),
			anim	: new Array(),
		});
		return setCurrentGroup(k);
	}

	inline function setCurrentGroup(k:String) {
		currentGroup = getGroup(k);
		return getGroup();
	}


	public inline function getFrameData(k:String, frame = 0) : Null<FrameData> {
		var g = getGroup(k);
		if( g==null )
			return null;
		else
			return g.frames[frame];
	}

	public inline function exists(k:String,frame=0) {
		return k!=null && frame>=0 && groups.exists(k) && groups.get(k).frames.length>frame;
	}

	public inline function getRandomFrame(k:String, ?rndFunc:Int->Int) {
		return (rndFunc==null ? Std.random : rndFunc)( countFrames(k) );
	}

	public inline function countFrames(k:String) {
		if( !exists(k) )
			throw "Unknown group "+k;
		return getGroup(k).frames.length;
	}



	/******************************************************
	* ATLAS INIT FUNCTIONS
	******************************************************/

	public function sliceCustom(groupName:String, page:Int, frame:Int, x:Int, y:Int, wid:Int, hei:Int, realX:Int, realY:Int, realWid: Int, realHei: Int) {
		var g = if( exists(groupName) ) getGroup(groupName) else createGroup(groupName);
		g.maxWid = M.imax( g.maxWid, wid );
		g.maxHei = M.imax( g.maxHei, hei );

		// if( realFrame==null )
		// 	realFrame = {x:0, y:0, realWid:wid, realHei:hei}

		var fd : FrameData = { page:page, x:x, y:y, wid:wid, hei:hei, realX: realX, realY: realY, realWid: realWid, realHei: realHei, tile: null };
		g.frames[frame] = fd;
		return fd;
	}

	public function resliceCustom( groupName: String, frame: Int, fd: FrameData ){
		var g = if( exists(groupName) ) getGroup(groupName) else createGroup(groupName);
		g.maxWid = M.imax( g.maxWid, fd.wid );
		g.maxHei = M.imax( g.maxHei, fd.hei );
		g.frames[frame] = fd;
		return fd;
	}

	public function slice(groupName:String, page:Int, x:Int, y:Int, wid:Int, hei:Int, repeatX=1, repeatY=1) {
		var g = createGroup(groupName);
		setCurrentGroup(groupName);
		g.maxWid = M.imax( g.maxWid, wid );
		g.maxHei = M.imax( g.maxHei, hei );
		for(iy in 0...repeatY)
			for(ix in 0...repeatX)
				g.frames.push({page : page, x : x+ix*wid, y : y+iy*hei, wid:wid, hei:hei, realX:0, realY:0, realWid: wid, realHei: hei, tile: null });
	}

	public function sliceGrid(groupName:String, page:Int, gx:Int, gy:Int, repeatX=1, repeatY=1) {
		var g = createGroup(groupName);
		setCurrentGroup(groupName);
		g.maxWid = M.imax( g.maxWid, gridX );
		g.maxHei = M.imax( g.maxHei, gridY );
		for(iy in 0...repeatY)
			for(ix in 0...repeatX)
				g.frames.push({page : page, x : gridX*(gx+ix), y : gridY*(gy+iy), wid:gridX, hei:gridY, realX:0, realY:0, realWid:gridX, realHei:gridY, tile: null });
	}

	public function sliceAnim(groupName:String, page:Int, frameDuration:Int, x:Int, y:Int, wid:Int, hei:Int, repeatX=1, repeatY=1) {
		slice(groupName, page, x, y, wid, hei, repeatX, repeatY);
		var frames = [];
		for(f in 0...repeatX*repeatY)
			for(i in 0...frameDuration)
				frames.push(f);
		__defineAnim(groupName, frames);
	}

	public function sliceAnimGrid(groupName:String, page:Int, frameDuration:Int, gx:Int, gy:Int, repeatX=1, repeatY=1) {
		sliceGrid(groupName, page, gx, gy, repeatX, repeatY);
		var frames = [];
		for(f in 0...repeatX*repeatY)
			for(i in 0...frameDuration)
				frames.push(f);
		__defineAnim(groupName, frames);
	}

	public function multiplyAllAnimDurations(factor:Int) {
		for(g in getGroups())
			if( g.anim.length>0 ) {
				var old = g.anim.copy();
				g.anim = [];
				for(f in old)
					for(i in 0...factor)
						g.anim.push(f);
			}
	}



	@:keep
	public function toString() {
		var l = [];
		for ( k in getGroups().keys() ) {
			var g = getGroup(k);
			l.push(
				k+" ("+g.maxWid+"x"+g.maxHei+")" +
				( g.frames.length>1 ? " "+g.frames.length+"f" : "" ) +
				( g.anim.length>1 ? " animated("+g.anim.length+"f)" : "" )
			);
		}
		l.sort(function(a,b) return Reflect.compare(a,b));
		return "| "+l.join("\n| ");
	}


	public inline function listAnims() {
		var l = [];
		for ( k in getGroups().keys() ) {
			var g = getGroup(k);
			if( g.anim.length>1 )
				l.push(k+" ("+g.maxWid+"x"+g.maxHei+") : "+g.frames.length+" frame(s), anim("+g.anim.length+"f)" );
		}
		l.sort(function(a,b) return Reflect.compare(a,b));
		return l;
	}


	public inline function addChild(s:SpriteInterface) {
		children.push(s);
	}

	public inline function removeChild(s:SpriteInterface) {
		children.remove(s);
	}

	public inline function countChildren() {
		return children.length;
	}



	/******************************************************
	* HEAPS API
	******************************************************/

	public inline function h_get(k:String, ?frame=0, ?xr=0., ?yr=0., ?smooth:Null<Bool>, ?p:h2d.Object) : HSprite {
		var s = new HSprite(this, k, frame);
		if( p!=null )
			p.addChild(s);
		s.setCenterRatio(xr,yr);
		if( smooth!=null )
			s.smooth = smooth;
		return s;
	}

	public inline function h_getRandom(k, ?rndFunc, ?p:h2d.Object) : HSprite {
		return h_get(k, getRandomFrame(k, rndFunc), p);
	}

	public inline function h_getAndPlay(k:String, ?plays=99999, ?killAfterPlay=false, ?p:h2d.Object) : HSprite {
		var s = h_get(k, p);
		s.anim.play(k, plays);
		if( killAfterPlay )
			s.anim.killAfterPlay();
		return s;
	}



	public inline function hbe_get(sb:HSpriteBatch, k:String, ?frame=0, ?xr=0., ?yr=0.) : HSpriteBE {
		var e = new HSpriteBE(sb, this, k, frame);
		e.setCenterRatio(xr,yr);
		return e;
	}

	public inline function hbe_getRandom(sb:HSpriteBatch, k, ?rndFunc) : HSpriteBE {
		return hbe_get(sb, k, getRandomFrame(k, rndFunc));
	}

	public inline function hbe_getAndPlay(sb:HSpriteBatch, k:String, plays=99999, ?killAfterPlay=false) : HSpriteBE {
		var s = hbe_get(sb, k);
		s.anim.play(k, plays);
		if( killAfterPlay )
			s.anim.killAfterPlay();
		return s;
	}

	public inline function be_get(sb:h2d.SpriteBatch, k:String, f=0, xr=0., yr=0.) : BatchElement {
		var e = new h2d.SpriteBatch.BatchElement( getTile(k,f) );
		e.t.setCenterRatio(xr,yr);
		sb.add(e);
		return e;
	}

	public inline function be_getRandom(sb:h2d.SpriteBatch, k:String, ?rndFunc) : BatchElement {
		var e = be_get(sb, k, getRandomFrame(k, rndFunc));
		sb.add(e);
		return e;
	}

	public inline function getTile(g:String, frame=0, px:Float=0.0, py:Float=0.0) : h2d.Tile {
		var fd = getFrameData(g, frame);
		if ( fd == null)
			throw 'Unknown group $g#$frame!';
		var t  = pages[fd.page].clone();
		return updTile(t, g,frame,px,py);
	}

	public inline function getBitmap(g:String, ?frame=0, ?px:Float=0.0, ?py:Float=0.0, ?p:h2d.Object) : h2d.Bitmap {
		return new h2d.Bitmap( getTile(g,frame,px,py), p );
	}

	public inline function updTile(t:h2d.Tile, g:String, frame=0, px:Float=0.0, py:Float=0.0) : h2d.Tile {
		var fd = getFrameData(g, frame);
		if ( fd == null)
			throw 'Unknown group $g#$frame!';

		t.setPosition(fd.x, fd.y);
		t.setSize(fd.wid, fd.hei);

		t.dx = -Std.int( fd.realWid * px + fd.realX );
		t.dy = -Std.int( fd.realHei * py + fd.realY );

		return t;
	}

	public inline function getTileRandom(g:String, px:Float=0.0, py:Float=0.0, ?rndFunc) : h2d.Tile {
		return getTile(g, getRandomFrame(g,rndFunc), px, py);
	}

	public inline function getCachedTile( g:String, frame=0 ) : h2d.Tile {
		var fd = getFrameData(g, frame);
		if ( fd == null)
			throw 'Unknown group $g#$frame!';
		if( fd.tile == null )
			fd.tile = getTile(g,frame);
		return fd.tile;
	}

	#end // End of #if !macro


	/**********************************************
	 * MACRO SECTION
	 **********************************************/

	public static function parseAnimDefinition(animDef:String,?timin=1) {
		animDef = StringTools.replace(animDef, ")", "(");
		var frames : Array<Int> = new Array();
		var parts = animDef.split(",");
		for (p in parts) {
			var curTiming = timin;
			if( p.indexOf("(")>0 ) {
				var t = Std.parseInt( p.split("(")[1] );
				if( Math.isNaN(t) )
					throw SLBError.InvalidFrameDuration(p);
				curTiming = t;
				p = p.substr( 0, p.indexOf("(") );
			}
			if( p.indexOf("-")<0 ) {
				var f = Std.parseInt(p);
				for(i in 0...curTiming)
					frames.push(f);
				continue;
			}
			if( p.indexOf("-")>0 ) {
				var from = Std.parseInt(p.split("-")[0]);
				var to = Std.parseInt(p.split("-")[1])+1;
				if( to<from )
					throw SLBError.EndFrameLower(p);
				while( from<to ) {
					for(i in 0...curTiming)
						frames.push(from);
					from++;
				}
				continue;
			}
			throw SLBError.InvalidFrames(p);
		}
		return frames;
	}


	public function generateAnim(group:String, seq:String) {
		__defineAnim( group, parseAnimDefinition(seq) );
	}

	@:noCompletion
	public function __defineAnim(?group:String, anim:Array<Int>) {
		#if !macro
		if( currentGroup==null && group==null )
			throw SLBError.NoCurrentGroup;

		if( group!=null )
			setCurrentGroup(group);

		for(f in anim)
			if( f>=currentGroup.frames.length )
				throw SLBError.AnimFrameExceeds(currentGroup.id, "["+anim.join(",")+"] "+currentGroup.frames.length, f);

		currentGroup.anim = anim;
		#end
	}




	#if macro
	static function error( ?msg="", p : Position ) {
		haxe.macro.Context.error(msg, p);
	}
	#end


	/* MACRO : Animation declaration ********************************************************************************************
	 *
	 * SYNTAX 1: frame[(optional_duration)], frame[(optional_duration)], ...
	 * SYNTAX 2: begin-end[(optional_duration)], begin-end[(optional_duration)], ...
	 *
	 * EXAMPLE: defineAnim( "walk", "0-5, 6(2), 7(1)" );
	 */
	public macro function defineAnim(ethis:Expr, ?groupName:String, ?baseFrame:Int, ?animDefinition:Expr) : Expr {
		var p = ethis.pos;
		var def = animDefinition;

		function parseError(str:String) {
			error(str + "\nSYNTAX: frame[(duration)], frame[(duration)], begin-end([duration]), ...", def.pos);
		}

		// Parameters
		if( isNull(def) && groupName==null )
			error("missing anim declaration", p);

		if( isNull(def) && groupName!=null ) {
			def = {expr:EConst(CString(groupName)), pos:p};
			groupName = null;
		}

		if( baseFrame==null )
			baseFrame = 0;

		if( isNull(def) )
			parseError("animation definition is required");

		var str = switch(def.expr) {
			case EConst(c) :
				switch( c ) {
					case CString(s) : s;
					default :
						parseError("a constant string is required here");
						null;
				}
			default :
				parseError("a constant string is required here");
				null;
		}

		var frames : Array<Int> = try{ parseAnimDefinition(str); } catch(e:Dynamic) { parseError(e); null; }

		var eframes = Lambda.array(Lambda.map(frames, function(f) return { pos:p, expr:EConst( CInt(Std.string(f)) ) } ));
		var arrayExpr = { pos:p, expr:EArrayDecl(eframes) };

		if( groupName==null )
			return macro $ethis.__defineAnim($arrayExpr);
		else {
			var groupExpr = { pos:p, expr:EConst(CString(groupName)) };
			return macro $ethis.__defineAnim($groupExpr, $arrayExpr);
		}
	}


	#if macro
	static function isNull(e:Expr) {
		switch(e.expr) {
			case EConst(c) :
				switch( c ) {
					case CIdent(v) : return v=="null";
					default :
						return false;
				}
			default :
				return false;
		}
	}
	#end
}




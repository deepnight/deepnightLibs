package dn.heaps.slib;

import h2d.Drawable;
import h2d.SpriteBatch;
import dn.heaps.slib.SpriteLib;
import dn.heaps.slib.SpriteInterface;
import dn.M;

class HSpriteBE extends BatchElement implements SpriteInterface {
	public var anim(get,never) : AnimManager;
	var _animManager : AnimManager;

	public var lib : SpriteLib;
	public var groupName : String;
	public var group : LibGroup;
	public var frame : Int;
	public var frameData : FrameData;
	public var pivot : SpritePivot;
	public var destroyed : Bool;
	public var animAllocated(get,never) : Bool;

	public var onAnimManAlloc : Null<AnimManager->Void>;
	public var onFrameChange: Null<Void->Void>;

	var allocated : Bool;

	public function new(sb:HSpriteBatch, l:SpriteLib, g:String, ?f=0) {
		super( l.tile.clone() );
		destroyed = false;

		pivot = new SpritePivot();

		sb.add(this);
		set(l,g,f);
	}

	@:allow(HSpriteBatch)
	function onAdd(){
		if( allocated ) return;
		allocated = true;
		if( lib != null )
			lib.addChild( this );
	}

	@:allow(HSpriteBatch)
	function onRemove(){
		if( !allocated ) return;
		allocated = false;
		if( lib != null )
			lib.removeChild( this );
	}

	inline function get_anim() {
		if( _animManager==null ) {
			_animManager = new AnimManager(this);
			if( batch!=null )
				batch.hasUpdate = true;
			if( onAnimManAlloc!=null )
				onAnimManAlloc(_animManager);
		}

		return _animManager;
	}

	inline function get_animAllocated() return _animManager!=null;

	public inline function disposeAnimManager() {
		if( animAllocated ) {
			_animManager.destroy();
			_animManager = null;
		}
	}

	public function toString() return "HSpriteBE_"+groupName+"["+frame+"]";

	public inline function set( ?l:SpriteLib, ?g:String, ?f=0, ?stopAllAnims=false ) {
		var changed = false;
		if( l!=null && lib!=l ) {
			changed = true;
			// Reset existing frame data
			if( g==null ) {
				groupName = null;
				group = null;
				frameData = null;
			}

			// Register SpriteLib
			if( allocated && lib!=null )
				lib.removeChild(this);
			lib = l;
			if( allocated )
				lib.addChild(this);
			if( pivot.isUndefined )
				setCenterRatio(lib.defaultCenterX, lib.defaultCenterY);
		}

		if( g!=null && g!=groupName ) {
			changed = true;
			groupName = g;
		}

		if( f!=null && f!=frame ) {
			changed = true;
			frame = f;
		}

		if( isReady() && changed ) {
			if( stopAllAnims && _animManager!=null )
				anim.stopWithoutStateAnims();

			group = lib.getGroup(groupName);
			frameData = lib.getFrameData(groupName, f);
			if( frameData==null )
				throw 'Unknown frame: $groupName($f)';

			updateTile();

			if( onFrameChange!=null )
				onFrameChange();
		}
	}



	public inline function setRandom(?l:SpriteLib, g:String, ?rndFunc:Int->Int) {
		set(l, g, lib.getRandomFrame(g, rndFunc==null ? Std.random : rndFunc));
	}

	public inline function setRandomFrame(?rndFunc:Int->Int) {
		if( isReady() )
			setRandom(groupName, rndFunc==null ? Std.random : rndFunc);
	}

	public inline function isGroup(k) {
		return groupName==k;
	}

	public inline function is(k, ?f=-1) return groupName==k && (f<0 || frame==f);

	public inline function isReady() {
		return !destroyed && groupName!=null;
	}

	public function fitToBox(w:Float, ?h:Null<Float>, ?useFrameDataRealSize=false) {
		if( useFrameDataRealSize )
			setScale( M.fmin( w/frameData.realWid, (h==null?w:h)/frameData.realHei ) );
		else
			setScale( M.fmin( w/t.width, (h==null?w:h)/t.height ) );
	}

	public inline function setScale(v:Float) scale = v;
	public inline function setPos(x:Float, y:Float) setPosition(x,y);
	public inline function setPosition(x:Float, y:Float) {
		this.x = x;
		this.y = y;
	}

	public function setFrame(f:Int) {
		var changed = f!=frame;
		frame = f;

		if( isReady() && changed ) {
			frameData = lib.getFrameData(groupName, frame);
			if( frameData==null )
				throw 'Unknown frame: $groupName($frame)';

			if( onFrameChange!=null )
				onFrameChange();

			updateTile();
		}
	}

	public inline function setPivotCoord(x:Float, y:Float) {
		pivot.setCoord(x, y);
		updateTile();
	}

	public inline function setCenterRatio(xRatio=0.5, yRatio=0.5) {
		pivot.setCenterRatio(xRatio, yRatio);
		updateTile();
	}

	public inline function totalFrames() {
		return group.frames.length;
	}


	public inline function uncolorize() {
		dn.legacy.Color.uncolorizeBatchElement(this);
	}
	public inline function colorize(c:UInt, ?ratio=1.0) {
		dn.legacy.Color.colorizeBatchElement(this, c, ratio);
	}
	public inline function isColorized() return r!=1 || g!=1 || b!=1;


	function updateTile() {
		if( !isReady() )
			return;


		var fd = frameData;
		lib.updTile(t, groupName, frame);

		if ( pivot.isUsingCoord() ) {
			t.dx = M.round(-pivot.coordX - fd.realX);
			t.dy = M.round(-pivot.coordY - fd.realY);
		}

		if ( pivot.isUsingFactor() ){
			t.dx = -Std.int(fd.realWid * pivot.centerFactorX + fd.realX);
			t.dy = -Std.int(fd.realHei * pivot.centerFactorY + fd.realY);
		}
	}

	public inline function dispose() remove();
	override function remove() {
		super.remove();

		if( !destroyed ) {
			destroyed = true;
			disposeAnimManager();
		}
	}

	override function update(et:Float) {
		if( animAllocated )
			anim.update( lib!=null ? lib.tmod : 1 );

		return super.update(et);
	}
}

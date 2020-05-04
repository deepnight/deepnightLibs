package dn.heaps.slib;

import dn.heaps.slib.SpriteLib;

interface SpriteInterface {

	public var lib : SpriteLib;
	public var group : Null<LibGroup>;
	public var groupName : Null<String>;
	public var frame(default,null) : Int;
	public var pivot : SpritePivot;
	private var frameData : FrameData;
	public var destroyed : Bool;

	public var animAllocated(get,never) : Bool;
	private var _animManager : AnimManager;
	public var anim(get,never) : AnimManager;

	public var onAnimManAlloc : Null<AnimManager->Void>;
	public var onFrameChange : Null<Void->Void>;



	private function toString() : String;
	public function remove() : Void;
	public function isReady() : Bool;

	public function set(?l:SpriteLib, ?g:String, ?frame:Int, ?stopAllAnims:Bool) : Void;
	public function setFrame(f:Int) : Void;
	public function setRandom(?l:SpriteLib, g:String, rndFunc:Int->Int) : Void;
	public function setRandomFrame(?rndFunc:Int->Int) : Void;

	public function isGroup(k:String) : Bool;
	public function is(k:String, ?f:Int) : Bool;

	public function setScale(#if h2d v:hxd.Float32 #else v:Float #end) : Void;
	public function setPos(x:Float, y:Float) : Void;
	public function setPivotCoord(x:Float, y:Float) : Void;
	public function setCenterRatio(xr:Float=0.5, yr:Float=0.5) : Void;
	public function fitToBox(w:Float, ?h:Null<Float>, ?useFrameDataRealSize:Bool=false) : Void;

	public function totalFrames() : Int;

	public function disposeAnimManager() : Void;
}

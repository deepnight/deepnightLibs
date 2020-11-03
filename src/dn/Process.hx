package dn;

import dn.Lib;

class Process {
	public static var CUSTOM_STAGE_WIDTH  = -1;
	public static var CUSTOM_STAGE_HEIGHT = -1;

	static var UNIQ_ID = 0;
	static var ROOTS : Array<Process> = [];

	public var uniqId : Int;
	public var ftime(default, null) : Float; // elapsed frames
	public var itime(get, never) : Int;
	public var paused(default, null) : Bool;
	public var destroyed(default, null) : Bool;
	var parent(default, null) : Process;

	public var utmod : Float; // this tmod value is unaffected by the time multiplier
	public var tmod(get,never) : Float; inline function get_tmod() return utmod * getComputedTimeMultiplier();
	public var uftime(default, null) : Float; // elapsed frames not affected by time multiplier
	var baseTimeMul = 1.0;

	public var dt(get,never) : Float; inline function get_dt() return tmod; // deprecated, kept for Dead Cells prod version in January 2019

	public var name : String;
	var children : Array<Process>;

	// Tools
	public var delayer : dn.Delayer;
	public var cd : dn.Cooldown;
	public var tw : dn.Tweenie;

	// Tools not affected by timeMultiplier
	public var udelayer : dn.Delayer;
	public var ucd : dn.Cooldown;

	// Fixed update
	public var fixedUpdateFps = 30;
	var _fixedUpdateCounter = 0.;

	// Optional graphic context
	#if( heaps || h3d )
	public var root			: Null<h2d.Layers>;
	public var engine(get,never)	: h3d.Engine;
	#elseif flash
	public var root			: Null<flash.display.Sprite>;
	var pt0					: flash.geom.Point;
	#end

	public function new(?parent : Process) {
		init();

		if (parent == null)
			ROOTS.push(this);
		else
			parent.addChild(this);
	}

	public function init(){
		name = "process";
		uniqId = UNIQ_ID++;
		children = [];
		paused = false;
		destroyed = false;
		ftime = 0;
		uftime = 0;
		utmod = 1;
		baseTimeMul = 1;

		cd = new Cooldown( getDefaultFrameRate() );
		delayer = new Delayer( getDefaultFrameRate() );
		tw = new Tweenie( getDefaultFrameRate() );

		ucd = new Cooldown( getDefaultFrameRate() );
		udelayer = new Delayer( getDefaultFrameRate() );
	}

	var _initOnceDone = false;
	function initOnceBeforeUpdate() {}

	// -----------------------------------------------------------------------
	// Graphic context (optional)
	// -----------------------------------------------------------------------

	#if( heaps || flash )
	public function createRoot(
		 #if heaps ?ctx:h2d.Object
		 #elseif flash ?ctx:flash.display.Sprite #end
	) {
		if( root!=null )
			throw this+": root already created!";

		if( ctx==null ) {
			if( parent==null || parent.root==null )
				throw this+": context required";
			ctx = parent.root;
		}

		#if( heaps || h3d )
			root = new h2d.Layers(ctx);
		#elseif flash
			root = new flash.display.Sprite();
			ctx.addChild(root);
			pt0 = new flash.geom.Point();
		#end
	}
	#end

	#if heaps
	public function createRootInLayers(ctx:h2d.Layers, plan:Int) {
		if( root!=null )
			throw this+": root already exists";
		root = new h2d.Layers();
		ctx.add(root, plan);
	}
	#end



	// -----------------------------------------------------------------------
	// overridable functions
	// -----------------------------------------------------------------------

	public function preUpdate() {}
	public function update() {}
	public function fixedUpdate() { }
	public function postUpdate() { }
	public function onResize() { }
	public function onDispose() { }

	public dynamic function onUpdateCb() {}
	public dynamic function onFixedUpdateCb() {}
	public dynamic function onDisposeCb() {}


	// -----------------------------------------------------------------------
	// private api
	// -----------------------------------------------------------------------

	@:keep function toString() return name+":"+uniqId;
	inline function get_itime() return Std.int(ftime);
	#if( heaps || h3d )
	inline function get_engine() return h3d.Engine.getCurrent();
	#end
	inline function addAlpha(c:Int, ?a=1.0) : #if flash UInt #else Int #end {
		return Std.int(a*255)<<24 | c;
	}
	inline function rnd(min,max,?sign) return Lib.rnd(min,max,sign);
	inline function irnd(min,max,?sign) return Lib.irnd(min,max,sign);
	inline function rndSign() return Std.random(2)*2-1;
	public inline function pretty(v:Float, ?precision=2) return M.pretty(v, precision);
	inline function rndSecondsF(min,max,?sign) return secToFrames( Lib.rnd(min,max,sign) );
	inline function irndSecondsF(min,max,?sign) return secToFrames( Lib.rnd(min,max,sign) );

	public function secToFrames(v:Float) return v*getDefaultFrameRate();
	public function framesToSec(v:Float) return v/getDefaultFrameRate();

	public inline function msToFrames(v:Float) return (v/1000)*getDefaultFrameRate();
	public inline function framesToMs(v:Float) return 1000*v/getDefaultFrameRate();

	function getDefaultFrameRate() : Float {
		#if heaps
		return hxd.Timer.wantedFPS;
		#elseif flash
		return flash.Lib.current.stage.frameRate;
		#else
		return 30; // N/A
		#end
	}


	public function setTimeMultiplier(v:Float) {
		baseTimeMul = v;
	}

	function getComputedTimeMultiplier() : Float {
		return M.fmax(0, baseTimeMul * ( parent==null ? 1 : parent.getComputedTimeMultiplier() ) );
	}


	// -----------------------------------------------------------------------
	// public api
	// -----------------------------------------------------------------------

	public inline function w(){
		if( CUSTOM_STAGE_WIDTH > 0 )
			return CUSTOM_STAGE_WIDTH;
		#if heaps
		return hxd.Window.getInstance().width;
		#elseif (flash||openfl)
		return flash.Lib.current.stage.stageWidth;
		#else
		return 1;
		#end
	}
	public inline function h(){
		if( CUSTOM_STAGE_HEIGHT > 0 )
			return CUSTOM_STAGE_HEIGHT;
		#if heaps
		return hxd.Window.getInstance().height;
		#elseif (flash||openfl)
		return flash.Lib.current.stage.stageHeight;
		#else
		return 1;
		#end
	}

	public function pause() paused = true;
	public function resume() paused = false;
	public inline function togglePause() paused ? resume() : pause();
	public inline function destroy() destroyed = true;

	public function addChild( p : Process ) {
		if (p.parent == null) ROOTS.remove(p);
		else p.parent.children.remove(p);
		p.parent = this;
		children.push(p);
	}

	public inline function isRootProcess() return parent==null;

	public function moveChildToRootProcesses( p : Process ) {
		if( p.parent!=this )
			throw "Not a child of this process";

		p.parent = null;
		children.remove(p);
		ROOTS.push(p);
	}

	public function removeAndDestroyChild( p : Process ) {
		if( p.parent!=this )
			throw "Not a child of this process";

		p.parent = null;
		children.remove(p);
		ROOTS.push(p); // needed for garbage collector
		p.destroy();
	}

	public function createChildProcess( ?onUpdate:Process->Void, ?onDispose:Process->Void, ?runUpdateImmediatly=false ) : Process {
		var p = new dn.Process(this);
		p.name = "childProcess";
		if( onUpdate!=null )
			p.onUpdateCb = function() {
				onUpdate(p);
			}

		if( onDispose!=null )
			p.onDisposeCb = function() {
				onDispose(p);
			}

		if( runUpdateImmediatly ) {
			_doPreUpdate(p,1);
			_doMainUpdate(p);
		}

		return p;
	}

	public function killAllChildrenProcesses() {
		for(p in children)
			p.destroy();
	}

	// -----------------------------------------------------------------------
	// Internals statics
	// -----------------------------------------------------------------------

	static inline function canRun(p:Process) return !p.paused && !p.destroyed;

	static inline function _doPreUpdate(p:Process, utmod:Float) {
		if( !canRun(p) )
			return;

		p.utmod = utmod;
		p.ftime += p.tmod;
		p.uftime += p.utmod;

		p.delayer.update(p.tmod);

		if( canRun(p) )
			p.udelayer.update(p.utmod);

		if( canRun(p) )
			p.cd.update(p.tmod);

		if( canRun(p) )
			p.ucd.update(p.utmod);

		if( canRun(p) )
			p.tw.update(p.tmod);

		if( canRun(p) ) {
			if( !p._initOnceDone ) {
				p.initOnceBeforeUpdate();
				p._initOnceDone = true;
			}
			p.preUpdate();
		}

		if( canRun(p) )
			for (c in p.children)
				_doPreUpdate(c,p.utmod);
	}

	static function _doMainUpdate(p : Process) {
		if( !canRun(p) )
			return;

		p.update();
		if( p.onUpdateCb!=null )
			p.onUpdateCb();

		if( canRun(p) )
			for (p in p.children)
				_doMainUpdate(p);
	}

	static function _doFixedUpdate(p : Process) {
		if( !canRun(p) )
			return;

		p._fixedUpdateCounter+=p.tmod;
		while( p._fixedUpdateCounter >= p.getDefaultFrameRate() / p.fixedUpdateFps ) {
			p._fixedUpdateCounter -= p.getDefaultFrameRate() / p.fixedUpdateFps;
			if( canRun(p) ) {
				p.fixedUpdate();
				if( p.onFixedUpdateCb!=null )
					p.onFixedUpdateCb();
			}
		}

		if( canRun(p) )
			for (p in p.children)
				_doFixedUpdate(p);
	}

	static inline function _doPostUpdate(p : Process) {
		if( !canRun(p) )
			return;

		p.postUpdate();

		if( !p.destroyed )
			for (c in p.children)
				_doPostUpdate(c);
	}

	static function _garbageCollector(plist:Array<Process>) {
		var i = 0;
		while (i < plist.length) {
			var p = plist[i];
			if( p.destroyed )
				_disposeProcess(p);
			else {
				_garbageCollector(p.children);
				i++;
			}
		}
	}

	static function _disposeProcess(p : Process) {
		// Children
		for(p in p.children)
			p.destroy();
		_garbageCollector(p.children);

		// Tools
		p.delayer.destroy();
		p.cd.destroy();
		p.tw.destroy();

		// Unregister from lists
		if (p.parent != null) {
			p.parent.children.remove(p);
		}
		else
			ROOTS.remove(p);

		// Graphic context
		#if( heaps || flash )
		if( p.root!=null ) {
			#if( heaps || h3d )
			p.root.remove();
			#else
			p.root.parent.removeChild(p.root);
			#end
		}
		#end

		// Callbacks
		p.onDispose();
		if( p.onDisposeCb != null )
			p.onDisposeCb();

		// Clean up
		p.parent = null;
		p.children = null;
		p.delayer = null;
		p.cd = null;
		p.tw = null;
		#if( heaps || h3d )
		p.root = null;
		#elseif flash
		p.root = null;
		p.pt0 = null;
		#end
	}

	static inline function _resizeProcess(p : Process) {
		if ( !p.destroyed ){
			p.onResize();
			for ( p in p.children )
				_resizeProcess(p);
		}
	}

	// -----------------------------------------------------------------------
	// Public static API
	// -----------------------------------------------------------------------

	public static function updateAll(utmod:Float) {
		for (p in ROOTS)
			_doPreUpdate(p, utmod);

		for (p in ROOTS)
			_doMainUpdate(p);

		for (p in ROOTS)
			_doFixedUpdate(p);

		for (p in ROOTS)
			_doPostUpdate(p);

		_garbageCollector(ROOTS);
	}

	public static function resizeAll() {
		for ( p in ROOTS )
			_resizeProcess(p);
	}
}

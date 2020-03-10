package dn;

import dn.Lib;

class Process {
	public static var CUSTOM_STAGE_WIDTH  = -1;
	public static var CUSTOM_STAGE_HEIGHT = -1;

	static var UNIQ_ID = 0;
	static var ROOTS : Array<Process> = [];

	public var uniqId					: Int;
	public var ftime(default, null)		: Float; // elapsed frames
	public var itime(get, never)		: Int;
	public var paused(default, null)	: Bool;
	public var destroyed(default, null)	: Bool;
	public var speedMod                 : Float;
	var parent(default, null)			: Process;
	public var tmod						: Float;

	public var dt(get,never) : Float; inline function get_dt() return tmod; // deprecated, kept for Dead Cells prod version in January 2019

	public var name			: String;
	var children			: Array<Process>;

	// Tools
	public var delayer		: dn.Delayer;
	public var cd			: dn.Cooldown;
	public var tw			: dn.Tweenie;

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
		tmod = 1;
		speedMod = 1.0;

		delayer = new Delayer( getDefaultFrameRate() );
		cd = new Cooldown( getDefaultFrameRate() );
		tw = new Tweenie( getDefaultFrameRate() );
	}

	// -----------------------------------------------------------------------
	// Graphic context (optional)
	// -----------------------------------------------------------------------

	public function createRoot( #if( heaps || h3d )    ?ctx:h2d.Object    #else    ?ctx:flash.display.Sprite   #end) {
		if( root!=null )
			throw this+": root already created!";

		if( ctx==null ) {
			if( parent==null || parent.root==null )
				throw this+": context required";
			ctx = parent.root;
		}

		#if( heaps || h3d )
		root = new h2d.Layers(ctx);
		#else
		root = new flash.display.Sprite();
		ctx.addChild(root);
		pt0 = new flash.geom.Point();
		#end
	}

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
	public function postUpdate() { }
	public function onResize() { }
	public function onDispose() { }

	public dynamic function onUpdateCb() {}
	public dynamic function onDisposeCb() {}


	// -----------------------------------------------------------------------
	// private api
	// -----------------------------------------------------------------------

	function toString() return name+":"+uniqId;
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
		#else
		return flash.Lib.current.stage.frameRate;
		#end
		//#if heaps
		//return hxd.System.getDefaultFrameRate();
		//#elseif h3d
		//return hxd.Stage.getInstance().getFrameRate();
		//#else
		//return flash.Lib.current.stage.frameRate;
		//#end
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
		#end
	}
	public inline function h(){
		if( CUSTOM_STAGE_HEIGHT > 0 )
			return CUSTOM_STAGE_HEIGHT;
		#if heaps
		return hxd.Window.getInstance().height;
		#elseif (flash||openfl)
		return flash.Lib.current.stage.stageHeight;
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

	public function removeChild( p : Process ) {
		if( p.parent != this ) throw "invalid parent access";
		p.parent = null;
		children.remove(p);
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
			_doProcessPreUpdate(p,1);
			_doProcessMainUpdate(p);
		}

		return p;
	}

	public function killAllChildrenProcesses() {
		for(p in children)
			p.destroy();
	}

	// -----------------------------------------------------------------------
	// internals statics
	// -----------------------------------------------------------------------

	static inline function _doProcessPreUpdate(p:Process, tmod:Float) {
		if( p.paused || p.destroyed )
			return;

		tmod *= p.speedMod;

		p.tmod = tmod;
		p.ftime += tmod;

		p.delayer.update(tmod);

		if( !p.paused && !p.destroyed )
			p.cd.update(tmod);

		if( !p.paused && !p.destroyed )
			p.tw.update(tmod);

		if( !p.paused && !p.destroyed )
			p.preUpdate();

		if( !p.destroyed )
			for (c in p.children)
				_doProcessPreUpdate(c,tmod);
	}

	static function _doProcessMainUpdate(p : Process) {
		if( p.paused || p.destroyed )
			return;

		p.update();
		if( p.onUpdateCb!=null )
			p.onUpdateCb();

		if( !p.paused && !p.destroyed )
			for (p in p.children)
				_doProcessMainUpdate(p);
	}

	static inline function _doProcessPostUpdate(p : Process) {
		if( p.paused || p.destroyed )
			return;

		p.postUpdate();

		if( !p.destroyed )
			for (c in p.children)
				_doProcessPostUpdate(c);
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
		if( p.root!=null ) {
			#if( heaps || h3d )
			p.root.remove();
			#else
			p.root.parent.removeChild(p.root);
			#end
		}

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
		#else
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

	public static function updateAll(tmod:Float) {
		for (p in ROOTS)
			_doProcessPreUpdate(p, tmod);

		for (p in ROOTS)
			_doProcessMainUpdate(p);

		for (p in ROOTS)
			_doProcessPostUpdate(p);

		_garbageCollector(ROOTS);
	}

	public static function resizeAll() {
		for ( p in ROOTS )
			_resizeProcess(p);
	}
}

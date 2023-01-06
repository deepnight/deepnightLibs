package dn;

import dn.Lib;
import dn.struct.FixedArray;
import dn.debug.MemTrack.measure as MM;

class Process {
	#if !unlimitedProcesses
	public static var MAX_PROCESSES = 1024;
	#end

	/** FPS frequency of the `fixedUpdate` calls **/
	public static var FIXED_UPDATE_FPS = 30;

	public static var CUSTOM_STAGE_WIDTH  = -1;
	public static var CUSTOM_STAGE_HEIGHT = -1;


	static var UNIQ_ID = 0;
	#if unlimitedProcesses
	static var ROOTS : Array<Process> = [];
	#else
	static var ROOTS : FixedArray<Process> = new FixedArray("RootProcesses", MAX_PROCESSES);
	#end
	static var BEGINNING_OF_FRAME_CALLBACKS : FixedArray< Void->Void > = new FixedArray(256);
	static var END_OF_FRAME_CALLBACKS : FixedArray< Void->Void > = new FixedArray(256);

	/** If TRUE, each Process.onResize() will be called *once* at the end of the frame **/
	static var RESIZE_REQUESTED = true;

	public var uniqId : Int;
	/** Elapsed frames from the client start **/
	public var ftime(default, null) : Float; // elapsed frames

	/** Elapsed frames from the client start, as 32bits Int **/
	public var itime(get, never) : Int;

	/** Elapsed seconds from the client start **/
	public var stime(get, never) : Float;

	@:noCompletion
	@:deprecated("Use isPaused() here")
	public var paused(get,never) : Bool; inline function get_paused() return _manuallyPaused;

	/** TRUE if this process was directly manually paused **/
	var _manuallyPaused: Bool;

	/** TRUE if process was marked for removal during garbage collection phase. Most stuff should stop from happening if this flag is set! **/
	public var destroyed(default, null) : Bool;

	/** Optional parent process ref **/
	var parent(default, null) : Process;

	/** Time modifier (1.0 if FPS is ok, >1 if some frames were lost, <1 if more frames are played than expected) **/
	public var tmod(get,never) : Float; inline function get_tmod() return utmod * getComputedTimeMultiplier();

	/** This `tmod` value is unaffected by the time multiplier **/
	public var utmod : Float;

	/** Elapsed frames not affected by time multiplier **/
	public var uftime(default, null) : Float;
	var baseTimeMul = 1.0;

	/** Set this to TRUE if you want this Process to ignore any existing time multipliers, including the ones from parent Processes. For example, a UI component will probably want to ignore time multipliers, even if the game is running in slow-motion. **/
	var ignoreTimeMultipliers = false;

	@:noCompletion
	@:deprecated("Use baseTimeMul instead")
	var speedMod(get,set) : Float;
		@:noCompletion inline function get_speedMod() return baseTimeMul;
		@:noCompletion inline function set_speedMod(v) return baseTimeMul = v;

	@:noCompletion
	@:deprecated("Use tmod instead")
	public var dt(get,never) : Float; inline function get_dt() return tmod;

	/** Process display name **/
	public var name : Null<String>;

	#if unlimitedProcesses
	var children : Array<Process>;
	#else
	var children : FixedArray<Process>;
	#end

	/** Delayer allows for callbacks to be called in a future frame **/
	public var delayer : dn.Delayer;

	/** Cooldown allows to track various countdowns for tons of good reasons **/
	public var cd : dn.Cooldown;

	/** Tweenie tweens values **/
	public var tw : dn.Tweenie;

	/** Same as `delayer` but it isn't affected by time multiplier **/
	public var udelayer : dn.Delayer;

	/** Same as `cd` but it isn't affected by time multiplier **/
	public var ucd : dn.Cooldown;

	var _fixedUpdateAccu = 0.;


	// Optional graphic context
	#if( heaps || h3d )
		/** Graphic context, can be null **/
		public var root : Null<h2d.Layers>;
		public var engine(get,never) : h3d.Engine;
	#elseif flash
		/** Graphic context, can be null **/
		public var root : Null<flash.display.Sprite>;
		var pt0 : flash.geom.Point; // to reduce allocations
	#end



	public function new(?parent : Process) {
		init();

		if (parent == null)
			ROOTS.push(this);
		else
			parent.addChild(this);

		resizeAll(false);
	}

	public function init(){
		uniqId = UNIQ_ID++;
		#if unlimitedProcesses
		children = [];
		#else
		children = new FixedArray(MAX_PROCESSES);
		#end
		_manuallyPaused = false;
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
	/** This special init method is only called once during next frame: call will happen *after* the constructor call and *before* any update. **/
	function initOnceBeforeUpdate() {}


	#if( heaps || flash )
	/** Init graphic context **/
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
			root.name = getDisplayName();
		#elseif flash
			root = new flash.display.Sprite();
			ctx.addChild(root);
			pt0 = new flash.geom.Point();
		#end
	}
	#end


	#if heaps
	/**
		Init graphic context without adding it anywhere
	**/
	public function createRootInNoContext() {
		if( root!=null )
			throw this+": root already created!";

		root = new h2d.Layers();
		root.name = getDisplayName();
	}
	#end


	#if heaps
	/** Init graphic context in specified `h2d.Layers` **/
	public function createRootInLayers(ctx:h2d.Layers, plan:Int) {
		if( root!=null )
			throw this+": root already exists";
		root = new h2d.Layers();
		root.name = getDisplayName();
		ctx.add(root, plan);
	}
	#end


	/**
		For debug purpose, print the hierarchy of all children processes of this one.
	**/
	public function rprintChildren() : String {

		function _crawl(p:dn.Process, depth=0) {
			var out = [];
			var indent = depth>0 ? " |--- " : "";
			indent = dn.Lib.repeatChar(" ",6*(depth-1)) + indent;
			out.push( indent + p.toString() );
			for( cp in p.children )
				out = out.concat( _crawl(cp, depth+1) );
			return out;
		}

		return _crawl(this).join("\n");
	}

	public static function rprintAll() : String {
		var all = [];
		for( p in ROOTS )
			all.push( p.rprintChildren() );
		return all.join("\n");
	}


	public static function destroyAllExcept(excepts:Array<Process>) {
		for(p in ROOTS) {
			if( p.destroyed )
				continue;

			var keep = false;
			for(e in excepts)
				if( e==p ) {
					keep = true;
					break;
				}
			if( !keep )
				p.destroy();
		}
	}



	/** Set to TRUE to enabled Process timing profiling (warning: this will reduce performances)**/
	public static var PROFILING = false;

	/** List of current profiling times **/
	public static var PROFILER_TIMES : Map<String,Float> = new Map();

	var tmpProfilerTimes = new Map();

	/** Clear current profiling times **/
	public static inline function clearProfilingTimes() {
		PROFILER_TIMES = new Map();
	}

	inline function markProfilingStart(id:String) {
		if( PROFILING ) {
			id = getDisplayName()+"."+id;
			tmpProfilerTimes.set(id, haxe.Timer.stamp());
		}
	}

	inline function markProfilingEnd(id:String) {
		if( PROFILING ) {
			id = getDisplayName()+"."+id;
			if( tmpProfilerTimes.exists(id) ) {
				var t = haxe.Timer.stamp()-tmpProfilerTimes.get(id);
				tmpProfilerTimes.remove(id);
				if( !PROFILER_TIMES.exists(id) )
					PROFILER_TIMES.set(id,t);
				else
					PROFILER_TIMES.set(id, PROFILER_TIMES.get(id)+t);
			}
		}
	}

	/**
		Return the current profiling times, sorted from highest to lowest
	**/
	public static function getSortedProfilerTimes() {
		var all = [];
		for(i in PROFILER_TIMES.keyValueIterator())
			all.push(i);
		all.sort( (a,b)->-Reflect.compare(a.value,b.value));
		return all;
	}



	inline function countChildren() {
		#if unlimitedProcesses
		return children.length;
		#else
		return children.allocated;
		#end
	}



	/** Called at the "beginning of the frame", before any Process update(), in declaration order **/
	function preUpdate() {}

	/** Called in the "middle of the frame", after all preUpdates() in declaration order **/
	function update() {}

	/**
		Called in the "middle of the frame", after all updates(), but only X times per seconds (see `fixedUpdateFps`), in declaration order.

		Eg. if the client is running 60fps, and fixedUpdateFps if 30fps, this method will only be called 1 frame out of 2.
	 **/
	function fixedUpdate() { }

	/**
		Return a ratio (0-1) representing the progression of the time between last fixedUpdate and the next one.
		This value is, for example, used to smooth position of elements that are updated at a lower FPS.
	**/
	public inline function getFixedUpdateAccuRatio() {
		return _fixedUpdateAccu / ( getDefaultFrameRate() / FIXED_UPDATE_FPS );
	}

	/** Called at the "end of the frame", after all updates()/fixedUpdates(), in declaration order. That's were graphic updates should probably happen. **/
	function postUpdate() { }

	/** Called when client window is resized. **/
	function onResize() { }

	/** Called when Process is garbaged, that's where all the cleanup should happen **/
	function onDispose() { }

	/** "Overridable at runtime" callbacks **/
	public dynamic function onUpdateCb() {}
	public dynamic function onFixedUpdateCb() {}
	public dynamic function onDisposeCb() {}


	/** Get printable process instance name **/
	@:keep
	public function toString() {
		return '#$uniqId ${getDisplayName()}${isPaused()?" [PAUSED]":""}';
	}

	/** Some human readable name for this Process instance **/
	var _cachedClassName : String;
	public inline function getDisplayName() {
		return name!=null
			? name
			: {
				if( _cachedClassName==null )
					_cachedClassName = Type.getClassName( Type.getClass(this) );
				return _cachedClassName;
			}
	}


	// -----------------------------------------------------------------------
	// private api
	// -----------------------------------------------------------------------
	inline function get_itime() return Std.int(ftime);
	inline function get_stime() return ftime/getDefaultFrameRate();
	#if( heaps || h3d )
	inline function get_engine() return h3d.Engine.getCurrent();
	#end
	inline function addAlpha(c:Int, ?a=1.0) : #if flash UInt #else Int #end {
		return Std.int(a*255)<<24 | c;
	}
	inline function rnd(min,max,?sign) return Lib.rnd(min,max,sign);
	inline function irnd(min,max,?sign) return Lib.irnd(min,max,sign);
	inline function rndSign() return Std.random(2)*2-1;
	inline function rndSecondsF(min,max,?sign) return secToFrames( Lib.rnd(min,max,sign) );
	inline function irndSecondsF(min,max,?sign) return secToFrames( Lib.rnd(min,max,sign) );
	public inline function pretty(v:Float, ?precision=2) return M.pretty(v, precision);

	public function secToFrames(v:Float) return v*getDefaultFrameRate();
	public function framesToSec(v:Float) return v/getDefaultFrameRate();

	public inline function msToFrames(v:Float) return (v/1000)*getDefaultFrameRate();
	public inline function framesToMs(v:Float) return 1000*v/getDefaultFrameRate();

	function getDefaultFrameRate() : Int {
		#if heaps
			return M.round( hxd.Timer.wantedFPS );
		#elseif flash
			return flash.Lib.current.stage.frameRate;
		#else
			return 30; // N/A
		#end
	}

	/** Set this process time multiplier, which will affect tmod, cd, delayers, etc. **/
	public function setTimeMultiplier(v:Float) {
		baseTimeMul = v;
	}

	/** Get "total" time multiplier, including parent processes **/
	function getComputedTimeMultiplier() : Float {
		return ignoreTimeMultipliers ? 1.0 : M.fmax(0, baseTimeMul * ( parent==null ? 1 : parent.getComputedTimeMultiplier() ) );
	}


	/** Get graphical context width **/
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

	/** Get graphical context height **/
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

	inline function anyParentPaused() {
		return parent!=null ? parent.isPaused() : false;
	}
	public function isPaused() {
		if( _manuallyPaused )
			return true;
		else
			return anyParentPaused();
	}
	public function pause() _manuallyPaused = true;
	public function resume() _manuallyPaused = false;
	public final inline function togglePause() : Bool {
		if( _manuallyPaused )
			resume();
		else
			pause();
		return _manuallyPaused;
	}
	public final inline function destroy() destroyed = true;

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

	static inline function canRun(p:Process) return !p.isPaused() && !p.destroyed;

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

		p.markProfilingStart("update");
		p.update();
		if( p.onUpdateCb!=null )
			p.onUpdateCb();
		p.markProfilingEnd("update");

		if( canRun(p) )
			for (p in p.children)
				_doMainUpdate(p);
	}

	static function _doFixedUpdate(p : Process) {
		if( !canRun(p) )
			return;

		p.markProfilingStart("fixed");
		p._fixedUpdateAccu+=p.tmod;
		while( p._fixedUpdateAccu >= p.getDefaultFrameRate() / FIXED_UPDATE_FPS ) {
			p._fixedUpdateAccu -= p.getDefaultFrameRate() / FIXED_UPDATE_FPS;
			if( canRun(p) ) {
				p.fixedUpdate();
				if( p.onFixedUpdateCb!=null )
					p.onFixedUpdateCb();
			}
		}
		p.markProfilingEnd("fixed");

		if( canRun(p) )
			for (p in p.children)
				_doFixedUpdate(p);
	}

	static inline function _doPostUpdate(p : Process) {
		if( !canRun(p) )
			return;

		p.markProfilingStart("post");
		p.postUpdate();
		p.markProfilingEnd("post");

		if( !p.destroyed )
			for (c in p.children)
				_doPostUpdate(c);
	}

	static function _garbageCollector(plist:#if unlimitedProcesses Array #else FixedArray #end<Process>) {
		var i = 0;
		var p : Process;

		#if unlimitedProcesses
		while (i < plist.length) {
			p = plist[i];
			if( p.destroyed )
				_disposeProcess(p);
			else {
				_garbageCollector(p.children);
				i++;
			}
		}
		#else
		while (i < plist.allocated) {
			p = plist.get(i);
			if( p.destroyed )
				_disposeProcess(p);
			else {
				_garbageCollector(p.children);
				i++;
			}
		}
		#end
	}

	static function _disposeProcess(p : Process) {
		// Children
		for(p in p.children)
			p.destroy();
		_garbageCollector(p.children);

		// Unregister from lists
		if (p.parent != null)
			p.parent.children.remove(p);
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

		// Tools
		p.delayer.destroy();
		p.udelayer.destroy();
		p.cd.dispose();
		p.ucd.dispose();
		p.tw.destroy();

		// Clean up
		p.parent = null;
		p.children = null;
		p.cd = null;
		p.ucd = null;
		p.delayer = null;
		p.udelayer = null;
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
		// Beginning of frame callbacks
		if( BEGINNING_OF_FRAME_CALLBACKS.allocated>0 ) {
			for( cb in BEGINNING_OF_FRAME_CALLBACKS )
				cb();
			BEGINNING_OF_FRAME_CALLBACKS.empty();
		}

		for (p in ROOTS)
			_doPreUpdate(p, utmod);

		for (p in ROOTS)
			_doMainUpdate(p);

		for (p in ROOTS)
			_doFixedUpdate(p);

		for (p in ROOTS)
			_doPostUpdate(p);

		if( RESIZE_REQUESTED ) {
			RESIZE_REQUESTED = false;
			for(p in ROOTS)
				_resizeProcess(p);
		}

		_garbageCollector(ROOTS);

		// End of frame callbacks
		if( END_OF_FRAME_CALLBACKS.allocated>0 ) {
			for(cb in END_OF_FRAME_CALLBACKS)
				cb();
			END_OF_FRAME_CALLBACKS.empty();
		}
	}

	/** Request a onResize() call for all processes. If `immediately` is false (default), the call will only happen **once** and **at the end** of current frame. **/
	public static function resizeAll(immediately=false) {
		if( immediately ) {
			for ( p in ROOTS )
				_resizeProcess(p);
		}
		else
			RESIZE_REQUESTED = true;
	}

	/** Request a onResize() call for ALL processes at the end of current frame. **/
	inline function emitResizeAtEndOfFrame() {
		resizeAll(false);
	}

	/** Request a onResize() call for ALL processes immediately. **/
	inline function emitResizeNow() {
		resizeAll(true);
	}

	/** Run a callback at the very beginning of the next frame, before any process. **/
	public static function callAtTheBeginningOfNextFrame( cb:Void->Void ) {
		BEGINNING_OF_FRAME_CALLBACKS.push(cb);
	}

	/** Run a callback at the absolute end of frame, after all processes and after dead processes garbage collection. **/
	public static function callAtTheEndOfCurrentFrame( cb:Void->Void ) {
		END_OF_FRAME_CALLBACKS.push(cb);
	}


	@:noCompletion
	public static function __test() {
		var root = new Process();
		CiAssert.isNotNull(root);
		CiAssert.isNotNull(root.cd);
		CiAssert.isNotNull(root.ucd);
		CiAssert.isNotNull(root.delayer);
		CiAssert.isNotNull(root.udelayer);
		CiAssert.isNotNull(root.tw);
		CiAssert.equals( root.tmod, 1 );
		#if unlimitedProcesses
		CiAssert.equals( ROOTS.length, 1);
		#else
		CiAssert.equals( ROOTS.allocated, 1);
		#end

		// Pause management
		CiAssert.equals( root.togglePause(), true );
		CiAssert.equals( root.togglePause(), false );

		var c1 = new Process(root);
		CiAssert.isNotNull(c1);
		CiAssert.equals(root.countChildren(), 1);
		CiAssert.isFalse( c1.isPaused() );
		root.pause();
		CiAssert.isTrue( c1.isPaused() );
		root.resume();

		var c2 = new Process(root);
		CiAssert.isNotNull(c2);
		CiAssert.equals(root.countChildren(), 2);
		CiAssert.equals(c2.parent, root);
		CiAssert.isFalse( c2.isPaused() );
		root.pause();
		CiAssert.isTrue( c2.isPaused() );

		// Destruction
		c2.destroy();
		updateAll(1); // force GC
		CiAssert.isFalse( c1.destroyed );
		CiAssert.isTrue( c2.destroyed );
		CiAssert.isFalse( root.destroyed );
		CiAssert.equals(root.countChildren(), 1);
		root.destroy();
		updateAll(1); // force GC
		CiAssert.isTrue( c1.destroyed );
		CiAssert.isTrue( c2.destroyed );
		CiAssert.isTrue( root.destroyed );
		#if unlimitedProcesses
		CiAssert.equals( ROOTS.length, 0);
		#else
		CiAssert.equals( ROOTS.allocated, 0);
		#end
	}
}

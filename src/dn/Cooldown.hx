package dn;

import dn.struct.RecyclablePool;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.ExprTools;
import haxe.macro.TypeTools;
import haxe.macro.Type;
#end

/**
 * The `Cooldown` class allows you to manage various state effects that expire after a set amount of time.
 *
 * **Name of cooldowns**
 *
 * Cooldown names are either a string or a string + an integer. This allows you to create cooldowns that share a name
 * but are different.
 *
 * *Examples*:
 * `cd.setS("punch", 0.4);`
 * `cd.setF("jump" + 1, 320);`
 *
 */
class Cooldown {
	/**
		Default size of the CdInst pool.
		Changing this value will NOT affect existing Cooldown class instances!
	**/
	public static var DEFAULT_COUNT_LIMIT = 512;

	/** Pool of cooldowns (actives or freed) **/
	var cds : RecyclablePool<CdInst>;

	@:noCompletion
	public var baseFps(default,null) : Float;

	@:noCompletion public inline function msToFrames(ms:Float) return ms * baseFps / 1000.;
	@:noCompletion public inline function secToFrames(s:Float) return s * baseFps;

	/** The available indices this cooldown class has available. **/
	@:allow(dn.CdInst)
	static var INDEXES : Array<String>;

	var fastCheck: haxe.ds.IntMap<Bool>;

	/**
		Create a new `Cooldown` manager
		@param fps The base FPS value at which you want to track cooldowns
	**/
	public function new(fps:Float, ?maxSize:Int) {
		if( INDEXES == null )
			if( haxe.rtti.Meta.getType(dn.Cooldown).indexes!=null )
				INDEXES = [for (str in haxe.rtti.Meta.getType(dn.Cooldown).indexes) Std.string(str)];
		baseFps = fps;
		changeMaxSizeAndReset(maxSize==null ? DEFAULT_COUNT_LIMIT : maxSize);
	}

	/**
		Resize the internal pool of cooldowns.
		**WARNING**: this will reset every existing cooldowns!
	**/
	public function changeMaxSizeAndReset(newMaxSize:Int) {
		cds = new RecyclablePool(newMaxSize, ()->new CdInst());
		reset();
	}

	/** Destroy the Cooldown manager **/
	public function dispose() {
		cds.dispose(null);
		cds = null;
		fastCheck = null;
	}
	@:noCompletion @:deprecated("Use cd.dispose()")
	public inline function destroy() dispose();

	@:keep
	public function toString() {
		return 'Cooldowns(${cds.allocated}/${cds.maxSize})';
	}

	/** Return the number of active cooldowns **/
	public inline function count() {
		return cds.allocated;
	}

	/** Reset all active cooldowns. WARNING: this won't trigger their onComplete callback. **/
	public inline function reset() {
		cds.freeAll();
		fastCheck = new haxe.ds.IntMap();
	}

	#if display
	/**
	 * Checks whether the cooldown with the associated name is active
	 * @param k name of the cooldown to check
	 * @return Bool `true` if it is still on cooldown
	 */
	public function has( k : String ) : Bool return false;

	/**
	 * Checks whether the cooldown exists, and if it does not also creates it
	 * @param k name of the cooldown to check
	 * @param seconds cooldown in seconds
	 * @return Bool `true` if the cooldown exists
	 */
	public function hasSetS( k : String, seconds : Float ) : Bool return false;

	/**
	 * Checks whether the cooldown exists, and if it does not also creates it
	 * @param k name of the cooldown to check
	 * @param ms cooldown in milliseconds
	 * @return Bool `true` if the cooldown exists
	 */
	public function hasSetMs( k : String, ms : Float ) : Bool return false;

	/**
	 * Checks whether the cooldown exists, and if it does not also creates it
	 * @param k name of the cooldown to check
	 * @param frames cooldown in frames
	 * @return Bool `true` if the cooldown exists
	 */
	public function hasSetF( k : String, frames : Float ) : Bool return false;

	/**
	 * Removes a cooldown from the list
	 * @param k name of the cooldown to remove
	 */
	public function unset( k : String ) {}

	/**
	 * Get the remaining time of a cooldown
	 * @param k name of the cooldown
	 * @return Float time remaining in seconds
	 */
	public function getS( k:String ) : Float return 0.;

	/**
	 * Get the remaining time of a cooldown
	 * @param k name of the cooldown
	 * @return Float time remaining in milliseconds
	 */
	public function getMs( k : String ) : Float return 0.;

	/**
	 * Get the remaining time of a cooldown
	 * @param k name of the cooldown
	 * @return Float time remaining in frames
	 */
	public function getF( k : String ) : Float return 0.;

	/**
	 * Create or overwrite a cooldown
	 * @param k name of the cooldown
	 * @param milliSeconds time in milliseconds
	 * @param allowLower whether to allow overwriting an existing cooldown with a lower one
	 * @param onComplete A callback invoked once this cooldown completes
	 */
	public function setMs( k : String, milliSeconds:Float, allowLower=true, ?onComplete:Void->Void ){}

	/**
	 * Create or overwrite a cooldown
	 * @param k name of the cooldown
	 * @param seconds time in seconds
	 * @param allowLower whether to allow overwriting an existing cooldown with a lower one
	 * @param onComplete A callback invoked once this cooldown completes
	 */
	public function setS( k : String, seconds:Float, allowLower=true, ?onComplete:Void->Void ){}

	/**
	 * Create or overwrite a cooldown
	 * @param k name of the cooldown
	 * @param frames time in frames
	 * @param allowLower whether to allow overwriting an existing cooldown with a lower one
	 * @param onComplete A callback invoked once this cooldown completes
	 */
	public function setF( k : String, frames:Float, allowLower=true, ?onComplete:Void->Void ){}

	/**
	 * Get the initial cooldown time
	 * @param k name of the cooldown
	 * @return Float the initial cooldown value in frames
	 */
	public function getInitialValueF( k : String ) : Float return 0.;

	/**
	 * Get the completion ratio of a given cooldown
	 *
	 * Starts at 1. and goes to 0. when completed
	 * @param k cooldown to check
	 * @return Float the ratio
	 */
	public function getRatio( k : String ) : Float return 0.;

	/**
	 * Set the completion callback for a given cooldown
	 * @param k name of the cooldown to set
	 * @param onceCB callback that will be called once the cooldown completes
	 */
	public function onComplete( k : String, onceCB : Void->Void ){}
	#else



	#if macro
	static function m_getMeta() : MetaAccess {
		for( m in Context.getModule("dn.Cooldown") )
			switch( m ){
			case TInst(ct,_):
				var c = ct.get();
				if( c.name == "Cooldown" ){
					return c.meta;
				}
			case _:
			}
		Context.error("Unable to getModule dn.Cooldown", Context.currentPos());
		return null;
	}

	static function m_getIndex( key : String, p : Position ) : Int {
		var meta = m_getMeta();
		var em = meta.extract("indexes")[0];
		var a = em==null ? [] : em.params;
		for( i in 0...a.length ){
			switch( a[i] ){
			case {expr: EConst(CString(str)), pos: _}if( str == key ):
				return i;
			case _:
			}
		}
		if( a.length > 0x3FF )
			Context.error("Too many cooldown strings (max 1024)", p);

		a.push(macro $v{key});
		meta.remove("indexes");
		meta.add("indexes", a, p);
		return a.length - 1;
	}

	static function m_key( k : ExprOf<String> ) : ExprOf<Int> {
		var key : String = null;
		var subIdx : Expr = null;
		switch( k.expr ){
		case EConst(CString(s)):
			key = s;
		case EBinop(OpAdd, {expr: EConst(CString(s)), pos: _}, e):
			var t = Context.typeof(e);
			switch(e.expr) {
				case EConst(CInt(_)):
					subIdx = e;

				case EConst(CFloat(_)):
					Context.warning("Float converted to Int", e.pos);
					subIdx = macro Std.int($e);

				case EConst(CIdent(k)):
					var ut = Context.followWithAbstracts(t);
					var uts = TypeTools.toString(ut);
					switch uts {
						case "Int":
							subIdx = e;

						case "Float":
							Context.warning("Abstract Float converted to Int", e.pos);
							subIdx = macro Std.int($e);

						case _:
							Context.fatalError("Unsupported type "+uts, e.pos);
					}

				case _:
					var ts = TypeTools.toString(t);
					if( ts=="Int" )
						subIdx = e;
					else
						Context.error(t+" should be Int", e.pos);
			}
			key = s;
		case _:
			Context.error("Invalid cooldown expression", k.pos);
		}

		var index = m_getIndex(key, k.pos) << 22;
		if( subIdx == null )
			subIdx = macro 0;
		var eIndex = {expr: EConst(CInt(Std.string(index))), pos: k.pos};
		#if debug
		return macro {
			// #if debug
			// var v = $subIdx;
			// if( v < 0 || v > 0x3FFFFF )
			// 	trace("Warning: out of bounds cooldown sub-index: \""+dn.Cooldown.INDEXES[$eIndex>>>22]+"\" + "+v);
			// #end
			(($eIndex) | (($subIdx)&0x3FFFFF));
		}
		#else
		return macro (($eIndex) | (($subIdx)&0x3FFFFF));
		#end
	}
	#end

	public macro function has( ethis : Expr, k : ExprOf<String> ){
		return macro $ethis._has(${m_key(k)});
	}

	public macro function hasSetS(ethis:Expr, k:ExprOf<String>, seconds:ExprOf<Float>)   return macro $ethis._hasSetF(${m_key(k)}, $ethis.secToFrames($seconds));
	public macro function hasSetMs(ethis:Expr, k:ExprOf<String>, ms:ExprOf<Float>)       return macro $ethis._hasSetF(${m_key(k)}, $ethis.msToFrames($ms));

	public macro function hasSetF( ethis : Expr, k : ExprOf<String>, frames : ExprOf<Float> ) {
		return macro $ethis._hasSetF(${m_key(k)},$frames);
	}

	public macro function unset( ethis : Expr, k : ExprOf<String> ){
		return macro $ethis._unset(${m_key(k)});
	}

	public macro function getS(ethis:Expr,k:ExprOf<String>) : ExprOf<Float>   return macro $ethis._getF(${m_key(k)}) / $ethis.baseFps;
	public macro function getMs(ethis:Expr,k:ExprOf<String>) : ExprOf<Float>  return macro $ethis._getF(${m_key(k)}) * 1000. / $ethis.baseFps;

	public macro function getF( ethis : Expr, k : ExprOf<String> ){
		return macro $ethis._getF(${m_key(k)});
	}

	public macro function setMs(ethis:Expr, k:ExprOf<String>, milliSeconds:ExprOf<Float>, extra:Array<Expr>){
		var allowLower : Expr = null, onComplete : Expr = macro null;
		for( e in extra )
			switch( e ){
			case {expr: EConst(CIdent(v)), pos: _} if( allowLower == null && (v == "true" || v == "false") ):
				allowLower = e;
			case _:
				onComplete = e;
			}
		if( allowLower == null ) allowLower = macro true;
		return macro $ethis._setF(${m_key(k)}, $ethis.msToFrames($milliSeconds), $allowLower, $onComplete);
	}
	public macro function setS(ethis:Expr, k:ExprOf<String>, seconds:ExprOf<Float>, extra:Array<Expr>){
		var allowLower : Expr = null, onComplete : Expr = macro null;
		for( e in extra )
			switch( e ){
			case {expr: EConst(CIdent(v)), pos: _} if( allowLower == null && (v == "true" || v == "false") ):
				allowLower = e;
			case _:
				onComplete = e;
			}
		if( allowLower == null ) allowLower = macro true;
		return macro $ethis._setF(${m_key(k)}, $ethis.secToFrames($seconds), $allowLower, $onComplete);
	}

	public macro function setF( ethis : Expr, k : ExprOf<String>, frames : ExprOf<Float>, extra:Array<Expr> ){
		var allowLower : Expr = null, onComplete : Expr = macro null;
		for( e in extra )
			switch( e ){
			case {expr: EConst(CIdent(v)), pos: _} if( allowLower == null && (v == "true" || v == "false") ):
				allowLower = e;
			case _:
				onComplete = e;
			}
		if( allowLower == null ) allowLower = macro true;
		return macro $ethis._setF(${m_key(k)}, $frames, $allowLower, $onComplete);
	}

	public macro function getInitialValueF( ethis : Expr, k : ExprOf<String> ){
		return macro $ethis._getInitialValueF(${m_key(k)});
	}

	/** Returns cooldown progression from 1 (start) to 0 (end) **/
	public macro function getRatio( ethis : Expr, k : ExprOf<String> ){
		return macro $ethis._getRatio(${m_key(k)});
	}

	public macro function onComplete( ethis : Expr, k : ExprOf<String>, onceCB : ExprOf<Void->Void> ){
		return macro $ethis._onComplete(${m_key(k)}, $onceCB);
	}

	#end

	public static macro function getKey( k : ExprOf<String> ){
		return m_key(k);
	}

	//

	@:noCompletion
	public inline function _getF(k : Int) : Float {
		var cd = _getCdObject(k);
		return cd == null ? 0 : cd.frames;
	}

	@:noCompletion
	public inline function _getInitialValueF(k : Int) : Float {
		var cd = _getCdObject(k);
		return cd == null ? 0 : cd.initial;
	}

	@:noCompletion
	public function _getRatio(k:Int) : Float { // 1->0
		var max = _getInitialValueF(k);
		return max<=0 ? 0 : _getF(k)/max;
	}

	// only called once when cooldown reaches 0, then CB destroyed
	@:noCompletion
	public inline function _onComplete(k:Int, onceCB:Void->Void) {
		var cd = _getCdObject(k);
		if( cd == null )
			throw "cannot bind onComplete("+k+"): cooldown "+k+" isn't running";
		cd.onCompleteOnce = onceCB;
	}

	@:noCompletion
	public inline function _setF(k:Int, frames:Float, allowLower=true, ?onComplete:Void->Void) : Void {
		// frames = Math.ffloor(frames*1000)/1000; // neko bug: fix precision variations between platforms
		var cur = _getCdObject(k);
		if( cur!=null && frames<cur.frames && !allowLower )
			return;

		if ( frames <= 0 ) {
			if( cur != null )
				unsetCdInst(cur); // TODO optim
		}
		else {
			fastCheck.set(k, true);
			if( cur != null ) {
				cur.frames = frames;
				cur.initial = frames;
			}
			else {
				var cd = cds.alloc();
				cd.set(k, frames);
			}
		}

		if( onComplete!=null )
			if( frames<=0 )
				onComplete();
			else
				this._onComplete(k, onComplete);
	}

	@:noCompletion
	public inline function _unset(k:Int) : Void {
		for(i in 0...cds.allocated)
			if ( cds.get(i).k == k ) {
				unsetIndex(i);
				break;
			}
	}

	@:noCompletion
	public inline function _has(k : Int) : Bool {
		return fastCheck.exists(k);
	}

	@:noCompletion
	public inline function _hasSetF(k:Int, frames:Float) : Bool {
		if ( _has(k) )
			return true;
		else {
			_setF(k, frames);
			return false;
		}
	}

	function _getCdObject(k:Int) : Null<CdInst> {
		for (cd in cds)
			if( cd.k == k )
				return cd;
		return null;
	}

	inline function unsetCdInst(cd:CdInst) {
		fastCheck.remove(cd.k);
		cds.freeElement(cd);
	}

	inline function unsetIndex(idx:Int) {
		fastCheck.remove( cds.get(idx).k );
		cds.freeIndex(idx);
	}

	public function debug(){
		return [ for( cd in cds ) cd.toString() ].join("\n");
	}

	/** Update all cooldowns, and trigger callbacks if they expire **/
	public function update(tmod:Float) {
		var i = 0;
		var cd : CdInst;
		var cb = null;
		while( i<cds.allocated ) {
			cd = cds.get(i);
			cd.frames -= tmod;
			if ( cd.frames<=0 ) {
				cb = cd.onCompleteOnce;
				unsetIndex(i);
				if( cb != null )
					cb();
			}
			else
				i++;
		}
	}


	@:noCompletion
	public static function __test() {
		#if !macro
		var fps = 10;
		var cd = new Cooldown(fps);

		function _advanceTimeS(sec:Float) {
			for( i in 0...M.ceil(sec*fps) )
				cd.update(1);
		}

		// Basic case
		cd.setS("test",1);
		CiAssert.isTrue( cd.has("test") );
		CiAssert.isTrue( cd.getRatio("test") == 1 );
		_advanceTimeS(1);
		CiAssert.isFalse( cd.has("test") );
		CiAssert.isTrue( cd.getRatio("test") == 0 );

		// Name + Int
		cd.setF("jump"+2, 5);
		CiAssert.isFalse( cd.has("jump") );
		CiAssert.isTrue( cd.has("jump"+2) );
		var id = 2;
		CiAssert.isTrue(cd.has("jump" + id));

		// Reset
		cd.setS("a", 1);
		cd.setS("b", 10);
		cd.reset();
		CiAssert.equals(cd.cds.allocated, 0);

		// Multiple CDs
		cd.setS("a", 0.5);
		cd.setS("b", 0.75);
		cd.setS("c", 1);
		CiAssert.equals( cd.has("a"), true );
		CiAssert.equals( cd.has("b"), true );
		CiAssert.equals( cd.has("c"), true );

		_advanceTimeS(0.25);
		CiAssert.equals( cd.has("a"), true );
		CiAssert.equals( cd.has("b"), true );
		CiAssert.equals( cd.has("c"), true );

		_advanceTimeS(0.25);
		CiAssert.equals( cd.has("a"), false );
		CiAssert.equals( cd.has("b"), true );
		CiAssert.equals( cd.has("c"), true );

		_advanceTimeS(0.25);
		CiAssert.equals( cd.has("b"), false );
		CiAssert.equals( cd.has("c"), true );

		_advanceTimeS(0.25);
		CiAssert.equals( cd.has("c"), false );
		CiAssert.equals( cd.cds.allocated, 0 );
		#end
	}
}



private class CdInst {
	public var k : Int;
	public var frames : Float;
	public var initial : Float;
	public var onCompleteOnce : Null< Void->Void >;

	public inline function new() {}

	public inline function set(key:Int, frames:Float) {
		this.k = key;
		this.frames = frames;
		initial = frames;
	}

	public function recycle() {
		onCompleteOnce = null;
	}

	public inline function getRemainingRatio() {
		return initial==0 ? 0 : frames/initial;
	}
	public inline function getProgressRatio() {
		return initial==0 ? 0 : 1-getRemainingRatio();
	}

	@:keep
	public function toString(){
		return
			Cooldown.INDEXES[ (k>>>22) ] + "|" + (k&0x3FFFFF)
			+ ': $frames/$initial (${M.round(getProgressRatio()*100)}%)';
	}
}

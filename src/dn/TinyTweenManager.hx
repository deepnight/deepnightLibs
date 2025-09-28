package dn;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

import dn.TinyTween;


class TinyTweenManager {
	public var fps(default,null) : Int;
	var pool : Array<RecyclableTinyTween> = [];


	public function new(fps, alloc=128) {
		this.fps = fps;
		for(i in 0...alloc)
			pool.push( new RecyclableTinyTween(this) );
	}


	@:noCompletion
	public function _allocTween(fromValue:Float, toValue:Float, durationS:Float, interp:TinyTweenInterpolation=EaseInOut, setter:Float->Void) {
		for(t in pool)
			if( !t.isCurrentlyRunning() ) {
				t.reset();
				t.applyValue = setter;
				t.start(fromValue, toValue, durationS, interp);
				return;
			}

		// Out of tweens
		trace("TinyTweenManager: pool exhausted (size="+pool.length+")");
		var t = new RecyclableTinyTween(this);
		pool.push(t);
		t.applyValue = setter;
		t.start(fromValue, toValue, durationS, interp);
	}


	public macro function start(ethis:Expr, ref:Expr, fromExpr:ExprOf<Float>, toExpr:ExprOf<Float>, durationS:ExprOf<Float>, interp:ExprOf<TinyTweenInterpolation>=null) {
		switch ref.expr {
			case EConst(CIdent(s)):
			case _: Context.error("Need a variable identifier", ref.pos);
		}
		interp = switch interp.expr {
			case EConst(CIdent("null")): macro EaseInOut;
			case _: interp;
		}
		return macro $ethis._allocTween($fromExpr, $toExpr, $durationS, $interp, v->$ref = v);
	}


	public function update(tmod:Float) {
		var n = 0;
		for(t in pool)
			if( t.update(tmod) )
				n++;
		return n;
	}
}



class RecyclableTinyTween extends TinyTween implements dn.struct.RecyclablePool.Recyclable {
	static var UNIQ = 0;
	public var uid(default,null) : Int;
	var manager : TinyTweenManager;

	public function new(manager:TinyTweenManager) {
		super(manager.fps);
		uid = UNIQ++;
		this.manager = manager;
	}

	public function recycle() {
		reset();
		onCompleteEverytime = _doNothing;
		applyValue = _applyNothing;
	}

	override function complete() {
		super.complete();
		recycle();
	}
}

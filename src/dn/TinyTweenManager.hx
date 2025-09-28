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


	public function dispose() {
		for(t in pool)
			t.dispose();
		pool = null;
	}


	@:noCompletion
	public function _allocTween(fromValue:Float, toValue:Float, durationS:Float, interp:TinyTweenInterpolation=EaseInOut, setter:Float->Void) : RecyclableTinyTween {
		for(t in pool)
			if( !t.isCurrentlyRunning() ) {
				t.reset();
				t.applyValue = setter;
				t.start(fromValue, toValue, durationS, interp);
				return t;
			}

		// Out of tweens
		trace("TinyTweenManager: pool exhausted (size="+pool.length+")");
		var t = new RecyclableTinyTween(this);
		pool.push(t);
		t.applyValue = setter;
		t.start(fromValue, toValue, durationS, interp);
		return t;
	}


	/**
		Starts a tween operation on a target variable.
		@param targetVar The variable to be tweened.
		@param tweenOp The tween operation among these two formats: "9" or "0>9"
		@param durationS The duration of the tween in seconds.
		@param interp The interpolation method.
	*/
	public macro function start(ethis:Expr, targetVarExpr:ExprOf<Float>, tweenOp:Expr, durationS:ExprOf<Float>, interp:ExprOf<TinyTweenInterpolation>=null) {
		switch targetVarExpr.expr {
			case EConst(CIdent(s)):
			case EField(e, field, kind):
			case _: Context.error("Need a variable identifier, got "+targetVarExpr.expr.getName(), targetVarExpr.pos);
		}
		interp = switch interp.expr {
			case EConst(CIdent("null")): macro EaseInOut;
			case _: interp;
		}

		var fromExpr : Expr = null;
		var toExpr : Expr = null;
		switch tweenOp.expr {
			case EConst(c): // "9", "v" etc
				fromExpr = targetVarExpr;
				toExpr = tweenOp;

			case EUnop(op, postFix, e): // "-9"
				switch op {
					case OpNeg:
						fromExpr = targetVarExpr;
						toExpr = tweenOp;

					case _:
						Context.error("Unsupported tween operator", tweenOp.pos);

				}

			case EBinop(op, e1, e2):
				switch op {
					case OpGt: // "0>9"
						fromExpr = e1;
						toExpr = e2;

					case _:
						Context.error("Unsupported tween operator", tweenOp.pos);
				}

			case _:
				Context.error("Unsupported tween expression", tweenOp.pos);
		}
		return macro $ethis._allocTween($fromExpr, $toExpr, $durationS, $interp, v->$targetVarExpr = v);
	}


	public function update(tmod:Float) {
		var n = 0;
		for(t in pool)
			if( t.update(tmod) )
				n++;
		return n;
	}
}



private class RecyclableTinyTween extends TinyTween implements dn.struct.RecyclablePool.Recyclable {
	static var UNIQ = 0;
	public var uid(default,null) : Int;
	var manager : TinyTweenManager;

	public function new(manager:TinyTweenManager) {
		super(manager.fps);
		uid = UNIQ++;
		this.manager = manager;
	}

	function _doNothingFloat(v:Float) {}

	public function recycle() {
		reset();
		applyValue = _doNothingFloat;
		onValueApplied = _doNothingFloat;
	}

	public function dispose() {
		reset();
		manager = null;
	}

	override function complete() {
		super.complete();
		recycle();
	}
}

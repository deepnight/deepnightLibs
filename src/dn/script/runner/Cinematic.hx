package dn.script.runner;

import hscript.Expr;

/**
	Cinematic: a specialized script runner that supports cinematic oriented features (pausing, async calls, waitUntil etc)

	IMPORTANT: `update()` must be called to support async features!
**/
class Cinematic extends dn.script.Runner {
	public var tmod(default,null) : Float = 1;
	var fps : Int;
	var runningTimeS = 0.;
	var running = false;

	var waitUntilFunctions : Map<String, Bool> = new Map();
	var runLoops : Array<(tmod:Float)->Bool> = []; // A custom loop is removed from the array if it returns TRUE
	var uniqId = 0;

	public function new(fps:Int) {
		super();
		this.fps = fps;

		bindInternalFunction("delayExecutionS", api_delayExecutionS);
		bindInternalFunction("waitUntil", api_waitUntil);
	}

	inline function makeUniqId() {
		return uniqId++;
	}


	/** Shortcut to create a Cinematic runner with api instance **/
	public static function createWithApi<T:Dynamic>(fps:Int, apiInstance:Dynamic, apiInterface:Class<T>) : Cinematic {
		var runner = new Cinematic(fps);
		runner.exposeClassInstance("api", apiInstance, apiInterface, true);
		return runner;
	}


	/**
		Destroy the runner and clean things up
	**/
	override function dispose() {
		super.dispose();
		running = false;
		runLoops = null;
		waitUntilFunctions = null;
	}



	// Create a script expression
	inline function mkExpr(e:ExprDef, p:Expr) {
		return hscript.Tools.mk( e, p );
	}
	// Create a script expression
	inline function mkBlock(arr:Array<Expr>, p:Expr) {
		return hscript.Tools.mk( EBlock(arr), p );
	}

	// Create an identifier expression
	inline function mkIdentExpr(ident:String, p:Expr) {
		return hscript.Tools.mk( EIdent(ident), p );
	}

	inline function mkFieldExpr(eObj, fieldName, p:Expr) {
		return hscript.Tools.mk( EField(eObj,fieldName), p );
	}

	// Create a function call expression
	inline function mkCallByName(func:String, args:Array<Expr>, p:Expr) {
		return mkExpr( ECall( mkIdentExpr(func,p), args ), p );
	}

	// Create a function call expression
	inline function mkCallByIdent(ident:Expr, args:Array<Expr>, p:Expr) {
		return mkExpr( ECall(ident,args), p);
	}

	// Create a function definition expression:  function() {...body...}
	function mkFunctionExpr(?name:String, ?args:Array<Argument>, functionBody:Expr, parentExpr:Expr) {
		return mkExpr( EFunction(args??[], functionBody, name), parentExpr );
	}


	public dynamic function onScriptStopped(success:Bool) {}


	override function run(script:String):Bool {
		return running = super.run(script);
	}

	override function reportError(err:ScriptError) {
		super.reportError(err);
		onScriptStopped(false);
	}

	public inline function hasScriptRunning() return running;

	/**
		Add a loop function to be used only during script execution. For example, this could be used to wait for a specific event to happen during the execution before continuing.
		See `delayExecutionS()` for an example.
		A custom loop function is removed from the array if it returns TRUE.
	**/
	function addRunLoop(loopFunc:Float->Bool) {
		runLoops.push(loopFunc);
	}

	function api_delayExecutionS( t:Float, doNext:Void->Void ) {
		var endS = runningTimeS + t;
		addRunLoop((tmod)->{
			if( runningTimeS>=endS )
				doNext();
			return runningTimeS>=endS;
		});
	}

	function api_waitUntil( cond:Void->Bool, doNext:Void->Void ) {
		addRunLoop((tmod)->{
			var result = cond();
			if( result )
				doNext();
			return result;
		});
	}



	/**
		Register a shortcut to a custom "waitUntil" function that can be used in scripting like this:
		```
			waitUntil;
			waitUntil(args);
			waitUntil >> {...}
			waitUntil(args) >> {...}
		```

		The code following the "waitUntil" (or the nested block when using >> syntax) will be paused until proceed() is called.

		The "waitUntil" function is required to return a Bool (TRUE means "proceed and continue script execution"):
		```
			function actionIsDone( ... ) : Bool;
		```

		Example:
		```
			someAction1();
			actionIsDone >> { // actionIsDone is a custom API function that returns TRUE when done
				someAction2(); // this only happens when actionIsDone() return TRUE.
			}
		```
	**/
	public function addWaitUntilFunction(funcName:String) {
		waitUntilFunctions.set(funcName,true);
	}



	/*
		Convert a standard program Expr to support Cinematic runner features.

		Transforms "custom waitUntil conditions" expressions to valid expressions.
			customWaitUntil(...)
			customWaitUntil
			customWaitUntil >> {...}
			customWaitUntil(...) >> {...}
			0.5;				// pause for 0.5s
			0.5 >> {...}		// async call block content in 0.5s
	*/
	override function convertProgramExpr(e:hscript.Expr) {
		super.convertProgramExpr(e);

		function _convertNewExpr(subExpr:Expr) {
			switch hscript.Tools.expr(subExpr) {
				case EBlock(_): convertProgramExpr(subExpr);
				case EFunction(_): hscript.Tools.iter(subExpr, convertProgramExpr);
				case _: throw 'Not a block: $subExpr';
			}
		}

		switch hscript.Tools.expr(e) {
			case EBlock(exprs):
				var idx = 0;
				function _replaceCurBlockExpr(with:ExprDef) {
					#if hscriptPos
					exprs[idx].e = with;
					#else
					exprs[idx] = with;
					#end
				}
				function _prependCurBlockExpr(with:Expr) {
					exprs.insert(idx, with);
					idx++;
				}
				function _getBlockInnerExprs(e:Expr) {
					return switch hscript.Tools.expr(e) {
						case EBlock(arr): arr.copy();
						case _: [e];
					}
				}
				while( idx<exprs.length ) {
					var e = exprs[idx];
					switch hscript.Tools.expr(e) {
						// Pausing
						case EConst(c):
							var timerS : Float = switch c {
								case CInt(v): v;
								case CFloat(v): v;
								case CString(v): 0;
							}
							if( timerS>0 ) {
								var delayExpr = mkExpr(EConst(CFloat(timerS)), e);
								var followingExprsBlock = mkExpr( EBlock( exprs.splice(idx+1,exprs.length) ), e );
								_convertNewExpr(followingExprsBlock);
								_replaceCurBlockExpr( ECall(
									mkIdentExpr("delayExecutionS",e),
									[ delayExpr, mkFunctionExpr(followingExprsBlock,e) ]
								));
								break;
							}

						// Special ">>" usage
						case EBinop(op, leftExpr, rightExpr):
							if( op==">>" ) {
								switch hscript.Tools.expr(leftExpr) {
									case EConst(CInt(_)), EConst(CFloat(_)):
										// 0.5 >> {...}
										var asyncFunc = mkFunctionExpr(rightExpr,e);
										_convertNewExpr(asyncFunc);
										_replaceCurBlockExpr( ECall(
											mkIdentExpr("delayExecutionS", e),
											[ leftExpr, asyncFunc ]
										));

									case EIdent(id):
										// TURNS: customWaitUntil >> { XXX }
										// INTO: waitUntil( ()->customWaitUntil(), ()->XXX );
										if( waitUntilFunctions.exists(id) ) {
											var asyncFunc = mkFunctionExpr(rightExpr,e);
											_convertNewExpr(asyncFunc);
											var args = [
												mkFunctionExpr( mkCallByName(id,[],e), e ),
												mkFunctionExpr( asyncFunc, e ),
											];
											_replaceCurBlockExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
										}

									#if hscriptPos
									case ECall({e:EIdent(id)}, params):
									#else
									case ECall(EIdent(id), params):
									#end
										// TURNS: customWaitUntil(...) >> { XXX }
										// INTO: waitUntil( ()->customWaitUntil(...), ()->XXX );
										if( waitUntilFunctions.exists(id) ) {
											var asyncFunc = mkFunctionExpr(rightExpr,e);
											_convertNewExpr(asyncFunc);
											var args = [
												mkFunctionExpr( mkCallByName(id,params,e), e ),
												mkFunctionExpr( asyncFunc, e ),
											];
											_replaceCurBlockExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
										}

									case _:
								}
							}

						// TURNS: customWaitUntil; XXX;
						// INTO: waitUntil( ()->customWaitUntil(), ()->XXX );
						case EIdent(id):
							if( waitUntilFunctions.exists(id) ) {
								var followingExprsBlock = mkExpr( EBlock( exprs.splice(idx+1,exprs.length) ), e );
								_convertNewExpr(followingExprsBlock);
								var args = [
									mkFunctionExpr( mkCallByName(id,[],e), e ),
									mkFunctionExpr( followingExprsBlock, e ),
								];
								_replaceCurBlockExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
								break;
							}

						// TURNS: customWaitUntil(...); XXX;
						// INTO: waitUntil( ()->customWaitUntil(...), ()->XXX );
						#if hscriptPos
						case ECall({e:EIdent(id)}, params):
						#else
						case ECall(EIdent(id), params):
						#end
							if( waitUntilFunctions.exists(id) ) {
								var followingExprsBlock = mkExpr( EBlock( exprs.splice(idx+1,exprs.length) ), e );
								_convertNewExpr(followingExprsBlock);
								var args = [
									mkFunctionExpr( mkCallByName(id,params,e), e ),
									mkFunctionExpr( followingExprsBlock, e ),
								];
								_replaceCurBlockExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
								break;
							}

						case EIf(eCond, eTrue, eFalse):
							var uid = makeUniqId();

							// Extract all following expressions and move them to a temp function
							var followingExprs = exprs.splice(idx+1,exprs.length);
							// if( followingExprs.length==0 )
							// 	break; // no need to change anything if there's nothing following the if

							var onCompleteExpr = mkFunctionExpr("_ifComplete"+uid, mkExpr(EBlock(followingExprs),e), e);
							var onCompleteCall = mkCallByName("_ifComplete"+uid,[],e);

							// Create "true" branch
							var eTrueBlock = switch hscript.Tools.expr(eTrue) {
								case EBlock(arr): mkExpr( EBlock(arr.concat([onCompleteCall]) ), e );
								case _: mkExpr( EBlock([eTrue,onCompleteCall]), e );
							}
							_convertNewExpr(eTrueBlock);

							// Create "false" branch
							var eFalseBlock = eFalse==null
								? mkBlock( [onCompleteCall], e )
								: switch hscript.Tools.expr(eFalse) {
									case EBlock(arr): mkBlock( arr.concat([onCompleteCall]), e );
									case _: mkBlock( [eFalse,onCompleteCall], e );
								}
							_convertNewExpr(eFalseBlock);

							// Replace current block with the temp function declaration, followed by the new EIf
							_prependCurBlockExpr(onCompleteExpr);
							_replaceCurBlockExpr( EIf(eCond, eTrueBlock, eFalseBlock) );
							break;


						case EFor(varName, eit, loopExpr):
							var uid = makeUniqId();

							var followingBlockExprs = exprs.splice(idx+1,exprs.length);
							var onCompleteExpr = mkFunctionExpr("_onComplete"+uid, mkExpr(EBlock(followingBlockExprs),e), e);
							_convertNewExpr(onCompleteExpr);

							// Rebuild the loop using an async function
							var iterIdent = mkIdentExpr("_i"+uid, e);
							var asyncLoopExprs = [
								// => "if( !_i.hasNext() ) { doFollowing(); return; }"
								mkExpr( EIf(
									mkExpr(EUnop(
										"!",
										true,
										mkCallByIdent( mkFieldExpr(iterIdent,"hasNext",e), [], e )
									), e),
									mkBlock( followingBlockExprs.length==0
										? [ mkExpr(EReturn(),e) ]
										: [ mkCallByName("_onComplete"+uid,[],e), mkExpr(EReturn(),e) ]
									, e )
								),e),

								// => "var varName = _i.next()"
								mkExpr( EVar(varName, mkCallByIdent( mkFieldExpr(iterIdent,"next",e), [], e )), e ),
							];

							// Build the loop body
							var exprs = _getBlockInnerExprs(loopExpr);
							exprs.push( mkCallByName("_loop"+uid, [], e) );
							var bodyExpr = mkBlock(exprs, e);
							_convertNewExpr(bodyExpr);

							var asyncLoopExpr = mkExpr(EBlock(asyncLoopExprs.concat([bodyExpr])),e);
							_replaceCurBlockExpr(EBlock([
								// => "var _i = makeIterator"
								onCompleteExpr,
								mkExpr( EVar("_i"+uid, mkCallByIdent( mkIdentExpr("makeIterator",eit), [eit], e )), e ),

								// Declare _loop var first, then set it to the function
								mkExpr( EVar("_loop"+uid, mkFunctionExpr(mkBlock([],e),e)), e ),
								mkExpr( EBinop( "=", mkIdentExpr("_loop"+uid,e), mkFunctionExpr(asyncLoopExpr,e) ), e ),

								// => "_loop()"
								mkCallByName("_loop"+uid, [], e),
							]));


						case EDoWhile(_), EWhile(_):
							throw new ScriptError('Loop is not supported yet', lastScriptStr);

						case _:
							hscript.Tools.iter(e, convertProgramExpr);
					}
					idx++;
				}

			case _:
				hscript.Tools.iter(e, convertProgramExpr);
		}
	}



	override function checkScriptExpr(scriptExpr:Expr) {
		super.checkScriptExpr(scriptExpr);

		// Check waitUntil functions
		for(fn in waitUntilFunctions.keys()) {
			if( !checker.getGlobals().exists(fn) )
				throw new ScriptError('Unknown waitUntil function: $fn', lastScriptStr);
			var tt = checker.getGlobals().get(fn);
			switch tt {
				case TFun(args, ret):
					if( ret!=TBool )
						throw new ScriptError('"$fn" function must return a Bool', lastScriptStr);

				case _:
					throw new ScriptError('"$fn" should be a function, found $tt', lastScriptStr);
			}
		}
	}



	override function init() {
		super.init();
		uniqId = 0;
		running = false;
		runningTimeS = 0;
		runLoops = [];
	}


	function updateRunningScript() {
		// Update custom loops
		var i = 0;
		while( i<runLoops.length ) {
			var f = runLoops[i];
			if( f(tmod) )
				runLoops.splice(i, 1);
			else
				i++;
		}
	}

	public function update(tmod:Float) {
		this.tmod = tmod;
		runningTimeS += tmod/fps;

		if( running )
			tryCatch(updateRunningScript);

		// Script completion detection
		if( running && runLoops.length==0 ) {
			running = false;
			onScriptStopped(true);
		}
	}
}


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

	var waitUntilFunctions : Map<String, Bool> = new Map();
	var runLoops : Array<(tmod:Float)->Bool> = []; // A custom loop is removed from the array if it returns TRUE

	public function new(fps:Int) {
		super();
		this.fps = fps;

		bindInternalFunction("delayExecutionS", api_delayExecutionS);
		bindInternalFunction("waitUntil", api_waitUntil);
	}


	/**
		Destroy the runner and clean things up
	**/
	override function dispose() {
		super.dispose();
		runLoops = null;
		waitUntilFunctions = null;
	}


	/**
		Add a loop function to be used only during script execution. For example, this could be used to wait for a specific event to happen during the execution before continuing.
		See `delayExecutionS()` for an example.
		A custom loop function is removed from the array if it returns TRUE.
	**/
	public function addRunLoop(loopFunc:Float->Bool) {
		runLoops.push(loopFunc);
	}

	function api_delayExecutionS( doNext:Void->Void, t:Float ) {
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
		Convert a standard program Expr to support Runner features.

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
				for(e in exprs) {
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
								_replaceCurBlockExpr( ECall(
									mkIdentExpr("delayExecutionS",e),
									[ mkSyncAnonymousFunction(followingExprsBlock,e), delayExpr ]
								));
								break;
							}

						// Special ">>" usage
						case EBinop(op, leftExpr, rightExpr):
							if( op==">>" ) {
								switch hscript.Tools.expr(leftExpr) {
									// 0.5 >> {...}
									case EConst(CInt(_)), EConst(CFloat(_)):
										_replaceCurBlockExpr( ECall(
											mkIdentExpr("delayExecutionS", e),
											[ mkSyncAnonymousFunction(rightExpr,e), leftExpr ]
										));

									// TURNS: customWaitUntil >> { XXX }
									// INTO: waitUntil( ()->customWaitUntil(), ()->XXX );
									case EIdent(id):
										if( waitUntilFunctions.exists(id) ) {
											var args = [
												mkSyncAnonymousFunction( mkCall(id,[],e), e ),
												mkSyncAnonymousFunction( rightExpr, e ),
											];
											_replaceCurBlockExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
										}

									// TURNS: customWaitUntil(...) >> { XXX }
									// INTO: waitUntil( ()->customWaitUntil(...), ()->XXX );
									#if hscriptPos
									case ECall({e:EIdent(id)}, params):
									#else
									case ECall(EIdent(id), params):
									#end
										if( waitUntilFunctions.exists(id) ) {
											var args = [
												mkSyncAnonymousFunction( mkCall(id,params,e), e ),
												mkSyncAnonymousFunction( rightExpr, e ),
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
								var args = [
									mkSyncAnonymousFunction( mkCall(id,[],e), e ),
									mkSyncAnonymousFunction( followingExprsBlock, e ),
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
								var args = [
									mkSyncAnonymousFunction( mkCall(id,params,e), e ),
									mkSyncAnonymousFunction( followingExprsBlock, e ),
								];
								_replaceCurBlockExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
								break;
							}

						case EFor(v, iterExpr, blockExpr):
							throw new ScriptError('"for" loop is not supported yet', lastScript);
							// TODO support async transform of: for(...) {...}
							// See implementation in Async.toCps (EFor)
							/*
								for(i in v) block; loops are translated to the following:

								var _i = makeIterator(v);
								function _loop() {
									if( !_i.hasNext() )
										return;
									var v = _i.next();
									block(function(_) _loop());
								}
								_loop();
							*/

						case _:
					}
					idx++;
				}

			case _:
		}
		hscript.Tools.iter(e, convertProgramExpr);
	}



	override function checkScriptExpr(scriptExpr:Expr) {
		super.checkScriptExpr(scriptExpr);

		// Check waitUntil functions
		for(fn in waitUntilFunctions.keys()) {
			if( !checker.getGlobals().exists(fn) )
				throw new ScriptError('Unknown waitUntil function: $fn', lastScript);
			var tt = checker.getGlobals().get(fn);
			switch tt {
				case TFun(args, ret):
					if( ret!=TBool )
						throw new ScriptError('"$fn" function must return a Bool', lastScript);

				case _:
					throw new ScriptError('"$fn" should be a function, found $tt', lastScript);
			}
		}
	}



	override function init() {
		super.init();
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
		if( running && runLoops.length==0 )
			end(true);
	}
}


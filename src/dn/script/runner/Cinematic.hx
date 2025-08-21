package dn.script.runner;

import hscript.Expr;
import hscript.Tools;

/**
	Cinematic: a specialized script runner that supports cinematic oriented features (pausing, async calls, waitUntil etc)

	IMPORTANT: `update()` must be called to support async features!
**/
class Cinematic extends dn.script.Runner {
	public var tmod(default,null) : Float = 1;
	var fps : Int;
	public var runningTimeS(default,null) = 0.;
	var running = false;

	var waitUntilFunctions : Map<String, Bool> = new Map();
	var runLoops : Array<(tmod:Float)->Bool> = []; // A custom loop is removed from the array if it returns TRUE
	var uniqId = 0;

	public function new(fps:Int) {
		super();
		this.fps = fps;
		origin = "Cinematic";

		addInternalKeyword("delayExecutionS", TDynamic, api_delayExecutionS);
		addInternalKeyword("waitUntil", TDynamic, api_waitUntil);
		addInternalKeyword("wait", TDynamic); // turned into a delayExecutionS() call at conversion time
	}

	inline function makeUniqId() {
		return uniqId++;
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
		var outExpr = Tools.mk( e, p );
		#if hscriptPos
		outExpr.origin = "CinematicConvert";
		#end
		return outExpr;
	}
	// Create a script expression
	inline function mkBlock(arr:Array<Expr>, p:Expr) {
		return mkExpr( EBlock(arr), p );
	}

	// Create an identifier expression
	inline function mkIdentExpr(ident:String, p:Expr) {
		return mkExpr( EIdent(ident), p );
	}

	inline function mkFieldExpr(eObj, fieldName, p:Expr) {
		return mkExpr( EField(eObj,fieldName), p );
	}

	// Create a function call expression
	inline function mkCallByName(func:String, ?args:Array<Expr>, p:Expr) {
		return mkExpr( ECall( mkIdentExpr(func,p), args??[] ), p );
	}

	// Create a function call expression
	inline function mkCallByIdent(ident:Expr, ?args:Array<Expr>, p:Expr) {
		return mkExpr( ECall(ident,args??[]), p);
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
		running = false;
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
	var lastLoopCompleteFunc : Null<String>;
	override function convertProgramExpr(program:hscript.Expr) {
		super.convertProgramExpr(program);

		switch Tools.expr(program) {
			case EBlock(exprs):
				asyncExprsArray(exprs);

			case _:
				asyncExprsArray([program]);
		}
	}


	function asyncExprsArray(blockExprs:Array<Expr>) {
		var idx = 0;

		function _convertFunctionBodyExpr(e:Expr) {
			switch Tools.expr(e) {
				case EFunction(args, body, _):
					switch Tools.expr(body) {
						case EBlock(exprs): asyncExprsArray(exprs);
						case _: asyncExprsArray([body]);
					}

				case _:
					emitError('Not a function: ${Tools.expr(e).getName()}', e);
			}
		}

		function _replaceCurBlockExpr(with:ExprDef) {
			#if hscriptPos
			blockExprs[idx].e = with;
			#else
			blockExprs[idx] = with;
			#end
		}

		function _prependCurBlockExpr(with:Expr) {
			blockExprs.insert(idx, with);
			idx++;
		}

		function _getBlockInnerExprs(e:Expr) {
			return switch Tools.expr(e) {
				case EBlock(arr): arr.copy();
				case _: [e];
			}
		}


		while( idx<blockExprs.length ) {
			var e = blockExprs[idx];
			switch Tools.expr(e) {
				// Pausing
				case EConst(c):
					var timerS : Float = switch c {
						case CInt(v): v;
						case CFloat(v): v;
						case CString(v): 0;
					}
					if( timerS>0 ) {
						var delayExpr = mkExpr(EConst(CFloat(timerS)), e);
						var followingExprs = blockExprs.splice(idx+1,blockExprs.length);
						asyncExprsArray(followingExprs);
						_replaceCurBlockExpr( ECall(
							mkIdentExpr("delayExecutionS",e),
							[ delayExpr, mkFunctionExpr( mkBlock(followingExprs,e), e ) ]
						));
						break;
					}

				// Special ">>" usage
				case EBinop(op, leftExpr, rightExpr):
					switch op {
						case "=":
							switch Tools.expr(leftExpr) {
								case EBinop(">>", _): emitError("Operators confusion (>> and =)", e);
								case _:
							}

						case ">>":
							switch Tools.expr(leftExpr) {
								case EConst(CInt(_)), EConst(CFloat(_)):
									// 0.5 >> {...}
									var asyncFunc = mkFunctionExpr(rightExpr,e);
									_convertFunctionBodyExpr(asyncFunc);
									_replaceCurBlockExpr( ECall(
										mkIdentExpr("delayExecutionS", e),
										[ leftExpr, asyncFunc ]
									));

								case EIdent(id):
									// TURNS: customWaitUntil >> { XXX }
									// INTO: waitUntil( ()->customWaitUntil(), ()->XXX );
									if( waitUntilFunctions.exists(id) ) {
										var asyncFunc = mkFunctionExpr(rightExpr,e);
										_convertFunctionBodyExpr(asyncFunc);
										var args = [
											mkFunctionExpr( mkExpr( EReturn(mkCallByName(id,[],e)), e ), e ),
											asyncFunc
										];
										_replaceCurBlockExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
									}

								case ECall( #if hscriptPos {e:EIdent(id)} #else EIdent(id) #end, params ):
									// TURNS: customWaitUntil(...) >> { XXX }
									// INTO: waitUntil( ()->customWaitUntil(...), ()->XXX );
									if( waitUntilFunctions.exists(id) ) {
										var asyncFunc = mkFunctionExpr(rightExpr,e);
										_convertFunctionBodyExpr(asyncFunc);
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
						var followingExprs = blockExprs.splice(idx+1,blockExprs.length);
						asyncExprsArray(followingExprs);
						var args = [
							mkFunctionExpr( mkExpr(EReturn(mkCallByName(id,[],e)),e), e ),
							mkFunctionExpr( mkBlock(followingExprs,e), e ),
						];
						_replaceCurBlockExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
						break;
					}

				case ECall( #if hscriptPos {e:EIdent(id)} #else EIdent(id) #end, params ):
					if( id=="wait" ) {
						// "wait(x);" keyword
						var followingExprs = blockExprs.splice(idx+1,blockExprs.length);
						asyncExprsArray(followingExprs);
						_replaceCurBlockExpr( ECall(
							mkIdentExpr("delayExecutionS",e),
							[ params[0], mkFunctionExpr( mkBlock(followingExprs,e), e ) ]
						));
					}
					else if( waitUntilFunctions.exists(id) ) {
						// TURNS: customWaitUntil(...); XXX;
						// INTO: waitUntil( ()->customWaitUntil(...), ()->XXX );
						var followingExprs = blockExprs.splice(idx+1,blockExprs.length);
						asyncExprsArray(followingExprs);
						var args = [
							mkFunctionExpr( mkCallByName(id,params,e), e ),
							mkFunctionExpr( mkBlock(followingExprs,e), e ),
						];
						_replaceCurBlockExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
						break;
					}



				// Make IF statement async
				case EIf(eCond, eTrue, eFalse):
					var uid = makeUniqId();

					// Extract all following expressions and move them to a temp function
					var followingExprs = blockExprs.splice(idx+1,blockExprs.length);
					asyncExprsArray(followingExprs);

					var afterIfFunc = mkFunctionExpr("_afterIf"+uid, mkBlock(followingExprs,e), e);
					var afterIfCall = mkCallByName("_afterIf"+uid,[],e);

					// Create "true" branch
					var trueBranchExprs = switch Tools.expr(eTrue) {
						case EBlock(arr): arr.concat([ afterIfCall ]);
						case _: [ eTrue, afterIfCall ];
					}
					asyncExprsArray(trueBranchExprs);

					// Create "false" branch
					var falseBranchExprs = eFalse==null
						? [ afterIfCall ]
						: switch Tools.expr(eFalse) {
							case EBlock(arr): arr.concat([ afterIfCall ]);
							case _: [ eFalse, afterIfCall ];
						}
					asyncExprsArray(falseBranchExprs);

					// Replace current block with the temp function declaration, followed by the new EIf
					_prependCurBlockExpr(afterIfFunc);
					_replaceCurBlockExpr( EIf(eCond, mkBlock(trueBranchExprs,e), mkBlock(falseBranchExprs,e)) );
					break;


				// Make FOR loop async
				case EFor(varName, eit, bodyExpr):
					var uid = makeUniqId();

					var followingExprs = blockExprs.splice(idx+1,blockExprs.length);
					asyncExprsArray(followingExprs);
					var onCompleteExpr = mkFunctionExpr("_forComplete"+uid, mkBlock(followingExprs,e), e);
					lastLoopCompleteFunc = "_forComplete"+uid;

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
							mkBlock( followingExprs.length==0
								? [ mkExpr(EReturn(),e) ]
								: [ mkCallByName("_forComplete"+uid,[],e), mkExpr(EReturn(),e) ]
							, e )
						),e),

						// => "var varName = _i.next()"
						mkExpr( EVar(varName, mkCallByIdent( mkFieldExpr(iterIdent,"next",e), [], e )), e ),
					];

					// Build the loop body
					var exprs = _getBlockInnerExprs(bodyExpr);
					exprs.push( mkCallByName("_for"+uid, [], e) );
					asyncExprsArray(exprs);
					var bodyExpr = mkBlock(exprs, e);

					// Try typing basic iterators
					var makeIteratorName : String = switch Tools.expr(eit) {
						case EBinop("...", e1, e2):
							Tools.expr(e1).match(EConst(CInt(_))) || Tools.expr(e2).match(EConst(CInt(_)))
								? "makeIterator_int"
								: "makeIterator_dynamic";

						case _: "makeIterator_dynamic";
					}

					var asyncLoopFuncBody = mkExpr(EBlock(asyncLoopExprs.concat([bodyExpr])),e);
					_replaceCurBlockExpr(EBlock([
						// Declare the onComplete function
						onCompleteExpr,

						// => "var _i = makeIterator"
						mkExpr( EVar("_i"+uid, mkCallByIdent( mkIdentExpr(makeIteratorName,eit), [eit], e )), e ),

						// Declare _for var first, then set it to the function
						mkExpr( EVar("_for"+uid, mkFunctionExpr(mkBlock([],e),e)), e ),
						mkExpr( EBinop( "=", mkIdentExpr("_for"+uid,e), mkFunctionExpr(asyncLoopFuncBody,e) ), e ),

						// Call the loop for the first time
						mkCallByName("_for"+uid, [], e),
					]));
					break;


				// Make WHILE loop async
				case EWhile(condExpr, bodyExpr):
					var uid = makeUniqId();

					var followingExprs = blockExprs.splice(idx+1,blockExprs.length);
					asyncExprsArray(followingExprs);
					var onCompleteExpr = mkFunctionExpr("_whileComplete"+uid, mkBlock(followingExprs,e), e);
					lastLoopCompleteFunc = "_whileComplete"+uid;

					// Rebuild body with added _while call
					var exprs = _getBlockInnerExprs(bodyExpr);
					exprs.push( mkCallByName("_while"+uid, [], e) );
					asyncExprsArray(exprs);
					var bodyExpr = mkBlock(exprs,e);

					// Wrap the body with condition evaluation
					var asyncLoopFuncBody = mkBlock([
						mkExpr( EIf(
							// Loop condition
							condExpr,

							// Proceed with the loop body
							bodyExpr,

							// Exit the loop
							mkCallByName("_whileComplete"+uid, [], e)
						), e ),
					],e);

					_replaceCurBlockExpr(EBlock([
						// Declare the onComplete function
						onCompleteExpr,

						// Declare _while var first, then set it to the function
						mkExpr( EVar("_while"+uid, mkFunctionExpr(mkBlock([],e),e)), e ),
						mkExpr( EBinop( "=", mkIdentExpr("_while"+uid,e), mkFunctionExpr(asyncLoopFuncBody,e) ), e ),

						// Start the loop
						mkCallByName("_while"+uid, [], e),
					]));
					break;


				// Make DO...WHILE loop async
				case EDoWhile(condExpr, bodyExpr):
					var uid = makeUniqId();

					var followingExprs = blockExprs.splice(idx+1,blockExprs.length);
					asyncExprsArray(followingExprs);
					var onCompleteExpr = mkFunctionExpr("_doWhileComplete"+uid, mkBlock(followingExprs,e), e);
					lastLoopCompleteFunc = "_doWhileComplete"+uid;

					// Rebuild body with added _doWhile call
					var exprs = [];
					exprs = exprs.concat( _getBlockInnerExprs(bodyExpr) );
					exprs.push( mkExpr( EIf(
						// Loop condition
						condExpr,

						// Repeat the loop
						mkCallByName("_doWhile"+uid, [], e),

						// Exit the loop
						mkCallByName("_doWhileComplete"+uid, [], e)
					), e ) );
					asyncExprsArray(exprs);
					var asyncLoopFuncBody = mkBlock(exprs,e);

					_replaceCurBlockExpr(EBlock([
						// Declare the onComplete function
						onCompleteExpr,

						// Declare _doWhile var first, then set it to the function
						mkExpr( EVar("_doWhile"+uid, mkFunctionExpr(mkBlock([],e),e)), e ),
						mkExpr( EBinop( "=", mkIdentExpr("_doWhile"+uid,e), mkFunctionExpr(asyncLoopFuncBody,e) ), e ),

						// First call to the loop
						mkCallByName("_doWhile"+uid, [], e),
					]));
					break;


				case EBreak:
					blockExprs.splice(idx+1,blockExprs.length); // remove all following expressions
					if( lastLoopCompleteFunc==null )
						emitError('Break not in a loop', e);

					_replaceCurBlockExpr( EBlock([
						mkCallByName(lastLoopCompleteFunc, [], e),
						mkExpr( EReturn(null), e),
					]) );
					lastLoopCompleteFunc = null; // reset the last loop complete function
					break;


				case EVar(name, type, valueExpr):
					switch Tools.expr(valueExpr) {
						case EBlock(exprs): asyncExprsArray(exprs);
						case _:
					}

				case EBlock(exprs):
					asyncExprsArray(exprs);

				case EFunction(args, body, name, ret):
					switch Tools.expr(body) {
						case EBlock(exprs): asyncExprsArray(exprs);
						case _: asyncExprsArray([body]);
					}

				case ESwitch(e, cases, defaultExpr):
					for(c in cases)
						switch Tools.expr(c.expr) {
							case EBlock(exprs): asyncExprsArray(exprs);
							case _: asyncExprsArray([c.expr]);
						}


				case ECall(_):
				case EParent(e):
				case EField(e, f):
				case EUnop(op, prefix, e):
				case EReturn(retExpr):
				case EArray(e, index):
				case EArrayDecl(e):
				case ENew(cl, params):
				case EObject(fl):
				case ETernary(cond, e1, e2):
				case EMeta(name, args, e):
				case ECheckType(e, t):
				case EForGen(it, e):

				case EContinue, EThrow(_), ETry(_):
					emitError('Unsupported in Cinematic', e);
			}
			idx++;
		}
	}



	override function checkScriptExpr(scriptExpr:Expr) {
		super.checkScriptExpr(scriptExpr);

		// Check waitUntil functions
		for(fn in waitUntilFunctions.keys()) {
			if( !checker.getGlobals().exists(fn) )
				emitError('Unknown waitUntil function: $fn');
			var tt = checker.getGlobals().get(fn);
			switch tt {
				case TFun(args, ret):
					if( ret!=TBool )
						emitError('"$fn" function must return a Bool');

				case _:
					emitError('"$fn" should be a function, found $tt');
			}
		}
	}



	override function init() {
		super.init();
		uniqId = 0;
		running = false;
		runningTimeS = 0;
		runLoops = [];
		lastLoopCompleteFunc = null;
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

		if( running ) {
			runningTimeS += tmod/fps;
			tryCatch(updateRunningScript);
		}

		// Script completion detection
		if( running && runLoops.length==0 ) {
			running = false;
			onScriptStopped(true);
		}
	}
}


package dn.script;

import hscript.Expr;
import dn.Col;

#if !hscript
#error "hscript lib is required"
#end

private typedef CheckerClass = {
	var cl : Class<Dynamic>;
	var globalInstanceFields : Bool;
	var ?instanceName : Null<String>;
}


/**
	ScriptRunner: an HScript wrapper

	USAGE:
	 - Create a new instance of ScriptRunner
	 - Provide Classes and Enums used in scripts using "exposeXXX()" methods.
	 - Call the ScriptRunner `update()` loop
	 - Use `run()` to execute a script text.
	 - Use `check()` to verify a script text syntax.
**/
class ScriptRunner {
	var fps : Int;
	var interp : hscript.Interp;
	var checker : Null<hscript.Checker>;
	var running = false;
	var runningTimeS = 0.;
	public var tmod(default,null) : Float = 1;
	var lastScript(default,null) : Null<String>;
	var onStopOnce : Null<Bool->Void>;

	var waitUntilFunctions : Map<String, Bool> = new Map();
	var checkerEnums : Array<Enum<Dynamic>> = [];
	var checkerClasses: Array<CheckerClass> = [];
	var internalApiFunctions: Array<{ name:String, func:Dynamic }> = [];

	var runLoops : Array<(tmod:Float)->Bool> = []; // A custom loop is removed from the array if it returns TRUE

	// If TRUE, throw errors
	public var throwErrors = false;

	// If TRUE, the script is not checked before running. This should only be used if check() is manually called before hand.
	public var runWithoutCheck = false;


	#if( debug && !hscriptPos )
	@:deprecated('"-D hscriptPos" is recommended when using ScriptRunner in debug mode')
	#end
	public function new(fps:Int) {
		this.fps = fps;

		interp = new hscript.Interp();
		bindInternalFunction("delayExecutionS", api_delayExecutionS);
		bindInternalFunction("waitUntil", api_waitUntil);
	}


	/**
		Destroy the runner and clean things up
	**/
	public function dispose() {
		running = false;
		runLoops = null;
		interp = null;

		waitUntilFunctions = null;
		checkerEnums = null;
		checkerClasses = null;

		lastScript = null;
	}


	function bindInternalFunction(name:String, func:Dynamic) {
		internalApiFunctions.push({
			name: name,
			func: func,
		});
		interp.variables.set(name,func);
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
		Register an Enum accessible from scripting.
	**/
	public function exposeEnum<T>(e:Enum<T>) {
		checkerEnums.push(e);

		// Add enum name to interp
		interp.variables.set(e.getName(), e);

		// Add enum values to interp
		for(c in e.getConstructors())
			interp.variables.set(c, e.createByName(c));

	}


	/**
		Expose an existing class instance to the script, as a global var with the given name
	 **/
	public function exposeClassInstance<T:Dynamic>(nameInScript:String, instance:Dynamic, ?interfaceInScript:Class<T>, makeFieldsGlobals=false) {
		switch Type.typeof(instance) {
			case TClass(c):
			case _: error( new ScriptError("Not a class: "+instance) );
		}

		var cl = interfaceInScript ?? Type.getClass(instance);
		checkRtti(cl);

		// Register for check
		checkerClasses.push({
			cl: cl,
			instanceName: nameInScript,
			globalInstanceFields: makeFieldsGlobals,
		});

		// Add instance variable to script
		interp.variables.set(nameInScript, instance);

		// Add class name to script
		var className = Type.getClassName(cl);
		interp.variables.set(className, cl); // expose package + class name
		interp.variables.set(className.split(".").pop(), cl); // expose class name only

		// Add all instance fields as globals in script
		if( makeFieldsGlobals )
			for( f in Type.getInstanceFields(cl) )
				interp.variables.set(f, Reflect.field(instance, f));
	}


	/**
		Expose a class to the script
	 **/
	public function exposeClass<T>(cl:Class<T>) {
		checkRtti(cl);
		checkerClasses.push({
			cl: cl,
			globalInstanceFields: false,
		});

		var className = Type.getClassName(cl);
		interp.variables.set(className, cl); // expose true class name (with package)
		interp.variables.set(className.split(".").pop(), cl); // expose just the class name (no package)
	}


	/**
		Register a class type for the check to work.
	 **/
	public function exposeClassForCheck<T>(cl:Class<T>) {
		checkRtti(cl);
		checkerClasses.push({
			cl: cl,
			globalInstanceFields: false,
		});
	}


	inline function checkRtti<T>(cl:Class<T>) {
		if( !Reflect.hasField(cl, "__rtti") )
			error( new ScriptError('Missing @:rtti for $cl') );
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



	// Create a script expression
	inline function mkExpr(e:ExprDef, p:Expr) {
		return hscript.Tools.mk(e,p);
	}

	inline function mkCall(func:String, args:Array<Expr>, p:Expr) {
		return mkExpr(
			ECall(
				mkIdentExpr(func,p),
				args
			),
			p
		);
	}

	// Create an identifier expression
	inline function mkIdentExpr(ident:String, p:Expr) {
		return hscript.Tools.mk(EIdent(ident),p);
	}

	// Create a sync anonymous function expression:  @sync function() {...body...}
	function mkSyncAnonymousFunction(functionBody:Expr, parentExpr:Expr) {
		var anonymousFuncExpr = mkExpr( EFunction([],functionBody), parentExpr );
		return mkExpr( EMeta("sync", [], anonymousFuncExpr), parentExpr );
	}


	/*
		Convert "custom conditions" expressions to valid expressions.
			customWaitUntil(...)
			customWaitUntil
			customWaitUntil >> {...}
			customWaitUntil(...) >> {...}
			0.5;				// pause for 0.5s
			0.5 >> {...}		// async call block content in 0.5s
	*/
	function transformConditionExprs(e:hscript.Expr) {
		switch hscript.Tools.expr(e) {
			case EBlock(exprs):
				var idx = 0;
				function _replaceExpr(with:ExprDef) {
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
								_replaceExpr( ECall(
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
										_replaceExpr( ECall(
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
											_replaceExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
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
											_replaceExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
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
								_replaceExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
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
								_replaceExpr( ECall( mkIdentExpr("waitUntil",e), args ) );
								break;
							}

						case _:
					}
					idx++;
				}

			case _:
		}
		hscript.Tools.iter(e, transformConditionExprs);
	}


	// Return program Expr as a human-readable String
	public function programExprToString(program:Expr) : String {
		var printer = new hscript.Printer();
		return printer.exprToString(program);
	}


	function initChecker() {
		checker = new hscript.Checker();

		var allXmls = [];

		function _addClassRttiXml<T>(c:Class<T>) {
			var rtti = Reflect.field(c, "__rtti");
			allXmls.push( Xml.parse(rtti) );
		}

		function _addEnumRttiXml<T>(e:Enum<T>) {
			var xmlStr = [];
			xmlStr.push('<enum path="${e.getName()}" params="" file="" module="">');
			for(k in e.getConstructors())
				xmlStr.push('<$k/>');
			xmlStr.push('</enum>');

			var xml = Xml.parse( xmlStr.join("\n") );
			allXmls.push(xml);
		}

		function _addTypeAliasXml(name:String, alias:String) {
			var xmlStr = [];
			xmlStr.push('<typedef path="$name" params="" file="" module="$name"><x path="$alias"/></typedef>');
			allXmls.push( Xml.parse(xmlStr.join("\n")) );
		}


		// Build all registered types XMLs
		for(e in checkerEnums)
			_addEnumRttiXml(e);

		for(ac in checkerClasses) {
			_addClassRttiXml(ac.cl);

			// Add alias for the class name alone, without its package
			var name = Type.getClassName(ac.cl);
			if( name.indexOf(".")>=0 )
				_addTypeAliasXml(name.split(".").pop(), name);
		}

		_addTypeAliasXml("dn.Col", "Int");


		// Aggregate XMLs into a single large XML
		var fullXml = Xml.createDocument();
		for(xml in allXmls)
			for(e in xml.elements()) {
				switch e.nodeType {
					case Element: fullXml.addChild(e);
					case PCData:
					case CData:
					case Comment:
					case ProcessingInstruction:
					case DocType, Document: error( new ScriptError("Unexpected node type "+e.nodeType) );
				}
			}

		// Register types
		checker.types.defineClass("String");
		checker.types.defineClass("Array");
		checker.types.addXmlApi(fullXml);

		// Internal API functions
		for(f in internalApiFunctions)
			checker.setGlobal(f.name, TDynamic);

		// Register all enum values as globals
		for(e in checkerEnums) {
			var tt = checker.types.resolve( e.getName() );
			for(k in e.getConstructors())
				checker.setGlobal(k, tt);
		}

		for(ac in checkerClasses) {
			var name = Type.getClassName(ac.cl);
			var tt = checker.types.resolve(name);
			checker.setGlobal(name.split(".").pop(), tt);

			// Register class instance var as global
			if( ac.instanceName!=null ) {
				var name = Type.getClassName(ac.cl);
				var tt = checker.types.resolve(name);
				checker.setGlobal(ac.instanceName, tt);
			}

			// Optionally: register this class instance fields as globals
			if( ac.globalInstanceFields ) {
				switch tt {
					case TInst(c, args): checker.setGlobals(c, args, true);
					case _:
				}
			}
		}
	}




	function scriptStringToExpr(rawScript:String) : Null<Expr> {
		var script = rawScript;

		var parser = new hscript.Parser();
		parser.allowTypes = true;
		parser.allowMetadata = true;

		var program = parser.parseString(script);
		transformConditionExprs(program);

		return program;
	}


	/**
		Check the script validity.
		This requires all types used in scripting to be registered first!
	**/
	public function check(script:String) : Bool {
		init();
		lastScript = script;

		return tryCatch(()->{
			var program = scriptStringToExpr(script);
			checkScriptExpr(program);
		});
	}

	function checkScriptExpr(scriptExpr:Expr) {
		if( checker==null )
			initChecker();
		checker.check(scriptExpr);
	}


	/**
		Execute a script
	**/
	public function run(script:String, ?onDone:Bool->Void) : Bool {
		init();
		lastScript = script;
		runningTimeS = 0;
		onStopOnce = onDone;

		return tryCatch(()->{
			var program = scriptStringToExpr(script);
			Sys.println(programExprToString(program));

			// Check the script
			if( !runWithoutCheck )
				checkScriptExpr(program);

			// Run
			running = true;
			interp.execute(program);
		});
	}


	function tryCatch(cb:Void->Void) : Bool {
		try {
			cb();
			return true;
		}
		catch( err:hscript.Expr.Error ) {
			error( ScriptError.fromHScriptError(err, lastScript) );
			return false;
		}
		catch( err:ScriptError ) {
			error(err);
			return false;
		}
		catch( e:haxe.Exception ) {
			error( ScriptError.fromGeneralException(e, lastScript) );
			return false;
		}
	}


	function init() {
		onStopOnce = null;
		running = false;
		runLoops = [];
	}

	function end(success:Bool) {
		var cb = onStopOnce;
		init();
		if( cb!=null )
			cb(success);
		onScriptStopped(success);
	}


	public function hasScriptRunning() return running;

	public dynamic function onScriptStopped(success:Bool) {}
	public dynamic function onError(err:ScriptError) {}
	public dynamic function onRunningUpdate(tmod:Float) {}


	inline function error(err:ScriptError) {
		#if hscriptPos
			if( err.scriptStr!=null && err.line>0 )
				printErrorInContext(err);
			else
				log(err.toString(), Red);
		#else
			log(err.toString(), Red);
		#end
		end(false);
		onError(err);
		if( throwErrors )
			throw err;
	}


	function printErrorInContext(err:ScriptError) {
		log('-- START OF SCRIPT --', Cyan);
		var i = 1;
		for(line in err.scriptStr.split("\n")) {
			line = StringTools.replace(line, "\t", "  ");
			if( err.line==i ) {
				log( Lib.padRight(Std.string(i), 4) + line+"     <---- "+err.toString(), err.line==i ? Red : White);
			}
			else
				log( Lib.padRight(Std.string(i), 4) + line, err.line==i ? Red : White);
			i++;
		}
		log('-- END OF SCRIPT --', Cyan);
	}


	/** Default log output method, replace it with your own **/
	public dynamic function log(str:String, col:dn.Col=White) {
		Sys.println(str);
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

		// Custom update
		onRunningUpdate(tmod);
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


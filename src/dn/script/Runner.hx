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
	Runner: an HScript wrapper that easily supports running and checking text scripts.

	USAGE:
	 - Create a new instance of Runner
	 - Provide Classes and Enums used in scripts using "exposeXXX()" methods.
	 - Call the Runner `update()` loop
	 - Use `run()` to execute a script text.
	 - Use `check()` to verify a script text syntax.
**/
class Runner {
	var interp : hscript.Interp;
	var checker : Null<hscript.Checker>;
	var lastScript(default,null) : Null<String>;
	var onStopOnce : Null<Bool->Void>;

	var checkerEnums : Array<Enum<Dynamic>> = [];
	var checkerClasses: Array<CheckerClass> = [];
	var internalApiFunctions: Array<{ name:String, func:Dynamic }> = [];

	// If TRUE, throw errors
	public var throwErrors = false;

	// If TRUE, the script is not checked before running. This should only be used if check() is manually called before hand.
	public var runWithoutCheck = false;


	#if( debug && !hscriptPos )
	@:deprecated('"-D hscriptPos" is recommended when using Runner in debug mode')
	#end
	public function new() {
		interp = new hscript.Interp();
	}


	/**
		Destroy the runner and clean things up
	**/
	public function dispose() {
		interp = null;

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
		Convert a standard program Expr to support Runner features.

		Transforms "custom waitUntil conditions" expressions to valid expressions.
			customWaitUntil(...)
			customWaitUntil
			customWaitUntil >> {...}
			customWaitUntil(...) >> {...}
			0.5;				// pause for 0.5s
			0.5 >> {...}		// async call block content in 0.5s
	*/
	function convertProgramExpr(e:hscript.Expr) {
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
		convertProgramExpr(program);

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
	public function run(script:String, ?onDone:(success:Bool)->Void) : Bool {
		init();
		lastScript = script;
		onStopOnce = onDone;

		return tryCatch(()->{
			var program = scriptStringToExpr(script);
			Sys.println(programExprToString(program));

			// Check the script
			if( !runWithoutCheck )
				checkScriptExpr(program);

			// Run
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
	}

	function end(success:Bool) {
		var cb = onStopOnce;
		init();
		if( cb!=null )
			cb(success);
		onScriptStopped(success);
	}


	public dynamic function onScriptStopped(success:Bool) {}
	public dynamic function onError(err:ScriptError) {}


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
}


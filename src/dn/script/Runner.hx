package dn.script;

import hscript.Expr;
import dn.Col;

#if !hscript
#error "hscript lib is required"
#end

private typedef ExposedClass = {
	var cl : Class<Dynamic>;
	var ?instance : { scriptName:String, ref:Dynamic, globalFields:Bool }
}


/**
	Runner: an HScript wrapper that easily supports running and checking text scripts.
	It is highly recommended to use -D hscriptPos when debugging.

	EXAMPLE:
	```haxe
	var runner = new Runner();
	runner.exposeClassInstance("api", myApiClassInstance, MyApiClassInterface);
	runner.run("var x=0; x++; x;");
	trace(runner.output_int); // 1
	```

	USAGE:
	 - Create a new instance of Runner
	 - Provide Classes and Enums used in scripts using "exposeXXX()" methods.
	 - Use `run()` to execute a script text.
	 - Use `check()` to verify a script text syntax.
**/
class Runner {
	var interp : hscript.Interp;
	var checker : Null<hscript.Checker>;
	var lastScript(default,null) : Null<String>;
	var lastRunOutput : Null<Dynamic>;

	var enums : Array<Enum<Dynamic>> = [];
	var classes : Array<ExposedClass> = [];
	var internalApiFunctions: Array<{ name:String, func:Dynamic }> = [];

	// If TRUE, throw errors instead of intercepeting them
	public var throwErrors = false;

	// If TRUE, the script is not checked before running. This should only be used if check() is manually called before hand.
	public var runWithoutCheck = false;

	/** Last script output, untyped **/
	public var output(get,never) : Null<Dynamic>;

	/** Last script output value typed as Null<String>. If the output isn't an actual String, this equals to the String representation of the output. **/
	public var output_str(get,never) : Null<String>;

	/** Last script output value typed as Int. If the output isn't a valid number, this equals to 0. **/
	public var output_int(get,never) : Int;

	/** Last script output value typed as Float. If the output isn't a valid number, this equals to 0. **/
	public var output_float(get,never) : Float;

	/** Last script output value typed as Bool. If the output isn't a valid Bool, this equals to FALSE. **/
	public var output_bool(get,never) : Bool;



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

		enums = null;
		classes = null;

		lastScript = null;
	}


	function bindInternalFunction(name:String, func:Dynamic) {
		internalApiFunctions.push({
			name: name,
			func: func,
		});
	}


	/**
		Register an Enum accessible from scripting.
	**/
	public function exposeEnum<T>(e:Enum<T>) {
		enums.push(e);
	}


	/**
		Expose an existing class instance to the script, as a global var with the given name.
		If `makeFieldsGlobals` is TRUE, then all fields from the instance will be directly available as globals in scripts.

		For example, if `myApi.doSomething()` exists then, in scripts, `doSomething()` may be called directly, in addition of `<nameInScript>.doSomething()`.

		IMPORTANT: the class should have both @:rtti and @:keep meta!
	 **/
	public function exposeClassInstance<T:Dynamic>(nameInScript:String, instance:Dynamic, ?interfaceInScript:Class<T>, makeFieldsGlobals=false) {
		switch Type.typeof(instance) {
			case TClass(c):
				if( interfaceInScript!=null && !Std.isOfType(instance,interfaceInScript) ) {
					emitError('$c is not $interfaceInScript');
					return;
				}
			case _:
				emitError('Not a class: $instance');
				return;
		}

		var cl = interfaceInScript ?? Type.getClass(instance);
		if( !checkRtti(cl) )
			return;

		// Register for check
		classes.push({
			cl: cl,
			instance: {
				scriptName: nameInScript,
				ref: instance,
				globalFields: makeFieldsGlobals,
			},
		});
	}


	/**)
		Expose a class to the script
		IMPORTANT: the class should have both @:rtti and @:keep meta!
	 **/
	public function exposeClass<T>(cl:Class<T>) {
		if( !checkRtti(cl) )
			return;

		classes.push({ cl: cl });
	}


	/**
		Register a class type for the check to work.
		This might be needed if one your API method returns an instance of some other class B. Then B should be provided for checking purpose.
		For example, if you have `var npc = myApi.createNpc()`, the npc variable is using a type (eg. Npc) that should be explictely exposed to the runner.
		IMPORTANT: the class should have both @:rtti and @:keep meta!
	 **/
	public function exposeClassForCheck<T>(cl:Class<T>) {
		if( !checkRtti(cl) )
			return;

		classes.push({ cl: cl });
	}


	function checkRtti<T>(cl:Class<T>) : Bool {
		if( Reflect.hasField(cl, "__rtti") ) {
			// Check @:keep presence
			// var rtti = haxe.rtti.Rtti.getRtti(cl);
			// var hasKeep = false;
			// for(m in rtti.meta)
			// 	if( m.name==":keep" ) {
			// 		hasKeep = true;
			// 		break;
			// 	}
			// if( !hasKeep )
			// 	emitError('Missing @:keep for $cl (this is required to prevent DCE from dumping functions used only through scripting)');
			// return hasKeep;

			return true; // a bug prevent checking the presence of @:keep (see https://github.com/HaxeFoundation/haxe/issues/12300)
		}
		else {
			emitError('Missing @:rtti for $cl');
			return false;
		}
	}




	/*
		Convert a standard program Expr to support special Runner language features.
	*/
	function convertProgramExpr(e:hscript.Expr) {}


	// Return program Expr as a human-readable String using Printer
	function printerExprToString(program:Expr) : String {
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
		for(e in enums)
			_addEnumRttiXml(e);

		for(ac in classes) {
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
					case _:
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
		for(e in enums) {
			var tt = checker.types.resolve( e.getName() );
			for(k in e.getConstructors())
				checker.setGlobal(k, tt);
		}

		for(ac in classes) {
			var name = Type.getClassName(ac.cl);
			var tt = checker.types.resolve(name);
			checker.setGlobal(name.split(".").pop(), tt);

			if( ac.instance!=null ) {
				// Register class instance var as global
				var name = Type.getClassName(ac.cl);
				var tt = checker.types.resolve(name);
				checker.setGlobal(ac.instance.scriptName, tt);

				// Optionally: register this class instance fields as globals
				if( ac.instance.globalFields ) {
					switch tt {
						case TInst(c, args): checker.setGlobals(c, args, true);
						case _:
					}
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



	function initInterpVariables() {
		// Init
		@:privateAccess interp.resetVariables(); // use Interp defaults

		// Classes
		for(c in classes) {
			// Add class instance variable to script
			if( c.instance!=null )
				interp.variables.set(c.instance.scriptName, c.instance.ref);

			// Add class name to script
			var className = Type.getClassName(c.cl);
			interp.variables.set(className, c.cl); // expose package + class name
			interp.variables.set(className.split(".").pop(), c.cl); // expose class name alone (wthout package)

			// Copy all instance fields as globals in script
			if( c.instance!=null && c.instance.globalFields ) {
				var fields = Type.getInstanceFields( Type.getClass(c.instance.ref));
				for( f in fields ) {
					if( f.substr(0,4)=="set_" )
						continue;

					if( f.substr(0,4)=="get_" )
						f = f.substr(4);

					interp.variables.set(f, Reflect.getProperty(c.instance.ref, f));
				}
			}
		}

		// Enums
		for(e in enums) {
			// Add enum name to interp
			interp.variables.set(e.getName(), e);

			// Add enum values to interp
			for(c in e.getConstructors())
				interp.variables.set(c, e.createByName(c));
		}


		// Internal API functions
		for(f in internalApiFunctions)
			interp.variables.set(f.name, f.func);
	}

	/**
		Execute a script
	**/
	public function run(script:String) : Bool {
		init();
		lastScript = script;

		var result = tryCatch(()->{
			initInterpVariables();

			var program = scriptStringToExpr(script);

			// Check the script
			if( !runWithoutCheck )
				checkScriptExpr(program);

			// Run
			lastRunOutput = interp.execute(program);
		});

		return result;
	}


	inline function get_output() return lastRunOutput;

	function get_output_int() {
		return switch Type.typeof(lastRunOutput) {
			case TInt, TFloat: M.isValidNumber(lastRunOutput) ? Std.int(lastRunOutput) : 0;
			case _: 0;
		}
	}

	function get_output_float() {
		return switch Type.typeof(lastRunOutput) {
			case TInt, TFloat: M.isValidNumber(lastRunOutput) ? lastRunOutput : 0;
			case _: 0;
		}
	}

	function get_output_bool() {
		return switch Type.typeof(lastRunOutput) {
			case TBool: lastRunOutput;
			case _: false;
		}
	}

	function get_output_str() {
		return switch Type.typeof(lastRunOutput) {
			case TNull: null;
			case TClass(String): lastRunOutput;
			case _: Std.string(lastRunOutput);
		}
	}


	function tryCatch(cb:Void->Void) : Bool {
		try {
			cb();
			return true;
		}
		catch( err:hscript.Expr.Error ) {
			var err = ScriptError.fromHScriptError(err, lastScript);
			reportError(err);
			if( throwErrors )
				throw err;
			return false;
		}
		catch( err:ScriptError ) {
			reportError(err);
			if( throwErrors )
				throw err;
			return false;
		}
		catch( e:haxe.Exception ) {
			if( throwErrors )
				throw e;
			else
				reportError( ScriptError.fromGeneralException(e, lastScript) );
			return false;
		}
	}


	function init() {
		lastRunOutput = null;
	}


	public dynamic function onError(err:ScriptError) {}

	function emitError(msg:String) {
		var err = new ScriptError(msg);
		reportError(err);
		if( throwErrors )
			throw err;
	}

	function reportError(err:ScriptError) {
		#if hscriptPos
			if( err.scriptStr!=null && err.line>0 )
				printErrorInContext(err);
			else
				log(err.toString(), Red);
		#else
			log(err.toString(), Red);
		#end
		onError(err);
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
		trace(str);
	}
}


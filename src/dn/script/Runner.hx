package dn.script;

import hscript.Expr;
import dn.Col;

#if !hscript
#error "hscript lib is required"
#end

enum ScriptGlobalAccess {
	None;
	PublicFields;
	PublicAndPrivateFields;
}

enum ScriptRethrowLevel {
	Nothing;
	HaxeExceptions;
	AllExceptions;
}

private typedef ExposedClass = {
	var cl : Class<Dynamic>;
	var ?instance : { scriptName:Null<String>, ref:Dynamic, globalAccess:ScriptGlobalAccess };
}

private typedef ExposedFunction = {
	var cl : Class<Dynamic>;
	var f : { realName:String, scriptName:String, ref:Dynamic };
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
	public var lastScriptStr(default,null) : Null<String>;
	public var lastScriptExpr(default,null) : Null<Expr>;
	public var lastRunUid(default,null) = 0;
	var lastRunOutput : Null<Dynamic>;
	var customRunOutput : Null<Dynamic>;
	public var origin : String = "Runner";

	public var lastException(default,null) : Null<haxe.Exception>;
	public var lastScriptError(get,never) : Null<ScriptError>;
		inline function get_lastScriptError() return Std.downcast(lastException,ScriptError);

	var enums : Array<Enum<Dynamic>> = [];
	var classes : Array<ExposedClass> = [];
	var functions : Array<ExposedFunction> = [];
	var consts : Array<{ name:String, value:Dynamic, ttype:hscript.Checker.TType }> = [];
	var internalKeywords: Array<{ name:String, type:hscript.Checker.TType, ?instanceRef:Dynamic }> = [];

	// If TRUE, throw errors instead of intercepeting them
	public var rethrowLevel : ScriptRethrowLevel = Nothing;

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


	#if heaps
	var debug : Null<dn.script.Debug>;
	#end


	#if( debug && !hscriptPos )
	@:deprecated('"-D hscriptPos" is recommended when using Runner in debug mode')
	#end
	public function new() {
		interp = new hscript.Interp();

		// Init iterator creators
		function _makeIteratorType(iteratedType:hscript.Checker.TType) : hscript.Checker.TType {
			return TFun(
				[{ name:"it", opt:false, t:TDynamic }],
				TAnon([
					{ name : "next", opt : false, t : TFun([],iteratedType) },
					{ name : "hasNext", opt : false, t : TFun([],TBool) }
				])
			);
		}
		addInternalKeyword("makeIterator_dynamic", _makeIteratorType(TDynamic), @:privateAccess interp.makeIterator);
		addInternalKeyword("makeIterator_int", _makeIteratorType(TInt), @:privateAccess interp.makeIterator);
		addInternalKeyword("out", TFun([{ name:"v", opt:false, t:TDynamic }], TVoid), forceOutput);

		// Register Int based named-colors (Red, Green, Blue, etc)
		var values = MacroTools.getAbstractEnumValues(Col.ColorEnum);
		for(v in values)
			addConst(v.name, v.value);
	}


	/**
		Destroy the runner and clean things up
	**/
	public function dispose() {
		interp = null;

		enums = null;
		classes = null;
		functions = null;
		consts = null;
		internalKeywords = null;

		lastScriptStr = null;
		lastScriptExpr = null;
		lastException = null;
		lastRunOutput = null;
		customRunOutput = null;
		#if heaps
		if( debug!=null ) {
			debug.destroy();
			debug = null;
		}
		#end
	}


	function addInternalKeyword(name:String, type:hscript.Checker.TType, ?instance:Dynamic) {
		internalKeywords.push({
			name: name,
			type: type,
			instanceRef: instance,
		});
		invalidateChecker();
	}


	public function isKeyword(name:String) : Bool {
		for( k in internalKeywords )
			if( k.name==name )
				return true;
		return false;
	}


	/**
		Register an Enum accessible from scripting.
	**/
	public function exposeEnum<T>(e:Enum<T>) {
		enums.push(e);
		invalidateChecker();
	}


	/**
		Expose an existing class instance to the script, as a global var with the given name.
		If `makeFieldsGlobals` is TRUE, then all fields from the instance will be directly available as globals in scripts.

		For example, if `myApi.doSomething()` exists then, in scripts, `doSomething()` may be called directly, in addition of `<nameInScript>.doSomething()`.

		IMPORTANT: the class should have both @:rtti and @:keep meta!
	 **/
	public function exposeClassInstance<T:Dynamic>(instance:Dynamic, ?interfaceInScript:Class<T>, ?nameInScript:String,globalAccess:ScriptGlobalAccess=None) {
		// Check instance validity
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

		// Register
		var cl = interfaceInScript ?? Type.getClass(instance);
		if( !checkRtti(cl) )
			return;
		classes.push({
			cl: cl,
			instance: {
				scriptName: nameInScript,
				ref: instance,
				globalAccess: globalAccess,
			},
		});

		invalidateChecker();
	}


	/**
		Register a class definition for the script checking.
		IMPORTANT: the class X should have both @:rtti and @:keep meta!

		This might be needed if one your API method returns an instance of some other class X. Then X should be provided for checking purpose.
		For example, if you have `var npc = myApi.createNpc()`, the npc variable is using some type (eg. Npc) that should be explictely exposed to the runner.
	 **/
	public function exposeClassDefinition<T>(cl:Class<T>) {
		if( !checkRtti(cl) )
			return;

		classes.push({ cl: cl });
		invalidateChecker();
	}


	public function exposeFunction<T:Dynamic>(classOrInst:T, func:Dynamic, ?customScriptName:String) {
		// Check class
		var cl = switch Type.typeof(classOrInst) {
			case TClass(c): c;
			case _: Type.getClass(classOrInst);
		}
		if( cl==null ) {
			emitError('Not a class or a class instance: $classOrInst');
			return;
		}

		// Check method
		switch Type.typeof(func) {
			case TFunction:
			case _:
				emitError('Not a function: $func');
				return;
		}

		if( !checkRtti(cl) )
			return;

		// Resolve function name
		var name : String = null;
		for(f in Type.getInstanceFields(cl) )
			if( Reflect.getProperty(classOrInst,f)==func ) {
				name = f;
				break;
			}
		if( name==null ) {
			emitError('Cannot resolve function name for $func in class $cl');
			return;
		}

		// Register
		functions.push({
			cl: cl,
			f: {
				realName: name,
				scriptName: customScriptName ?? name,
				ref: func,
			},
		});

		invalidateChecker();
	}


	public function addConst(name:String, value:Dynamic) {
		// Check name validity
		if( isKeyword(name) ) {
			emitError('Cannot add const "$name": this name is already used as an internal keyword');
			return;
		}
		if( hasConst(name) ) {
			emitError('Cannot add const "$name": this name is already used as a const');
			return;
		}

		// Check value type
		var ttype : hscript.Checker.TType = switch Type.typeof(value) {
			case TInt: TInt;
			case TFloat: TFloat;
			case TBool: TBool;
			case _: null;
		}
		if( ttype==null ) {
			emitError('Const "$name" has unsupported type: ${Type.typeof(value)}');
			return;
		}

		// Register
		consts.push({ name:name, value:value, ttype:ttype });
		invalidateChecker();
	}


	public function hasConst(name:String) : Bool {
		for( c in consts )
			if( c.name==name )
				return true;
		return false;
	}


	public function exposeFunctionsByPrefix(classOrInst:Dynamic, prefix:String, keepPrefix:Bool) {
		// Check class
		var cl = switch Type.typeof(classOrInst) {
			case TClass(c): c;
			case _: Type.getClass(classOrInst);
		}
		if( cl==null ) {
			emitError('Not a class or a class instance: $classOrInst');
			return;
		}

		if( !checkRtti(cl) )
			return;

		// Register all functions with the given prefix
		var count = 0;
		for(f in Type.getInstanceFields(cl))
			if( f.indexOf(prefix)==0 ) {
				exposeFunction(classOrInst, Reflect.getProperty(classOrInst,f), keepPrefix ? f : f.substr(prefix.length) );
				count++;
			}

		if( count==0 )
			emitError('No function found with prefix "$prefix" in class $cl');
	}


	function checkRtti<T>(cl:Class<T>) : Bool {
		if( haxe.rtti.Rtti.hasRtti(cl) ) {
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
	function convertProgramExpr(program:hscript.Expr) {}


	// Return program Expr as a human-readable String using Printer
	function printerExprToString(program:Expr) : String {
		var printer = new hscript.Printer();
		return printer.exprToString(program);
	}

	public function getLastScriptExprAsString() : String {
		return lastScriptExpr==null ? "" : printerExprToString(lastScriptExpr);
	}

	#if heaps
	public function openDebugger(ctx:h2d.Object) {
		if( debug==null )
			debug = new dn.script.Debug(this, ctx);
		return debug;
	}

	public function closeDebugger() {
		if( debug!=null ) {
			debug.destroy();
			debug = null;
		}
	}

	public inline function isDebuggerOpen() return debug!=null && !debug.destroyed;
	#end


	function invalidateChecker() {
		checker = null;
	}

	function initChecker() {
		checker = new hscript.Checker();

		var allXmls = [];

		var doneClasses = new Map();
		function _addClassRttiXml<T>(c:Class<T>) {
			var id = Type.getClassName(c);
			if( doneClasses.exists(id) )
				return;
			doneClasses.set(id, true);
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

		for(f in functions)
			_addClassRttiXml(f.cl);

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

		// Register all enum values as globals
		for(e in enums) {
			var enumTType = checker.types.resolve( e.getName() );
			for( k in e.getConstructors() )
				checker.setGlobal(k, enumTType);
		}

		// Classes
		for(ac in classes) {
			var name = Type.getClassName(ac.cl);
			var tt = checker.types.resolve(name);
			checker.setGlobal(name.split(".").pop(), tt);

			// Check that all super classes are known
			var superCl = Type.getSuperClass(ac.cl);
			while( superCl!=null ) {
				var name = Type.getClassName(superCl);
				var tt = checker.types.resolve(name);
				if( tt==null )
					emitError('Unknown superclass "$name" (from ${Type.getClassName(ac.cl)}). Use `exposeClassDefinition($name)` maybe?');
				superCl = Type.getSuperClass(superCl);
			}

			if( ac.instance!=null ) {
				// Register class instance var as global
				var name = Type.getClassName(ac.cl);
				var tt = checker.types.resolve(name);
				if( ac.instance.scriptName!=null )
					checker.setGlobal(ac.instance.scriptName, tt);

				// Optionally: register this class instance fields as globals
				switch tt {
					case TInst(c, args):
						switch ac.instance.globalAccess {
							case None:
							case PublicFields: checker.setGlobals(c, args, false);
							case PublicAndPrivateFields: checker.setGlobals(c, args, true);
						}
					case _:
				}
			}
		}

		for(fn in functions) {
			var found = false;
			var classTType = checker.types.resolve(Type.getClassName(fn.cl));
			switch classTType {
				case TInst(c, args):
					for( field in c.fields ) {
						if( field.name==fn.f.realName) {
							found = true;
							checker.setGlobal(fn.f.scriptName, field.t);
							break;
						}
					}

				case _:
					emitError('Not a class: ${fn.cl}');
			}
			if( !found ) {
				emitError('Function "${fn.f.realName}" cannot be typed in ${Type.getClassName(fn.cl)} (inherited maybe?)');
				continue;
			}
		}

		// Consts
		for(c in consts)
			checker.setGlobal(c.name, c.ttype);

		// Internal keywords
		var globals = checker.getGlobals();
		for(k in internalKeywords)
			if( globals.exists(k.name) )
				emitError('Script keyword "${k.name}" is used somewhere');
			else
				globals.set(k.name, k.type);
	}




	function scriptStringToExpr(rawScript:String) : Null<Expr> {
		var script = rawScript;

		var parser = new hscript.Parser();
		parser.allowTypes = true;
		parser.allowMetadata = true;

		var program = parser.parseString(script, origin);
		convertProgramExpr(program);

		return program;
	}


	/**
		Check the script validity.
		This requires all types used in scripting to be registered first!
	**/
	public function check(script:String) : Bool {
		init();
		lastScriptStr = script;

		return tryCatch(()->{
			var program = scriptStringToExpr(script);
			lastScriptExpr = program;
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
			if( c.instance!=null && c.instance.scriptName!=null )
				interp.variables.set(c.instance.scriptName, c.instance.ref);

			// Add class name to script
			var className = Type.getClassName(c.cl);
			interp.variables.set(className, c.cl); // expose package + class name
			interp.variables.set(className.split(".").pop(), c.cl); // expose class name alone (wthout package)

			// Copy all instance fields as globals in script
			if( c.instance!=null ) {
				switch c.instance.globalAccess {
					case None:
					case PublicFields, PublicAndPrivateFields:
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
		}

		// Functions
		for(fn in functions) {
			var fields = Type.getInstanceFields(fn.cl);
			interp.variables.set(fn.f.scriptName, fn.f.ref);
		}

		// Enums
		for(e in enums) {
			// Add enum name to interp
			interp.variables.set(e.getName(), e);

			// Add enum values to interp
			for(c in e.getConstructors())
				interp.variables.set(c, e.createByName(c));
		}


		// Consts
		for(c in consts)
			interp.variables.set(c.name, c.value);

		// Bind internal keyword references to instances
		for(k in internalKeywords)
			if( k.instanceRef!=null )
				interp.variables.set(k.name, k.instanceRef);
	}


	#if heaps
	public function loadAndRunRes(r:hxd.res.Resource) {
		var s = null;
		tryCatch(()->{
			s = r.entry.getText();
			origin = r.entry.name;
		});
		return s!=null ? run(s) : false;
	}
	#end

	#if sys
	public function loadAndRunFile(filePath:String) {
		var s = null;
		tryCatch(()->{
			s = sys.io.File.getContent(filePath);
			origin = FilePath.extractFileWithExt(filePath);
		});
		return s!=null ? run(s) : false;
	}
	#end

	/**
		Execute a script
	**/
	public function run(script:String) : Bool {
		init();
		lastScriptStr = script;

		var result = tryCatch(()->{
			initInterpVariables();

			var program = scriptStringToExpr(script);
			lastScriptExpr = program;

			// Check the script
			if( !runWithoutCheck )
				checkScriptExpr(program);

			// Run
			lastRunOutput = interp.execute(program);
		});

		return result;
	}


	function forceOutput(v:Dynamic) {
		customRunOutput = v;
	}

	inline function get_output() return customRunOutput ?? lastRunOutput;

	function get_output_int() {
		return switch Type.typeof(output) {
			case TInt, TFloat: M.isValidNumber(output) ? Std.int(output) : 0;
			case _: 0;
		}
	}

	function get_output_float() {
		return switch Type.typeof(output) {
			case TInt, TFloat: M.isValidNumber(output) ? output : 0;
			case _: 0;
		}
	}

	function get_output_bool() {
		return switch Type.typeof(output) {
			case TBool: output;
			case _: false;
		}
	}

	function get_output_str() {
		return switch Type.typeof(output) {
			case TNull: null;
			case TClass(String): output;
			case _: Std.string(output);
		}
	}


	function tryCatch(cb:Void->Void) : Bool {
		try {
			try {
				try {
					cb();
					return true;
				}
				catch( err:hscript.Expr.Error ) {
					var err = ScriptError.fromHScriptError(err, lastScriptStr);
					reportError(err);
					switch rethrowLevel {
						case Nothing:
						case HaxeExceptions:
						case AllExceptions:
							throw err;
					}
					return false;
				}
			}
			catch( err:ScriptError ) {
				reportError(err);
				switch rethrowLevel {
					case Nothing:
					case HaxeExceptions:
					case AllExceptions:
						throw err;
				}
				return false;
			}
		}
		catch( unknownException:haxe.Exception ) {
			reportError(unknownException);
			switch rethrowLevel {
				case Nothing:
				case HaxeExceptions, AllExceptions:
					throw unknownException;
			}
			return false;
		}
	}


	function init() {
		lastRunUid++;
		lastException = null;
		lastRunOutput = null;
		customRunOutput = null;
		lastScriptStr = null;
		lastScriptExpr = null;
	}


	public dynamic function onError(err:haxe.Exception) {}


	// Throw a ScriptError exception with the given message.
	public inline function emitError(msg:String, ?expr:Expr) {
		var err = new ScriptError(msg, lastScriptStr);
		#if hscriptPos
		if( expr!=null )
			err.overrideLine(expr.line);
		#end
		throw err;
	}

	function reportError(exception:haxe.Exception) {
		lastException = exception;
		onError(exception);
		if( #if heaps debug==null && #end Std.isOfType(exception,ScriptError) ) {
			#if hscriptPos
				if( lastScriptError.scriptStr!=null && lastScriptError.line>0 )
					printErrorInContext(lastScriptError);
				else
					log(lastScriptError.toString(), Red);
			#else
				log(lastScriptError.toString(), Red);
			#end
		}
	}


	function printErrorInContext(err:ScriptError) {
		log('-- $origin --', Cyan);
		var i = 1;
		for(line in err.scriptStr.split("\n")) {
			line = StringTools.replace(line, "\t", "  ");
			if( err.line==i )
				log( Lib.padRight(Std.string(i), 4) + line+"     <---- "+err.getErrorOnly(), Red);
			else
				log( Lib.padRight(Std.string(i), 4) + line, White);
			i++;
		}
		log('-- EOF --', Cyan);
	}


	/** Default log output method, replace it with your own **/
	public dynamic function log(str:String, col:dn.Col=White) {
		trace(str);
	}
}


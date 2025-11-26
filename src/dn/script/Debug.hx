package dn.script;

import hscript.Expr;
import dn.Col;


enum ExposedTypeCategory {
	T_Enum;
	T_ClassInst;
	T_ClassDef;
}

typedef ExposedType = {
	var name : String;
	var category : ExposedTypeCategory;
	var values : Array<{ desc:String, col:Col }>;
}


class Debug extends dn.Process {
	var runner : Runner;

	var minWidth : Int = 400;
	var gap = 8;
	var baseColor : Col = 0x1e1936;
	var badColor : Col = 0xA71837;

	var font : h2d.Font;
	var wrapper : h2d.Flow;
	var header : h2d.Flow;

	var errorFlow : h2d.Flow;
	var scriptFlow : h2d.Flow;
	var runtimeFlow : h2d.Flow;
	var typesFlow : h2d.Flow;
	var globalsFlow : h2d.Flow;

	var timerTf : h2d.Text;
	var outputTf : h2d.Text;
	var originTf : h2d.Text;

	var expands : Map<String,Bool> = new Map();

	public function new(r:Runner, ctx:h2d.Object) {
		super();

		createRoot(ctx);
		runner = r;

		font = hxd.res.DefaultFont.get();

		wrapper = new h2d.Flow(root);
		wrapper.layout = Vertical;
		wrapper.verticalSpacing = gap;
		wrapper.minWidth = minWidth;
		wrapper.backgroundTile = h2d.Tile.fromColor(baseColor.toBlack(0.5).withAlpha(0.85));

		header = new h2d.Flow(wrapper);
		header.paddingLeft = 4;
		header.layout = Horizontal;
		header.horizontalSpacing = gap;
		header.verticalAlign = Middle;
		header.backgroundTile = h2d.Tile.fromColor(isAsync() ? 0x044c1e : 0x062e52);

		createText(isAsync() ? "ASYNC" : "SYNC", isAsync() ? 0x1dd862 : 0x2780ce, header);
		timerTf = createText("", White, header);
		header.getProperties(timerTf).minWidth = 50;

		var f = new h2d.Flow(header);
		f.layout = Horizontal;
		f.verticalAlign = Middle;
		createText("out=", f);
		outputTf = createText("", White, f);
		header.getProperties(f).minWidth = 50;

		originTf = createText(runner.origin, White, header);

		var closeBt = createButton("x", ()->{
			if( destroyed )
				return;
			onClose();
			destroy();
		}, header);
		header.getProperties(closeBt).horizontalAlign = Right;

		var spacing = 1;
		errorFlow = new h2d.Flow(wrapper);
		errorFlow.layout = Vertical;
		errorFlow.verticalSpacing = spacing;

		runtimeFlow = new h2d.Flow(wrapper);
		runtimeFlow.layout = Vertical;
		runtimeFlow.verticalSpacing = spacing;

		scriptFlow = new h2d.Flow(wrapper);
		scriptFlow.layout = Vertical;
		scriptFlow.verticalSpacing = spacing;

		typesFlow = new h2d.Flow(wrapper);
		typesFlow.layout = Vertical;
		typesFlow.verticalSpacing = spacing;

		globalsFlow = new h2d.Flow(wrapper);
		globalsFlow.layout = Vertical;
		globalsFlow.verticalSpacing = spacing;

		renderAll();
	}

	/** Replace this and return TRUE when the Debug panel should self-destroy (eg. if some attached context is lost)**/
	public dynamic function shouldSelfDestroy() return false;

	override function onDispose() {
		super.onDispose();

		@:privateAccess
		if( runner.debug==this )
			runner.debug = null;

		runner = null;
		expands = null;
		font = null;
	}

	inline function isAsync() return runner is dn.script.AsyncRunner;
	inline function asAsync() return Std.downcast(runner, dn.script.AsyncRunner);

	function renderAll() {
		renderError();
		renderRuntime();
		renderScript();
		renderTypes();
		renderGlobals();

		updateTimer();
	}

	function updateTimer() {
		if( isAsync() ) {
			timerTf.text = M.pretty(asAsync().runningTimeS, 2) + "s";
			timerTf.visible = true;
		}
		else
			timerTf.visible = false;
	}


	function renderError() {
		errorFlow.removeChildren();
		if( runner.lastException==null ) {
			errorFlow.visible = false;
		}
		else {
			errorFlow.visible = true;
			createCollapsable(runner.lastException.message, badColor.toBlack(0.65), (p)->{
				createCopyButton(runner.lastException.stack.toString(), p);
				createText(runner.lastException.toString(), Red, p);
				if( runner.lastScriptError!=null && runner.lastScriptError.line>=0 )
					createScript(runner.lastScriptError.scriptStr, p);
				else
					createText(runner.lastException.stack.toString(), p);
			}, errorFlow);
		}
	}

	function renderScript() {
		scriptFlow.removeChildren();

		// Original script string
		createCollapsable("Script (original)", (p)->{
			if( runner.lastScriptStr==null )
				return;

			createScript(runner.lastScriptStr, p);
		}, scriptFlow);

		// Converted script expr
		createCollapsable("Script (converted)", (p)->{
			if( runner.lastScriptExpr==null )
				return;

			createCopyButton( runner.getLastScriptExprAsString(), p );

			var raw = runner.getLastScriptExprAsString();
			raw = StringTools.replace(raw, "\t", "   ");
			raw = StringTools.replace(raw, "\r", "");
			for(line in raw.split("\n")) {
				if( line.length==0 )
					p.addSpacing(8);
				else
					createText(line, White, p);
			}
		}, scriptFlow);
	}


	function createScript(script:String, p:h2d.Flow) {
		var col : Col = White;
		var raw = script;
		raw = StringTools.replace(raw, "\t", "   ");
		raw = StringTools.replace(raw, "\r", "");

		var i = 1;
		for(line in raw.split("\n")) {
			if( line.length==0 )
				p.addSpacing(8);
			else {
				var lineWithNumber = Lib.padRight(Std.string(i), 4) + line;
				if( runner.lastScriptError!=null && runner.lastScriptError.line==i )
					createText( lineWithNumber+"    <--- "+runner.lastScriptError.getErrorOnly(), badColor, p);
				else
					createText( lineWithNumber, col, p);
			}
			i++;
		}
	}


	function renderRuntime() {
		if( !isAsync() )
			return;

		runtimeFlow.removeChildren();

		var async = asAsync();

		function _renderPromiseList(f:h2d.Flow) {
			f.removeChildren();
			createText("PROMISES:", White, f);
			@:privateAccess
			for(prom in async.waitedPromises)
				createText(prom.toString(), prom.isFinished() ? Lime : Yellow, f);
		}
		createCollapsable("Promises", (f:h2d.Flow)->{
			_renderPromiseList(f);
			@:privateAccess
			for(prom in async.waitedPromises)
				if( !prom.isFinished() )
					prom.onAnyEnd( ()->_renderPromiseList(f) );
		}, runtimeFlow);
	}

	function initChecker() {
		@:privateAccess
		if( runner.checker==null )
			runner.initChecker();
	}

	function getAllExposedTypes() : Array<ExposedType> {
		var allTypes : Array<ExposedType> = [];

		// Enums
		@:privateAccess
		for(e in runner.enums) {
			allTypes.push({
				name: e.getName(),
				category : T_Enum,
				values: e.getConstructors().map( k->{
					desc: k,
					col: Pink,
				}),
			});
		}

		// Classes
		@:privateAccess
		for(c in runner.classes) {
			var name = Type.getClassName(c.cl);
			var t : ExposedType = {
				name: name,
				category: c.instance!=null ? T_ClassInst : T_ClassDef,
				values: [],
			}
			allTypes.push(t);

			// List all class fields
			for( f in runner.checker.getFields( runner.checker.types.resolve(name) ) )
				t.values.push({
					desc: getDescFromTType(f.name, f.t),
					col: getColorFromTType(f.name, f.t),
				});

			t.values.sort((a,b)->Reflect.compare(a.desc.toLowerCase(), b.desc.toLowerCase()));
		}

		return allTypes;
	}


	function renderTypes() {
		typesFlow.removeChildren();

		initChecker();

		// List unresolved types
		var unresolveds = getAllUnresolvedTypes();
		function _getUnresolveds(className:Null<String>) {
			var filter = unresolveds.filter( u->u.className==className );
			return filter.length>0 ? filter[0].unresolveds : [];
		}

		// Unresolved globals
		var unresolverGlobals = _getUnresolveds(null);
		if( unresolverGlobals.length>0 )
			createCollapsable("Unresolved globals", badColor, (p)->{
				for(u in unresolverGlobals)
					createText("   "+u, badColor, p);
			}, typesFlow);

		// Exposed types
		var allTypes = getAllExposedTypes();
		for(t in allTypes) {
			var catLabel = switch t.category {
				case T_Enum: 'Enum';
				case T_ClassInst: 'Class Instance';
				case T_ClassDef: 'Class Definition';
			}
			var unresolvedCount = _getUnresolveds(t.name).length;
			createCollapsable(
				'"${t.name}"' + (unresolvedCount>0?' ($unresolvedCount)':''),
				catLabel,
				unresolvedCount>0 ? badColor : 0,
				(p)->{
					for(v in t.values)
						createText(v.desc, v.col, p);
				},
				typesFlow
			);
		}
	}


	function getAllUnresolvedTypes() {
		var unresolveds : Array<{ className:Null<String>, unresolveds:Array<String> }> = [];

		function _addUnresolved(className:Null<String>, name:String, ttype:hscript.Checker.TType) {
			for(u in unresolveds)
				if( u.className==className ) {
					u.unresolveds.push( getDescFromTType(name,ttype) );
					return;
				}
			unresolveds.push({ className:className, unresolveds:[ getDescFromTType(name,ttype) ] });
		}

		function _checkFunction(className:String, functionName:String, functionTType:hscript.Checker.TType) {
			switch functionTType {
				case TFun(args, ret):
					for(a in args)
						switch a.t {
							case TUnresolved(_):
								_addUnresolved(className, functionName, functionTType);
								return;

							case _:
						}
					switch ret {
						case TUnresolved(_):
							_addUnresolved(className, functionName, functionTType);
							return;

						case _:
					}

				case _:
			}
		}


		// Globals
		@:privateAccess
		for(g in runner.checker.getGlobals().keyValueIterator()) {
			switch g?.value {
				case TUnresolved(name): _addUnresolved(null, name, g.value);
				case _:
			}
		}

		// Class fields
		@:privateAccess
		for(c in runner.classes) {
			var className = Type.getClassName(c.cl);
			for( f in runner.checker.getFields( runner.checker.types.resolve(className) ) ) {
				switch f.t {
					case TUnresolved(name): _addUnresolved(className, f.name, f.t);
					case TFun(args, ret): _checkFunction(className, f.name, f.t);
					case _:
				}
			}
		}

		return unresolveds;
	}


	function renderGlobals() {
		globalsFlow.removeChildren();

		function _isFunction(ttype:hscript.Checker.TType) : Bool {
			return switch ttype {
				case TFun(_): true;
				case _: false;
			}
		}

		function _createFilteredGlobalsGroup(label:String, filter) {
			createCollapsable(label, (p)->{
				var all = getGlobals( (n,t)->filter(n,t) );
				for(g in all)
					createText(g.desc, g.col, p);
			}, globalsFlow);
		}

		_createFilteredGlobalsGroup("Keywords", (n,t)->runner.isKeyword(n) );
		_createFilteredGlobalsGroup("Global vars", (n,t)->runner.hasGlobalVar(n) );
		_createFilteredGlobalsGroup("Global values", (n,t)->!runner.hasGlobalVar(n) && !runner.isKeyword(n) && !_isFunction(t) );
		_createFilteredGlobalsGroup("Global functions", (n,t)->_isFunction(t) && !runner.isKeyword(n) );

		emitResizeAtEndOfFrame();
	}

	function getGlobals(?filter:(name:String,ttype:hscript.Checker.TType)->Bool) {
		var all = [];

		@:privateAccess
		for( g in runner.checker.getGlobals().keyValueIterator() ) {
			if( filter!=null && !filter(g.key, g.value) )
				continue;

			if( runner.isKeyword(g.key) ) {
				// Keyword
				all.push({
					desc: switch g.value {
						case TFun(args, ret): '< ${g.key}(...) >';
						case _: '< ${g.key} : ${g.value} >';
					},
					col: Col.coldMidGray(),
				});
			}
			else {
				// User-defined global
				all.push({
					desc: getDescFromTType(g.key, g.value),
					col: getColorFromTType(g.key, g.value),
				});
			}
		}

		all.sort((a,b)->Reflect.compare(a.desc.toLowerCase(), b.desc.toLowerCase()));
		return all;
	}


	function createCollapsable(label:String, ?subLabel:String, col:Col=0, forceOpen=false, renderContent:h2d.Flow->Void, ?onHide:Void->Void, p:h2d.Flow) {
		var wrapper = new h2d.Flow(p);
		wrapper.layout = Vertical;

		var id = label;
		if( forceOpen )
			expands.set(id, true);

		var expandedWrapper = new h2d.Flow();
		expandedWrapper.minWidth = minWidth;
		expandedWrapper.layout = Vertical;
		expandedWrapper.verticalSpacing = 1;
		expandedWrapper.paddingHorizontal= gap;
		expandedWrapper.paddingBottom = gap;
		expandedWrapper.backgroundTile = Col.black().toTile();

		var bt : h2d.Flow = null;
		function _renderCollapsable() {
			expandedWrapper.visible = expands.exists(id);
			if( expands.exists(id) ) {
				renderContent(expandedWrapper);
				bt.minWidth = M.imax(minWidth, expandedWrapper.outerWidth);
				wrapper.filter = new dn.heaps.filter.PixelOutline(White);
			}
			else {
				expandedWrapper.removeChildren();
				bt.minWidth = minWidth;
				if( onHide!=null )
					onHide();
				wrapper.filter = null;
			}
			emitResizeAtEndOfFrame();
		}

		bt = createButton(label, subLabel, col!=0?col:baseColor, ()->{
			if( expands.exists(id) )
				expands.remove(id);
			else
				expands.set(id, true);
			_renderCollapsable();
		}, wrapper);
		bt.minWidth = minWidth;
		wrapper.addChild(expandedWrapper);

		_renderCollapsable();
		return bt;
	}

	function createText(v:Dynamic, col:Col=ColdLightGray, p:h2d.Flow) {
		var tf = new h2d.Text(font, p);
		tf.text = Std.string(v);
		tf.textColor = col;
		return tf;
	}


	function createButton(label:String, ?subLabel:String, col:Col=0xd90c24, cb:Void->Void, p:h2d.Flow) {
		var col = col.withAlpha(1);
		var bt = new h2d.Flow(p);
		bt.layout = Horizontal;
		bt.horizontalSpacing = Std.int( gap*0.5 );
		bt.verticalAlign = Middle;
		bt.padding = 4;
		bt.paddingTop = 2;
		bt.paddingBottom = 6;

		bt.enableInteractive = true;
		bt.interactive.cursor = Button;
		bt.interactive.backgroundColor = col;

		var tf = new h2d.Text(font, bt);
		tf.text = label;
		tf.textColor = White;

		if( subLabel!=null) {
			var subTf = new h2d.Text(font, bt);
			bt.getProperties(subTf).horizontalAlign = Right;
			subTf.text = '<$subLabel>';
			subTf.textColor = White;
			subTf.alpha = 0.6;
		}

		bt.interactive.onClick = ev->cb();
		bt.interactive.onOver = _->{
			bt.interactive.backgroundColor = col.toWhite(0.25);
		}
		bt.interactive.onOut = _->{
			bt.interactive.backgroundColor = col;
		}
		return bt;
	}

	function createCopyButton(value:String, p) {
		return createButton("Copy", ()->hxd.System.setClipboardText(value), p);
	}

	function getTTypeShortName(ttype:hscript.Checker.TType) : String {
		return switch ttype {
			case TInt: 'Int';
			case TFloat: 'Float';
			case TBool: 'Bool';
			case TDynamic: 'Dynamic';
			case TUnresolved(name): '<$name?>';
			case TInst(c, args): c.name;
			case TEnum(e, args): e.name;
			case TAbstract(a, args): a.name;
			case TFun(args, ret): 'Callback';
			case TVoid: 'Void';
			case TNull(t): 'Null<${getTTypeShortName(t)}>';
			case TAnon(fields): '{${fields.map(f->f.name).join(",")}}';
			case TType(t, args): t.name;
			case _: '?${ttype.getName()}';
		}
	}

	function getDescFromTType(name:String, ttype:hscript.Checker.TType) : String {
		return switch ttype {
			case TUnresolved(typeName): 'var $name : <$typeName?>';
			case null: 'var $name : <null?>';

			case TInt, TFloat, TBool:
				var out = 'var $name : ${ttype.getName()}';
				@:privateAccess if( runner.interp.variables.exists(name) )
					out += ' = ' + runner.interp.variables.get(name);
				out;

			case TNull(t):
				var out = 'var $name : ${getTTypeShortName(ttype)}';
				@:privateAccess if( runner.interp.variables.exists(name) )
					out += ' = ' + runner.interp.variables.get(name);
				out;

			case TDynamic: 'instance "$name" => ${ttype.getName()}';
			case TInst(c, args): 'instance "$name" => ${c.name}';
			case TEnum(e, args): 'enum ${e.name}.$name';

			case TFun(args, ret):
				var argsStr = args.map(
					a -> (a.opt?"?":"") + a.name + ":" + getTTypeShortName(a.t)
				);
				'function $name( ${argsStr.join(', ')} ) : ${getTTypeShortName(ret)}';

			case _: '? $name : ${ttype.getName()}';
		}
	}

	function getColorFromTType(name:String, ttype:hscript.Checker.TType) : Col {
		var bad = Col.red().toWhite(0.3); // brighter than badColor
		return runner.hasGlobalVar(name)
			? ColdLightGray
			: switch ttype {
				case TInt, TFloat, TBool: White;
				case TEnum(e, args): Pink;
				case TInst(_): Yellow;
				case TUnresolved(_): bad;
				case TDynamic: Orange;
				case TNull(t): Orange;

				case TFun(args, ret):
					var col : Col = Cyan;
					for(a in args)
						switch a.t {
							case TUnresolved(name): col = bad; // override color for unresolved args
							case _:
						}
					switch ret {
						case TUnresolved(_): col = bad; // override color for unresolved return type
						case _:
					}
					col;

				case _: badColor; // Unknown type
			}
	}


	public dynamic function onClose() {}


	override function onResize() {
		super.onResize();

		wrapper.setScale( dn.heaps.Scaler.bestFit_smart(800,600) );
		wrapper.maxHeight = Std.int( stageHei/wrapper.scaleY );
		wrapper.overflow = Scroll;
		wrapper.x = stageWid - wrapper.outerWidth * wrapper.scaleX;
	}


	override function finalUpdate() {
		super.finalUpdate();
		header.minWidth = 0;
		header.minWidth = wrapper.outerWidth;
	}

	override function preUpdate() {
		super.preUpdate();
		if( shouldSelfDestroy() )
			destroy();
	}

	override function postUpdate() {
		super.postUpdate();
		if( shouldSelfDestroy() )
			destroy();
	}


	var lastRunUid = -1;
	var lastErrorUid = -1;
	var wasRunning = false;
	override function update() {
		super.update();

		if( shouldSelfDestroy() ) {
			destroy();
			return;
		}

		// Update header info
		if( originTf.text!=runner.origin )
			originTf.text = runner.origin;

		if( outputTf.text!=runner.output.string )
			outputTf.text = runner.output.string+"("+runner.output.type+")";

		// Refresh timer
		if( isAsync() && asAsync().hasScriptRunning() )
			updateTimer();

		// Refresh runtime
		// if( isAsync() && !cd.hasSetS("runtimeRefresh",0.1) && asAsync().hasScriptRunning() )
			// renderRuntime();
		if( isAsync() && wasRunning && !asAsync().hasScriptRunning() )
			renderRuntime();

		// Start a new script
		if( lastRunUid!=runner.lastRunUid ) {
			lastRunUid = runner.lastRunUid;
			renderAll();
		}

		// Error
		if( runner.lastException!=null && lastErrorUid!=runner.lastRunUid ) {
			lastErrorUid = runner.lastRunUid;
			renderAll();
		}

		wasRunning = isAsync() && asAsync().hasScriptRunning();
	}
}


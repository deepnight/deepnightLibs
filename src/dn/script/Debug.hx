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

	var font : h2d.Font;
	var wrapper : h2d.Flow;
	var header : h2d.Flow;
	var scriptFlow : h2d.Flow;
	var typesFlow : h2d.Flow;
	var timerTf : h2d.Text;
	var outputTf : h2d.Text;
	var originTf : h2d.Text;

	var expands : Map<String,Bool> = new Map();

	public function new(r:Runner, ctx:h2d.Object, process:dn.Process) {
		super(process);

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
		outputTf = createText(runner.origin, White, f);
		header.getProperties(f).minWidth = 50;

		originTf = createText(runner.origin, White, header);

		var closeBt = createButton("x", destroy, header);
		header.getProperties(closeBt).horizontalAlign = Right;

		scriptFlow = new h2d.Flow(wrapper);
		scriptFlow.layout = Vertical;

		typesFlow = new h2d.Flow(wrapper);
		typesFlow.layout = Vertical;

		render();
	}

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

	function render() {
		renderScript();
		renderTypes();
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


	function renderScript() {
		scriptFlow.removeChildren();

		// Original script string
		createCollapsable("Script (original)", runner.lastError!=null, (p)->{
			if( runner.lastScriptStr==null )
				return;

			var raw = runner.lastScriptStr;
			raw = StringTools.replace(raw, "\t", "   ");
			raw = StringTools.replace(raw, "\r", "");

			var i = 1;
			for(line in raw.split("\n")) {
				if( line.length==0 )
					p.addSpacing(8);
				else {
					var lineWithNumber = Lib.padRight(Std.string(i), 4) + line;
					if( runner.lastError!=null && runner.lastError.line==i )
						createText( lineWithNumber+"    <--- "+runner.lastError.getErrorOnly(), Red, p);
					else
						createText( lineWithNumber, White, p);
				}
				i++;
			}
		}, scriptFlow);

		// Converted script expr
		createCollapsable("Script (converted)", (p)->{
			if( runner.lastScriptExpr==null )
				return;

			createButton("Copy", ()->{
				hxd.System.setClipboardText( runner.getLastScriptExprAsString() );
			},p);

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


	function renderTypes() {
		typesFlow.removeChildren();

		// Exposed types
		var allTypes = getAllExposedTypes();
		for(t in allTypes) {
			var catLabel = switch t.category {
				case T_Enum: 'Enum';
				case T_ClassInst: 'Class Instance';
				case T_ClassDef: 'Class Definition';
			}
			createCollapsable(t.name, catLabel, (p)->{
				for(v in t.values)
					createText(v.desc, v.col, p);
			}, typesFlow);
		}

		// Globals
		var k = "<Globals>";
		createCollapsable(k, (p)->{
			var all = [];

			@:privateAccess
			for( g in runner.checker.getGlobals().keyValueIterator() ) {
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
						col: getColorFromTType(g.value),
					});
				}
			}

			all.sort((a,b)->Reflect.compare(a.desc.toLowerCase(), b.desc.toLowerCase()));
			for(g in all)
				createText(g.desc, g.col, p);
		}, typesFlow);

		emitResizeAtEndOfFrame();
	}

	function createCollapsable(label:String, ?subLabel:String, forceOpen=false, renderContent:h2d.Flow->Void, ?onHide:Void->Void, p:h2d.Flow) {
		var id = label;
		if( forceOpen )
			expands.set(id, true);

		var expandedWrapper = new h2d.Flow();
		expandedWrapper.minWidth = minWidth;
		expandedWrapper.layout = Vertical;
		expandedWrapper.verticalSpacing = 1;
		expandedWrapper.paddingLeft = gap;
		expandedWrapper.paddingBottom = gap;

		var bt : h2d.Flow = null;
		function _renderCollapsable() {
			expandedWrapper.visible = expands.exists(id);
			if( expands.exists(id) ) {
				renderContent(expandedWrapper);
				bt.minWidth = M.imax(minWidth, expandedWrapper.outerWidth);

			}
			else {
				expandedWrapper.removeChildren();
				bt.minWidth = minWidth;
				if( onHide!=null )
					onHide();
			}
			emitResizeAtEndOfFrame();
		}

		bt = createButton(label, subLabel, baseColor, ()->{
			if( expands.exists(id) )
				expands.remove(id);
			else
				expands.set(id, true);
			_renderCollapsable();
		}, p);
		bt.minWidth = minWidth;
		p.addChild(expandedWrapper);

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
			subTf.text = '($subLabel)';
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

	function getTTypeShortName(ttype:hscript.Checker.TType) : String {
		return switch ttype {
			case TInt: 'Int';
			case TFloat: 'Float';
			case TBool: 'Bool';
			case TDynamic: 'Dynamic';
			case TUnresolved(name): '?$name';
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
			case TInt, TFloat, TBool: 'var $name : ${ttype.getName()}';
			case TDynamic: 'instance "$name" => ${ttype.getName()}';
			case TInst(c, args): 'instance "$name" => ${c.name}';
			case TEnum(e, args): 'enum ${e.name}.$name';
			case TUnresolved(typeName): 'var $name : ?$typeName (unresolved)';

			case TFun(args, ret):
				var argsStr = args.map(
					a -> (a.opt?"?":"") + a.name + ":" + getTTypeShortName(a.t)
				);
				'function $name( ${argsStr.join(', ')} ) : ${getTTypeShortName(ret)}';

			case _: '? $name : ${ttype.getName()}';
		}
	}

	function getColorFromTType(ttype:hscript.Checker.TType) : Col {
		return switch ttype {
			case TInt, TFloat, TBool: White;
			case TEnum(e, args): Pink;
			case TInst(_): Yellow;
			case TUnresolved(_): Red;
			case TDynamic: Orange;

			case TFun(args, ret):
				var col = Cyan;
				for(a in args)
					switch a.t {
						case TUnresolved(name): col = Red; // override color for unresolved args
						case _:
					}
				col;

			case _: Red; // Unknown type
		}
	}


	function getAllExposedTypes() : Array<ExposedType> {
		@:privateAccess
		if( runner.checker==null )
			runner.initChecker();

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
					col: getColorFromTType(f.t),
				});

			t.values.sort((a,b)->Reflect.compare(a.desc.toLowerCase(), b.desc.toLowerCase()));
		}

		return allTypes;
	}



	override function onResize() {
		super.onResize();

		wrapper.setScale( M.fmin(
			dn.heaps.Scaler.bestFit_smart(800,600),
			dn.heaps.Scaler.bestFit_f(wrapper.outerWidth, wrapper.outerHeight)
		));
		wrapper.x = stageWid - wrapper.outerWidth * wrapper.scaleX;
	}


	override function finalUpdate() {
		super.finalUpdate();
		header.minWidth = 0;
		header.minWidth = wrapper.outerWidth;
	}

	var lastRunUid = -1;
	var lastErrorUid = -1;
	override function update() {
		super.update();

		if( originTf.text!=runner.origin )
			originTf.text = runner.origin;

		if( outputTf.text!=runner.output )
			outputTf.text = Std.string(runner.output);

		if( isAsync() && asAsync().hasScriptRunning() )
			updateTimer();

		if( lastRunUid!=runner.lastRunUid ) {
			lastRunUid = runner.lastRunUid;
			renderScript();
		}

		if( runner.lastError!=null && lastErrorUid!=runner.lastRunUid ) {
			lastErrorUid = runner.lastRunUid;
			renderScript();
		}
	}
}


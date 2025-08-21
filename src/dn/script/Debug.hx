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
	var font : h2d.Font;
	var wrapper : h2d.Flow;
	var scriptFlow : h2d.Flow;
	var typesFlow : h2d.Flow;

	var expands : Map<String,Bool> = new Map();

	public function new(r:Runner, process:dn.Process) {
		super(process);

		if( process.root==null )
			throw "Parent process has no root!";
		createRootInLayers(process.root, 99999);

		runner = r;

		font = hxd.res.DefaultFont.get();

		wrapper = new h2d.Flow(root);
		wrapper.layout = Vertical;
		wrapper.verticalSpacing = 1;
		wrapper.minWidth = minWidth;

		scriptFlow = new h2d.Flow(wrapper);
		scriptFlow.layout = Vertical;

		typesFlow = new h2d.Flow(wrapper);
		typesFlow.layout = Vertical;
		typesFlow.verticalSpacing = 1;

		render();
	}

	function toggleTypeSelection(type:String) {
		if( expands.exists(type) )
			expands.remove(type);
		else
			expands.set(type, true);
		render();
	}

	function render() {
		var gap = 8;
		typesFlow.removeChildren();

		function _makeText(v:Dynamic, col:Col=ColdLightGray, indent=false) {
			var tf = new h2d.Text(font, typesFlow);
			tf.text = Std.string(v);
			tf.textColor = col;
			if( indent )
				typesFlow.getProperties(tf).paddingLeft = gap;
			return tf;
		}

		function _makeButton(label:String, ?subLabel:String, cb:Void->Void) {
			var col = new Col(0x1e1936).withAlpha(1);
			var bt = new h2d.Flow(typesFlow);
			bt.minWidth = minWidth;
			bt.layout = Horizontal;
			bt.horizontalSpacing = Std.int( gap*0.5 );
			bt.verticalAlign = Middle;
			bt.padding = 4;

			bt.enableInteractive = true;
			bt.interactive.cursor = Button;
			bt.interactive.backgroundColor = col;

			var tf = new h2d.Text(font, bt);
			tf.text = label;
			tf.textColor = Yellow;

			if( subLabel!=null) {
				var subTf = new h2d.Text(font, bt);
				subTf.text = '($subLabel)';
				subTf.textColor = WarmLightGray;
			}

			bt.interactive.onClick = ev->cb();
			bt.interactive.onOver = _->{
				bt.interactive.backgroundColor = col.toWhite(0.25);
				tf.textColor = White;
			}
			bt.interactive.onOut = _->{
				bt.interactive.backgroundColor = col;
				tf.textColor = Yellow;
			}
			return bt;
		}

		// Exposed types
		var allTypes = getAllExposedTypes();
		for(t in allTypes) {
			var catLabel = switch t.category {
				case T_Enum: 'Enum';
				case T_ClassInst: 'Class Instance';
				case T_ClassDef: 'Class Definition';
			}
			_makeButton(t.name, catLabel, ()->{
				toggleTypeSelection(t.name);
			});

			// Expand fields
			if( expands.exists(t.name) ) {
				for(v in t.values)
					_makeText(v.desc, v.col, true);

				typesFlow.addSpacing(gap);
			}
		}

		// Globals
		var k = "<Globals>";
		_makeButton(k, ()->toggleTypeSelection(k));
		if( expands.exists(k) ) {
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
				_makeText(g.desc, g.col, true);
		}

		emitResizeAtEndOfFrame();
	}

	function getTTypeShortName(ttype:hscript.Checker.TType) : String {
		return switch ttype {
			case TInt: 'Int';
			case TFloat: 'Float';
			case TBool: 'Bool';
			case TDynamic: 'Dynamic';
			case TUnresolved(name): name;
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
			dn.heaps.Scaler.bestFit_smart(wrapper.outerWidth, wrapper.outerHeight)
		));
		wrapper.x = stageWid - wrapper.outerWidth * wrapper.scaleX;
	}
}


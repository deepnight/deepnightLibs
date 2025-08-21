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

class TypesExplorer extends dn.Process {
	var runner : Runner;

	var font : h2d.Font;
	var typesFlow : h2d.Flow;
	var selectedTypes : Map<String,Bool> = new Map();

	public function new(r:Runner, process:dn.Process) {
		super(process);

		if( process.root==null )
			throw "Parent process has no root!";
		createRootInLayers(process.root, 99999);

		runner = r;

		font = hxd.res.DefaultFont.get();

		typesFlow = new h2d.Flow(root);
		typesFlow.layout = Vertical;
		typesFlow.verticalSpacing = 1;
		typesFlow.minWidth = 300;

		render();
	}

	function toggleTypeSelection(type:String) {
		if( selectedTypes.exists(type) )
			selectedTypes.remove(type);
		else
			selectedTypes.set(type, true);
		render();
	}

	function render() {
		var gap = 16;
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
			bt.minWidth = typesFlow.minWidth;
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
			if( selectedTypes.exists(t.name) ) {
				for(v in t.values)
					_makeText(v.desc, v.col, true);

				typesFlow.addSpacing(gap);
			}
		}

		// Globals
		var k = "<Globals>";
		_makeButton(k, ()->toggleTypeSelection(k));
		if( selectedTypes.exists(k) ) {
			var all = [];

			@:privateAccess
			for( g in runner.checker.getGlobals().keyValueIterator() )
				all.push({
					desc: getDescFromTType(g.key, g.value),
					col: getColorFromTType(g.value),
				});

			all.sort((a,b)->Reflect.compare(a.desc.toLowerCase(), b.desc.toLowerCase()));
			for(g in all)
				_makeText(g.desc, g.col, true);
		}

		emitResizeAtEndOfFrame();
	}


	function getDescFromTType(name:String, ttype:hscript.Checker.TType) : String {
		return switch ttype {
			case TInt, TFloat, TBool, TDynamic: 'var $name : ${ttype.getName()}';
			case TInst(c, args): 'var $name : ${c.name}';
			case TEnum(e, args): 'enum ${e.name}.$name';
			case TFun(args, ret): 'function $name(${args.map(a->a.name+":"+a.t.getName()).join(', ')}) : ${ret.getName()}';
			case TUnresolved(name): '?$name : (unresolved)';
			// case TAbstract(a, args):
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
		typesFlow.setScale( M.fmin(
			dn.heaps.Scaler.bestFit_smart(640,480),
			dn.heaps.Scaler.bestFit_smart(typesFlow.outerWidth, typesFlow.outerHeight)
		));
		typesFlow.x = stageWid - typesFlow.outerWidth * typesFlow.scaleX;
	}
}


package dn.script;

import hscript.Expr;
import dn.Col;

enum TypeCategory {
	T_Enum;
	T_ClassInst;
	T_ClassDef;
}

enum ValueCategory {
	V_Var;
	V_UnresolvedVar;
	V_Function;
	V_Unknown;
}

typedef ExposedType = {
	var category : TypeCategory;
	var values : Array<{ category:Null<ValueCategory>, name:String, details:Null<String> }>;
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
		for(e in allTypes.keyValueIterator()) {
			var catLabel = switch e.value.category {
				case T_Enum: 'Enum';
				case T_ClassInst: 'Class Instance';
				case T_ClassDef: 'Class Definition';
			}
			_makeButton(e.key, catLabel, ()->{
				toggleTypeSelection(e.key);
			});
			if( selectedTypes.exists(e.key) ) {
				var allLabels = [];
				for(v in e.value.values) {
					var col = switch v.category {
						case null: White;
						case V_Var: White;
						case V_UnresolvedVar: Orange;
						case V_Function: Cyan;
						case V_Unknown: Red;
					}
					var label = switch v.category {
						case null: v.name;
						case V_Var: 'var ${v.name} : ${v.details}';
						case V_UnresolvedVar: 'var ${v.name} : (unresolved)';
						case V_Function: 'function ${v.name}${v.details}';
						case V_Unknown: 'Unknown ${v.name} (${v.details})';
					}
					allLabels.push({ label:label, col:col });
				}

				allLabels.sort((a,b)->Reflect.compare(a.label.toLowerCase(), b.label.toLowerCase()));
				for(l in allLabels)
					_makeText(l.label, l.col, true);

				typesFlow.addSpacing(gap);
			}
		}

		// Globals
		var k = "<Globals>";
		_makeButton(k, ()->{
			toggleTypeSelection(k);
		});
		if( selectedTypes.exists(k) ) {
			var allLabels = [];

			@:privateAccess
			for( g in runner.checker.getGlobals().keyValueIterator() ) {
				allLabels.push({
					label: switch g.value {
						case TInt, TFloat, TBool: 'var ${g.key} : ${g.value.getName()}';
						case TInst(c, args): 'var ${g.key} : ${c.name}';
						case TEnum(e, args): 'enum ${e.name}.${g.key}';
						case TFun(args, ret): 'function ${g.key}(${args.map(a->a.name).join(', ')}): ${ret.getName()}';
						case TUnresolved(name): '?${g.key} : (unresolved)';
						// case TAbstract(a, args):
						case _: '? ${g.key} : ${g.value.getName()}';
					},
					col: switch g.value {
						case TInt, TFloat, TBool: White;
						case TFun(_): Cyan;
						case TEnum(e, args): Pink;
						case TInst(_): Yellow;
						case TUnresolved(_): Orange;
						case _: Red; // Unknown type
					}
				});
			}

			allLabels.sort((a,b)->Reflect.compare(a.label.toLowerCase(), b.label.toLowerCase()));
			for(l in allLabels)
				_makeText(l.label, l.col, true);

		}


		emitResizeAtEndOfFrame();
	}


	public function getAllExposedTypes() : Map<String, ExposedType> {
		@:privateAccess
		if( runner.checker==null )
			runner.initChecker();

		var allTypes : Map<String, ExposedType> = new Map();

		// Enums
		@:privateAccess
		for(e in runner.enums) {
			allTypes.set(e.getName(), {
				category : T_Enum,
				values : e.getConstructors().map( k->{
					name: k,
					details: null,
					category: null,
				}),
			});
		}

		// Classes
		@:privateAccess
		for(c in runner.classes) {
			var name = Type.getClassName(c.cl);
			var t : ExposedType = {
				category: c.instance!=null ? T_ClassInst : T_ClassDef,
				values: [],
			}
			var classTType = runner.checker.types.resolve(name);
			for(f in runner.checker.getFields(classTType) ) {
				var name = f.name;
				var field = switch f.t {
					case TInt: t.values.push({ name:name, category:V_Var, details:'Int' });
					case TUnresolved(_): t.values.push({ name:name, category:V_UnresolvedVar, details:null });
					case TFloat: t.values.push({ name:name, category:V_Var, details:'Float' });
					case TBool: t.values.push({ name:name, category:V_Var, details:'Bool' });

					case TFun(args, ret):
						t.values.push({
							name:name,
							category:V_Function,
							details:'(${args.map(a->a.name).join(', ')}): ${ret.getName()}'
						});

					case _: t.values.push({ name:name, category:V_Unknown, details:f.t.getName() });
				}
			}
			allTypes.set(name, t);
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


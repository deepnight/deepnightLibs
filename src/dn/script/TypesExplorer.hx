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
	var values : Array<{ category:ValueCategory, name:String, ?type:String }>;
}

class TypesExplorer extends dn.Process {
	var runner : Runner;

	var typesFlow : h2d.Flow;
	var selectedTypes : Map<String,Bool> = new Map();

	public function new(r:Runner, process:dn.Process) {
		super(process);

		if( process.root==null )
			throw "Parent process has no root!";
		createRootInLayers(process.root, 99999);

		runner = r;

		typesFlow = new h2d.Flow(root);
		typesFlow.layout = Vertical;

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
			var tf = new h2d.Text(hxd.res.DefaultFont.get(), typesFlow);
			tf.text = Std.string(v);
			tf.textColor = col;
			if( indent )
				typesFlow.getProperties(tf).paddingLeft = gap;
			return tf;
		}

		function _makeButton(label:String, ?subLabel:String, cb:Void->Void) {
			var bt = new h2d.Flow(typesFlow);
			bt.layout = Horizontal;
			bt.horizontalSpacing = Std.int( gap*0.5 );
			bt.verticalAlign = Middle;
			bt.padding = 4;
			bt.enableInteractive = true;
			bt.interactive.backgroundColor = ColdDarkGray;

			var tf = new h2d.Text(hxd.res.DefaultFont.get(), bt);
			tf.text = label;
			tf.textColor = Yellow;

			if( subLabel!=null) {
				var subTf = new h2d.Text(hxd.res.DefaultFont.get(), bt);
				subTf.text = '($subLabel)';
				subTf.textColor = WarmLightGray;
			}

			bt.interactive.onClick = ev->cb();
			bt.interactive.onOver = _->tf.textColor = White;
			bt.interactive.onOut = _->tf.textColor = Yellow;
			return bt;
		}


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
						case V_Var: White;
						case V_UnresolvedVar: Orange;
						case V_Function: Cyan;
						case V_Unknown: Red;
					}
					var label = switch v.category {
						case V_Var: 'var ${v.name} : ${v.type}';
						case V_UnresolvedVar: 'var ${v.name} : (unresolved)';
						case V_Function: 'function ${v.name}';
						case V_Unknown: 'Unknown ${v.name} (${v.type})';
					}
					allLabels.push({ label:label, col:col });
				}

				allLabels.sort((a,b)->Reflect.compare(a.label,b.label));
				for(l in allLabels)
					_makeText(l.label, l.col, true);

				typesFlow.addSpacing(gap);
			}
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
					type: null,
					category: V_Var,
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
					case TInt: t.values.push({ name:name, category:V_Var, type:'Int' });
					case TUnresolved(_): t.values.push({ name:name, category:V_UnresolvedVar, type:null });
					case TFloat: t.values.push({ name:name, category:V_Var, type:'Float' });
					case TBool: t.values.push({ name:name, category:V_Var, type:'Bool' });

					case TFun(args, ret):
						t.values.push({
							name:name,
							category:V_Function,
							type:'(${args.map(a->a.name).join(', ')}): ${ret.getName()}'
						});

					case _: t.values.push({ name:name, category:V_Unknown, type:f.t.getName() });
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

	}
}


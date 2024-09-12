package dn;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

class AbstractEnumFlags<T:Int> {
	var flagNames : Map<T,String>;
	var flagValues : Map<T,Bool> = new Map();

	function new(flagNames:Map<T,String>) {
		this.flagNames = flagNames;
	}

	public inline function has(flag:T) {
		return flagValues.exists(flag);
	}

	public inline function setOnce(flag:T) {
		if( !has(flag) ) {
			set(flag);
			return true;
		}
		else
			return false;
	}

	public inline function set(flag:T, v=true) {
		if( v )
			flagValues.set(flag,v);
		else
			flagValues.remove(flag);
	}

	public inline function toggle(flag:T) {
		set(flag, !has(flag));
	}

	public inline function getFlagValue(flag:T) {
		return flagValues.exists(flag);
	}

	public inline function remove(flag:T) {
		return flagValues.remove(flag);
	}

	public function getActiveFlags() : Array<T> {
		var allFlags : Array<T> = [];
		for(f in flagValues.keys())
			allFlags.push(f);
		return allFlags;
	}

	public inline function getFlagName(flag:T) : String {
		return flagNames.get(flag);
	}

	public function clearAll() {
		flagValues = new Map();
	}

	@:keep public function toString() : String {
		var out = [];
		for(f in flagValues.keys())
			out.push( getFlagName(f) );
		return "["+out.join(",")+"]";
	}


	public static macro function createFromAbstractIntEnum(abstractEnumType:haxe.macro.Expr) {
		var allValues = MacroTools.getAbstractEnumValuesForMacros(abstractEnumType);

		// Check enum underlying type
		for(v in allValues)
			switch v.valueExpr.expr {
				case EConst(CInt(_)):
				case _: Context.fatalError("Only abstract enum of Int is supported.", abstractEnumType.pos);
			}

		// Build `0=>"ValueName"` expressions
		var mapInitExprs = [];
		for(v in allValues)
			mapInitExprs.push( macro $e{v.valueExpr} => $v{v.name} );

		// Build Map declaration as `[ 0=>"ValueName", 1=>"ValueName" ]`
		var flagNamesExpr : Expr = { pos:Context.currentPos(), expr: EArrayDecl(mapInitExprs) }
		return macro @:privateAccess new dn.AbstractEnumFlags( $flagNamesExpr );
	}

}
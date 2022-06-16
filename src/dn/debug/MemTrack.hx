package dn.debug;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end


class MemAlloc {
	public var total = 0.;
	public var calls = 0;
	public inline function new() {}
}

class MemTrack {
	@:noCompletion
	public static var allocs : Map<String, MemAlloc> = new Map();

	@:noCompletion
	public static var firstMeasure = -1.;

	/** Measure a block or a function call memory usage **/
	public static macro function measure( e:Expr, ?ename:ExprOf<String> ) {
		#if !debug

			return e;

		#else

			var p = Context.getPosInfos( Context.currentPos() );
			var id = Context.getLocalModule()+"."+Context.getLocalMethod()+"@"+p.min+": ";
			id += switch e.expr {
				case ECall(e, params):
					haxe.macro.ExprTools.toString(e)+"()";

				case EBlock(_):
					"<block>";

				case _:
					'<${e.expr.getName()}>';
			}

			switch ename.expr {
				case EConst(CIdent("null")):
				case _: id+=".";
			}

			return macro {
				if( dn.debug.MemTrack.firstMeasure<0 )
					dn.debug.MemTrack.firstMeasure = haxe.Timer.stamp();
				var old = dn.Gc.getCurrentMem();

				$e;

				var m = dn.M.fmax( 0, dn.Gc.getCurrentMem() - old );

				var id = $v{id};
				if( $ename!=null )
					id+=$ename;
				if( !dn.debug.MemTrack.allocs.exists(id) )
					@:privateAccess dn.debug.MemTrack.allocs.set(id, new dn.debug.MemTrack.MemAlloc());
				var alloc = dn.debug.MemTrack.allocs.get(id);
				alloc.total += m;
				alloc.calls++;
			}

		#end
	}

	/** Reset current allocs tracking **/
	public static function reset() {
		allocs = new Map();
		firstMeasure = -1;
	}



	static inline function padRight(str:String, minLen:Int, padChar=" ") {
		while( str.length<minLen )
			str+=padChar;
		return str;
	}

	/**
		Print report to standard output.
		If `reset` arg is TRUE, then current tracking is also reset.
	**/
	public static function report(?printer:String->Void, alsoReset=true) {
		var t = haxe.Timer.stamp() - firstMeasure;

		if( printer==null )
			printer = (v)->trace(v);

		var all = [];
		for(a in allocs.keyValueIterator())
			all.push({id: a.key, mem:a.value });
		all.sort( (a,b) -> -Reflect.compare(a.mem.total/t, b.mem.total/t) );

		if( all.length==0 ) {
			printer("MemTrack has nothing to report.");
			return;
		}

		printer("MEMTRACK REPORT");
		printer('Elapsed time: ${M.pretty(t,1)}s');
		var table = [["", "MEM/S", "TOTAL"]];
		var total = 0.;
		for(a in all) {
			total+=a.mem.total;
			table.push([
				a.id,
				dn.M.unit(a.mem.total/t)+"/s",
				dn.M.unit(a.mem.total),
			]);
		}

		// Build visual table
		var colWidths : Array<Int> = [];
		for(line in table) {
			for(i in 0...line.length)
				if( !M.isValidNumber(colWidths[i]) )
					colWidths[i] = line[i].length;
				else
					colWidths[i] = M.imax(colWidths[i], line[i].length);
		}
		// Create header line
		inline function _separator() {
			var line = [];
			for(i in 0...colWidths.length)
				line.push( padRight("", colWidths[i],"-") );
			return line;
		}
		table.insert( 1, _separator() );
		table.push(_separator());
		table.push(["", dn.M.unit(total/t)+"/s", dn.M.unit(total)]);

		// Print table
		for(line in table) {
			for(i in 0...line.length)
				line[i] = padRight(line[i], colWidths[i]);
			printer("| " + line.join(" | ") + " |");
		}

		if( alsoReset )
			reset();
	}
}
package dn.debug;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

class MemTrack {
	@:noCompletion
	public static var allocs : Map<String, { total:Float, calls:Int }> = new Map();

	public static var firstMeasure = -1.;

	/** Measure a block or a function call memory usage **/
	public static macro function measure( e:Expr ) {
		#if !debug

			return e;

		#else

			var id = Context.getLocalModule()+"."+Context.getLocalMethod()+": ";
			id += switch e.expr {
				case ECall(e, params):
					haxe.macro.ExprTools.toString(e)+"()";

				case EBlock(_):
					"{block}";

				case _:
					"<unknown>";
			}

			return macro {
				if( dn.debug.MemTrack.firstMeasure<0 )
					dn.debug.MemTrack.firstMeasure = haxe.Timer.stamp();
				var old = dn.Gc.getCurrentMem();

				$e;

				var m = dn.M.fmax( 0, dn.Gc.getCurrentMem() - old );

				if( !dn.debug.MemTrack.allocs.exists($v{id}) )
					dn.debug.MemTrack.allocs.set($v{id}, { total:0, calls:0 });
				var alloc = dn.debug.MemTrack.allocs.get( $v{id} );
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

	/** Print report to standard output **/
	public static function report(?printer:String->Void) {
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
		for(a in all)
			table.push([
				a.id,
				dn.M.unit(a.mem.total/t)+"/s",
				dn.M.unit(a.mem.total),
			]);

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
		var line = [];
		for(i in 0...colWidths.length)
			line.push( padRight("", colWidths[i],"-") );
		table.insert(1, line);

		// Print table
		for(line in table) {
			for(i in 0...line.length)
				line[i] = padRight(line[i], colWidths[i]);
			printer("| " + line.join("  |  ") + " |");
		}

		reset();
	}
}
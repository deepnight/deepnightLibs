package dn.debug;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

class MemTrack {
	@:noCompletion
	public static var allocs : Map<String, { total:Float, time:Float, calls:Int }> = new Map();

	/** Measure a block or a function call memory usage **/
	public static macro function measure( e:Expr ) {
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
			var t = haxe.Timer.stamp();
			var old = hl.Gc.stats().currentMemory;

			$e;

			var m = dn.M.fmax( 0, hl.Gc.stats().currentMemory - old );
			t = haxe.Timer.stamp() - t;

			if( !dn.debug.MemTrack.allocs.exists($v{id}) )
				dn.debug.MemTrack.allocs.set($v{id}, { total:0, time:0, calls:0 });
			var alloc = dn.debug.MemTrack.allocs.get( $v{id} );
			alloc.total += m;
			alloc.time += t;
			alloc.calls++;
		}
	}

	/** Reset current allocs tracking **/
	public static function reset() {
		allocs = new Map();
	}

	/** Print report to standard output **/
	public static function report() {
		var all = [];
		for(a in allocs.keyValueIterator())
			all.push({id: a.key, mem:a.value });
		all.sort( (a,b) -> -Reflect.compare(a.mem.total, b.mem.total) );

		trace("MemTrack report");
		trace("---------------");
		for(a in all)
			trace(
				"  "+a.id+" => "+dn.M.unit(a.mem.total)+", "
				+dn.M.unit(a.mem.total/a.mem.calls)+"/call "
				+"("+dn.M.pretty(a.mem.time,2)+"s)"
			);
	}
}
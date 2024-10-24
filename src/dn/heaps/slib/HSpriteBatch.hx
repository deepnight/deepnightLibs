package dn.heaps.slib;
import h2d.SpriteBatch.BatchElement;

@:access(h2d.BatchElement)
class HSpriteBatch extends h2d.SpriteBatch {

	override function onAdd(){
		super.onAdd();
		var e = first;
		while( e != null ){
			if( Std.isOfType(e,HSpriteBE) )
				Std.downcast(e, HSpriteBE).onAdd();
			e = e.next;
		}
	}

	override function onRemove(){
		super.onRemove();
		var e = first;
		while( e != null ){
			if( Std.isOfType(e,HSpriteBE) )
				Std.downcast(e, HSpriteBE).onRemove();
			e = e.next;
		}
	}

	override function add( e : BatchElement, before=false ){
		e = super.add(e,before);
		if( allocated && Std.isOfType(e,HSpriteBE) )
			Std.downcast(e, HSpriteBE).onAdd();
		return e;
	}

	override function delete( e : BatchElement ){
		super.delete(e);
		if( allocated && Std.isOfType(e,HSpriteBE) )
			Std.downcast(e, HSpriteBE).onRemove();
	}

}
package dn.heaps.slib;
import h2d.SpriteBatch.BatchElement;

@:access(h2d.BatchElement)
class HSpriteBatch extends h2d.SpriteBatch {

	override function onAdd(){
		super.onAdd();
		var c = first;
		while( c != null ){
			if( Std.isOfType(c,HSpriteBE) )
				(cast c:HSpriteBE).onAdd();
			c = c.next;
		}
	}

	override function onRemove(){
		super.onRemove();
		var c = first;
		while( c != null ){
			if( Std.isOfType(c,HSpriteBE) )
				(cast c:HSpriteBE).onRemove();
			c = c.next;
		}
	}

	override function add( e : BatchElement, before=false ){
		e = super.add(e,before);
		if( allocated && Std.isOfType(e,HSpriteBE) )
			(cast e:HSpriteBE).onAdd();
		return e;
	}

	override function delete( e : BatchElement ){
		super.delete(e);
		if( allocated && Std.isOfType(e,HSpriteBE) )
			(cast e:HSpriteBE).onRemove();
	}

}
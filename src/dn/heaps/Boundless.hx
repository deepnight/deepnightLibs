package dn.heaps;

/**
	The Bounds of this utility class are always empty, even if it has children.
	This is useful with h2d.Flow, to add a child that doesn't affect the Flow bounds.
**/
class Boundless extends h2d.Object {
	public function new(setAbsoluteInParentFlow=false, ?parent) {
		super(parent);
		if( setAbsoluteInParentFlow && Std.isOfType(parent,h2d.Flow) )
			Std.downcast(parent, h2d.Flow).getProperties(this).isAbsolute = true;
	}

	override function getBoundsRec(relativeTo:h2d.Object, out:h2d.col.Bounds, forSize:Bool) {
		super.getBoundsRec(relativeTo, out, forSize);
		out.empty();
	}
}
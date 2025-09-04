package dn;

import haxe.Int32;
import haxe.Int64;


abstract Handle(Int64) from Int64 to Int64 {
	#if uuid
	static var flakeId : uuid.FlakeId = null;
	#end

	public inline function new(sourceUid:Int32, subUid:Int32) {
		this = Int64.make(sourceUid, subUid);
	}

	public var sourceUid(get,never) : Int32;
		inline function get_sourceUid() return this.high;

	public var subUid(get,never) : Int32;
		inline function get_subUid() return this.low;


	@:to public static inline function toString(h:Handle) : String {
		return 'Handle(${h.sourceUid}:${h.subUid})';
	}


	#if uuid
	/** Generate a new unique Handle using a SnowFlake UUID */
	public static inline function generateUUID() {
		if( flakeId == null )
			flakeId = new uuid.FlakeId();
		var uuid = flakeId.nextId();
		return new Handle(uuid.high, uuid.low);
	}
	#end


	public inline function toBinary(addSpaces=true) {
		return dn.M.int64ToBitString(this, addSpaces);
	}


	public inline function is(otherSourceUid:Int32, otherSubUid:Int32) : Bool {
		return sourceUid==otherSourceUid && subUid==otherSubUid;
	}

	public inline function sameSource(other:Handle) : Bool {
		return sourceUid == other.sourceUid;
	}

	public inline function sameSubUid(other:Handle) : Bool {
		return subUid == other.subUid;
	}
}
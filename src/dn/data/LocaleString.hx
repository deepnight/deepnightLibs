package dn.data;

abstract LocaleString(String) to String {
	inline public function new(s:String) {
		this = s;
	}

	public inline function toUpperCase() : LocaleString return new LocaleString(this.toUpperCase());
	public inline function toLowerCase() : LocaleString return new LocaleString(this.toLowerCase());
	public inline function charAt(i) return this.charAt(i);
	public inline function charCodeAt(i) return this.charCodeAt(i);
	public inline function indexOf(i, ?s) return this.indexOf(i,s);
	public inline function lastIndexOf(i, ?s) return this.lastIndexOf(i,s);
	public inline function split(i) return this.split(i);
	public inline function substr(i, ?l) return this.substr(i, l);
	public inline function substring(i, ?e) return this.substring(i, e);

	public inline function trim(){
        return new LocaleString( StringTools.trim(this) );
    }

	@:op(A+B) function add(to:LocaleString) return new LocaleString(this + cast to);

	public var length(get,never) : Int;
	inline function get_length() return this.length;

	#if heaps
	@:to
	inline function toUString() : String {
		return (cast this:String);
	}
	#end
}

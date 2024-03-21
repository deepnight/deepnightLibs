package dn.store.impl;

class DummyImpl extends dn.store.StoreAPI {
	public function new() {
		super();
		name = 'Dummy';
	}

	override function isActive() {
		return true;
	}
}
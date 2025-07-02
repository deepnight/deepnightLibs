package dn.script;

interface IScriptRunnerApi {
	// Call `doNext()` after `timerS` seconds
	// public function delay(doNext:Void->Void, timerS:Float) : Void;

	// Initialize the API and its context to be ready to execute a new script from scratch.
	public function reset() : Void;

	// Return TRUE if any script element is still active
	public function isRunning() : Bool;

	// Script API loop
	// public function update(tmod:Float) : Void;
}

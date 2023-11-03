package dn.heaps.input;

import dn.heaps.input.*;
import dn.heaps.input.Controller;
import dn.struct.FixedArray;
import dn.Col;

class ControllerQueue<T:Int> {
	var watches : Array<T> = [];
	var ca : ControllerAccess<T>;
	var events : Map<T, QueueEventStacks<T>> = new Map();
	var defaultMaxKeepDurationS : Float;

	public function new(ca:ControllerAccess<T>, defaultMaxKeepDurationS=0.3) {
		this.ca = ca;
		this.defaultMaxKeepDurationS = defaultMaxKeepDurationS;
	}

	public function watch(a:T, ?maxKeepDurationS=-1.) {
		stopWatch(a);

		watches.push(a);
		events.set(a, new QueueEventStacks(a, maxKeepDurationS<=0 ? defaultMaxKeepDurationS : maxKeepDurationS));
	}

	public function stopWatch(a:T) {
		watches.remove(a);
		events.remove(a);
	}

	/**
		Check if given `action` was pressed recently, and removes it from history if TRUE.

		`curTimeS` is the current context time stamp in seconds.

		By default, the press events chronological order is respected. So, if another action was pressed before the one requested, this method would return FALSE accordingly.

		If `ignoreChronologicalOrder` is FALSE, then the chronological order is ignored.

		**Example**: if the user quickly pressed the A,B,C,D actions sequence:
		- `checkAndPopPress(B, curTimeS)` would return FALSE (A is queued before B)
		- `checkAndPopPress(B, curTimeS, true)` would return TRUE, and B would be consumed from the queue, A would also be discarded because it happened before B, and C and D would stay in the queue.

	**/
	public function checkAndPopPress(action:T, curTimeS:Float, ignoreChronologicalOrder=false) {
		var nextT = events.get(action).getNextPress();
		if( !ignoreChronologicalOrder ) {
			for(ev in events)
				if( ev.action!=action && ev.getNextPress()<nextT )
					return false;
		}
		var result = events.get(action).popPress(curTimeS);
		if( result )
			for(ev in events)
				ev.discardPressesEarlier(nextT);

		return result;
	}

	public function update(stime:Float) {
		for(a in watches) {
			if( ca.isDown(a) )
				events.get(a).onDown(stime);
			else
				events.get(a).onUp(stime);
		}
	}

	public function clearAll() {
		for(ev in events)
			ev.clear();
	}

	public function clearAction(a:T) {
		if( events.exists(a) )
			events.get(a).clear();
	}

	public function createDebugger(parent:dn.Process) {
		var p = parent.createChildProcess();
		p.createRootInLayers(parent.root, 99999);
		var wrapper = new h2d.Object(p.root);

		var font = hxd.res.DefaultFont.get();

		p.onUpdateCb = ()->{
			var curTimeS = p.stime;

			wrapper.removeChildren();
			var i = 0;
			var lineHei = 32;
			var secondWidth = 100;
			for(ev in events) {
				var lineWrapper = new h2d.Object(wrapper);
				lineWrapper.y = i*lineHei;

				// Label
				var tf = new h2d.Text(font, lineWrapper);
				tf.text = Std.string(ev.action);

				var g = new h2d.Graphics(lineWrapper);
				g.x = 60;

				// Bg
				g.beginFill(Black, 0.8);
				g.drawRect(0,0, ev.maxKeepDurationS*secondWidth, lineHei);
				g.endFill();

				// Graduations
				var t = 0.;
				while( t<ev.maxKeepDurationS ) {
					t+=0.1;
					g.lineStyle(1, WarmMidGray, 0.3);
					g.moveTo(t*secondWidth, 0);
					g.lineTo(t*secondWidth, lineHei);
				}

				// Keep limit
				g.lineStyle(1, Red, 0.3);
				g.moveTo(0, 0);
				g.lineTo(0, lineHei);

				// Event stacks
				var eventIdx = 0;
				var eventHei = 8;
				inline function _renderStack(stack:Array<Float>, col:dn.Col) {
					ev.gc(stack, curTimeS);
					for(t in stack) {
						g.beginFill(col,1);
						g.lineStyle(1, col.toWhite(0.3));
						g.drawCircle((ev.maxKeepDurationS-(curTimeS-t))*secondWidth, eventIdx*eventHei + eventHei*0.5, eventHei*0.5);
						g.endFill();
					}
					eventIdx++;
				}
				_renderStack(ev.presses, Green);
				_renderStack(ev.releases, Orange);

				i++;
			}
		}

		p.onResizeCb = ()->{
			p.root.setScale( dn.heaps.Scaler.bestFit_i(300));
		}

		p.onDisposeCb = ()->{}
	}
}


private class QueueEventStacks<T> {
	public var action(default,null) : T;
	var wasDown = false;
	public var presses(default,null) : Array<Float>;
	public var releases(default,null) : Array<Float>;
	public var maxKeepDurationS(default,null) : Float;

	public function new(a:T, maxKeepDurationS:Float) {
		action = a;
		presses = [];
		releases = [];
		this.maxKeepDurationS = maxKeepDurationS;
	}

	public function onDown(stime:Float) {
		if( !wasDown ) {
			wasDown = true;
			presses.push(stime);
			gc(presses, stime);
		}
	}

	public function onUp(stime:Float) {
		if( wasDown ) {
			wasDown = false;
			releases.push(stime);
			gc(releases, stime);
		}
	}

	public inline function popPress(curTimeS:Float) : Bool {
		return tryToPopFromStack(presses,curTimeS);
	}

	public inline function getNextPress() {
		return presses.length>0 ? presses[0] : 999999;
	}

	public inline function popRelease(curTimeS:Float) : Bool {
		return tryToPopFromStack(releases,curTimeS);
	}

	function tryToPopFromStack(stack:Array<Float>, curTimeS:Float) : Bool {
		gc(stack,curTimeS);
		if( stack.length>0 ) { //&& curTimeS-stack[0]<=maxKeepDurationS ) {
			stack.shift();
			return true;
		}
		else
			return false;
	}

	public function discardPressesEarlier(t:Float) {
		while( presses.length>0 && presses[0]<=t )
			presses.shift();
	}

	public inline function gc(stack:Array<Float>, stime:Float) {
		while( stack.length>0 && stime-stack[0]>maxKeepDurationS )
			stack.shift();
	}

	public function clear() {
		wasDown = false;
		presses = [];
		releases = [];
	}
}
package dn.pathfinder;

class GraphCrawler {
	/**
	 * Return all nodes that are not reachable from the start node by crawling the nodes network.
	 * @param nodes The list of all nodes.
	 * @param start The starting node.
	 * @param canCrawl A function that determines if crawling from->to is possible.
	 * @return An array of nodes that are disconnected from the start node.
	**/
	public static function getDisconnectedsFrom<T>(nodes:Array<T>, start:T, canCrawl:(from:T,to:T)->Bool) : Array<T> {
		var pending = [start];
		var dones = [];
		while( pending.length > 0 ) {
			var current = pending.pop();
			if( dones.contains(current) )
				continue;
			dones.push(current);

			for( node in nodes ) {
				if( node==current || dones.contains(node) )
					continue;

				if( canCrawl(current,node) && !pending.contains(node) )
					pending.push(node);
			}
		}

		return nodes.filter( node -> !dones.contains(node) );
	}



	#if deepnightLibsTests
	public static function test() {
		var nodes = ["D","C","A","B"];
		var canCrawl = (v1:String, v2:String)->v1!="D" && v2!="D";
		var disconnecteds = getDisconnectedsFrom(nodes, "A", canCrawl);
		CiAssert.isTrue( disconnecteds.length==1 && disconnecteds[0]=="D" );

		var nodes = ["E","A","F","B","C"];
		var canCrawl = (v1:String, v2:String)->v2.charCodeAt(0)==v1.charCodeAt(0)+1;
		var disconnecteds = getDisconnectedsFrom(nodes, "A", canCrawl);
		CiAssert.isTrue( disconnecteds.length==2 && disconnecteds.contains("E") && disconnecteds.contains("F") );

		var nodes = ["B","A","D","C"];
		var canCrawl = (v1:String, v2:String)->v2.charCodeAt(0)==v1.charCodeAt(0)+1;
		CiAssert.isTrue( getDisconnectedsFrom(nodes, "A", canCrawl).length==0 );

		var nodes = ["A"];
		var canCrawl = (v1:String, v2:String)->v2.charCodeAt(0)==v1.charCodeAt(0)+1;
		CiAssert.isTrue( getDisconnectedsFrom(nodes, "A", canCrawl).length==0 );

		var nodes = [];
		var canCrawl = (v1:String, v2:String)->v2.charCodeAt(0)==v1.charCodeAt(0)+1;
		CiAssert.isTrue( getDisconnectedsFrom(nodes, "A", canCrawl).length==0 );
	}
	#end

}
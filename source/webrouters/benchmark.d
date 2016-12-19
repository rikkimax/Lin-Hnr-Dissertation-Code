module webrouters.benchmark;
import webrouters.defs;

struct BenchMarkItems {
	BenchMarkItem[] items;

	RouterRequest[] allRequests;
	IWebSite[] allWebsites;
}

struct BenchMarkItem {
	Route route;
	RouterRequest[] requests;
}

BenchMarkItems createBenchMarks(uint maxEntries, uint maxParts, uint maxVariables) {
	import std.math : ceil;
	import std.random : uniform01, randomShuffle;

	// /part/:var/*
	BenchMarkItems ret;

	// number of entries that we will be doing
	size_t countEntries = cast(size_t)ceil(segmoidForX(uniform01()) * maxEntries);
	ret.items.length = countEntries;

	// Ok I'm kinda lazy for the next part.
	// The easiest way to make sure parent nodes are still filled correctly
	//  we must use a tree graph.
	// But that helps only in figuring out path part constants.
	// To figure out the order, we can use randomShuffle upon on the order of all entries.

	uint[] partOrders;
	partOrders.length = maxParts * 2;
	foreach(i, ref v; partOrders)
		v = i;

	uint[] allPartsOrderVars;
	allPartsOrderVars.length = maxParts * countEntries;

	InternalEntry[] partsOrder;
	partsOrder.length = countEntries;

	foreach(i, ref entry; partsOrder) {
		double temp = segmoidForX(countEntries / (i + 1));

		uint numParts = cast(size_t)ceil(temp * maxParts);
		uint numVariables = cast(size_t)ceil(uniform01() < 0.3 ? (temp * maxVariables) : 0);
		uint numConstants = numParts - numVariables;
		bool haveCatchAll = segmoidForX(numParts / (numVariables + 1)) < 0.46812;

		if (numConstants == 0) {
			if (numVariables > 0 && uniform01() <= 0.48) {
				numVariables--;
			}

			numConstants++;
		}

		entry.numConstants = numConstants;
		entry.numVariables = numVariables;
		entry.haveCatchAll = haveCatchAll;

		entry.order = allPartsOrderVars[0 .. numVariables + numConstants];
		allPartsOrderVars = allPartsOrderVars[numVariables + numConstants .. $];

		entry.order[] = partOrders[0 .. entry.order.length];
		randomShuffle(entry.order);

		if (entry.order[0] >= numConstants) {
			foreach(j; 0 .. entry.order.length) {
				if (entry.order[j] < numConstants) {
					uint temp2 = entry.order[0];
					entry.order[0] = entry.order[j];
					entry.order[j] = temp2;
					break;
				}
			}
		}
	}

	import std.stdio;
	writeln(partsOrder);



	return ret;
}

private {
	string[] words;

	struct InternalEntry {
		uint numConstants, numVariables;
		uint[] order;
		bool haveCatchAll;
	}

	static this() {
		import std.file : readText;
		import std.string : splitLines, indexOf;

		size_t realLength;
		words.length = 50_000;

		foreach(line; readText("data/wordlist/en_US.dic").splitLines) {
			auto index = line.indexOf('/');

			if (realLength == words.length) {
				words.length += 1000;
			}

			if (index == -1) {
				words[realLength] = line.dup;
			} else {
				words[realLength] = line[0 .. index].dup;
			}

			realLength++;
		}

		words.length = realLength;
	}

	double segmoidForX(double x) {
		import std.math : sqrt, pow;
		return (x-1.1f)/(2f * sqrt(1f+pow(x-1.2f, 2f)))/1f+0.4f;
	}
}
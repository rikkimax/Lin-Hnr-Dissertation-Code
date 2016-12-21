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

	uint[] partTypeConstants, partTypeVariables, partTypeCatchAlls;
	partTypeConstants.length = maxParts * 2;
	partTypeVariables.length = maxParts * 2;
	partTypeCatchAlls.length = maxParts * 2;

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

		partTypeCatchAlls[numConstants + numVariables]++;
		foreach(j, o; entry.order) {
			if (o < numConstants) {
				partTypeConstants[j]++;
			} else {
				partTypeVariables[j]++;
			}
		}
	}

	import std.stdio;
	writeln(partsOrder);

	// Now we have to generate a tree graph that describes the uniqueness of each constant, variable and catch all
	InternalTreeEntry root;

	foreach(ref part; partsOrder) {
		processPartOrderTree(root, part, 0);
	}

	writeln(root.toString);

	return ret;
}

private {
	string[] words;

	struct InternalEntry {
		uint numConstants, numVariables;
		uint[] order;
		bool haveCatchAll;
	}

	struct InternalTreeEntry {
		InternalTreeEntry* parent;

		InternalTreeEntry[] children;
		string constant;
		bool haveCatchAll, haveVariable;

		string toString() {
			string ret = "InternalTreeEntry(";
			ret ~= `"` ~ constant ~ `"`;
			ret ~= haveVariable ? ":" : "-";
			ret ~= haveCatchAll ? "*" : "_";
			ret ~= " [";

			foreach(child; children) {
				ret ~= child.toString;
				ret ~= ", ";
			}

			return ret ~ "])";
		}
	}

	void processPartOrderTree(ref InternalTreeEntry parent, ref InternalEntry entry, uint offset) {
		import std.random : uniform;

		if (entry.order.length > offset) {
			if (entry.order[offset] < entry.numConstants) {
				if (parent.children.length == 0) {
					parent.children ~= InternalTreeEntry(&parent);
					processPartOrderTree(parent.children[0], entry, offset+1);
				} else {
					size_t idx = uniform(0, parent.children.length + 1);

					if (idx == parent.children.length) {
						parent.children ~= InternalTreeEntry(&parent);
						processPartOrderTree(parent.children[$-1], entry, offset+1);
					} else {
						processPartOrderTree(parent.children[idx], entry, offset+1);
					}
				}
			} else {
				// ugh oh variable!

				if (parent.haveVariable) {
					// ok already exists, we've got to go up the tree and make this leaf "unique"
					makePartOrderTreeUnique(parent, entry, offset);
				} else {
					parent.haveVariable = true;

					if (entry.haveCatchAll || (entry.order.length > offset+1 && entry.order[offset+1] >= entry.numConstants)) {
						// ok so a variable
						// we've got to create a new node for it
						// and only then process it
						parent.children ~= InternalTreeEntry(&parent);
						processPartOrderTree(parent.children[0], entry, offset+1);
					}
				}
			}
		} else if (entry.haveCatchAll) {
			if (parent.haveCatchAll) {
				// ok already exists, we've got to go up the tree and make this leaf "unique"
				makePartOrderTreeUnique(parent, entry, offset);
			} else {
				parent.haveCatchAll = true;
			}
		}
	}

	void makePartOrderTreeUnique(ref InternalTreeEntry parent, ref InternalEntry entry, uint offset) {
		// /cnst/:var/:var ➔ /cnst/:var/← ➔ /cnst/←/← ➔ /↓ ➔ /cnst2 ➔ /cnst2/:var ➔ /cnst2/:var/:var
		// /cnst/* ➔ /cnst/← ➔ /↓ ➔ /cnst2 ➔ /cnst2/*

		InternalTreeEntry* tempParent = parent.parent;

		foreach_reverse(i; 0 .. offset-1) {
			// basically we go up until we find a new parent to start creating from
			// once we have done that, we execute processPartOrderTree again

			// If we've executing this code that means that we're either a variable or a catch all
			//  and it can't be added to this parent node :(
			// To work around this we must evaluate each parent node out.
			// Variables are ignored since they like catch alls are one add parts
			//  however constant parts are equal opportunities, here we MUST add a new child node!
			// From there we rebuild the tree and return from here.

			if (entry.order[i] < entry.numConstants) {
				// oh goody we found a constant!

				// Now we could go do some walking of the tree graph.
				// But who likes walking? We've done enough already.
				// So let's forget that crazy idea and just dump it into
				//  its own new branch of the graph.

				tempParent.children ~= InternalTreeEntry(&parent);
				makePartOrderTreeUnique(*tempParent, entry, i);
				return;
			}

			// oh great... next please :(

			tempParent = tempParent.parent;
			if (tempParent is null)
				return; // oh stuff this it doesn't have to be exact
		}

		// what ever, shouldn't happen and who cares if it does
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
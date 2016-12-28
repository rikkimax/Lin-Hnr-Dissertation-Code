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
		v = cast(uint)i;

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

		uint numParts = cast(uint)ceil(temp * maxParts);
		uint numVariables = cast(uint)ceil(uniform01() < 0.3 ? (temp * maxVariables) : 0);
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

	// Now we have to generate a tree graph that describes the uniqueness of each constant, variable and catch all
	//  naturally we also must specify if there an element is also an end point, but only for constant and variable.
	// While we're at it, we'll do some flattening

	InternalTreeEntry root;

	foreach(ref part; partsOrder) {
		processPartOrderTree(&root, part, 0);
	}

	uint offsetForEntry;
	ret.items.length = countEntries;

	root.fillText;

	dchar[] buffer;
	buffer.length = 1024;
	buffer[] = '_';
	buffer[0] = '/';

	import std.utf : byDchar, count;
	uint tL=1;
	foreach(c; root.constant.byDchar) {
		buffer[tL] = c;
		tL++;
	}

	// this adds the tree for route definitions into the return data
	foreach(ref child; root.children) {
		if (child.haveVariable >= 0) {
			flattenTree(&child, offsetForEntry, ret, buffer, tL, true, 0, maxParts, false);
		} else {
			flattenTree(&child, offsetForEntry, ret, buffer, 0, true, 0, maxParts, false);
		}
	}

	// now we've got to add test routes against the definition
	// however this is some sort of "curve", definately not segmoid
	// that determines how many get tested




	// TODO: flatten the tree graph into a BenchMarkItems
	import std.stdio;
	//writeln(partsOrder);
	//writeln(root.toString);

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
		string constant, varName;
		bool haveCatchAll, isAnEnd;
		int haveVariable=-1;

		string toString(string prepend="") {
			import std.conv :text;
			string newprepend = prepend ~ "    ";

			string ret = prepend ~ "InternalTreeEntry(\n";

			if (haveVariable >= 0 && children.length > 1) {
				ret ~= newprepend ~ `constant "` ~ constant ~ `" var(` ~ haveVariable.text ~ `)"` ~ varName ~ `"`;
			} else if (haveVariable >= 0) {
				ret ~= newprepend ~ `var(` ~ haveVariable.text ~ `)"` ~ varName ~ `"`;
			} else if (children.length > 0) {
				ret ~= newprepend ~ `constant "` ~ constant ~ `"`;
			} else {
				ret ~= newprepend;
			}

			ret ~= haveVariable >= 0 ? ":" : "";
			ret ~= haveCatchAll ? "*" : "";
			ret ~= (haveCatchAll || isAnEnd) ? "←|" : "";
			ret ~= " [\n";

			foreach(child; children) {
				ret ~= child.toString(newprepend);
			}

			return ret ~ prepend ~ "])\n";
		}
	}

	void processPartOrderTree(InternalTreeEntry* parent, ref InternalEntry entry, uint offset) {
		import std.random : uniform;

		if (entry.order.length <= offset) {
			parent.isAnEnd = true;
		}

		if (entry.order.length > offset) {
			if (entry.order[offset] < entry.numConstants) {
				if (parent.children.length == 0) {
					parent.children ~= InternalTreeEntry(parent);
					processPartOrderTree(&parent.children[0], entry, offset+1);
				} else {
					size_t idx = uniform(0, parent.children.length + 1);

					if (idx == parent.children.length) {
						parent.children ~= InternalTreeEntry(parent);
						processPartOrderTree(&parent.children[$-1], entry, offset+1);
					} else {
						processPartOrderTree(&parent.children[idx], entry, offset+1);
					}
				}
			} else {
				// ugh oh variable!

				if (parent.haveVariable >= 0) {
					// ok already exists, we've got to go up the tree and make this leaf "unique"
					makePartOrderTreeUnique(parent, entry, offset);
				} else {
					// ok so a variable
					// we've got to create a new node for it
					parent.haveVariable = cast(uint)parent.children.length;
					parent.children ~= InternalTreeEntry(parent);
					processPartOrderTree(&parent.children[$-1], entry, offset+1);
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

	void makePartOrderTreeUnique(InternalTreeEntry* parent, ref InternalEntry entry, uint offset) {
		// /cnst/:var/:var ➔ /cnst/:var/← ➔ /cnst/←/← ➔ /↓ ➔ /cnst2 ➔ /cnst2/:var ➔ /cnst2/:var/:var
		// /cnst/* ➔ /cnst/← ➔ /↓ ➔ /cnst2 ➔ /cnst2/*

		InternalTreeEntry* tempParent = parent.parent;

		foreach_reverse(i; 0 .. offset) {
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

				tempParent.children ~= InternalTreeEntry(parent);
				processPartOrderTree(&tempParent.children[$-1], entry, i);
				return;
			}

			// oh great... next please :(

			tempParent = tempParent.parent;
			if (tempParent is null)
				return; // oh stuff this it doesn't have to be exact
		}

		// what ever, shouldn't happen and who cares if it does
	}

	void fillText(ref InternalTreeEntry entry) {
		import std.random : uniform;

		if (entry.haveVariable >= 0) {
			entry.varName = words[uniform(0, words.length)];
		}
		
		entry.constant = words[uniform(0, words.length)];

		foreach(ref child; entry.children) {
			fillText(child);
		}
	}

	void flattenTree(InternalTreeEntry* parent, ref uint offsetForEntry, ref BenchMarkItems ret, dchar[] buffer,
		uint offset, bool generateNewData, uint numPartsSoFar, uint maxNumParts, bool unconditionalGenerate) {
		import std.utf : count, byDchar;

		if (generateNewData && !unconditionalGenerate) {
			import std.random : uniform01;
			// this gives a chance to NOT to continue generation process to children
			// but not only is there the curve based upon number of parts so far out of the total
			// there is also a chance it will be included anyway
			// keep in mind this occurs EVERY path part in the tree, so there is a good chance however slim
			// to get not be generating after this
			// so short paths get preference for test generation
			generateNewData = curveForX(1-(maxNumParts / (cast(float)maxNumParts-numPartsSoFar))) >= 0.0618205187 ||
				uniform01() <= 0.46812051;
		}

		uint endLength;
		if (parent.haveVariable >= 0) {
			// variable

			if (!generateNewData) {
				uint len = cast(uint)parent.varName.count;
				endLength = len + 2;

				buffer[offset++] = '/';
				buffer[offset++] = ':';
				foreach(c; parent.varName.byDchar) {
					buffer[offset++] = c;
				}
				
				flattenTree(&parent.children[parent.haveVariable], offsetForEntry, ret, buffer, offset, generateNewData, numPartsSoFar + 1, maxNumParts, unconditionalGenerate);
				offset -= endLength;
			}
		}
		if (parent.haveCatchAll) {
			// catch all

			if (!generateNewData) {
				buffer[offset .. offset + 2] = "/*"d;
				offset += 2;
			
				endLength = 2;
			}
		} else if (!(parent.children.length == 0 && (parent.isAnEnd || parent.haveCatchAll))) {
			// constant

			uint len = cast(uint)parent.constant.count;
			endLength = len + 1;

			buffer[offset++] = '/';
			foreach(c; parent.constant.byDchar) {
				buffer[offset++] = c;
			}

			uint i;
			foreach(ref child; parent.children) {
				if (i != parent.haveVariable)
					flattenTree(&child, offsetForEntry, ret, buffer, offset, generateNewData, numPartsSoFar + 1, maxNumParts, unconditionalGenerate);
				i++;
			}
		}

		if (parent.isAnEnd || parent.haveCatchAll) {
			dstring thispath = buffer[0 .. offset].idup;

			// okay we need to start /saving/ the given route!

			offset -= endLength;

			if (generateNewData) {

				import std.stdio;
				writeln("END: generate {", thispath, "}");

			} else {

				import std.stdio;
				writeln("END:          {", thispath, "}");

			}
		}
	}

	static this() {
		import std.file : readText;
		import std.string : splitLines, indexOf, tr;

		size_t realLength;
		words.length = 50_000;

		foreach(line; readText("data/wordlist/en_US.dic").splitLines) {
			auto index = line.indexOf('/');

			if (realLength == words.length) {
				words.length += 1000;
			}

			if (index == -1) {
				words[realLength] = line.tr("'", "_");
			} else {
				words[realLength] = line[0 .. index].tr("'", "_");
			}

			realLength++;
		}

		words.length = realLength;
	}

	double segmoidForX(double x) {
		import std.math : sqrt, pow;
		return (x-1.1f)/(2f * sqrt(1f+pow(x-1.2f, 2f)))/1f+0.4f;
	}

	double curveForX(double x) {
		import std.math : E, pow;
		import std.random : uniform01;
		x += uniform01() * (1/8f);
		return (pow(E, 0.68271 * x - (2967/4000)) / 6);
	}
}
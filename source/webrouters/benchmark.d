module webrouters.benchmark;
import webrouters.defs;

struct BenchMarkItems {
	BenchMarkItem[] items;

	RouterRequest[] allRequests;
	IWebSite[] allWebsites;

	string toString() {
		string ret;

		foreach(item; items) {
			ret ~= item.toString;
		}

		return ret;
	}
}

struct BenchMarkItem {
	Route route;
	RouterRequest[] requests;

	string toString() {
		import std.conv : text;
		string ret;

		ret ~= "    |\n";
		ret ~= "    |----| " ~ route.path.text ~ "\n";
		foreach(request; requests) {
			ret ~= "    |    |---- " ~ request.path.text ~ "\n";
		}

		return ret;
	}
}

BenchMarkItems createBenchMarks(uint maxEntries, uint maxParts, uint maxVariables, uint maxTests) {
	import std.math : ceil;
	import std.random : uniform01, uniform, randomShuffle;
	import std.algorithm : clamp;

	// /part/:var/*
	BenchMarkItems ret;

	// number of entries that we will be doing
	size_t countEntries = cast(size_t)ceil(segmoidForX(uniform01()).clamp(0f, 1f) * maxEntries);
	ret.items.length = countEntries;
	ret.allRequests.length = countEntries * maxTests;

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

	uint offsetForEntry, offsetForRequest;
	root.fillText;

	dchar[] buffer;
	buffer.length = 1024;
	buffer[] = '_';
	buffer[0] = '/';

	import std.utf : byDchar, count;
	uint tL;

	// this adds the tree for route definitions into the return data
	// but it also creates a set of tests for the given child
	// this is a complicated process, that requires curves and random numbers!
	foreach(ref child; root.children) {
		if (child.haveVariable >= 0) {
			buffer[0] = '/';
			tL=1;
			
			foreach(c; root.constant.byDchar) {
				buffer[tL] = c;
				tL++;
			}

			flattenTreeSpec(&child, tL, buffer, ret, offsetForEntry, false, maxParts, 0, offsetForRequest);
		} else {
			flattenTreeSpec(&child, 0, buffer, ret, offsetForEntry, false, maxParts, 0, offsetForRequest);
		}
	}

	ret.items.length = offsetForEntry;
	countEntries = ret.items.length;

	foreach(_; 0 .. uniform(1, maxTests+1)) {
		offsetForEntry = 0;

		foreach(ref child; root.children) {
			if (child.haveVariable >= 0) {
				buffer[0] = '/';
				tL=1;

				foreach(c; root.constant.byDchar) {
					buffer[tL] = c;
					tL++;
				}

				flattenTreeSpec(&child, tL, buffer, ret, offsetForEntry, true, maxParts, 0, offsetForRequest);
			} else {
				flattenTreeSpec(&child, 0, buffer, ret, offsetForEntry, true, maxParts, 0, offsetForRequest);
			}
		}
	}

	ret.allRequests.length = offsetForRequest;

	// TODO: websites
	// TODO: ports
	// TODO: addresses
	// TODO: HTTP status codes

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

	void flattenTreeSpec(InternalTreeEntry* parent, uint offset, dchar[] buffer,
		ref BenchMarkItems ret, ref uint offsetForEntry, bool forTests,
		uint maxNumParts, uint numPartsSoFar, ref uint offsetForRequest) {
		import std.utf : count, byDchar;
		import std.random : uniform, uniform01;
		
		bool generateNewData;
		if (forTests) {
			// this gives a chance to NOT to continue generation process to children
			// but not only is there the curve based upon number of parts so far out of the total
			// there is also a chance it will be included anyway
			// keep in mind this occurs EVERY path part in the tree, so there is a good chance however slim
			// to get not be generating after this
			// so short paths get preference for test generation
			generateNewData = curveForX(1-(maxNumParts / (cast(float)maxNumParts-numPartsSoFar))) >= 0.0618205187 ||
				uniform01() <= 0.46812051;
		}
		
		if (parent.haveCatchAll) {
			// catch all
			uint offsetT = offset;
			
			if (generateNewData) {
				uint numPartsToTest = cast(uint)(segmoidForX(maxNumParts / (numPartsSoFar + 1)) * ((maxNumParts + 2) - numPartsSoFar));
				
				foreach(_; 0 .. numPartsToTest) {
					string word = words[uniform(0, words.length)];
					
					buffer[offsetT++] = '/';
					foreach(c; word.byDchar) {
						buffer[offsetT++] = c;
					}
				}
				
				flattenTreeSpecEntry(buffer[0 .. offsetT], ret, offsetForEntry, 
					forTests, maxNumParts, numPartsSoFar+1, offsetForRequest);
			} else if (!forTests) {
				buffer[offsetT .. offsetT + 2] = "/*"d;
				offsetT += 2;
				flattenTreeSpecEntry(buffer[0 .. offsetT], ret, offsetForEntry, 
					forTests, maxNumParts, numPartsSoFar+1, offsetForRequest);
			}
		}
		
		if (parent.haveVariable >= 0) {
			// variable
			
			if (generateNewData) {
				string word = words[uniform(0, words.length)];
				uint len = cast(uint)(word.length + 1);
				
				buffer[offset++] = '/';
				foreach(c; word.byDchar) {
					buffer[offset++] = c;
				}
				
				flattenTreeSpec(&parent.children[parent.haveVariable], offset, buffer, ret, offsetForEntry,
					forTests, maxNumParts, numPartsSoFar+1, offsetForRequest);
			} else if (!forTests) {
				uint len = cast(uint)parent.varName.count;
				
				buffer[offset++] = '/';
				buffer[offset++] = ':';
				foreach(c; parent.varName.byDchar) {
					buffer[offset++] = c;
				}
				
				flattenTreeSpec(&parent.children[parent.haveVariable], offset, buffer, ret, offsetForEntry, 
					forTests, maxNumParts, numPartsSoFar+1, offsetForRequest);
			}
		} else {
			// constant
			
			uint len = cast(uint)parent.constant.count;
			buffer[offset++] = '/';
			foreach(c; parent.constant.byDchar) {
				buffer[offset++] = c;
			}
			
			uint i;
			foreach(ref child; parent.children) {
				if (i != parent.haveVariable)
					flattenTreeSpec(&child, offset, buffer, ret, offsetForEntry,
						forTests, maxNumParts, numPartsSoFar+1, offsetForRequest);
				i++;
			}
		}
		
		if (parent.isAnEnd) {
			if (forTests && !generateNewData)
				offsetForEntry++;
			else
				flattenTreeSpecEntry(buffer[0 .. offset], ret, offsetForEntry, 
					forTests, maxNumParts, numPartsSoFar+1, offsetForRequest);
		}
	}
	
	void flattenTreeSpecEntry(dchar[] buffer, ref BenchMarkItems ret, ref uint offsetForEntry,
		bool forTests, uint maxNumParts, uint numPartsSoFar, ref uint offsetForRequest) {

		if (!forTests && offsetForEntry == ret.items.length) {
			ret.items.length++;
		}
		
		auto item = &ret.items[offsetForEntry];

		if (forTests) {
			if (item.requests.length == 0) {
				item.requests = ret.allRequests[offsetForRequest .. offsetForRequest + 1];
			} else {
				item.requests = item.requests.ptr[0 .. item.requests.length + 1];
			}

			offsetForRequest++;
			item.requests[$-1] = RouterRequest(null, buffer.idup);
		} else {
			item.route.path = buffer.idup;
		}
		
		offsetForEntry++;
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
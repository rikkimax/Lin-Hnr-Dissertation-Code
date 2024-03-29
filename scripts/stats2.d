struct Entry {
	ulong listA, listI;
	ulong treeA, treeI;
	ulong regexA, regexI;

	ulong treeOA, treeOI;
	ulong regexOA, regexOI;

	this(T)(T values) {
		listA = values.front;
		values.popFront;
		listI = values.front;
		values.popFront;
		
		treeA = values.front;
		values.popFront;
		treeI = values.front;
		values.popFront;
		
		regexA = values.front;
		values.popFront;
		regexI = values.front;
		values.popFront;

		treeOA = values.front;
		values.popFront;
		treeOI = values.front;
		values.popFront;
		
		regexOA = values.front;
		values.popFront;
		regexOI = values.front;
		values.popFront;
	}
}

Entry[] parseFile(string filename) {
	import std.file : readText;
	import std.algorithm;
	import std.range;
	import std.conv;

	string raw_text = readText(filename);
	
	auto countNewLines = raw_text.count('\n');
	if (countNewLines <= 1)
		return null;
	countNewLines--;
	
	debug {
		import std.stdio : writeln;
		writeln(filename);
		writeln(" newLines: ", countNewLines);
	}

	Entry[] ret;
	ret.length = countNewLines;

	auto temp = raw_text
		.splitter("\n")
		.dropExactly(1)
		.filter!(b => b.length > 1)
		.map!(a => a
			.splitter(" ")
			.dropExactly(1)
			.filter!(b => b.length > 0)
			.map!(b => b.to!ulong)
			.chunks(10)
			.map!(b => Entry(b))
		)
		.joiner
		.lockstep(iota(0, countNewLines));
	
	foreach(a, i; temp) {
		ret[i] = a;
	}

	return ret;
}

void main() {
	import std.stdio : File;
	import std.array : appender;
	import std.string : split;

	auto output = appender!string;
	output ~= "File ";

	output ~= "below(listA) below(listI) below(treeA) below(treeI) ";
	output ~= "below(regexA) below(regexI) below(treeOA) below(treeOI) ";
	output ~= "below(regexOA) below(regexOI) ";

	output ~= "above(listA) above(listI) above(treeA) above(treeI) ";
	output ~= "above(regexA) above(regexI) above(treeOA) above(treeOI) ";
	output ~= "above(regexOA) above(regexOI) ";
	
	output ~= "atmean(listA) atmean(listI) atmean(treeA) atmean(treeI) ";
	output ~= "atmean(regexA) atmean(regexI) atmean(treeOA) atmean(treeOI) ";
	output ~= "atmean(regexOA) atmean(regexOI)\n";

	Entry[] means = parseFile("../benchmarks/mean.csv");
	size_t meanEntry;
	
	foreach(line; File("../benchmarks/titles.txt", "r").byLine) {
		if (line is null)
			continue;

		string[] parts = cast(string[])line.split("\t");
		foreach(strit; ["1", "10", "100", "1000"]) {		
			string name = "../benchmarks/" ~ parts[0][0 .. $-5] ~ "_iterations_" ~ strit ~ 
"_result.csv";

			Entry mean = means[meanEntry];

//		if (name == "../benchmarks/set_136_sites_30_iterations_10_result.csv") {
			Entry[] entries = parseFile(cast(string)name);
			if (entries.length <= 1)
				continue;			

			Entry below, above, atmean;
			foreach(ref v; entries) {
				handleData!"listA"(v, below, above, atmean, mean);
				handleData!"listI"(v, below, above, atmean, mean);
				handleData!"treeA"(v, below, above, atmean, mean);
				handleData!"treeI"(v, below, above, atmean, mean);
				handleData!"regexA"(v, below, above, atmean, mean);
				handleData!"regexI"(v, below, above, atmean, mean);
				handleData!"treeOA"(v, below, above, atmean, mean);
				handleData!"treeOI"(v, below, above, atmean, mean);
				handleData!"regexOA"(v, below, above, atmean, mean);
				handleData!"regexOI"(v, below, above, atmean, mean);
			}

			import std.format : formattedWrite;
			output ~= name[14 .. $];

			output.formattedWrite(" %d %d %d %d %d %d %d %d %d %d ",
				below.listA, below.listI, below.treeA, below.treeI,
				below.regexA, below.regexI, below.treeOA, below.treeOI,
				below.regexOA, below.regexOI);
			output.formattedWrite("%d %d %d %d %d %d %d %d %d %d ",
				above.listA, above.listI, above.treeA, above.treeI,
				above.regexA, above.regexI, above.treeOA, above.treeOI,
				above.regexOA, above.regexOI);
				
			output.formattedWrite("%d %d %d %d %d %d %d %d %d %d\n",
				atmean.listA, atmean.listI, atmean.treeA, atmean.treeI,
				atmean.regexA, atmean.regexI, atmean.treeOA, atmean.treeOI,
				atmean.regexOA, atmean.regexOI);
//		}

			meanEntry++;
		}
	}

	import std.file : write;
	write("../abovebelow.csv", output.data);
}

void handleData(string member)(ref Entry entry, ref Entry below, ref Entry above, ref Entry atmean, ref Entry mean) {
	enum E = "entry." ~ member;
	enum M = "mean." ~ member;
	enum I = "below." ~ member;
	enum A = "above." ~ member;
	enum T = "atmean." ~ member;
	
	if (mixin(M) > mixin(E)) {
		mixin(I)++;
	}
	
	if (mixin(M) < mixin(E)) {
		mixin(A)++;
	}
	
	auto minT = mixin(M) > 5 ? mixin(M) -5 : 0;
	auto maxT = mixin(M) < ulong.max ? mixin(M) +5 : ulong.max;
	if (mixin(E) >= minT && mixin(E) <= maxT) {
		mixin(T)++;
	}
}

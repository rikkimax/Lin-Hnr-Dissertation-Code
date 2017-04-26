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

	output ~= "min(listA) min(listI) min(treeA) min(treeI) ";
	output ~= "min(regexA) min(regexI) min(treeOA) min(treeOI) ";
	output ~= "min(regexOA) min(regexOI) ";

        output ~= "max(listA) max(listI) max(treeA) max(treeI) ";
        output ~= "max(regexA) max(regexI) max(treeOA) max(treeOI) ";
        output ~= "max(regexOA) max(regexOI)\n";

	foreach(line; File("../benchmarks/titles.txt", "r").byLine) {
		if (line is null)
			continue;

		string[] parts = cast(string[])line.split("\t");
		foreach(strit; ["1", "10", "100", "1000"]) {		
			string name = "../benchmarks/" ~ parts[0][0 .. $-5] ~ "_iterations_" ~ strit ~ 
"_result.csv";

//		if (name == "../benchmarks/set_136_sites_30_iterations_10_result.csv") {
			Entry[] entries = parseFile(cast(string)name);
			if (entries.length <= 1)
				continue;			

			Entry min, max;
			min = entries[0];
			foreach(ref v; entries) {
				handleData!"listA"(v, min, max);
				handleData!"listI"(v, min, max);
				handleData!"treeA"(v, min, max);
				handleData!"treeI"(v, min, max);
				handleData!"regexA"(v, min, max);
				handleData!"regexI"(v, min, max);
				handleData!"treeOA"(v, min, max);
				handleData!"treeOI"(v, min, max);
				handleData!"regexOA"(v, min, max);
				handleData!"regexOI"(v, min, max);
			}

			import std.format : formattedWrite;
			output ~= name[14 .. $];

			output.formattedWrite(" %d %d %d %d %d %d %d %d %d %d ",
				min.listA, min.listI, min.treeA, min.treeI,
				min.regexA, min.regexI, min.treeOA, min.treeOI,
				min.regexOA, min.regexOI);
                        output.formattedWrite("%d %d %d %d %d %d %d %d %d %d\n",
                                max.listA, max.listI, max.treeA, max.treeI,
                                max.regexA, max.regexI, max.treeOA, max.treeOI,
                                max.regexOA, max.regexOI);
//		}
		}
	}

	import std.file : write;
	write("../minmax.csv", output.data);
}

void handleData(string member)(ref Entry entry, ref Entry min, ref Entry max) {
	enum E = "entry." ~ member;
	enum I = "min." ~ member;
	enum A = "max." ~ member;

	mixin(I ~ " = " ~ E ~ " < " ~ I ~ " ? " ~ E ~ " : " ~ I ~ ";");
	mixin(A ~ " = " ~ E ~ " > " ~ A ~ " ? " ~ E ~ " : " ~ A ~ ";");
}

import std.stdio;
import webrouters.benchmark;
import webrouters.defs;

void main(string[] args) {
	import std.getopt;
	import std.file : exists, isDir, mkdirRecurse, remove;

	bool generateBenchmarks;
	string benchmarkDirectory = "benchmarks";

	uint maxEntries, maxParts, maxVariables, maxTests;
	maxEntries = 1_000_000;
	maxParts = 20;
	maxVariables = 8;
	maxTests = 20;

	auto helpInformation = getopt(
		args,

		// generic stuff

		"benchmarkDirectory|bd", "Benchmark directory, default: ./benchmarks", &benchmarkDirectory,
		"verbose|v", &verboseMode,

		// benchmark generatior stuff

		"benchmark|bg", "Generate benchmark test sets", &generateBenchmarks,
		"benchmarkMaxEntires|bme", "Benchmark max entries, default: 1,000,000", &maxEntries,
		"benchmarkMaxParts|bmp", "Benchmark max parts, default: 20", &maxParts,
		"benchmarkMaxVariables|bmv", "Benchmark max variables, default: 8", &maxVariables,
		"benchmarkMaxTests|bmt", "Benchmark max tests, default: 20", &maxTests,
	);

	if (helpInformation.helpWanted) {
		defaultGetoptPrinter(`Benchmarking suite for web routers

Syntax: ` ~ args[0] ~ ` <args>

Copyright Richard(Rikki) Andrew Cattermole © 2016-2017
 as part of Honors at Lincoln University
`, helpInformation.options);
		return;
	}

	try {
		if (exists(benchmarkDirectory)) {
			if (isDir(benchmarkDirectory)) {
				// we're ok
			} else {
				// umm, delete?
				remove(benchmarkDirectory);
				mkdirRecurse(benchmarkDirectory);
			}
		} else {
			mkdirRecurse(benchmarkDirectory);
		}
	} catch (Exception e) {
		writeln("Failed to cleanup/create the benchmark directory.");

		if (verboseMode) {
			writeln(e.toString);
		}
		return;
	}

	if (generateBenchmarks) {
		if (verboseMode) {
			writeln(":::::::::::::::::::::::::::::::::::::::::");
			writeln(":         Benchmark generation          :");
			writeln(":::::::::::::::::::::::::::::::::::::::::");
		}

		createAllBenchmarks(benchmarkDirectory, maxEntries, maxParts, maxVariables, maxTests);

		if (verboseMode) {
			writeln(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;");
			writeln(";         Benchmark generation          ;");
			writeln(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;");
		}
	}
}

void createAllBenchmarks(string directory, uint maxEntries, uint maxParts, uint maxVariables, uint maxTests) {
	import core.memory : GC;
	import std.path : buildPath;

	foreach(i, dst; [directory.buildPath("a.csuf"), directory.buildPath("b.csuf")]) {
		import std.stdio;

		if (verboseMode) {
			writeln(i, ": filename(\"", dst, "\")");
		}

		createAndStoreBenchmark(dst, 1_000_000, 20, 8, 20);

		// Do you like OOM errors? Because I certainly don't...
		// this doesn't exactly fix the issue,
		// but for middle sized data sets with in use by lower teir processors (32bit/low RAM)
		// it can help greatly.
		GC.collect;
	}
}

void createAndStoreBenchmark(string filename, uint maxEntries, uint maxParts, uint maxVariables, uint maxTests) {
	import std.file : write;

	auto got = createBenchMarks(maxEntries, maxParts, maxVariables, maxTests);

	if (verboseMode) {
		writeln("\t", "route(specifications(", got.items.length, "), tests(", got.allRequests.length, "))");
		writeln("\t", "websites(", got.allWebsites.length, ")");
	}

	write(filename, createBenchmarkCSUF(got));
}

string createBenchmarkCSUF(BenchMarkItems benchmark) {
	import std.array : appender;

	auto ret = appender!string();
	ret.reserve(1_000_000);

	IWebSite lastWebsite;

	foreach(i, item; benchmark.items) {
		if (lastWebsite !is item.route.website || i == 0) {
			lastWebsite = item.route.website;

			if (i > 0)
				ret ~= "\n";
			ret ~= ".new\n";
		}

		ret ~= item.route.path;
		foreach(request; item.requests) {
			ret ~= " ";
			ret ~= request.path;
		}
		ret ~= "\n";
	}

	return ret.data;
}
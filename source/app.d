import std.stdio;
import webrouters.benchmark;
import webrouters.defs;

void main(string[] args) {
	import std.getopt;
	import std.file : exists, isDir, isFile, mkdirRecurse, remove, dirEntries, SpanMode;
	import std.algorithm : uniq;
	import std.path : dirName, baseName;
	import std.mmfile;
	import csuf.reader;

	bool generateBenchmarks, runBenchmark;
	string benchmarkDirectory = "benchmarks";
	string[] benchmarkLoad = ["benchmarks/*"];

	uint maxEntries, maxParts, maxVariables, maxTests;
	maxEntries = 1_000_000;
	maxParts = 20;
	maxVariables = 8;
	maxTests = 20;

	MmFile[] loadedBenchmarkFiles;
	CommandSequenceReader!dstring[] benchmarkFilesCSR;

	try {
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

			// benchmark loading stuff

			"run", "Runs the benchmark", &runBenchmark,
			"load", "Load a benchmark file, is a glob, default: benchmarks/*", &benchmarkLoad,
		);

		if (helpInformation.helpWanted) {
			defaultGetoptPrinter(`Benchmarking suite for web routers

	Syntax: ` ~ args[0] ~ ` <args>

	Copyright Richard(Rikki) Andrew Cattermole © 2016-2017
	 as part of Honors at Lincoln University
	`, helpInformation.options);
			return;
		}
	} catch (Exception e) {
		writeln;
		writeln(e.msg);
		writeln("See --help for more information");
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

	if (runBenchmark) {
		if (verboseMode) {
			writeln(":::::::::::::::::::::::::::::::::::::::::");
			writeln(":           Benchmark runner            :");
			writeln(":::::::::::::::::::::::::::::::::::::::::");
		}

		if (benchmarkLoad.length > 1) {
			// remove the default if its overidden
			benchmarkLoad = benchmarkLoad[1 .. $];
		}

		uint countFilesToLoad, currentFileToLoad;
		foreach(toload; benchmarkLoad.uniq) {
			foreach(file; dirEntries(dirName(toload), baseName(toload), SpanMode.depth)) {
				countFilesToLoad++;
			}
		}

		loadedBenchmarkFiles.length = countFilesToLoad;
		benchmarkFilesCSR.length = countFilesToLoad;

		foreach(toload; benchmarkLoad.uniq) {
			foreach(file; dirEntries(dirName(toload), baseName(toload), SpanMode.depth)) {
				if (verboseMode) {
					writeln("-----:::::::");
					writeln("     loading ", file);
				}

				if (isFile(file)) {
					// load the files via memory mapping
					
					auto mmfile = new MmFile(file, MmFile.Mode.read, 0, null);
					
					if (currentFileToLoad == loadedBenchmarkFiles.length) {
						loadedBenchmarkFiles.length++;
						benchmarkFilesCSR.length++;
					}
					
					loadedBenchmarkFiles[currentFileToLoad] = mmfile;
					benchmarkFilesCSR[currentFileToLoad] = CommandSequenceReader!dstring(cast(dstring)mmfile[]);
					
					// ugh do we need to do anything further?
					auto csr = &benchmarkFilesCSR[currentFileToLoad];
					
					// probably not at this point
					// we'd need to figure out the routers first
					// although setting up all the e.g. websites and routes would be a good thing...
				} else {
					if (verboseMode) {
						writeln("     Not a file, ignoring");
					}
				}

				currentFileToLoad++;
				if (verboseMode) {
					writeln("-----;;;;;;;");
				}
			}
		}

		if (verboseMode) {
			writeln(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;");
			writeln(";           Benchmark runner            ;");
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

dstring createBenchmarkCSUF(BenchMarkItems benchmark) {
	import std.utf : byDchar;
	import std.array : appender;

	auto ret = appender!dstring();
	ret.reserve(1_000_000);

	IWebSite lastWebsite;

	foreach(i, item; benchmark.items) {
		if (lastWebsite !is item.route.website || i == 0) {
			lastWebsite = item.route.website;

			if (i > 0)
				ret ~= '\n';
			ret ~= ".new\n"d;
		}

		foreach(c; item.route.path.byDchar) {
			ret ~= c;
		}

		foreach(request; item.requests) {
			ret ~= ' ';

			foreach(c; request.path.byDchar) {
				ret ~= c;
			}
		}
		ret ~= '\n';
	}

	return ret.data;
}
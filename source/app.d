import std.stdio;
import webrouters.benchmark;
import webrouters.benchmarker;
import webrouters.defs;
import webrouters.list : ListRouter;
import webrouters.dumbtree : DumbTreeRouter;
import webrouters.regex : DumbRegexRouter;
import csuf.reader;

void main(string[] args) {
	import std.getopt;
	import std.file : exists, isDir, isFile, mkdirRecurse, remove, dirEntries, SpanMode;
	import std.algorithm : uniq;
	import std.path : dirName, baseName;
	import std.mmfile;

	bool generateBenchmarks, runBenchmark;
	string benchmarkDirectory = "benchmarks";
	string[] benchmarkLoad = ["benchmarks/*"];

	string[] benchmarkerToLoad = [ListRouter.RouterName, DumbTreeRouter.RouterName, DumbRegexRouter.RouterName];
	size_t originalSizeOfBenchmarkerToLoad = benchmarkerToLoad.length;

	uint maxEntries, maxParts, maxVariables, maxTests;
	maxEntries = 1_000_000;
	maxParts = 20;
	maxVariables = 8;
	maxTests = 20;

	MmFile[] loadedBenchmarkFiles;
	CommandSequenceReader!string[] benchmarkFilesCSR;

	Benchmarker benchmarker;

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

			// benchmarker stuff

			"run", "Runs the benchmark", &runBenchmark,
			"load", "Load a benchmark file, is a glob, default: benchmarks/*", &benchmarkLoad,
			"benchmarkLoad|brl", "Adds a router implementation to benchmark, default: all", &benchmarkerToLoad,
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

	// validate that we know all the asked for router implementations.
	if (benchmarkerToLoad.length > originalSizeOfBenchmarkerToLoad) {
		benchmarkerToLoad = benchmarkerToLoad[originalSizeOfBenchmarkerToLoad .. $];

		foreach(bmrtl; benchmarkerToLoad) {
			switch(bmrtl) {
				case ListRouter.RouterName:
				case DumbTreeRouter.RouterName:
				case DumbRegexRouter.RouterName:
					break;
				default:
					writeln("Unrecognised router implementation ", bmrtl, ".");

					if (verboseMode) {
						writeln;
						writeln("Valid ones are:");

						foreach(m; [ListRouter.RouterName, DumbTreeRouter.RouterName, DumbRegexRouter.RouterName]) {
							writeln(" - ", m);
						}
					}
					return;
			}
		}
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
					benchmarkFilesCSR[currentFileToLoad] = CommandSequenceReader!string(cast(string)mmfile[]);
					
					// ugh do we need to do anything further?
					version(none) {
						auto csr = &benchmarkFilesCSR[currentFileToLoad];
					}

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

		// add each router implementation to test
		foreach(bmrtl; benchmarkerToLoad) {
			final switch(bmrtl) {
				case ListRouter.RouterName:
					benchmarker.registerRouterImplementation!ListRouter;
					break;
				case DumbTreeRouter.RouterName:
					benchmarker.registerRouterImplementation!DumbTreeRouter;
					break;
				case DumbRegexRouter.RouterName:
					//benchmarker.registerRouterImplementation!DumbRegexRouter;
					break;
			}
		}

		loadBenchmarkerWithTests(&benchmarker, benchmarkFilesCSR);
		benchmarker.setup();

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

string createBenchmarkCSUF(BenchMarkItems benchmark) {
	import std.array : appender;
	import std.format : sformat;

	auto ret = appender!string();
	ret.reserve(1_000_000);

	IWebSite lastWebsite;

	char[8] buffer;
	size_t sinceLastWebsite_num_requests, sinceLastWebsite_len_paths, sinceLastWebsite_len_requests;
	size_t countTotalEntries;

	foreach(i, item; benchmark.items) {
		if (lastWebsite !is item.route.website || i == 0) {
			lastWebsite = item.route.website;
			countTotalEntries++;
		}
	}

	ret ~= ".new HEADER\n";
	ret ~= ".num_entries ";
	ret ~= sformat(buffer[0 .. $], "%d", countTotalEntries);
	ret ~= '\n';
	
	lastWebsite = null;
	foreach(i, item; benchmark.items) {
		if (lastWebsite !is item.route.website || i == 0) {
			lastWebsite = item.route.website;

			if (i > 0) {
				ret ~= ".num_requests ";
				ret ~= sformat(buffer[0 .. $], "%d", sinceLastWebsite_num_requests);
				ret ~= '\n';

				ret ~= ".len_paths ";
				ret ~= sformat(buffer[0 .. $], "%d", sinceLastWebsite_len_paths);
				ret ~= '\n';

				ret ~= ".len_requests ";
				ret ~= sformat(buffer[0 .. $], "%d", sinceLastWebsite_len_requests);
				ret ~= '\n';
				
				ret ~= '\n';
			}

			ret ~= ".new\n";
			sinceLastWebsite_num_requests = 0;
			sinceLastWebsite_len_paths = 0;
			sinceLastWebsite_len_requests = 0;
		}

		sinceLastWebsite_len_paths += item.route.path.length;
		foreach(c; item.route.path) {
			ret ~= c;
		}

		sinceLastWebsite_num_requests += item.requests.length;
		foreach(request; item.requests) {
			ret ~= ' ';

			sinceLastWebsite_len_requests += request.path.length;
			foreach(c; request.path) {
				ret ~= c;
			}
		}
		ret ~= '\n';

		ret ~= "..status_code ";
		ret ~= sformat(buffer[0 .. $], "%d", item.route.code);
		ret ~= '\n';

		ret ~= "..requiresSSL ";
		ret ~= item.route.requiresSSL ? "true" : "false";
		ret ~= '\n';
	}

	if (sinceLastWebsite_len_paths > 0) {
		ret ~= ".num_requests ";
		ret ~= sformat(buffer[0 .. $], "%d", sinceLastWebsite_num_requests);
		ret ~= '\n';
		
		ret ~= ".len_paths ";
		ret ~= sformat(buffer[0 .. $], "%d", sinceLastWebsite_len_paths);
		ret ~= '\n';
		
		ret ~= ".len_requests ";
		ret ~= sformat(buffer[0 .. $], "%d", sinceLastWebsite_len_requests);
		ret ~= '\n';
	}
	
	return ret.data;
}

void loadBenchmarkerWithTests(Benchmarker* benchmarker, CommandSequenceReader!string[] benchmarkFilesCSR) {
	import webrouters.tests : DummyWebSite;

	foreach(ref dataset; benchmarkFilesCSR) {
		size_t totalNumberOfEntries;
	F2: foreach(ref entry; dataset.entries) {
			if (entry.commands[0].args.length > 0 && entry.commands[0].args[0] == "HEADER") {
				foreach(ref cmd; entry.commands[1 .. $]) {
					if (cmd.name == "num_entries") {
						totalNumberOfEntries = cmd.get!size_t(0);
					}
				}
				continue F2;
			}

			writeln(totalNumberOfEntries);
			IWebSite website = new DummyWebSite([
					WebsiteAddress("foo.bar", WebSiteAddressPort(80)),
					WebsiteAddress("foo.bar", WebSiteAddressPort(443), true, true)]);

			import std.stdio;

			foreach(ref info; entry.information) {
				BenchmarkerTest test;
				test.website = website;
				test.path = info.name;
				test.tests = info.args;

				foreach(cmd; info.commands) {
					if (cmd.name == "status_code")
						test.statuscode = cmd.get!ushort(0);
					else if (cmd.name == "requiresSSL")
						test.requiresSSL = cmd.args[0] == "true";
				}

				benchmarker.registerTest(test);
			}
		}
	}
}
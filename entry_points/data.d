import std.stdio;
import webrouters.benchmark;
import webrouters.benchmarker;
import webrouters.defs;
import webrouters.list : ListRouter;
import webrouters.dumbtree : DumbTreeRouter;
import webrouters.regex : DumbRegexRouter;
import csuf.reader;
import std.path : dirName, baseName, rootName, buildPath;

void main(string[] args) {
	import std.getopt;
	import std.file : exists, isDir, isFile, mkdirRecurse, remove, dirEntries, SpanMode, append, write;
	import std.algorithm : uniq;
	import std.mmfile;
	import std.format : format, sformat;
	import std.array : appender;
	
	bool generateBenchmarks;
	string benchmarkDirectory = "benchmarks";
	string[] benchmarkLoad = ["benchmarks/*.csuf"];
	string benchmarkOutputMean, benchmarkOutputAll, benchmarkAppendTitle, runBenchmark, benchmarkOutput;
	
	string[] benchmarkerToLoad = [ListRouter.RouterName, DumbTreeRouter.RouterName, DumbRegexRouter.RouterName];
	size_t originalSizeOfBenchmarkerToLoad = benchmarkerToLoad.length;
	
	uint maxEntries, maxParts, maxVariables, maxTests, benchmarkIterations, benchmarkDataIterations;
	maxEntries = 1_000_000;
	maxParts = 20;
	maxVariables = 8;
	maxTests = 20;
	benchmarkIterations = 10;
	benchmarkDataIterations = 1;
	
	MmFile[] loadedBenchmarkFiles;
	CommandSequenceReader!string[] benchmarkFilesCSR;
	
	Benchmarker benchmarker;
	
	try {
		auto helpInformation = getopt(
			args,
			"verbose|v", &verboseMode,
			
			// generic stuff
			
			"benchmarkDirectory|bd", "Benchmark directory, default: ./benchmarks", &benchmarkDirectory,
			"benchmarkOutput|bo", "Output benchmark file, appends only", &benchmarkOutput,
			
			// benchmark generatior stuff
			
			"benchmark|bg", "Generate benchmark test sets", &generateBenchmarks,
			"benchmarkMaxEntires|bme", "Benchmark max entries, default: 1,000,000", &maxEntries,
			"benchmarkMaxParts|bmp", "Benchmark max parts, default: 20", &maxParts,
			"benchmarkMaxVariables|bmv", "Benchmark max variables, default: 8", &maxVariables,
			"benchmarkMaxTests|bmt", "Benchmark max tests, default: 20", &maxTests,
			"benchmarkDataIterations|bmi", "Number of iterations to create benchmark data for, default: 1", &benchmarkDataIterations,
			"benchmarkTitleAppend|bma", "Append title of benchmark test set", &benchmarkAppendTitle,

			// benchmarker stuff
			
			"run", "Runs the benchmark and load file", &runBenchmark,
			"benchmarkLoad|brl", "Adds a router implementation to benchmark, default: all", &benchmarkerToLoad,
			"benchmarkIterations|bri", "Number of iterations to run benchmark for, default: 10", &benchmarkIterations,
			"benchmarkOutputMean|brom", "Output benchmark results mean", &benchmarkOutputMean,
			"benchmarkOutputAll|broa", "Output benchmark results", &benchmarkOutputAll,
			
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
		
		if (benchmarkOutputAll !is null) {
			string benchmarkOutputAllBase = rootName(benchmarkOutputAll);
			if (exists(benchmarkOutputAllBase)) {
				if (isDir(benchmarkOutputAllBase)) {
				} else {
					remove(benchmarkOutputAllBase);
					mkdirRecurse(benchmarkOutputAllBase);
				}
			} else {
				mkdirRecurse(benchmarkOutputAllBase);
			}
			
			if (exists(benchmarkOutputAll))
				write(benchmarkOutputMean, "_ (UA)List (UI)List (UA)Tree (UI)Tree (UA)Regex (UI)Regex (OA)List (OI)List (OA)Tree (OI)Tree (OA)Regex (OI)Regex\n");
		}
		
		if (benchmarkOutputMean !is null) {
			string benchmarkOutputMeanBase = rootName(benchmarkOutputMean);
			if (exists(benchmarkOutputMeanBase)) {
				if (isDir(benchmarkOutputMeanBase)) {
				} else {
					remove(benchmarkOutputMeanBase);
					mkdirRecurse(benchmarkOutputMeanBase);
				}
			} else {
				mkdirRecurse(benchmarkOutputMeanBase);
			}
			
			if (exists(benchmarkOutputMean))
				write(benchmarkOutputMean, "_ (UA)List (UI)List (UA)Tree (UI)Tree (UA)Regex (UI)Regex (OA)List (OI)List (OA)Tree (OI)Tree (OA)Regex (OI)Regex\n");
		}


		if (benchmarkAppendTitle !is null) {
			string benchmarkAppendTitleBase = rootName(benchmarkAppendTitle);
			if (exists(benchmarkAppendTitleBase)) {
				if (isDir(benchmarkAppendTitleBase)) {
				} else {
					remove(benchmarkAppendTitleBase);
					mkdirRecurse(benchmarkAppendTitleBase);
				}
			} else {
				mkdirRecurse(benchmarkAppendTitleBase);
			}
			
			/+if (exists(benchmarkAppendTitle))
			 write(benchmarkAppendTitle, "\n");+/
		}

	} catch (Exception e) {
		writeln("Failed to cleanup/create the benchmark+output directory.");
		
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

		if (benchmarkAppendTitle !is null && !exists(buildPath(benchmarkDirectory, benchmarkOutput))) {
			append(buildPath(benchmarkDirectory, benchmarkAppendTitle), format("%s\tMax (Entries %d Parts %d Variables %d Tests %d)\n", benchmarkOutput, maxEntries, maxParts, maxVariables, maxTests));
		}

		foreach(i; 0 .. benchmarkDataIterations) {
			createAllBenchmarks(benchmarkDirectory, maxEntries, maxParts, maxVariables, maxTests, benchmarkOutput);
		}
		
		if (verboseMode) {
			writeln(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;");
			writeln(";         Benchmark generation          ;");
			writeln(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;");
		}
	}
	
	if (runBenchmark !is null) {
		if (verboseMode) {
			writeln(":::::::::::::::::::::::::::::::::::::::::");
			writeln(":           Benchmark runner            :");
			writeln(":::::::::::::::::::::::::::::::::::::::::");
		}
		
		loadedBenchmarkFiles.length = 1;
		benchmarkFilesCSR.length = 1;
		
		string toload = runBenchmark;
		size_t currentFileToLoad;

		foreach(string file; dirEntries(dirName(toload), baseName(toload), SpanMode.depth)) {
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
		
		if (verboseMode) {
			writeln("-----:::::::");
			writeln("     creating routers");
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
					version(release) {
						benchmarker.registerRouterImplementation!DumbRegexRouter;
					} else {
						if (verboseMode) {
							writeln("Not including regex router, it is too slow in non-release builds.");
						}
					}
					break;
			}
		}
		if (verboseMode) {
			writeln("-----;;;;;;;");
		}
		
		if (verboseMode) {
			writeln("-----:::::::");
			writeln("     adding tests");
		}
		loadBenchmarkerWithTests(&benchmarker, benchmarkFilesCSR);
		if (verboseMode) {
			writeln("-----;;;;;;;");
		}
		
		if (verboseMode) {
			writeln("-----:::::::");
			writeln("     setting up routers to benchmark");
		}
		benchmarker.setup();
		if (verboseMode) {
			writeln("-----;;;;;;;");
		}
		
		char[32] rfbuffer;
		
		if (verboseMode) {
			writeln("-----:::::::");
			writeln("     benchmarking");
		}
		auto results = benchmarker.perform(benchmarkIterations);
		if (verboseMode) {
			writeln("-----;;;;;;;");
		}
		
		auto meanAppender = appender!string();
		auto allAppender = appender!string();

		if (benchmarkOutputMean !is null) {
			meanAppender ~= runBenchmark;
			meanAppender ~= " ";

			foreach(ref ur; results.unoptimized) {
				long t1 = ur.average.total!"usecs";
				long t2 = (ur.average / results.numberOfTests).total!"usecs";
				meanAppender ~= sformat(rfbuffer, "%d %d ", t1, t2);
			}

			foreach(ref or; results.optimized) {
				long t1 = or.average.total!"usecs";
				long t2 = (or.average / results.numberOfTests).total!"usecs";
				meanAppender ~= sformat(rfbuffer, "%d %d ", t1, t2);
			}

			meanAppender ~= '\n';
			append(buildPath(benchmarkDirectory, benchmarkOutputMean), meanAppender.data);
		}
		
		if (benchmarkOutputAll !is null) {
			meanAppender ~= runBenchmark;
			meanAppender ~= " ";

			foreach(i; 0 .. benchmarkIterations) {
				foreach(ref ur; results.unoptimized) {
					auto diff = ur.timeItTook[i];
					long t1 = diff.total!"usecs";
					long t2 = (diff / results.numberOfTests).total!"usecs";
					allAppender ~= sformat(rfbuffer, "%d %d ", t1, t2);
				}
				
				foreach(ref or; results.optimized) {
					auto diff = or.timeItTook[i];
					long t1 = diff.total!"usecs";
					long t2 = (diff / results.numberOfTests).total!"usecs";
					allAppender ~= sformat(rfbuffer, "%d %d ", t1, t2);
				}

				allAppender ~= '\n';
			}

			append(buildPath(benchmarkDirectory, benchmarkOutputAll), allAppender.data);
		}
		
		if (verboseMode) {
			writeln(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;");
			writeln(";           Benchmark runner            ;");
			writeln(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;");
		}
	}
}

void createAllBenchmarks(string directory, uint maxEntries, uint maxParts, uint maxVariables, uint maxTests, string benchmarkOutput) {
	import core.memory : GC;
	import std.stdio;
	
	benchmarkOutput = buildPath(directory, benchmarkOutput);
	
	if (verboseMode) {
		writeln("filename(\"", benchmarkOutput, "\")");
	}
	
	createAndStoreBenchmark(benchmarkOutput, maxEntries, maxParts, maxVariables, maxTests);
	
	// Do you like OOM errors? Because I certainly don't...
	// this doesn't exactly fix the issue,
	// but for middle sized data sets with in use by lower teir processors (32bit/low RAM)
	// it can help greatly.
	GC.collect;
}

void createAndStoreBenchmark(string filename, uint maxEntries, uint maxParts, uint maxVariables, uint maxTests) {
	import std.file : append;
	
	auto got = createBenchMarks(maxEntries, maxParts, maxVariables, maxTests);
	
	if (verboseMode) {
		writeln("\t", "route(specifications(", got.items.length, "), tests(", got.allRequests.length, "))");
		writeln("\t", "websites(", got.allWebsites.length, ")");
	}
	
	append(filename, createBenchmarkCSUF(got));
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
	F2: foreach(ref entry; dataset.entries) {
			IWebSite website = new DummyWebSite([
					WebsiteAddress("foo.bar", WebSiteAddressPort(80)),
					WebsiteAddress("foo.bar", WebSiteAddressPort(443), true, true)]);
			
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
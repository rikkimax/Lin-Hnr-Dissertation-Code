import std.file : write;
import std.array : appender;

auto output = appender!(char[])();

void main() {
	output.reserve(1024 * 1024 * 8);	

	version(Bash) {
		/* */

		output ~= "### This file is generated from create_script.d ###\n";
		output ~= "###              Do not run.                    ###\n";
		output ~= "###              Do not modify.                 ###\n";
		output ~= '\n';
		output ~= "# Performs cleanup from previous sets\n";
		output ~= "rm -rf benchmarks\n";
		output ~= "mkdir benchmarks\n";
		output ~= '\n';

		output ~= "## Creation logic goes here ##\n";
		output ~= '\n';
	} else version(Batch) {}

	logic_create();
	
	version(Bash) {
		write("create.sh", output.data);
	} else version(Batch) {
		write("create.bat", output.data);
	}

	/* */

	output.clear();

	/* */
	
	output ~= "### This file is generated from create_script.d ###\n";
        output ~= "###              Do not run.                    ###\n";
        output ~= "###              Do not modify.                 ###\n";
        output ~= '\n';

	output ~= "## Run logic goes here ##\n";
	output ~= '\n';
	logic_run();

	write("run.sh", output.data);

	/* */
}

void outputCreateCommand(uint testId, uint testSitesId, uint maxEntries, uint maxParts, uint maxVariables, uint maxTests) {
	import std.format : sformat;

	// $ ./code --bg --bme 10 --bmp 10 --bmv 10 --bmt 10 --bo test_1.csuf --bma titles.txt
	
	char[1024] buffer;
	version(Bash) {
		output ~= buffer[].sformat("./code_data --bg --bme %d --bmp %d --bmv %d --bmt %d --bmi %d --bo set_%d_sites_%d.csuf --bma titles.txt",
			maxEntries, maxParts, maxVariables, maxTests, testSitesId,
			testId, testSitesId);
	} else version(Batch) {
		output ~= buffer[].sformat("code_data --bg --bme %d --bmp %d --bmv %d --bmt %d --bmi %d --bo set_%d_sites_%d.csuf --bma titles.txt",
			maxEntries, maxParts, maxVariables, maxTests, testSitesId,
			testId, testSitesId);

	}
	output ~= '\n';
}

void outputRunCommand(uint testId, uint testSitesId, uint maxEntries, uint maxParts, uint maxVariables, uint maxTests, uint iteration) {
	import std.format : sformat;

	// $ ./code --run --brom mean.csv --broa set_%d_sites_%d_result.csv --load benchmarks/set_%d_sites_%d.csuf
	
	char[1024] buffer;
	version(Bash) {
		output ~= buffer[].sformat("./code_data --run --brom mean.csv --bri %d --broa set_%d_sites_%d_iterations_%d_result.csv --load benchmarks/set_%d_sites_%d.csuf",
			iteration,
			testId, testSitesId, iteration,
			testId, testSitesId);
	} else version(Batch) {
		output ~= buffer[].sformat("code_data --run --brom mean.csv --bri %d --broa set_%d_sites_%d_iterations_%d_result.csv --load benchmarks/set_%d_sites_%d.csuf",
			iteration,
			testId, testSitesId, iteration,
			testId, testSitesId);

	}
	output ~= '\n';
}

static {
	uint[]
		EntriesArray   = [10, 20, 50, 100, 200, 1000, 10_000, 100_000/+, 200_000, 1_000_000+/],
		PartsArray     = [5,  10, 20, 30],
		VariablesArray = [4,  10, 20],
		TestsArray     = [4,  10, 20],
		TestsSiteCount = [1,  2,  3,  5,   10,  20,   30,     100,   /+200,     300,     500, 1_000+/],
		Iterations     = [1,  10, 100,     1_000]
	;
}

void logic_create() {
	// is responsible for creating the benchmarks/*.csuf files

	uint testId;
	foreach(entry; EntriesArray) {
		foreach(part; PartsArray) {
			foreach(var; VariablesArray) {
				foreach(test; TestsArray) {
					foreach(siteCount; TestsSiteCount) {
						outputCreateCommand(testId, siteCount, entry, part, var, test);
					}
					testId++;
				}
			}
		}
	}
}

void logic_run() {
	// is responsible running the benchmarker upon the benchmarks/*.csuf files
	//  and sending that off to the required analysis engine
	
	uint testId;
	foreach(entry; EntriesArray) {
		foreach(part; PartsArray) {
			foreach(var; VariablesArray) {
				foreach(test; TestsArray) {
					foreach(siteCount; TestsSiteCount) {
						foreach(iteration; Iterations) {
							outputRunCommand(testId, siteCount, entry, part, var, test, iteration);
						}
					}
					testId++;
				}
			}
		}
	}
}

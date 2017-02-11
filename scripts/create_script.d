import std.file : write;
import std.array : appender;

auto output = appender!(char[])();

void main() {
	output.reserve(1024 * 1024 * 8);	

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
	logic_create();

	write("create.sh", output.data);

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

	// $ ./code --bg --bme 10 --bmp 10 --bmv 10 --bmt 10 --bo test_1.csuf
	
	char[1024] buffer;
	output ~= buffer[].sformat("./code --bg --bme %d --bmp %d --bmv %d --bmt %d --bo set_%d_sites_%d.csuf",
					maxEntries, maxParts, maxVariables, maxTests, testId, testSitesId);
	output ~= '\n';
}

static {
	uint[]
		EntriesArray   = [10, 20, 50, 100, 200, 1000, 10_000, 100_000, 200_000, 1_000_000],
		PartsArray     = [5,  10, 20, 30],
		VariablesArray = [4,  10, 20],
		TestsArray     = [4,  10, 20],
		TestsSiteCount = [1,  2,  3,  5,   10,  20,   30,     100,     200,     300,     500, 1_000]
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
						foreach(_; 0 .. siteCount) {
							outputCreateCommand(testId, siteCount, entry, part, var, test);
						}
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
	
	
}

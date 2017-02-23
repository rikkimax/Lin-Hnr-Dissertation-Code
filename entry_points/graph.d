void main() {
	import std.stdio : File;
	import std.string : split;

	generateGraph("benchmarks/mean.csv", "Mean");

	foreach(line; File("benchmarks/titles.txt", "r").byLine) {
		if (line is null)
			continue;

		string[] parts = cast(string[])line.split('\t');
		if (parts.length != 2)
			continue;

		generateGraph(parts[0], parts[1]);
	}
}

void generateGraph(string filename, string title) {
	import std.process : pipeProcess, wait;
	auto pipes = pipeProcess(["gnuplot/bin/gnuplot"]);

	pipes.stdin.write(`
set encoding utf8
set terminal png with size 800, 600

set xlabel "Router"
set ylabel "Micro Seconds"

set style data histogram
set style histogram clustered
`);

	pipes.stdin.writeln(`set title "` ~ title ~ `"`);
	pipes.stdin.writeln(`set output "` ~ filename ~ `_graph.png"`);
	pipes.stdin.write(`for [COL=2:5:1] '` ~ filename ~ `' using COL:xticlabels(1) title columnheader'`);
}


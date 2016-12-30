import std.stdio;
import webrouters.benchmark;

void main() {
	writeln(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;");
	auto got = createBenchMarks(10_000_000, 20, 8, 20);
	write(got);
	writeln(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;");
}

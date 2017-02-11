module webrouters.benchmarker;
import webrouters.defs;

struct Benchmarker {
	private {
		string[] routerNames, routerNamesOptimized;
		IRouter delegate()[] routerCreators, routerCreatorsOptimized;

		BenchmarkerTest[] allTests;
		size_t allTestsRealLength;

		IRouter[] routerInstances, routerOptimizedInstances;
	}

	@disable
	this(this);

	void registerRouterImplementation(T : IRouter)() if (__traits(compiles, {string s = T.RouterName;})) {
		routerNames ~= T.RouterName;
		routerCreators ~= () { return new T; };

		static if (is(T : IRouterOptimizable)) {
			routerNamesOptimized ~= T.RouterName;
			routerCreatorsOptimized ~= () { return new T; };
		}
	}

	void registerTest(BenchmarkerTest test) {
		if (allTestsRealLength == allTests.length) {
			allTests.length += 1024;
		}

		allTests[allTestsRealLength] = test;
		allTestsRealLength++;
	}

	void setup() {
		routerInstances.length = routerCreators.length;
		routerOptimizedInstances.length = routerCreatorsOptimized.length;

		foreach(i, rc; routerCreators) {
			routerInstances[i] = rc();
		}

		foreach(i, roc; routerCreatorsOptimized) {
			routerOptimizedInstances[i] = roc();
		}

		void addTests(IRouter router) {
			if (router.maximumNumberRoutes >= allTestsRealLength) {
				foreach(test; allTests[0 .. allTestsRealLength]) {
					router.addRoute(Route(test.website, test.path, test.statuscode, test.requiresSSL));
				}
			}
		}

		foreach(router; routerInstances) {
			addTests(router);
			router.preuse();
		}

		foreach(router; routerOptimizedInstances) {
			addTests(router);
			router.preuse();
			(cast(IRouterOptimizable)router).preuseOptimize();
		}
	}

	BenchmarkResults perform(uint numberOfIterations) {
		BenchmarkResults ret;
		ret.numberOfTests = allTestsRealLength;

		ret.unoptimized.length = routerInstances.length;
		ret.optimized.length = routerOptimizedInstances.length;

		size_t i;
		foreach(uor; routerInstances) {
			if (uor.maximumNumberRoutes >= allTestsRealLength) {
				ret.unoptimized[i].name = routerNames[i];
				ret.unoptimized[i].timeItTook.length = numberOfIterations;
				performTest(uor, numberOfIterations, ret.unoptimized[i]);
				i++;
			} else
				ret.unoptimized.length--;
		}

		i = 0;
		foreach(or; routerOptimizedInstances) {
			if (or.maximumNumberRoutes >= allTestsRealLength) {
				ret.optimized[i].name = routerNamesOptimized[i];
				ret.optimized[i].timeItTook.length = numberOfIterations;
				performTest(or, numberOfIterations, ret.optimized[i]);
				i++;
			} else
				ret.optimized.length--;
		}

		return ret;
	}

	private {
		void performTest(IRouter router, uint numberOfIterations, ref BenchmarkResult result) {
			import std.datetime : Clock;
			import core.time : Duration;

			foreach(i; 0 .. numberOfIterations) {
				auto start = Clock.currTime;

				foreach(j, ref test; allTests[0 .. allTestsRealLength]) {
					RouterRequest request;

					request.hostname = test.website.addresses[0].hostname;
					assert(!test.website.addresses[0].port.isSpecial);
					request.port = test.website.addresses[0].port.value;

					request.path = test.path;
					request.useSSL = test.requiresSSL;

					router.run(request, test.statuscode);
				}

				auto end = Clock.currTime;
				Duration diff = cast(Duration)(end - start);
				result.timeItTook[i] = diff;
				result.average += diff;
			}

			result.average = result.average / numberOfIterations;
		}
	}
}

struct BenchmarkerTest {
	IWebSite website;
	string path;

	string[] tests;

	ushort statuscode;
	bool requiresSSL;
}

struct BenchmarkResults {
	BenchmarkResult[] unoptimized, optimized;
	size_t numberOfTests;
}

struct BenchmarkResult {
	import core.time : Duration;

	string name;
	Duration[] timeItTook;

	Duration average;
}
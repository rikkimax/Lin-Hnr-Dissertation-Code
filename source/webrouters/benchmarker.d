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

		allTests[allTestsRealLength++] = test;
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
			foreach(test; allTests[0 .. allTestsRealLength]) {
				router.addRoute(Route(test.website, test.path, test.statuscode, test.requiresSSL));
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
}

struct BenchmarkerTest {
	IWebSite website;
	string path;

	string[] tests;

	ushort statuscode;
	bool requiresSSL;
}
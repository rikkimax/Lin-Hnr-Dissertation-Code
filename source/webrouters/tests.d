﻿module webrouters.tests;
import webrouters.defs;

T canAdd(T:IRouter)() {
	version(unittest) {
		//static assert(__traits(hasMember, T, "allRoutes"), "The router must provide an allRoutes member with all known routes.");

		T router = new T;
		RouteTest[] tests;

		//router.dummyData_1(tests);
		//router.dummyData_2(tests);
		router.dummyData_3(tests);

		router.preuse;

		foreach(test; tests) {
			auto result = router.run(test.request);

			if (test.willSucceed && result.isNull) {
				import std.stdio;
				writeln(__LINE__, ": ", result);
				writeln(__LINE__, ": ", test);
				assert(0);
			}
		}

		if (IRouterOptimizable o = cast(IRouterOptimizable)router) {
			o.preuseOptimize;
			
			foreach(test; tests) {
				auto result = router.run(test.request);
				
				if (test.willSucceed && result.isNull) {
					import std.stdio;
					writeln(__LINE__, ": ", result);
					writeln(__LINE__, ": ", test);
					assert(0);
				}
			}
		}

		return router;
	} else {
		return null;
	}
}

final class DummyWebSite : IWebSite {
	WebsiteAddress[] values;

	this(WebsiteAddress[] values) {
		this.values = values;
	}

	override const(WebsiteAddress[]) addresses() { return cast(const)values; }
}

private:

struct RouteTest {
	bool willSucceed;

	Route route;
	RouterRequest request;
}

void adder(IRouter router, ref RouteTest[] tests, Route route, RouterRequest request, bool willSucceed=true) {
	router.addRoute(route);
	tests ~= RouteTest(willSucceed, route, request);
}

void dummyData_1(IRouter router, ref RouteTest[] tests) {
	IWebSite website = new DummyWebSite([
		WebsiteAddress("example.com", WebSiteAddressPort(80), true, false),
		WebsiteAddress("example.com", WebSiteAddressPort(443), true, true),
	]);

	router.adder(tests, Route(website, "some/path", 200, false), RouterRequest("example.com", "some/path", 80));
	router.adder(tests, Route(website, "*", 404, false), RouterRequest("example.com", "alt", 80), false);
    router.adder(tests, Route(website, "*", 500, false), RouterRequest("example.com", "alt", 80), false);
	router.adder(tests, Route(website, "abcd", 200, false), RouterRequest("example.com", "abcd", 80));
	router.adder(tests, Route(website, "xyz/*", 500, false), RouterRequest("example.com", "xyz/alt", 80), false);
	router.adder(tests, Route(website, "xyz/d", 200, false), RouterRequest("example.com", "xyz/d", 80));
}

void dummyData_2(IRouter router, ref RouteTest[] tests) {
	router.dummyData_1(tests);

	IWebSite website1 = new DummyWebSite([
		WebsiteAddress("sub.example.com", WebSiteAddressPort(80), true, false),
		WebsiteAddress("sub.example.com", WebSiteAddressPort(443), true, true),
	]);

	IWebSite website2 = new DummyWebSite([
		WebsiteAddress("sub2.example.com", WebSiteAddressPort(80), true, false),
		WebsiteAddress("sub2.example.com", WebSiteAddressPort(443), true, true),
	]);

	router.adder(tests, Route(website1, "some/path", 200, false), RouterRequest("sub.example.com", "some/path", 80));
	router.adder(tests, Route(website1, "*", 200, false), RouterRequest("sub.example.com", "something/val", 80));

	router.adder(tests, Route(website2, "some/path", 200, false), RouterRequest("sub2.example.com", "some/path", 80));
	router.adder(tests, Route(website2, "some/:myvar", 200, false), RouterRequest("sub2.example.com", "some/value_here", 80));
	router.adder(tests, Route(website2, "some/path/*", 200, false), RouterRequest("sub2.example.com", "some/path/goes/through/here", 80));
}

void dummyData_3(IRouter router, ref RouteTest[] tests) {
	router.dummyData_2(tests);

	IWebSite website = new DummyWebSite([
		WebsiteAddress("*.example.com", WebSiteAddressPort(80), true, false),
		WebsiteAddress("*.example.com", WebSiteAddressPort(443), true, true),
	]);

	router.adder(tests, Route(website, "some/path", 200, false), RouterRequest("abc.example.com", "some/path", 80));
	router.adder(tests, Route(website, "some/path/*", 200, false), RouterRequest("abc.example.com", "some/path/here", 80));
	router.adder(tests, Route(website, "*", 404, false), RouterRequest("abc.example.com", "alt", 80), false);
	router.adder(tests, Route(website, "*", 500, false), RouterRequest("abc.example.com", "alt", 80), false);
	router.adder(tests, Route(website, "abcd", 200, false), RouterRequest("abc.example.com", "abcd", 80));
	router.adder(tests, Route(website, "xyz/d", 86, false), RouterRequest("abc.example.com", "xyz/d", 80), false);
	router.adder(tests, Route(website, "xyz/*", 82, false), RouterRequest("abc.example.com", "xyz/e", 80), false);
}

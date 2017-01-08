module webrouters.tests;
import webrouters.defs;

T canAdd(T:IRouter)() {
	version(unittest) {
		//static assert(__traits(hasMember, T, "allRoutes"), "The router must provide an allRoutes member with all known routes.");

		T router = new T;
		RouteTest[] tests;

		//router.dummyData_1(tests);
		//router.dummyData_2(tests);
		router.dummyData_3(tests);

		router.optimize;

		foreach(test; tests) {
			auto result = router.run(test.request);

			if (test.route is Route.init && !test.willSucceed) {
				assert(0);
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

	const(WebsiteAddress[]) addresses() { return cast(const)values; }
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
		WebsiteAddress("example.com"d, WebSiteAddressPort(80), true, false),
		WebsiteAddress("example.com"d, WebSiteAddressPort(443), true, true),
	]);

	router.adder(tests, Route(website, "some/path", 200, false), RouterRequest("example.com", "some/path"));
	router.adder(tests, Route(website, "*", 404, false), RouterRequest("example.com", "alt"), false);
	router.adder(tests, Route(website, "some/path", 200, false), RouterRequest("example.com", "some/path"));
	router.adder(tests, Route(website, "some/path", 200, false), RouterRequest("example.com", "some/path"));
	router.adder(tests, Route(website, "some/path", 200, false), RouterRequest("example.com", "some/path"));
	router.adder(tests, Route(website, "some/path", 200, false), RouterRequest("example.com", "some/path"));

	router.addRoute(Route(website, "some/path/*", 200, false));
	router.addRoute(Route(website, "*", 404, false));
	router.addRoute(Route(website, "*", 500, false));
	router.addRoute(Route(website, "abcd", 200, false));
	router.addRoute(Route(website, "xyz/*", 500, false));
	router.addRoute(Route(website, "xyz/d", 200, false));
}

void dummyData_2(IRouter router, ref RouteTest[] tests) {
	router.dummyData_1(tests);

	IWebSite website1 = new DummyWebSite([
		WebsiteAddress("sub.example.com"d, WebSiteAddressPort(80), true, false),
		WebsiteAddress("sub.example.com"d, WebSiteAddressPort(443), true, true),
	]);

	IWebSite website2 = new DummyWebSite([
		WebsiteAddress("sub2.example.com"d, WebSiteAddressPort(80), true, false),
		WebsiteAddress("sub2.example.com"d, WebSiteAddressPort(443), true, true),
	]);

	router.addRoute(Route(website1, "some/path", 200, false));
	router.addRoute(Route(website1, "*", 200, false));
	router.addRoute(Route(website2, "some/path", 200, false));
	router.addRoute(Route(website2, "some/:var", 200, false));
	router.addRoute(Route(website2, "some/path/*", 200, false));
}

void dummyData_3(IRouter router, ref RouteTest[] tests) {
	router.dummyData_2(tests);

	IWebSite website = new DummyWebSite([
		WebsiteAddress("*.example.com"d, WebSiteAddressPort(80), true, false),
		WebsiteAddress("*.example.com"d, WebSiteAddressPort(443), true, true),
	]);

	router.addRoute(Route(website, "some/path", 200, false));
	router.addRoute(Route(website, "some/path/*", 200, false));
	router.addRoute(Route(website, "*", 404, false));
	router.addRoute(Route(website, "*", 500, false));
	router.addRoute(Route(website, "abcd", 200, false));
	router.addRoute(Route(website, "xyz/d", 86, false));
	router.addRoute(Route(website, "xyz/*", 82, false));
}

module webrouters.tests;
import webrouters.defs;

T canAdd(T:IRouter)() {
	version(unittest) {
		T router = new T;
		router.dummyData_2;
		router.optimize;



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

void dummyData_1(IRouter router) {
	IWebSite website = new DummyWebSite([
		WebsiteAddress("example.com"d, WebSiteAddressPort(80), true, false),
		WebsiteAddress("example.com"d, WebSiteAddressPort(443), true, true),
	]);

	router.addRoute(Route(website, "some/path", 200, false));
	router.addRoute(Route(website, "some/path/*", 200, false));
	router.addRoute(Route(website, "*", 404, false));
	router.addRoute(Route(website, "*", 500, false));
	router.addRoute(Route(website, "abcd", 200, false));
	router.addRoute(Route(website, "xyz/d", 200, false));
	router.addRoute(Route(website, "xyz/*", 500, false));
}

void dummyData_2(IRouter router) {
	router.dummyData_1;

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

void dummyData_3(IRouter router) {
	router.dummyData_2;

	/+router.addRoute(new DummyWebSite([
		WebsiteAddress("*.example.com"d, WebSiteAddressPort(80), true, false),
		WebsiteAddress("*.example.com"d, WebSiteAddressPort(443), true, true),
	]));+/
}

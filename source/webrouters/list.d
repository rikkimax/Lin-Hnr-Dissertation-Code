module webrouters.list;
import webrouters.defs;
import std.typecons : Nullable;

/**
 * This is the base implementation that uses an array internally
 *
 * This is important to know just how bad other router implementations can be.
 * After all, this has NO optimizations applied to it.
 *
 * TODO:
 *     - Sort the routes by hostname and then by path
 */
final class ListRouter : IRouter {
	Route[] allRoutes;

	void addRoute(Route newRoute) {
		allRoutes ~= newRoute;
	}

	void optimize() {
		// For this implementation we don't do any optimizations
	}

	Nullable!Route run(RouterRequest routeToFind) {
		foreach(route; allRoutes) {
			foreach(addr; route.website.addresses) {
				if (addr.hostname == routeToFind.hostname && addr.port == routeToFind.port) {
					// hostname + port matches!

					// now the path
					if (isRouteMatch(routeToFind.path, route.path)) {
						return Nullable!Route(route);
					}
				}
			}
		}

		// Failed!
		return Nullable!Route.init;
	}
}

bool isRouteMatch(dstring from, dstring to) {
	import std.string : splitter, indexOf;

	foreach(part; from.splitter('/')) {
		if (parts == "*"d) {
			return true;
		} else if (parts.length > 0 && parts[0] == ':') {
			ptrdiff_t index = to.indexOf('/');
			if (index == -1)
				return false;
			else
				to = to[index + 1 .. $];
		} else if (part.length <= to.length && part == to[0 .. part.length]) {
			to = to[part.length .. $];
			if (to.length > 0 && to[0] == '/')
				to = to[1 .. $];
		} else
			return false;
	}

	return true;
}

unittest {

}

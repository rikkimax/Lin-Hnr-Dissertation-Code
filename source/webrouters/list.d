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

	/**
	 * In truth this probably won't actually make things any faster
	 * It just shuffles the order up a bit
	 * 
	 * But is required to make things work correctly :/
	 * Otherwise routes will be out of order
	 */
	void optimize() {
		import std.algorithm : multiSort;

		multiSort!(
			"(a.code == 404 || a.code == 500) && b.code == 200",
			"!(a.code == 404 || a.code == 500) && a.code < b.code",
			(Route a, Route b){ return isRouteLess(a.path, b.path); },
			"a.website.addresses < b.website.addresses",
			)(allRoutes);
	}

	Nullable!Route run(RouterRequest routeToFind) {
		return run(routeToFind, true, false);
	}

	Nullable!Route run(RouterRequest routeToFind, bool nextCatchAll, bool useCatchAll) {
		foreach(route; allRoutes) {
			foreach(addr; route.website.addresses) {

				// hostname,
				// port,
				//
				// (non-/require)ssl
				if (addr.hostname == routeToFind.hostname &&
					((!useCatchAll && !addr.port.isSpecial && addr.port.value == routeToFind.port) ||
						(useCatchAll && (addr.port.isSpecial && addr.port.special == WebSiteAddressPort.Special.CatchAll))) &&
					((addr.supportsSSL && routeToFind.useSSL) || (!routeToFind.useSSL) || (addr.requiresSSL && routeToFind.useSSL))) {

					// now the path
					if (isRouteMatch(routeToFind.path, route.path)) {
						return Nullable!Route(route);
					}
				}

			}
		}

		// Failed!
		if (nextCatchAll)
			return run(routeToFind, false, true);
		else
			return Nullable!Route.init;
	}
}

bool isRouteMatch(dstring from, dstring to) {
	import std.algorithm : splitter;
	import std.string : indexOf;

	foreach(part; from.splitter('/')) {
		if (part == "*"d) {
			return true;
		} else if (part.length > 0 && part[0] == ':') {
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

bool isRouteLess(dstring from, dstring to) {
	import std.algorithm : splitter;
	import std.string : indexOf;

	// TRUE= /abc versus /abc/def
	// FALSE= /abc/* versus /abc/def

	dstring from2 = from;

	foreach(part; from.splitter('/')) {
		if (from2.length > part.length)
			from2 = from2[part.length + 1 .. $];
		else
			from2 = from2[part.length .. $];

		if (part == "*"d) {
			return to.indexOf('/') == -1 && ((to.length > 0 && to[0] != '*') || to.length == 0);
		} else if (part.length > 0 && part[0] == ':') {
			ptrdiff_t index = to.indexOf('/');
			if (index == -1) {
				index = to.indexOf('/');
				return index > 0 || (index == -1 && (part < to));
			} else if (to[1] == ':')
				to = to[index + 1 .. $];
			else
				return true;
		} else if (part.length <= to.length && part == to[0 .. part.length]) {
			to = to[part.length .. $];
			if (to.length > 0 && to[0] == '/')
				to = to[1 .. $];
		} else
			return from2 < to;
	}
	
	return from2 < to;
}

unittest {
	import webrouters.tests;
	import std.stdio : writeln;

	ListRouter router = canAdd!ListRouter;
	foreach(route; router.allRoutes) {
		writeln(route);
		foreach(addr; route.website.addresses) {
			writeln("\t", addr.toString);
		}
	}
}

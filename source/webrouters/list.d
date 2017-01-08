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
			isRouteLess,
			isAddressesLess, 
			"a.code < b.code",
			"(!a.requiresSSL && b.requiresSSL) || (a.requiresSSL && b.requiresSSL)"
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

bool isAddressesLess(ref Route a, ref Route b) {
	// should we go first?

	auto from = a.website.addresses;
	auto to = b.website.addresses;

	if (from.length > to.length)
		return false;
	else if (from.length < to.length)
		return true;
	else {
		// same length so lets check if they match

		uint lessPort, morePort;
		uint lessSupportsSSL, moreSupportsSSL;
		uint lessRequiresSSL, moreRequiresSSL;
		uint lessHostname, moreHostname;

		foreach(ref f; from) {
			foreach(ref t; to) {
				if (f.port.isSpecial && t.port.isSpecial) {
					// inaction
				} else if (f.port.isSpecial) {
					lessPort++;
				} else if (t.port.isSpecial) {
					morePort++;
				} else if (f.port.value < t.port.value)
					lessPort++;
				else
					morePort++;

				if (f.supportsSSL && t.supportsSSL) {
					// inaction
				} else if (f.supportsSSL && !t.supportsSSL)
					lessSupportsSSL++;
				else if (!f.supportsSSL && t.supportsSSL)
					moreSupportsSSL++;
				else {
					// inaction
				}

				if (f.requiresSSL && t.requiresSSL) {
					// inaction
				} else if (f.requiresSSL && !t.requiresSSL)
					lessRequiresSSL++;
				else if (!f.requiresSSL && t.requiresSSL)
					moreRequiresSSL++;
				else {
					// inaction
				}

				if (f.hostname == t.hostname) {
					// inaction
				} else if (f.hostname < t.hostname)
					lessHostname++;
				else if (f.hostname > t.hostname)
					moreHostname++;

				if (f.hostname[0] == '*' && t.hostname[0] == '*') {
					//inaction
				} else if (f.hostname[0] == '*')
					moreHostname++;
				else if (t.hostname[0] == '*')
					lessHostname++;
				else {
					// inaction
				}

			}
		}

		return lessPort < morePort &&
			lessRequiresSSL < lessRequiresSSL &&
			lessSupportsSSL < moreSupportsSSL &&
			lessHostname < moreHostname;
	}
}

bool isRouteLess(ref Route a, ref Route b)
out(v) {
	import std.stdio;
	writeln("!! ", v);
	writeln;
} body {
	import std.algorithm : splitter;
	import std.range : zip;
	import std.string : indexOf;

	auto from = a.path;
	auto to = b.path;

	// TRUE= /abc versus /abc/def
	// FALSE= /abc/* versus /abc/def

	if (from == to)
		return false;

	import std.stdio;
	writeln(from, "\t", to);

	if (from[$-1] == '*' && to[$-1] == '*')
		return from.length < to.length;
	else if (from[$-1] == '*')
		return false;
	else if (to[$-1] == '*')
		return true;
	else {
		// inaction
	}

	foreach(parta, partb; zip(from.splitter('/'), to.splitter('/'))) {
		writeln(":: ", parta, "\t", partb);

		if (parta is null) {
			return false;
		} else if (partb is null)
			return true;

		if (from[$-1] == '*' && to[$-1] == '*') {
			return false;
		} else if (parta[0] == ':' || partb[0] == ':') {
			if (parta[0] != ':')
				return false;
		} else if (parta == partb) {
			// do nothing
		} else {
			return false;
		}
	}
	
	return true;
}

unittest {
	import webrouters.tests;
	import std.stdio : writeln;

	ListRouter router = canAdd!ListRouter;
	foreach(route; router.allRoutes) {
		//writeln(route);
		foreach(addr; route.website.addresses) {
			//writeln("\t", addr.toString);
		}
	}
}

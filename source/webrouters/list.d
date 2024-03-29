﻿module webrouters.list;
import webrouters.defs;
import webrouters.util;
import std.typecons : Nullable;

/**
 * This is the base implementation that uses an array internally
 *
 * This is important to know just how bad other router implementations can be.
 * After all, this has NO optimizations applied to it.
 */
class ListRouter : IRouter {
	enum RouterName = "list";

	Route[] allRoutes;

	void addRoute(Route newRoute) {
		if (newRoute.path[0] == '/')
			newRoute.path = newRoute.path[1 .. $];
		allRoutes ~= newRoute;
	}

	/**
	 * In truth this probably won't actually make things any faster
	 * It just shuffles the order up a bit
	 * 
	 * But is required to make things work correctly :/
	 * Otherwise routes will be out of order
	 */
	void preuse() {
		import std.algorithm : multiSort;

		multiSort!(
			isRouteLess,
			isAddressesLess, 
			"a.code < b.code",
			"(!a.requiresSSL && b.requiresSSL) || (a.requiresSSL && b.requiresSSL)"
		)(allRoutes);
	}

	Nullable!Route run(RouterRequest routeToFind, ushort statusCode=200) {
		Route* lastCatchAll, lastRoute;

	F1: foreach(ref route; allRoutes) {
			if (route.code != statusCode)
				continue F1;

			foreach(addr; route.website.addresses) {
				// hostname,
				// port,
				//
				// (non-/require)ssl
				if (isHostnameMatch(addr.hostname, routeToFind.hostname) &&
					((addr.supportsSSL && routeToFind.useSSL) || (!routeToFind.useSSL) || (addr.requiresSSL && routeToFind.useSSL))) {

					// now the path
					if (isRouteMatch(route.path, routeToFind.path)) {
						if (!addr.port.isSpecial && addr.port.value == routeToFind.port) {
							lastRoute = &route;
						} else if (addr.port.isSpecial && addr.port.special == WebSiteAddressPort.Special.CatchAll) {
							lastCatchAll = &route;
						} else {
						}
						continue F1;
					} else if (lastRoute !is null) {
						// early break out, cos its costly to keep it going after we've hit ours
						break F1;
					} else {
					}
				}
			}
		}

		if (lastRoute !is null && ((lastCatchAll !is null && lastCatchAll < lastRoute) || lastCatchAll is null)) {
			return Nullable!Route(*lastRoute);
		} else if (lastCatchAll !is null) {
			return Nullable!Route(*lastCatchAll);
		} else {
			// Failed!
			return Nullable!Route.init;
		}
	}
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

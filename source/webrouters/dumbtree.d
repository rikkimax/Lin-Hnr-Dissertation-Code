module webrouters.dumbtree;
import webrouters.defs;
import std.typecons : Nullable;

/**
 *
 */
final class DumbTreeRouter : IRouter {
	DumbTreeRoot[] roots;

	this() {}

	void addRoute(Route newRoute) {
		import std.algorithm : splitter;
		import std.string : indexOf;

		Nullable!DumbTreeElement* parent, parentInit;

		// we need to determine which root we are talking about
		// keep in mind we don't attempt to "merge" websites

		foreach(ref root; roots) {
			if (root.website == newRoute.website) {
				parent = &root.root;
			}
		}

		if (parent is null) {
			roots.length++;
			roots[$-1].root = DumbTreeElement();
			roots[$-1].website = newRoute.website;
			parent = &roots[$-1].root;
		}

		parentInit = parent;

		foreach(part; newRoute.path.splitter('/')) {
			if (part == "*"d) {
				// ok we're at an end
				assert(parent.catchAllEndRoute.isNull);
				parent.catchAllEndRoute = Nullable!Route(newRoute);
				return;
			} else if (part.length > 0 && part[0] == ':') {
				if (parent.variableRoute is null) {
					parent.variableRoute = new Nullable!DumbTreeElement(DumbTreeElement());
					parent = parent.variableRoute;
				} else {
					parent = parent.variableRoute;
				}
			} else {
				foreach(ref child; parent.children) {
					if (child.constant == part) {
						parent = &child;
						continue;
					}
				}

				parent.children ~= Nullable!DumbTreeElement(DumbTreeElement());
				parent = &parent.children[$-1];
			}
		}

		if (parent !is parentInit) {
			parent.endRoute = newRoute;
		}
	}

	void optimize() {}

	Nullable!Route run(RouterRequest routeToFind) {
		import std.algorithm : splitter;
		Nullable!DumbTreeElement* parent, parentCatchAll;
		Nullable!Route lastCatchAll;
		auto pathLeft = routeToFind.path.splitter("/"d);

		foreach(ref root; roots) {
			foreach(addr; root.website.addresses) {
				
				// hostname,
				// port,
				//
				// (non-/require)ssl
				if (addr.hostname == routeToFind.hostname &&
					((addr.supportsSSL && routeToFind.useSSL) || (!routeToFind.useSSL) || (addr.requiresSSL && routeToFind.useSSL))) {

					if (!addr.port.isSpecial && addr.port.value == routeToFind.port) {
						parent = &root.root;
					} else if (addr.port.isSpecial && addr.port.special == WebSiteAddressPort.Special.CatchAll) {
						parentCatchAll = &root.root;
					}
				}
			}
		}

		if (parent is null && parentCatchAll is null) {
			// not valid website
			return Nullable!Route.init;
		} else if (parent is null) {
			parent = parentCatchAll;
		}

		bool didLastContinue;
	L1: do {
			didLastContinue = false;

			foreach(ref child; parent.children) {
				if (child.constant == pathLeft.front) {
					parent = &child;
					pathLeft.popFront;
					didLastContinue = true;
					continue L1;
				}
			}

			// if we didn't hit a constant that matches us
			// assume its a variable or catch all

			if (parent.variableRoute !is null) {
				parent = parent.variableRoute;
				pathLeft.popFront;

				if (!parent.catchAllEndRoute.isNull) {
					lastCatchAll = parent.catchAllEndRoute;
				}

				didLastContinue = true;
				continue L1;
			}

			if (!parent.catchAllEndRoute.isNull) {
				return parent.catchAllEndRoute;
			}

			if (!didLastContinue) {
				if (!lastCatchAll.isNull) {
					return lastCatchAll;
				} else {
					break;
				}
			}

		} while(!pathLeft.empty);

		// Failed!
		return Nullable!Route.init;
	}
}

private {
	struct DumbTreeRoot {
		IWebSite website;
		Nullable!DumbTreeElement root;
	}

	struct DumbTreeElement {
		dstring constant;
		Nullable!Route endRoute;
		Nullable!Route catchAllEndRoute;

		Nullable!DumbTreeElement* variableRoute;
		Nullable!DumbTreeElement[] children;
	}

	unittest {
		import webrouters.tests;
		import std.stdio : writeln;
		
		DumbTreeRouter router = canAdd!DumbTreeRouter;
	}
}
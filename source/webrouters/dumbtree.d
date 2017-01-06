module webrouters.dumbtree;
import webrouters.defs;
import std.typecons : Nullable;

/**
 *
 */
final class DumbTreeRouter : IRouter {
	Nullable!DumbTreeElement root;

	this() {
		root = DumbTreeElement();
	}

	void addRoute(Route newRoute) {
		import std.algorithm : splitter;
		import std.string : indexOf;

		Nullable!DumbTreeElement* parent = &root;

		foreach(part; newRoute.path.splitter('/')) {
			if (part == "*"d) {
				// ok we're at an end
				assert(parent.catchAllEndRoute.isNull);
				parent.catchAllEndRoute = newRoute;
				return;
			} else if (part.length > 0 && part[0] == ':') {
				if (parent.variableRoute is null) {
					parent.variableRoute = new Nullable!DumbTreeElement();
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

				parent.children.length++;
				parent = &parent.children[$-1];
			}
		}

		if (parent !is &root) {
			parent.endRoute = newRoute;
		}
	}

	void optimize() {}

	Nullable!Route run(RouterRequest routeToFind) {
		return run(routeToFind, true, false);
	}
	
	Nullable!Route run(RouterRequest routeToFind, bool nextCatchAll, bool useCatchAll) {
		// Failed!
		if (nextCatchAll)
			return run(routeToFind, false, true);
		else
			return Nullable!Route.init;
	}
}

private {
	struct DumbTreeElement {
		dstring constant;
		Nullable!Route endRoute;
		Nullable!Route catchAllEndRoute;

		Nullable!DumbTreeElement* variableRoute;
		Nullable!DumbTreeElement[] children;
	}
}
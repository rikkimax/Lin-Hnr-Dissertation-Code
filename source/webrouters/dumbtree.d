module webrouters.dumbtree;
import webrouters.defs;
import std.typecons : Nullable;

/**
 *
 */
final class DumbTreeRouter : IRouter {
	Nullable!DumbTreeElement root;

	this() {
		root = Nullable!DumbTreeElement(DumbTreeElement());
	}

	void addRoute(Route newRoute) {
		import std.algorithm : splitter;
		import std.string : indexOf;

		Nullable!DumbTreeElement* parent = &root;

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

		if (parent !is &root) {
			parent.endRoute = newRoute;
		}
	}

	void optimize() {}

	Nullable!Route run(RouterRequest routeToFind) {
		import std.algorithm : splitter;
		Nullable!DumbTreeElement* parent = &root;
		Nullable!Route lastCatchAll;
		auto pathLeft = routeToFind.path.splitter("/"d);

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
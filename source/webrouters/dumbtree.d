module webrouters.dumbtree;
import webrouters.defs;
import std.typecons : Nullable;

/**
 *
 */
class DumbTreeRouter : IRouter {
	size_t totalNumberOfElements;
	DumbTreeRoot[] roots;
	
	this() {}
	
	void addRoute(Route newRoute) {
		import std.algorithm : splitter;
		import std.string : indexOf;
		
		Nullable!DumbTreeElement* parent, parentInit;
		
		// we need to determine which root we are talking about
		// keep in mind we don't attempt to "merge" websites
		
		foreach(ref root; roots) {
			if (root.website == newRoute.website && root.statusCode == newRoute.code) {
				parent = &root.root;
			}
		}
		
		if (parent is null) {
			roots.length++;
			roots[$-1].root = DumbTreeElement();
			roots[$-1].statusCode = newRoute.code;
			roots[$-1].website = newRoute.website;
			parent = &roots[$-1].root;
			totalNumberOfElements++;
		}
		
		parentInit = parent;
		
	F1: foreach(part; newRoute.path.splitter('/')) {
			if (part == "*"d) {
				// ok we're at an end
				assert(parent.catchAllEndRoute.isNull);
				parent.catchAllEndRoute = Nullable!Route(newRoute);
				totalNumberOfElements++;
				return;
			} else if (part.length > 0 && part[0] == ':') {
				if (parent.variableRoute is null) {
					parent.variableRoute = new Nullable!DumbTreeElement(DumbTreeElement());
					parent = parent.variableRoute;
					totalNumberOfElements++;
				} else {
					parent = parent.variableRoute;
				}
			} else {
				foreach(ref child; parent.children) {
					if (child.constant == part) {
						parent = &child;
						continue F1;
					}
				}
				
				parent.children ~= Nullable!DumbTreeElement(DumbTreeElement());
				parent = &parent.children[$-1];
				parent.constant = part;
				totalNumberOfElements++;
			}
		}
		
		if (parent !is parentInit) {
			parent.endRoute = newRoute;
		}
	}
	
	void optimize() {}
	
	Nullable!Route run(RouterRequest routeToFind, ushort toFindStatusCode=200) {
		import std.algorithm : splitter;
		import webrouters.list : isHostnameMatch;
		
		Nullable!DumbTreeElement* parent, parentCatchAll, parentCatchAll2;
		Nullable!Route* lastCatchAll, lastRoute;
		auto pathLeft = routeToFind.path.splitter("/"d);
		auto pathLeftCatchAll = pathLeft;

	F1: foreach(ref root; roots) {
			if (root.statusCode == toFindStatusCode) {
				foreach(addr; root.website.addresses) {
					
					// hostname,
					// port,
					//
					// (non-/require)ssl
					if (isHostnameMatch(addr.hostname, routeToFind.hostname) &&
						((addr.supportsSSL && routeToFind.useSSL) || (!routeToFind.useSSL) || (addr.requiresSSL && routeToFind.useSSL))) {
						
						if (!addr.port.isSpecial && addr.port.value == routeToFind.port) {
							parent = &root.root;
							break F1;
						} else if (addr.port.isSpecial && addr.port.special == WebSiteAddressPort.Special.CatchAll) {
							parentCatchAll = &root.root;
							break F1;
						}
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

		do {
			bool wasHandled;

			if (parent !is null) {
				if (processARun(parent, parentCatchAll, pathLeft,
						lastRoute, lastCatchAll,
						routeToFind, toFindStatusCode)) {
					// we hit a constant route, yay!
					wasHandled = true;
				}
			}

			if (parentCatchAll !is null) {
				pathLeftCatchAll = pathLeft.save;
				if (processARun(parentCatchAll, parentCatchAll2, pathLeftCatchAll,
							lastRoute, lastCatchAll,
							routeToFind, toFindStatusCode)) {
					parent = parentCatchAll;
					parentCatchAll = parentCatchAll2;
					pathLeft = pathLeftCatchAll;

					// handles a variable parent
					wasHandled = true;
				}
			}

			if (!wasHandled) {
				break;
			}
		} while (parent !is null && !pathLeft.empty);
		
		if (lastRoute !is null && ((lastCatchAll !is null && lastCatchAll < lastRoute) || lastCatchAll is null)) {
			return Nullable!Route(*lastRoute);
		} else if (lastCatchAll !is null) {
			return Nullable!Route(*lastCatchAll);
		} else {
			// Failed!
			return Nullable!Route.init;
		}
	}
	
	bool processARun(T)(ref Nullable!DumbTreeElement* parent, ref Nullable!DumbTreeElement* nextVariable, ref T source,
		ref Nullable!Route* endRoute, ref Nullable!Route* catchAllRoute, 
		ref RouterRequest routeToFind, ushort toFindStatusCode) {

		bool somethingHasChanged;
		Nullable!DumbTreeElement* nextParent = parent;
		do {
			bool altered, alteredCatchAll;

			// you can't be empty for variables path parts of constants ;)
			if (!source.empty) {
			F2: foreach(ref child; parent.children) {
					if (child.constant == source.front) {
						altered = true;
						nextParent = &child;

						if (!child.endRoute.isNull) {
							endRoute = &child.endRoute;
						}

						break F2;
					}
				}

				if (parent.variableRoute !is null) {
					alteredCatchAll = true;
					nextVariable = parent.variableRoute;
					if (!nextVariable.endRoute.isNull) {
						catchAllRoute = &nextVariable.endRoute;
					}
				}
			}

			if (!parent.catchAllEndRoute.isNull) {
				alteredCatchAll = true;
				catchAllRoute = &parent.catchAllEndRoute;
			}

			if (alteredCatchAll) {
				// a catch all was set (thats ok then).
				somethingHasChanged = true;

				if (!source.empty) {
					source.popFront;
				} else {
					source = T.init;
				}
			}

			if (altered) {
				if (!source.empty) {
					source.popFront;
				} else {
					source = T.init;
				}
				parent = nextParent;
				somethingHasChanged = true;
			} else {
				// nothing happend
				return somethingHasChanged;
			}

		} while(parent !is null);

		return somethingHasChanged;
	}
}

private {
	struct DumbTreeRoot {
		IWebSite website;
		int statusCode;
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
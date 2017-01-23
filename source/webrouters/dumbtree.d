module webrouters.dumbtree;
import webrouters.defs;
import webrouters.util;
import std.typecons : Nullable;

/**
 *
 */
class DumbTreeRouter : IRouter, IRouterOptimizable {
	size_t totalNumberOfElements, depthOfElements;
	DumbTreeRoot[] unoptimizedRoots, optimizedRoots;
	Nullable!DumbTreeElement[] optimizedElements;
	Nullable!DumbTreeElement*[] optimizedDepthElements;
	size_t[] optimizedDepthElementProperty;
	bool sinceLastOptimizationHaveAdded;
	
	this() {}
	
	void addRoute(Route newRoute) {
		import std.algorithm : splitter;
		import std.string : indexOf;
		
		Nullable!DumbTreeElement* parent, parentInit;
		
		// we need to determine which root we are talking about
		// keep in mind we don't attempt to "merge" websites
		
		foreach(ref root; unoptimizedRoots) {
			if (root.website == newRoute.website && root.statusCode == newRoute.code) {
				parent = &root.root;
			}
		}
		
		if (parent is null) {
			unoptimizedRoots.length++;
			unoptimizedRoots[$-1].root = DumbTreeElement();
			unoptimizedRoots[$-1].statusCode = newRoute.code;
			unoptimizedRoots[$-1].website = newRoute.website;
			parent = &unoptimizedRoots[$-1].root;
			totalNumberOfElements++;
		}
		
		parentInit = parent;
		size_t depthOfElement;

	F1: foreach(part; newRoute.path.splitter('/')) {
			if (part == "*") {
				// ok we're at an end
				assert(parent.catchAllEndRoute.isNull);
				parent.catchAllEndRoute = Nullable!Route(newRoute);
				totalNumberOfElements++;
				depthOfElement++;
				return;
			} else if (part.length > 0 && part[0] == ':') {
				if (parent.variableRoute is null) {
					parent.variableRoute = new Nullable!DumbTreeElement(DumbTreeElement());
					parent = parent.variableRoute;
					totalNumberOfElements++;
					depthOfElement++;
				} else {
					parent = parent.variableRoute;
					depthOfElement++;
				}
			} else {
				foreach(ref child; parent.children) {
					if (child.constant == part) {
						parent = &child;
						depthOfElement++;
						continue F1;
					}
				}
				
				parent.children ~= Nullable!DumbTreeElement(DumbTreeElement());
				parent = &parent.children[$-1];
				parent.constant = part;
				totalNumberOfElements++;
				depthOfElement++;
			}
		}
		
		if (parent !is parentInit) {
			if (depthOfElement > depthOfElements)
				depthOfElements = depthOfElement;

			sinceLastOptimizationHaveAdded = true;
			parent.endRoute = newRoute;
		}
	}
	
	void preuse() {}

	void preuseOptimize() {
		if (sinceLastOptimizationHaveAdded) {
			sinceLastOptimizationHaveAdded = false;

			optimizedRoots.length = unoptimizedRoots.length;
			optimizedRoots[] = DumbTreeRoot.init;
			optimizedElements.length = totalNumberOfElements + 1; // +1 #lazy
			optimizedElements[] = Nullable!DumbTreeElement.init;
			optimizedDepthElements.length = (depthOfElements * 2) + 2; // +1 #lazy
			optimizedDepthElementProperty.length = depthOfElements + 1; // +1 #lazy

			DumbTreeRoot* currentRoot;
			Nullable!DumbTreeElement*[] oldRootDepthElement, newRootDepthElement;
			size_t offsetIntoOptimizedElements;
			ptrdiff_t realLengthOfDepthElements;
			oldRootDepthElement = optimizedDepthElements[0 .. depthOfElements + 1];
			newRootDepthElement = optimizedDepthElements[depthOfElements + 1 .. $];

			foreach(i, ref oldRoot; unoptimizedRoots) {
				currentRoot = &optimizedRoots[i];
				currentRoot.website = oldRoot.website;
				currentRoot.statusCode = oldRoot.statusCode;
				currentRoot.root = Nullable!DumbTreeElement(DumbTreeElement.init);

				oldRootDepthElement[0] = &oldRoot.root;
				newRootDepthElement[0] = &currentRoot.root;
				optimizedDepthElementProperty[0] = 0;
				realLengthOfDepthElements = 0;

				Nullable!DumbTreeElement* oldParent, newParent, oldChild, newChild;
				do {
					oldParent = oldRootDepthElement[realLengthOfDepthElements];
					newParent = newRootDepthElement[realLengthOfDepthElements];
					size_t currentProperty = optimizedDepthElementProperty[realLengthOfDepthElements];
					size_t realLengthOfDepthElementsT = realLengthOfDepthElements;

					if (currentProperty == 0) {
						// handles:
						//  - constant
						//  - endRoute
						//  - catchAllEndRoute
						//  - variableRoute

						if (oldParent.children.length > 0) {
							// we copy the children array now to keep locality + so we don't have to deal with it later
							newParent.children = optimizedElements[offsetIntoOptimizedElements .. offsetIntoOptimizedElements + oldParent.children.length];
							offsetIntoOptimizedElements += oldParent.children.length;
						}

						// TODO: umm shouldn't we copy this into a new buffer?!!!!!!
						// especially for string reuse in mind
						newParent.constant = oldParent.constant;
						// nothing to do here
						newParent.endRoute = oldParent.endRoute;
						// nothing to do here
						newParent.catchAllEndRoute = oldParent.catchAllEndRoute;

						oldChild = oldParent.variableRoute;
						if (oldChild !is null && !oldChild.isNull) {
							newParent.variableRoute = &optimizedElements[offsetIntoOptimizedElements];
							*newParent.variableRoute = Nullable!DumbTreeElement(DumbTreeElement.init);
							newChild = newParent.variableRoute;
							offsetIntoOptimizedElements++;

							realLengthOfDepthElements++;
							oldRootDepthElement[realLengthOfDepthElements] = oldChild;
							newRootDepthElement[realLengthOfDepthElements] = newChild;
							optimizedDepthElementProperty[realLengthOfDepthElements] = 0;
						}

						currentProperty = 1;
					} else if (oldParent.children.length > 0) {
						// handles:
						//  - children
						if (currentProperty <= oldParent.children.length) {
							oldChild = &oldParent.children[currentProperty-1];
							newParent.children[currentProperty-1] = Nullable!DumbTreeElement(DumbTreeElement.init);
							newChild = &newParent.children[currentProperty-1];

							realLengthOfDepthElements++;
							oldRootDepthElement[realLengthOfDepthElements] = oldChild;
							newRootDepthElement[realLengthOfDepthElements] = newChild;
							optimizedDepthElementProperty[realLengthOfDepthElements] = 0;

							currentProperty++;
						} else {
							realLengthOfDepthElements--;
						}
					} else {
						realLengthOfDepthElements--;
					}

					optimizedDepthElementProperty[realLengthOfDepthElementsT] = currentProperty;
				} while (realLengthOfDepthElements >= 0);
			}
		}
	}
	
	Nullable!Route run(RouterRequest routeToFind, ushort toFindStatusCode=200) {
		import std.algorithm : splitter;
		import webrouters.list : isHostnameMatch;
		
		Nullable!DumbTreeElement* parent, parentCatchAll, parentCatchAll2;
		Nullable!Route* lastCatchAll, lastRoute;
		auto pathLeft = routeToFind.path.splitter("/");
		auto pathLeftCatchAll = pathLeft;

		DumbTreeRoot[] roots;

		if (sinceLastOptimizationHaveAdded) {
			roots = unoptimizedRoots;
		} else {
			roots = optimizedRoots;
		}

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
		string constant;
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
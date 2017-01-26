module webrouters.regex;
import webrouters.defs;
import webrouters.util;
import std.regex;
import std.typecons : Nullable;

class DumbRegexRouter : IRouter {
	RegexRoot[] roots;
	char[] buffer;
	size_t bufferOffset;

	void addRoute(Route newRoute) {
		import std.algorithm : splitter;
		import std.string : indexOf;
		
		// we need to determine which root we are talking about
		// keep in mind we don't attempt to "merge" websites

		RegexRoot* root;

		foreach(ref rootT; roots) {
			if (rootT.website == newRoute.website && rootT.statusCode == newRoute.code) {
				root = &rootT;
			}
		}
		
		if (root is null) {
			roots.length++;
			roots[$-1].statusCode = newRoute.code;
			roots[$-1].website = newRoute.website;
			root = &roots[$-1];
		}
		
		foreach(ref routeE; root.routes) {
			// now the path
			if (isRouteSpecMatch(newRoute.path, routeE.route.path)) {
				return;
			}
		}

		char[] theRegex;
		// okay we need to construct the regex for the given route up.

		if (buffer.length - bufferOffset < newRoute.path.length * 5) {
			buffer.length += newRoute.path.length * 5;
		}

		size_t bufferOffsetStart = bufferOffset;
		bufferOffset++;
		theRegex = buffer[bufferOffsetStart .. bufferOffset];
		theRegex[0] = '^';

		size_t partOffset;
		foreach(part; newRoute.path.splitter('/')) {
			if (partOffset == 0) {
				bufferOffset += 2;
				theRegex = buffer[bufferOffsetStart .. bufferOffset];
				theRegex[1 .. 3] = "/?";
			} else {
				bufferOffset++;
				theRegex = buffer[bufferOffsetStart .. bufferOffset];
				theRegex[$-1] = '/';
			}

			if (part[0] == '*') {
				bufferOffset += 2;
				theRegex = buffer[bufferOffsetStart .. bufferOffset];
				theRegex[$-2] = '.';
				theRegex[$-1] = '*';
			} else if (part[0] == ':') {
				bufferOffset += 7;
				theRegex = buffer[bufferOffsetStart .. bufferOffset];
				theRegex[$-7 .. $] = "([^/]+)";
			} else {
				bufferOffset += part.length;
				theRegex = buffer[bufferOffsetStart .. bufferOffset];
				theRegex[$-part.length .. $] = part;
			}

			partOffset++;
		}


		bufferOffset++;
		theRegex = buffer[bufferOffsetStart .. bufferOffset];
		theRegex[$-1] = '$';

		root.routes ~= RegexElement(newRoute, regex(theRegex));
	}

	void preuse() {}

	Nullable!Route run(RouterRequest routeToFind, ushort toFindStatusCode=200) {
		import std.algorithm : splitter;
		import webrouters.list : isHostnameMatch;
		
		RegexRoot* parent, parentCatchAll;
		Route* lastCatchAll, lastRoute;
		auto pathLeft = routeToFind.path.splitter("/");
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
							parent = &root;
							break F1;
						} else if (addr.port.isSpecial && addr.port.special == WebSiteAddressPort.Special.CatchAll) {
							parentCatchAll = &root;
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

		foreach(ref routeE; parent.routes) {
			// now the path
			if (matchFirst(routeToFind.path, routeE.regex)) {
				if (routeE.route.path[$-1] == '*')
					lastCatchAll = &routeE.route;
				else
					lastRoute = &routeE.route;
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

private {
	struct RegexRoot {
		IWebSite website;
		int statusCode;
		RegexElement[] routes;
		
		string toString() {
			import std.conv : text;
			string ret;
			ret ~= "statusCode: " ~ statusCode.text ~ "\n";
			
			ret ~= "addresses:\n";
			foreach(addr; website.addresses) {
				ret ~= " - " ~ addr.toString() ~ "\n";
			}

			ret ~= "routes:\n";
			foreach(route; routes) {
				ret ~= "  |-\n";
				ret ~= route.toString("  | ");
			}
			return ret;
		}
	}

	struct RegexElement {
		Route route;
		Regex!char regex;

		string toString(string prefix) {
			import std.conv : text;
			return prefix ~ route.text ~ "\n";
		}
	}

	unittest {
		import webrouters.tests;
		import std.stdio : writeln;
		
		DumbRegexRouter router = canAdd!DumbRegexRouter;
	}
}
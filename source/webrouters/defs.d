module webrouters.defs;
import std.typecons : Nullable;

__gshared bool verboseMode;

/**
 * We don't actually define or care about the connection
 *  as part of this research.
 * But we must acknoledge its existance.
 */
interface IConnection {
    ref RouterRequest request();
}

/**
 * The router implementation definition.
 *
 * Usage:
 *      1. default error pages
 *      2. addRoute(s)
 *      3. optimize
 *      4. run
 */
interface IRouter {
    void addRoute(Route);
    void preuse();
	Nullable!Route run(RouterRequest, ushort statusCode=200);
}

/// Consider this a "second" router for benchmarking
interface IRouterOptimizable {
	void preuseOptimize();
}

/**
 *
 *
 *
 */
abstract class IWebSite {
    const(WebsiteAddress[]) addresses();

	override bool opEquals(Object other) {
		// when we compare websites, 
		// we take us and look for us in another
		// the other may have only a partial equality
		// and that means we don't equal
		// in usage, remember != probably really means <

		if (IWebSite otherW = cast(IWebSite)other) {
			if (addresses.length != otherW.addresses.length) {
				return false;
			}

			// the next problem is the order of addresses
			// wonderful...
			// host.name, sub.host.name versus sub.host.name, host.name
			// wrong order, but still perfactly valid

			uint addressesMatched;
		F1: foreach(addr; addresses) {
			F2: foreach(addr2; otherW.addresses) {
					// if we match, we continue

					// check the ports, so we know it matches there
					if (addr.port.isSpecial && addr2.port.isSpecial &&
						addr.port.special == addr2.port.special) {
						// matched, fine ok
					} else if (!addr.port.isSpecial && !addr2.port.isSpecial &&
						addr.port.value == addr2.port.value) {
						// value same, ok
					} else {
						// didn't match 
						continue F2;
					}

					if (addr.supportsSSL == addr2.supportsSSL) {
					} else {
						continue F2;
					}

					if (addr.requiresSSL == addr2.requiresSSL) {
					} else {
						continue F2;
					}

					if (addr.hostname == addr2.hostname) {
					} else {
						continue F2;
					}

					addressesMatched++;
					continue F1;
				}
			}

			return addressesMatched == addresses.length;
		} else {
			return false;
		}
	}
}

struct WebSiteAddressPort {
	this(uint port) {
		isSpecial = false;
		this.value = port;
	}

	this(Special special) {
		this.special = special;
	}

	bool isSpecial = true;

	union {
		uint value;
		Special special;
	}

	enum Special {
		Error,
		CatchAll
	}

	string toString() const {
		import std.conv : text;

		if (isSpecial)
			return special.text;
		else
			return value.text;
	}
}

struct WebsiteAddress {
    string hostname;
	WebSiteAddressPort port;

    bool supportsSSL;
    bool requiresSSL;

	string toString() const {
		import std.conv : text;
		return hostname.text ~ ":" ~ port.toString ~ " " ~ 
			(supportsSSL ? (requiresSSL ? "[require SSL]" : "[SSL]") : "");
	}
}

struct Route {
    IWebSite website;
    string path;

    /**
     * If this route is "special" e.g. error handler
     *  then this won't be 200, e.g. 404.
     */
	ushort code = 200;

    bool requiresSSL;

    void delegate(IConnection) handler;
}

struct RouterRequest {
    string hostname;
    string path;

    uint port;
    bool useSSL;

	// we don't actually use this, so ignore it for now
    string[] fieldsKeys;
    string[] fieldsValues;
}
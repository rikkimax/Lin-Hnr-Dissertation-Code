module webrouters.defs;
import std.typecons : Nullable;

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
    void optimize();
	Nullable!Route run(RouterRequest);
}

/**
 *
 *
 *
 */
interface IWebSite {
    const(WebsiteAddress[]) addresses();
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
    dstring hostname;
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
    dstring path;

    /**
     * If this route is "special" e.g. error handler
     *  then this won't be 200, e.g. 404.
     */
    int code = 200;

    bool requiresSSL;

    void delegate(IConnection) handler;
}

struct RouterRequest {
    dstring hostname;
    dstring path;

    uint port;
    bool useSSL;

	// we don't actually use this, so ignore it for now
    dstring[] fieldsKeys;
    dstring[] fieldsValues;
}
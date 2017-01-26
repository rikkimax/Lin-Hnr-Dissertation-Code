module webrouters.util;
import webrouters.defs;

bool isAddressesLess(ref Route a, ref Route b) {
	// should we go first?
	
	auto from = a.website.addresses;
	auto to = b.website.addresses;
	
	uint lessPort, morePort;
	uint lessSupportsSSL, moreSupportsSSL;
	uint lessRequiresSSL, moreRequiresSSL;
	
	ulong hostnamesA, hostnamesB;
	hostnamesA = 0;
	hostnamesB = 0;
	ulong addrCalcVal;
	
	addrCalcVal = 10_00_00_00_00_00_00_00_00_00UL;
	foreach(ref f; from) {
		auto v = addressCalculation(f, addrCalcVal);
		hostnamesA += v;
	}
	
	addrCalcVal = 10_00_00_00_00_00_00_00_00_00UL;
	foreach(ref t; to) {
		auto v = addressCalculation(t, addrCalcVal);
		hostnamesB += v;
	}
	
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
		}
	}
	
	return lessPort < morePort &&
		lessRequiresSSL < lessRequiresSSL &&
			lessSupportsSSL < moreSupportsSSL &&
			hostnamesA < hostnamesB;
}

bool isRouteLess(ref Route a, ref Route b) {
	import std.algorithm : splitter;
	import std.range : zip;
	import std.string : indexOf;
	
	auto from = a.path;
	auto to = b.path;
	
	// TRUE= /abc versus /abc/def
	// FALSE= /abc/* versus /abc/def
	
	if (from == to)
		return false;
	
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

bool isRouteMatch(string from, string to) {
	import std.algorithm : splitter;
	import std.string : indexOf;
	
	foreach(part; from.splitter('/')) {
		if (part == "*") {
			return true;
		} else if (part.length > 0 && part[0] == ':') {
			if (to is null)
				return false;
			
			ptrdiff_t index = to.indexOf('/');
			if (index == -1)
				to = null;
			else
				to = to[index + 1 .. $];
		} else if (part.length <= to.length && part == to[0 .. part.length]) {
			if (to is null)
				return false;
			
			to = to[part.length .. $];
			if (to.length > 0 && to[0] == '/')
				to = to[1 .. $];
		} else
			return false;
	}
	
	return true;
}

bool isRouteSpecMatch(string from, string to) {
	import std.algorithm : splitter;
	import std.string : indexOf;

	foreach(part; from.splitter('/')) {
		if (part == "*") {
			if (to is null)
				return false;
			return to[0 .. $] == "*";
		} else if (part.length > 0 && part[0] == ':') {
			if (to is null || to[0] != ':')
				return false;
			
			ptrdiff_t index = to.indexOf('/');
			if (index == -1)
				to = null;
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

private:

ulong addressCalculation(ref const WebsiteAddress addr, ulong val) {
	ulong ret;
	size_t len, numPart;
	
	foreach_reverse(i, c; addr.hostname) {
		// 0 .. 4 == 4 / (100 / len)
		// 5 == *
		
		// an assumption of how hostnames hashing works
		assert(numPart <= 10);
		
		string part;
		if (c == '.' || i == 0) {
			numPart++;
			if (len == 0 && i > 0) {
				val >>= 4;
				len = 0;
				continue;
			} else if (len == 0) {
				part = addr.hostname[0 .. 1];
				len = 1;
			} else
				part = addr.hostname[i+1 .. i+1 + len];
			
			if (part == "*") {
				ret += val * 5;
			} else {
				ret += cast(ulong)(val * (4f / (100f / len)));
			}
			
			// devide by 10
			val >>= 4;
			len = 0;
		} else {
			len++;
		}
	}
	
	return ret;
}
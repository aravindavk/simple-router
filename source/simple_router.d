module simple_router;

import std.stdio;
import std.typecons;
import std.string;
import std.uuid;
import std.conv;
import std.json;

/*
 * Takes the params reference and sets the key value based on
 * the data type. All the params are already validated during
 * route lookup.
 */
void setPathParamValue(ref JSONValue params, string key, string value)
{
    string varName;
    string validation;

    auto parts = key.strip(":").strip("*").split(":");

    if (parts.length > 0)
        varName = parts[0];

    if (parts.length == 2)
        validation = parts[1];

    if (varName.empty)
        varName = "*";

    switch (validation)
    {
        case "int", "integer":
            params[varName] = value.to!int;
            break;
        case "long":
            params[varName] = value.to!long;
            break;
        case "bool", "boolean":
            params[varName] = value.to!bool;
            break;
        case "float":
            params[varName] = value.to!float;
            break;
        case "double":
            params[varName] = value.to!double;
            break;
        default:
            params[varName] = value;
            break;
    }
}

/*
 * Parse and return the Path params as JSONValue
 *
 * ---
 * parsePathParams("/services/id:int/:action", "/services/1234/start");
 * // Returns {"id": 1234, "action": "start"}
 * ---
 */
JSONValue parsePathParams(string tmplPath, string path, string sep = "/")
{
    auto tmplParts = tmplPath.strip(sep).split(sep);
    auto pathParts = path.strip(sep).split(sep);
    JSONValue pathParams;

    foreach(idx, part; tmplParts)
    {
        if (part.startsWith(":"))
        {
            auto key = part.split(":")[1];
            if (pathParts.length > idx)
                setPathParamValue(pathParams, part, pathParts[idx]);
        }
        else if (part.startsWith("*"))
        {
            auto key = part.replace("*", "");
            key = key.empty ? "*" : key;
            if (pathParts.length > idx)
                setPathParamValue(pathParams, part, pathParts[idx .. $].join(sep));
        }
    }

    return pathParams;
}

/*
 * Checks if the given string can be converted to the given type
 */
bool canConvert(T)(string value)
{
    try
    {
        value.to!T;
        return true;
    }
    catch (ConvException)
    {
        return false;
    }
    catch (UUIDParsingException)
    {
        return false;
    }
}

/*
 * Check if the path param is of valid type.
 */
bool isValid(string pattern, string value)
{
    string varName;
    string validation;

    if (!pattern.startsWith(":") && !pattern.startsWith("*"))
        return false;

    auto parts = pattern.strip(":").strip("*").split(":");
    if (parts.length > 0)
        varName = parts[0];

    if (parts.length == 2)
        validation = parts[1];

    if (validation.empty) return true;

    switch(validation)
    {
        case "str", "string":
            return true;
        case "int", "integer":
            return canConvert!int(value);
        case "bool":
            return canConvert!bool(value);
        case "long":
            return canConvert!long(value);
        case "float":
            return canConvert!float(value);
        case "double":
            return canConvert!double(value);
        case "uuid":
            return canConvert!UUID(value);
        default:
            import std.regex;
            auto m = matchFirst(value, r"^" ~ validation ~ r"$");
            return !m.empty;
    }
}

/*
 * Radix Tree based Router
 *
 * ---
 * alias Handler = void delegate(Request request, Response response);
 *
 * Router!Handler getRouter;
 * getRouter.register("/users", &listUsersHandler);
 * auto route1 = getRouter.lookup("/users"); // Returns the Router
 * auto route2 = getRouter.lookup("/users/abcd"); // Returns the nil
 * ---
 */
struct SimpleRouter(T)
{
    string label;
    string sep = "/";
    string fullPath;
    SimpleRouter[] children;
    Nullable!T handler_;
    JSONValue params;
    SimpleRouter!T[string] namespacedRoutes;

    auto handler()
    {
        return handler_.get;
    }

    /*
     * If handler is defined for this Route
     */
    bool handlerExists()
    {
        return !handler_.isNull;
    }

    bool isVariable()
    {
        return label.startsWith(":");
    }

    bool isStar()
    {
        return label.startsWith("*");
    }

    /*
     * Find the node by name and return the reference so that
     * its children can be updated directly
     */
    Nullable!(SimpleRouter*) findChild(string name)
    {
        foreach(child; children)
            if (child.label == name) return (&child).nullable;

        return Nullable!(SimpleRouter*).init;
    }

    /*
     * Register a new route
     */
    void register(string name, T handler)
    {
        auto parts = name.strip(sep).split(sep);

        if (parts.empty)
        {
            this.handler_ = handler;
            return;
        }

        SimpleRouter* parentRouter = &this;
        Nullable!(SimpleRouter*) rtr;
        foreach(part; parts)
        {
            rtr = parentRouter.findChild(part);
            if (rtr.isNull)
                parentRouter.children ~= SimpleRouter(part, sep);

            parentRouter = &parentRouter.children[$-1];
        }
        parentRouter.handler_ = handler;
    }

    /*
     * Convert any type to String for the namespace
     */
    string prepareNamespace(U)(U namespace)
    {
        return (namespace.to!string).toLower;
    }

    /*
     * Register route with namespace
     */
    void register(U)(U namespace, string path, T handler)
    {
        auto ns = prepareNamespace(namespace);
        if (ns !in namespacedRoutes)
            namespacedRoutes[ns] = SimpleRouter!T();

        namespacedRoutes[ns].register(path, handler);
    }

    /*
     * Find the matching child based on name or the pattern
     */
    Nullable!SimpleRouter matchingChild(string name)
    {
        foreach(child; children)
        {
            if (child.label == name || isValid(child.label, name))
                return child.nullable;
        }

        return Nullable!SimpleRouter.init;
    }

    /*
     * Namespace based lookup
     */
    Nullable!(SimpleRouter!T) lookup(U)(U namespace, string name)
    {
        auto ns = prepareNamespace(namespace);
        return namespacedRoutes[ns].lookup(name);
    }

    /*
     * Lookup for the given path
     */
    Nullable!(SimpleRouter!T) lookup(string name)
    {
        alias RetType = Nullable!(SimpleRouter!T);
        auto parts = name.strip(sep).split(sep);
        SimpleRouter parentRouter = this;
        Nullable!SimpleRouter rtr;
        string[] outLabel = [""]; // Root item
        int foundParts = 0;

        // If root handler exists
        if (parts.empty && handlerExists)
            return parentRouter.nullable;

        foreach(part; parts)
        {
            rtr = parentRouter.matchingChild(part);
            if (rtr.isNull)
                return rtr;

            foundParts++;
            outLabel ~= rtr.get.label;
            auto outRtr = rtr.get;
            outRtr.fullPath = outLabel.join(sep);
            outRtr.params = parsePathParams(outRtr.fullPath, name, sep);

            if (rtr.get.isStar && rtr.get.handlerExists)
                return outRtr.nullable;

            if (rtr.get.handlerExists && foundParts == parts.length)
                return outRtr.nullable;

            parentRouter = rtr.get;
        }

        return RetType.init;
    }
}

unittest
{
    struct Request{}
    struct Response{}
    void handler(Request request, Response response){}

    //alias Handler = typeof(&handler);
    alias Handler = void delegate(Request, Response);

    SimpleRouter!Handler root;
    root.register("/", &handler);
    root.register("/blog/:slug/edit", &handler);
    root.register("/file", &handler);
    root.register("/file/*/*", &handler);
    root.register("/services/*path", &handler);
    assert(!root.lookup("/").isNull);
    assert(root.lookup("/blog/1234").isNull);
    assert(!root.lookup("/blog/1234/edit").isNull);
    assert(!root.lookup("/file").isNull);
    assert(root.lookup("/file/1234").isNull);
    assert(!root.lookup("/file/1234/5678").isNull);
    assert(!root.lookup("/services/1234/5678").isNull);
    assert(root.lookup("/services/1234/5678").get.params["path"].str == "1234/5678");

    SimpleRouter!Handler root1;
    root1.sep = "=";
    root1.register("=", &handler);
    root1.register("=blog=:slug=edit", &handler);
    root1.register("=file", &handler);
    root1.register("=file=*=*", &handler);
    assert(!root1.lookup("=").isNull);
    assert(root1.lookup("=blog=1234").isNull);
    assert(!root1.lookup("=blog=1234=edit").isNull);
    assert(!root1.lookup("=file").isNull);
    assert(root1.lookup("=file=1234").isNull);
    assert(!root1.lookup("=file=1234=5678").isNull);

    // Priority to the first registered Route
    SimpleRouter!Handler root2;
    root2.register("/services/:name/start", &handler);
    root2.register("/services/:name/stop", &handler);
    root2.register("/services/:name/:action", &handler);
    assert(root2.lookup("/services/1234/start").get.fullPath == "/services/:name/start");
    assert(root2.lookup("/services/1234/stop").get.fullPath == "/services/:name/stop");
    assert(root2.lookup("/services/1234/reset").get.fullPath == "/services/:name/:action");

    // Validations
    SimpleRouter!Handler root3;
    root3.register("/blog/:id:integer", &handler);
    root3.register("/switch/:value:bool", &handler);
    assert(!root3.lookup("/blog/1234").isNull);
    assert(root3.lookup("/blog/1234.65").isNull);
    assert(root3.lookup("/blog/ABCD").isNull);
    assert(!root3.lookup("/switch/true").isNull);
    assert(!root3.lookup("/switch/false").isNull);
    assert(root3.lookup("/switch/abcd").isNull);
    assert(parsePathParams("/services/:id:int/:action", "/services/1234/reset") == parseJSON(`{"id": 1234, "action": "reset"}`));

    // Namespaced routes tests
    SimpleRouter!Handler root4;
    root4.register("get", "/notes", &handler);        // List
    root4.register("post", "/notes", &handler);       // (C) Create
    root4.register("get", "/notes/:id", &handler);    // (R) Retrive
    root4.register("put", "/notes/:id", &handler);    // (U) Update
    root4.register("delete", "/notes/:id", &handler); // (D) Delete
    assert(!root4.lookup("get", "/notes").isNull);
    assert(!root4.lookup("post", "/notes").isNull);
    assert(!root4.lookup("get", "/notes/1234").isNull);
    assert(!root4.lookup("put", "/notes/1234").isNull);
    assert(!root4.lookup("delete", "/notes/1234").isNull);
}

/+ dub.sdl:
 dependency "simple-router" path="../"
 dependency "serverino" version="~>0.8.5"
 +/

import std.json;
import std.stdio;

import serverino;
import simple_router;

alias Handler = void function(Request, Output, JSONValue);

SimpleRouter!Handler router;

// Register routes
static this()
{
    router.register("get", "/", &homeHandler);
    router.register("get", "/services", &listServicesHandler);
    router.register("get", "/services/:name", &getServiceHandler);
    router.register("post", "/services", &createServiceHandler);
    router.register("put", "/services/:name", &editServiceHandler);
    router.register("delete", "/services/:name", &deleteServiceHandler);
}

void homeHandler(Request request, Output output, JSONValue params)
{
    output ~= "Home";
}

void listServicesHandler(Request request, Output output, JSONValue params)
{
    output ~= "Services list";
}

void getServiceHandler(Request request, Output output, JSONValue params)
{
    output ~= "Get Service (" ~ params["name"].str ~ ")";
}

void createServiceHandler(Request request, Output output, JSONValue params)
{
    output ~= "Create Service";
}

void editServiceHandler(Request request, Output output, JSONValue params)
{
    output ~= "Edit Service (" ~ params["name"].str ~ ")";
}

void deleteServiceHandler(Request request, Output output, JSONValue params)
{
    output ~= "Delete Service (" ~ params["name"].str ~ ")";
}

void error404(Request request, Output output, JSONValue params)
{
    output.status = 404;
    output ~= "Page not found";
}

mixin ServerinoMain;

/*
 * Main Endpoint Route everything from here
 */
@endpoint
void root(Request request, Output output)
{
    auto route = router.lookup(request.method, request.path);
    if (route.isNull) return error404(request, output, JSONValue.init);

    auto func = route.get.handler;
    func(request, output, route.get.params);
}

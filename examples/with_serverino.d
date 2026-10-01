/+ dub.sdl:
 dependency "simple-router" path="../"
 dependency "serverino" version="~>0.8.5"
 +/

import std.json;

import serverino;
import simple_router;

alias Handler = void function(Request, Output, JSONValue);

Router!Handler getRouter;

// Register routes
static this()
{
    getRouter.register("/", &homeHandler);
    getRouter.register("/services", &listServicesHandler);
    getRouter.register("/services/:name", &getServiceHandler);
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
    auto route = getRouter.lookup(request.path);
    if (route.isNull) return error404(request, output, JSONValue.init);

    auto func = route.get.handler.get;
    func(request, output, route.get.params);
}

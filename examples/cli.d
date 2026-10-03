/+ dub.sdl:
 dependency "simple-router" path="../"
 +/

import std.stdio;
import std.json;
import std.string : join;

import simple_router;

int listTodos(string[] args, JSONValue params)
{
    writeln("List of TODOs");
    return 0;
}

int getTodo(string[] args, JSONValue params)
{
    writeln("TODO: ", params["name"].str);
    return 0;
}

int main(string[] args)
{
    alias Handler = int function(string[], JSONValue);
    SimpleRouter!Handler router;
    router.sep = " ";

    router.register("todo list", &listTodos);
    router.register("todo get :name", &getTodo);

    if (args.length < 2)
        return 1;

    auto route = router.lookup(args[1 .. $].join(" "));
    if (route.isNull)
    {
        writeln("No Route found");
        return 1;
    }

    auto func = route.get.handler;
    return func(args, route.get.params);
}

/+ dub.sdl:
 dependency "simple-router" path="../"
 +/

import std.stdio;
import std.json;

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
    Router!Handler router;

    router.register("/todo", &listTodos);
    router.register("/todo/:name", &getTodo);

    if (args.length < 2)
        return 1;

    auto route = router.lookup(args[1]);
    if (route.isNull)
    {
        writeln("No Route found");
        return 1;
    }

    auto func = route.get.handler.get;
    return func(args, route.get.params);
}

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
    router.register("get", "/api/notes", &listNotesHandler);
    router.register("get", "/api/notes/:id", &getNoteHandler);
    router.register("post", "/api/notes", &createNoteHandler);
    router.register("put", "/api/notes/:id", &editNoteHandler);
    router.register("delete", "/api/notes/:id", &deleteNoteHandler);
}

void homeHandler(Request request, Output output, JSONValue params)
{
    output ~= "Home";
}

void listNotesHandler(Request request, Output output, JSONValue params)
{
    output ~= "Notes list";
}

void getNoteHandler(Request request, Output output, JSONValue params)
{
    output ~= "Get Note (" ~ params["id"].str ~ ")";
}

void createNoteHandler(Request request, Output output, JSONValue params)
{
    output ~= "Create Note";
}

void editNoteHandler(Request request, Output output, JSONValue params)
{
    output ~= "Edit Note (" ~ params["id"].str ~ ")";
}

void deleteNoteHandler(Request request, Output output, JSONValue params)
{
    output ~= "Delete Note (" ~ params["id"].str ~ ")";
}

void error404(Request request, Output output)
{
    output.status = 404;
    output ~= "Page not found";
}

mixin ServerinoMain;

/*
 * Main Endpoint Route everything from here
 *
 * Example 1: Home page
 * ---
 * $ curl -i -X GET http://localhost:8080
 * HTTP/1.1 200 OK
 * date: Sat, 03 Oct 2026 14:44:57 GMT
 * connection: keep-alive
 * content-length: 4
 * content-type: text/html;charset=utf-8
 *
 * Home
 * ---
 *
 * Example 2: List Notes
 * ---
 * $ curl -i -X GET http://localhost:8080/api/notes
 * HTTP/1.1 200 OK
 * date: Sat, 03 Oct 2026 14:47:56 GMT
 * connection: keep-alive
 * content-length: 10
 * content-type: text/html;charset=utf-8
 *
 * Notes list
 * ---
 *
 * Example 3: Create Note
 * ---
 * $ curl -i -X POST http://localhost:8080/api/notes
 * HTTP/1.1 200 OK
 * date: Sat, 03 Oct 2026 14:48:20 GMT
 * connection: keep-alive
 * content-length: 11
 * content-type: text/html;charset=utf-8
 *
 * Create Note
 * ---
 *
 * Example 4: Edit note
 * ---
 * $ curl -i -X PUT http://localhost:8080/api/notes/1234
 * HTTP/1.1 200 OK
 * date: Sat, 03 Oct 2026 14:48:41 GMT
 * connection: keep-alive
 * content-length: 16
 * content-type: text/html;charset=utf-8
 *
 * Edit Note (1234)
 * ---
 *
 * Example 5: Get note
 * ---
 * $ curl -i -X GET http://localhost:8080/api/notes/1234
 * HTTP/1.1 200 OK
 * date: Sat, 03 Oct 2026 14:48:59 GMT
 * connection: keep-alive
 * content-length: 15
 * content-type: text/html;charset=utf-8
 *
 * Get Note (1234)
 * ---
 *
 * Example 6: Delete note
 * ---
 * $ curl -i -X DELETE http://localhost:8080/api/notes/1234
 * HTTP/1.1 200 OK
 * date: Sat, 03 Oct 2026 14:49:19 GMT
 * connection: keep-alive
 * content-length: 18
 * content-type: text/html;charset=utf-8
 *
 * Delete Note (1234)
 * ---
 */
@endpoint
void root(Request request, Output output)
{
    auto route = router.lookup(request.method, request.path);
    if (route.isNull) return error404(request, output);

    auto func = route.get.handler;
    func(request, output, route.get.params);
}


Our minimal wrapper for using [elm-pages scripts](https://elm-pages.com/docs/elm-pages-scripts/) to write all our non-compiler Lamdera tooling in Elm.

This is a work-in-progress and could do with some cleanup, but is functional.

You may find it useful if you like our top-level design choices.

### Differences to [elm-pages scripts](https://elm-pages.com/docs/elm-pages-scripts/)

Our CLI tooling is aligned to specific design choices:

- The only STDOUT output should be output controlled and intentionally specified by the Elm code
- Every effect that reaches out into the world (including reads) should always be logged to disk
- The output of that logging to STDOUT should be optional (`LDEBUG=1` ENV flag)

As a result:

- Wrapped [elm-pages scripts](https://elm-pages.com/docs/elm-pages-scripts/) output to remove the default `BackendTask.Custom.run` and HTTP `fetch` debug output
- Most effects are implemented (or re-implemented) in `custom-backend-task.ts` including error handling with clear input context
- Logging is written to controlled files, i.e. `run-2024-03-22021333196Z.log`
  - This means you're never left wondering "wait hold on, what happened exactly?" when things go wrong or unexpectedly – you can always check the logs for a full audit of everything the script did
  - Running with `DEBUG=1` will print those same logs to the console as well when you do want to see the output
- 🔥 Extensive use of emojis in logging to identify effects, after a while it becomes amazingly easy to skim & understand what's happening vs raw text logging

Other opinionated things:

- `type alias IO a = BackendTask FatalError a`, everything in `src/IO/*` uses this alias
- Not everything in elm-pages has been wrapped, i.e. the `bashStream` was setup before `BackendTask.Stream` was a thing.
- Anything from elm-pages core `BackendTask.*` is usable, but will be missing the logging and error handling implemented in `custom-backend-task.ts`, which would defeat the point of this approach.

Otherwise `lamdera/script` is just entirely using [elm-pages scripts](https://elm-pages.com/docs/elm-pages-scripts/).

### Usage

`./run.sh <command> [args]`.

```
$ ./run.sh example --someArg testing
───> Starting a thing for testing...
It's a mac!
```

```
$ cat run-2024-08-11073005957Z.log
runLogPath: /Users/mario/dev/projects/lamdera-script/run-2024-08-11073005957Z.log
runId: 2024-08-11073005957Z
DEBUG:1
isDebug: true
───> Starting a thing for testing...
debug: debug:👀💻:MacOS
It's a mac!
```

See `src/Lx.elm` for the example CLI implementation, this is where you would implement your own CLI like normal.

module IO.Util exposing (..)

import BackendTask exposing (BackendTask)
import FatalError exposing (FatalError)


type alias IO a =
    BackendTask FatalError a


type alias FilePath =
    String


iff condition trueVal falseVal =
    if condition then
        trueVal

    else
        falseVal


iff_ conditionTask trueTask falseTask =
    passthrough
        (conditionTask
            |> BackendTask.andThen
                (\condition ->
                    if condition then
                        trueTask

                    else
                        falseTask
                )
        )


andThen =
    BackendTask.andThen


map =
    BackendTask.map


succeed =
    BackendTask.succeed


fatal str =
    str |> FatalError.fromString |> BackendTask.fail


allowFatal =
    BackendTask.allowFatal


discardAndThen task prev =
    prev |> BackendTask.andThen (\_ -> task)


with_ task fn previous =
    previous |> discardAndThen task |> BackendTask.andThen fn


with : BackendTask err a -> (a -> BackendTask err b) -> BackendTask err b
with task fn =
    task |> BackendTask.andThen fn


with2 : BackendTask err a -> BackendTask err b -> (a -> b -> BackendTask err c) -> BackendTask err c
with2 task1 task2 fn =
    task1 |> BackendTask.andThen (\v1 -> task2 |> BackendTask.andThen (\v2 -> fn v1 v2))


with3 : BackendTask err a -> BackendTask err b -> BackendTask err c -> (a -> b -> c -> BackendTask err d) -> BackendTask err d
with3 task1 task2 task3 fn =
    task1
        |> BackendTask.andThen
            (\v1 ->
                task2
                    |> BackendTask.andThen
                        (\v2 ->
                            task3
                                |> BackendTask.andThen
                                    (\v3 ->
                                        fn v1 v2 v3
                                    )
                        )
            )


passthrough : BackendTask err a -> BackendTask err b -> BackendTask err b
passthrough task previous =
    previous |> BackendTask.andThen (\previousResult -> task |> BackendTask.map (\_ -> previousResult))


resultAndThen : (Result err a -> BackendTask err2 b) -> BackendTask err a -> BackendTask err2 b
resultAndThen fn previous =
    previous |> BackendTask.toResult |> BackendTask.andThen fn


passthroughWithVal : (a -> BackendTask err b) -> BackendTask err a -> BackendTask err a
passthroughWithVal fn previous =
    previous |> BackendTask.andThen (\previousResult -> fn previousResult |> BackendTask.map (\_ -> previousResult))


{-| Runs the condition task, and if true, runs the previous result through fn,
and returns the previous result ignoring the fn's result (i.e. passthrough):

    succeed 123 |> passthroughWithValWhen (succeed True) (\\val -> succeed (val + 1))

succeeds with 123, NOT with 124.

Useful when you want to do something with a value in the chain, but NOT modify the value

-}
passthroughWithValWhen : BackendTask err Bool -> (a -> BackendTask err b) -> BackendTask err a -> BackendTask err a
passthroughWithValWhen conditionTask fn previous =
    conditionTask
        |> BackendTask.andThen
            (\condition ->
                if condition then
                    previous |> BackendTask.andThen (\val -> fn val |> BackendTask.map (\_ -> val))

                else
                    previous
            )


passthroughWhen : BackendTask err Bool -> BackendTask err b -> BackendTask err a -> BackendTask err a
passthroughWhen conditionTask task previous =
    conditionTask
        |> BackendTask.andThen
            (\condition ->
                if condition then
                    previous |> passthrough task

                else
                    previous
            )

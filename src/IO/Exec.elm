module IO.Exec exposing
    ( bash
    , bashDetached
    , bashDetached_
    , bashStream
    , bashStream_
    , bash_
    , crash
    , crash_
    , die
    , die_
    , exec
    , execStream
    , execStream_
    , exec_
    , exit
    , exit_
    , sleep
    , sleep_
    )

import BackendTask
import BackendTask.Custom
import IO.Log
import IO.Util exposing (..)
import Json.Decode as D
import Json.Encode as E


type alias ExecResult =
    { out : String, err : String, exitCode : Int }


bash : String -> IO ExecResult
bash cmd =
    exec "bash" [ "-c", "'" ++ cmd ++ "'" ]
        |> andThen
            (\execResult ->
                if execResult.exitCode == 0 then
                    succeed execResult

                else
                    fatal (execResult.out ++ execResult.err)
            )


bash_ : String -> IO a -> IO a
bash_ cmd previous =
    previous |> passthrough (bash cmd)


bashStream : String -> IO ExecResult
bashStream cmd =
    execStream "bash" [ "-c", cmd ]
        |> andThen
            (\execResult ->
                if execResult.exitCode == 0 then
                    succeed execResult

                else
                    fatal execResult.err
            )


bashStream_ : String -> IO a -> IO a
bashStream_ cmd previous =
    previous |> passthrough (bashStream cmd)


bashDetached : String -> IO ()
bashDetached cmd =
    execDetached "bash" [ "-c", cmd ]


bashDetached_ : String -> IO a -> IO a
bashDetached_ cmd previous =
    previous |> passthrough (bashDetached cmd)


exec : String -> List String -> IO ExecResult
exec bin args =
    BackendTask.Custom.run "exec"
        (E.object [ ( "bin", E.string bin ), ( "args", E.list E.string args ) ])
        (D.map3 (\out err exitCode -> { out = out, err = err, exitCode = exitCode })
            (D.field "stdout" D.string)
            (D.field "stderr" D.string)
            (D.field "exitCode" D.int)
        )
        -- |> debug ("🤖  " ++ Debug.toString ([ bin ] ++ args))
        |> BackendTask.allowFatal


exec_ : String -> List String -> IO a -> IO a
exec_ bin args previous =
    previous |> passthrough (exec bin args)


execStream : String -> List String -> IO ExecResult
execStream bin args =
    BackendTask.Custom.run "execStream"
        (E.object [ ( "bin", E.string bin ), ( "args", E.list E.string args ) ])
        (D.map3 (\out err exitCode -> { out = out, err = err, exitCode = exitCode })
            (D.field "stdout" D.string)
            (D.field "stderr" D.string)
            (D.field "exitCode" D.int)
        )
        -- |> debug ("🤖  " ++ Debug.toString ([ bin ] ++ args))
        |> BackendTask.allowFatal


execStream_ : String -> List String -> IO a -> IO a
execStream_ bin args previous =
    previous |> passthrough (exec bin args)


execDetached : String -> List String -> IO ()
execDetached bin args =
    BackendTask.Custom.run "execDetached"
        (E.object [ ( "bin", E.string bin ), ( "args", E.list E.string args ) ])
        (D.succeed ())
        |> BackendTask.allowFatal


exit : IO ()
exit =
    BackendTask.Custom.run "exit"
        E.null
        (D.succeed ())
        |> BackendTask.allowFatal


exit_ : IO a -> IO ()
exit_ previous =
    previous |> andThen (\_ -> exit)


die : Int -> IO ()
die exitCode =
    BackendTask.Custom.run "die"
        (E.int exitCode)
        (D.succeed ())
        |> BackendTask.allowFatal


die_ : Int -> IO a -> IO ()
die_ exitCode previous =
    previous |> andThen (\_ -> die exitCode)


crash : String -> IO ()
crash message =
    IO.Log.print ("$(red)IO.Exec.crash with message:$(normal)" ++ message)
        |> andThen (\_ -> die 1)


crash_ : String -> IO a -> IO ()
crash_ message previous =
    previous |> andThen (\_ -> crash message)


sleep : Int -> IO ()
sleep milliseconds =
    BackendTask.Custom.run "sleep"
        (E.int milliseconds)
        (D.succeed ())
        -- |> debug ("🤖  sleep")
        |> BackendTask.allowFatal


sleep_ : Int -> IO a -> IO a
sleep_ milliseconds previous =
    previous |> passthrough (sleep milliseconds)

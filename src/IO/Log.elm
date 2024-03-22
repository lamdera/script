module IO.Log exposing (..)

import BackendTask exposing (..)
import BackendTask.Custom
import FatalError exposing (FatalError)
import IO.Custom
import IO.Util exposing (..)
import Json.Decode as D
import Json.Encode as E
import Pages.Script as Script exposing (Script)



-- debug :
--     String
--     ->
--         BackendTask
--             { fatal : FatalError.FatalError
--             , recoverable : BackendTask.Custom.Error
--             }
--             a
--     ->
--         BackendTask
--             { fatal : FatalError.FatalError
--             , recoverable : BackendTask.Custom.Error
--             }
--             a


debugNote str =
    IO.Custom.printDebug str


debugNote_ str previous =
    previous |> passthrough (IO.Custom.printDebug str)



-- Disabling temporarily as we can't control the output into writeRunLog with the Script.log setup
-- But we also can't use IO.Log.print as the error type is wrong
-- debug tag IO =
--     task
--         |> passthroughWithValWhen isDebug
--             (\x ->
--                 Script.log ("debug:" ++ tag ++ ":" ++ Debug.toString x)
--                     |> BackendTask.andThen (\_ -> BackendTask.succeed x)
--             )
-- isDebug : BackendTask { fatal : FatalError.FatalError, recoverable : BackendTask.Custom.Error } Bool
-- isDebug =
--     -- BackendTask.succeed True
--     -- IO.Custom.readEnv "LDEBUG" |> BackendTask.map (\x -> x /= Nothing)
--     BackendTask.Custom.run "readEnv" (E.string "LDEBUG") (D.nullable D.string)
--         |> BackendTask.map (\x -> x /= Nothing)


debug : String -> IO a -> IO a
debug tag io =
    io
        |> passthroughWithValWhen isDebugTask
            -- |> BackendTask.andThen
            (\x ->
                IO.Custom.printDebug ("debug:" ++ tag ++ ":" ++ Debug.toString x)
                    |> BackendTask.andThen (\_ -> BackendTask.succeed x)
            )


debugNoteFatal : String -> IO String
debugNoteFatal logEntry =
    IO.Custom.printDebug (Debug.log "debugNoteFatal" logEntry)


isDebugTask : IO Bool
isDebugTask =
    -- BackendTask.succeed True
    IO.Custom.readEnv "DEBUG" |> BackendTask.map (\x -> x /= Nothing)


log str =
    IO.Custom.print ("log: " ++ str)


log_ str previous =
    previous |> passthrough (log str)


print : String -> IO String
print str =
    printRaw str |> BackendTask.allowFatal


print_ : String -> IO a -> IO a
print_ str prev =
    prev |> passthrough (print str)


printRaw : String -> BackendTask { fatal : FatalError.FatalError, recoverable : BackendTask.Custom.Error } String
printRaw str =
    str
        -- https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
        |> String.replace "$(black)" "\u{001B}[30m"
        |> String.replace "$(red)" "\u{001B}[31m"
        |> String.replace "$(green)" "\u{001B}[32m"
        |> String.replace "$(yellow)" "\u{001B}[33m"
        |> String.replace "$(blue)" "\u{001B}[34m"
        |> String.replace "$(magenta)" "\u{001B}[35m"
        |> String.replace "$(cyan)" "\u{001B}[36m"
        |> String.replace "$(white)" "\u{001B}[37m"
        |> String.replace "$(default)" "\u{001B}[39m"
        |> String.replace "$(normal)" "\u{001B}[0m"
        |> IO.Custom.printRaw

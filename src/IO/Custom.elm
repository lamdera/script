module IO.Custom exposing (..)

import BackendTask exposing (BackendTask)
import BackendTask.Custom
import FatalError exposing (FatalError)
import IO.Util exposing (IO)
import Json.Decode as D
import Json.Encode as E


requireEnv : String -> IO String
requireEnv varname =
    BackendTask.Custom.run "requireEnv" (E.string varname) D.string |> BackendTask.allowFatal


readEnv : String -> IO (Maybe String)
readEnv varname =
    BackendTask.Custom.run "readEnv" (E.string varname) (D.nullable D.string)
        |> BackendTask.allowFatal


print : String -> IO String
print str =
    BackendTask.Custom.run "print" (E.string str) D.string
        |> BackendTask.allowFatal


printDebug : String -> IO String
printDebug logEntry =
    BackendTask.Custom.run "printDebug" (E.string logEntry) D.string
        |> BackendTask.allowFatal


getPlatformString : IO String
getPlatformString =
    BackendTask.Custom.run "environmentPlatform" E.null D.string |> BackendTask.allowFatal


getFreePort : IO Int
getFreePort =
    BackendTask.Custom.run "getFreePort" E.null D.int |> BackendTask.allowFatal



-- {-| Don't use this directly!
-- -- BackendTask.Custom.run "writeRunLog" (E.string logEntry) D.string
-- -- |> BackendTask.allowFatal
-- -}
-- writeRunLog : String -> IO String
-- writeRunLog logEntry =
--     IO.Util.fatal "writeRunLog should not be used directly! Use log or logDebug instead."
-- Original sigs


printRaw : String -> BackendTask { fatal : FatalError.FatalError, recoverable : BackendTask.Custom.Error } String
printRaw str =
    BackendTask.Custom.run "print" (E.string str) D.string


postgresRawQuery : String -> BackendTask FatalError String
postgresRawQuery sql =
    BackendTask.Custom.run "postgresRawQuery"
        (E.object [ ( "sql", E.string sql ) ])
        D.string
        |> BackendTask.allowFatal


postgresRawQueryJSON : String -> BackendTask FatalError D.Value
postgresRawQueryJSON sql =
    BackendTask.Custom.run "postgresRawQueryJSON"
        (E.object [ ( "sql", E.string sql ) ])
        D.value
        |> BackendTask.allowFatal

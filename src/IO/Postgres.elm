module IO.Postgres exposing (..)

import IO.Custom
import IO.Util exposing (IO)
import Json.Decode as D


rawQuery : String -> IO String
rawQuery =
    IO.Custom.postgresRawQuery


rawQueryJSON : String -> IO D.Value
rawQueryJSON =
    IO.Custom.postgresRawQueryJSON

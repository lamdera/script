module IO.Http exposing (..)

import BackendTask
import BackendTask.Http
import IO exposing (..)
import Json.Encode
import Pages.Script as Script exposing (Script)



-- Wrappers around HTTP with added logging for errors


postReturnString url jsonBody =
    debugNote ("🚀  POST " ++ url ++ "\n" ++ Json.Encode.encode 0 jsonBody)
        |> andThen
            (\body ->
                BackendTask.Http.post
                    url
                    (BackendTask.Http.jsonBody jsonBody)
                    BackendTask.Http.expectString
                    |> BackendTask.allowFatal
                    |> debug " => "
                    |> logErrorDetail_ url
            )



-- get path expectation =
--     log ("🚀  GET " ++ path) |> BackendTask.andThen (\_ -> BackendTask.Http.get path expectation)


getFatal path expectation =
    debugNote ("🚀  GET " ++ path)
        |> andThen
            (\_ ->
                BackendTask.Http.request
                    { url = path
                    , method = "GET"
                    , headers = []
                    , body = BackendTask.Http.emptyBody
                    , retries = Just 2
                    , timeoutInMs = Just 2000
                    }
                    expectation
                    |> BackendTask.allowFatal
            )

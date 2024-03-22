module IO.Env exposing (..)

import BackendTask.Custom
import IO.Custom
import IO.Util exposing (..)


requireEnv =
    IO.Custom.requireEnv


readEnv =
    IO.Custom.readEnv


getPlatform : IO Platform
getPlatform =
    IO.Custom.getPlatformString
        |> map
            (\p ->
                -- We pattern match for all valid nodejs process.platform values
                -- https://nodejs.org/api/process.html#processplatform
                case p of
                    "aix" ->
                        AIX

                    "darwin" ->
                        MacOS

                    "freebsd" ->
                        FreeBSD

                    "linux" ->
                        Linux

                    "openbsd" ->
                        OpenBSD

                    "sunos" ->
                        SunOS

                    "win32" ->
                        Win32

                    s ->
                        UnknownPlatform s
            )


type Platform
    = AIX
    | MacOS
    | FreeBSD
    | Linux
    | OpenBSD
    | SunOS
    | Win32
    | UnknownPlatform String

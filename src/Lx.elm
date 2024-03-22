module Lx exposing (run)

import BackendTask
import BackendTask.Http
import Cli.Option as Option
import Cli.OptionsParser as OptionsParser
import Cli.Program as Program
import IO exposing (..)
import IO.Postgres
import Json.Decode as D
import Pages.Script as Script exposing (Script)


type CliOptions
    = Example { someArg : String }


commandLineConfigParser : Program.Config CliOptions
commandLineConfigParser =
    Program.config
        |> Program.add
            (OptionsParser.map Example
                (OptionsParser.buildSubCommand "example"
                    (\someArg ->
                        { someArg = someArg
                        }
                    )
                    |> OptionsParser.withDoc "Just an example"
                    |> required "someArg"
                )
            )


positional s =
    OptionsParser.with (Option.requiredPositionalArg s)


required s =
    OptionsParser.with (Option.requiredKeywordArg s)


run : Script
run =
    Script.withCliOptions commandLineConfigParser
        (\cmd ->
            case cmd of
                Example config ->
                    example config
        )


example { someArg } =
    print ("───> $(blue)Starting a thing for " ++ someArg ++ "...$(normal)")
        |> discardAndThen
            (with2
                isMacOS
                (BackendTask.succeed "whatever")
                (\isMacOS_ thing ->
                    if isMacOS_ then
                        print "It's a mac!"

                    else
                        print "It's not a mac!"
                )
            )
        |> write_ "test.txt" "Hello, world!"
        |> end

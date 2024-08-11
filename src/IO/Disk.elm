module IO.Disk exposing
    ( append
    , changeDirectory
    , changeDirectory_
    , copy
    , copy_
    , currentDirectory
    , doesPathExist
    , homeDirectory
    , mkdir
    , mkdir_
    , mkdirs
    , mkdirs_
    , move
    , move_
    , nukeAndRecreateDir_
    , pathMissing
    , read
    , remove
    , removeAll
    , removeAll_
    , removeOrContinue
    , removeOrContinue_
    , remove_
    , replaceInFile
    , replaceInFile_
    , symlink
    , symlink_
    , touch
    , touch_
    , withFileIfExists
    , withFileIfExists_
    , withinDirectory
    , withinDirectory_
    , write
    , write_
    )

{-| The \_ suffiexed functions denote the variants that will automatically
passthrough the prior IO so they can be chained easily
-}

import BackendTask exposing (BackendTask)
import BackendTask.Custom
import FatalError exposing (FatalError)
import IO.Log exposing (..)
import IO.Util exposing (..)
import Json.Decode as D
import Json.Encode as E


read : String -> IO String
read path =
    BackendTask.Custom.run "readFile"
        (E.string path)
        D.string
        |> BackendTask.allowFatal


write : String -> String -> IO String
write path contents =
    BackendTask.Custom.run "writeFile"
        (E.object [ ( "path", E.string path ), ( "contents", E.string contents ) ])
        D.string
        |> BackendTask.allowFatal



-- |> debug ("✍️  " ++ path)


write_ : String -> String -> IO a -> IO a
write_ path contents =
    passthrough (write path contents)


append : String -> String -> IO String
append path contents =
    BackendTask.Custom.run "appendFile"
        (E.object [ ( "path", E.string path ), ( "contents", E.string contents ) ])
        D.string
        |> BackendTask.allowFatal


touch : String -> IO ()
touch path =
    BackendTask.Custom.run "touchFile"
        (E.object [ ( "path", E.string path ) ])
        (D.succeed ())
        |> BackendTask.allowFatal


touch_ : String -> IO a -> IO a
touch_ path previous =
    previous |> passthrough (touch path)


replaceInFile : String -> String -> String -> IO String
replaceInFile path find replace =
    BackendTask.Custom.run "replaceInFile"
        (E.object [ ( "path", E.string path ), ( "find", E.string find ), ( "replace", E.string replace ) ])
        D.string
        |> BackendTask.allowFatal


replaceInFile_ : String -> String -> String -> IO a -> IO a
replaceInFile_ path find replace previous =
    previous |> passthrough (replaceInFile path find replace)


withFileIfExists : String -> (String -> IO a) -> IO a -> IO a
withFileIfExists path fn fallback =
    read path
        |> BackendTask.toResult
        |> BackendTask.andThen
            (\res ->
                case res of
                    Ok contents ->
                        fn contents

                    Err err ->
                        fallback
            )


withFileIfExists_ : String -> (String -> IO a) -> IO a -> IO b -> IO b
withFileIfExists_ path fn fallback previous =
    previous |> passthrough (withFileIfExists path fn fallback)



-- mkdirs : List String -> IO ()
-- mkdirs dirs =
--     -- @TODO could be optimised into a single custom port call
--     dirs
--         |> List.map mkdir
--         |> BackendTask.combine
--         |> log_ ("mkdirs:" ++ "\n  " ++ String.join "\n  " dirs)
--         |> BackendTask.andThen (\_ -> BackendTask.succeed ())
-- Causes this error:
-- (node:45693) Warning: Label 'BackendTask.Custom.run "makeDirectory"' already exists for console.time()
-- (Use `node --trace-warnings ...` to show where the warning was created)
-- BackendTask.Custom.run "makeDirectory": 0.632ms
-- log:mkdirs:
--   ~/lamdera-builds/build-test-local-preview
--   ~/lamdera-deploys
-- (node:45693) Warning: No such label 'BackendTask.Custom.run "makeDirectory"' for console.timeEnd()


mkdirs : List String -> IO ()
mkdirs dirs =
    BackendTask.Custom.run "makeDirectories" (E.list E.string dirs) D.string
        |> BackendTask.allowFatal
        |> debugNote_ ("mkdirs:" ++ "\n  " ++ String.join "\n  " dirs)
        |> BackendTask.andThen (\_ -> BackendTask.succeed ())


mkdirs_ : List String -> IO a -> IO a
mkdirs_ dirs previous =
    previous |> passthrough (mkdirs dirs)


mkdir : String -> IO ()
mkdir dir =
    BackendTask.Custom.run "makeDirectory" (E.string dir) D.string
        |> BackendTask.allowFatal
        |> BackendTask.andThen (\_ -> BackendTask.succeed ())


mkdir_ : String -> IO a -> IO a
mkdir_ dir previous =
    previous |> passthrough (mkdir dir)


nukeAndRecreateDir_ : String -> IO a -> IO a
nukeAndRecreateDir_ dir previous =
    previous
        |> removeOrContinue_ dir
        |> mkdir_ dir


changeDirectory : String -> IO String
changeDirectory path =
    BackendTask.Custom.run "changeDirectory" (E.string path) D.string
        |> BackendTask.allowFatal


changeDirectory_ : String -> IO a -> IO a
changeDirectory_ path previous =
    previous |> passthrough (changeDirectory path)


currentDirectory : IO String
currentDirectory =
    BackendTask.Custom.run "currentDirectory" E.null D.string
        |> BackendTask.allowFatal


withinDirectory : String -> IO a -> IO a
withinDirectory path io =
    with currentDirectory
        (\return ->
            changeDirectory path
                |> BackendTask.andThen (\_ -> io)
                |> changeDirectory_ return
        )


withinDirectory_ : String -> IO a -> IO a -> IO a
withinDirectory_ path io previous =
    previous |> passthrough (withinDirectory path io)


remove : String -> IO String
remove path =
    BackendTask.Custom.run "remove" (E.string path) D.string
        |> BackendTask.allowFatal


remove_ : String -> IO a -> IO a
remove_ path previous =
    previous |> passthrough (remove path)


removeOrContinue : String -> IO String
removeOrContinue path =
    BackendTask.Custom.run "removeOrContinue" (E.string path) D.string
        |> BackendTask.allowFatal


removeOrContinue_ : String -> IO a -> IO a
removeOrContinue_ path previous =
    previous |> passthrough (removeOrContinue path)


removeAll : List String -> IO String
removeAll paths =
    BackendTask.Custom.run "removeAll" (E.list E.string paths) D.string
        |> BackendTask.allowFatal


removeAll_ : List String -> IO a -> IO a
removeAll_ paths previous =
    previous |> passthrough (removeAll paths)


copy : String -> String -> IO String
copy src dest =
    BackendTask.Custom.run "copy" (E.object [ ( "src", E.string src ), ( "dest", E.string dest ) ]) D.string
        |> BackendTask.allowFatal


copy_ : String -> String -> IO a -> IO a
copy_ src dest previous =
    previous |> passthrough (copy src dest)


move : String -> String -> IO String
move src dest =
    BackendTask.Custom.run "move" (E.object [ ( "src", E.string src ), ( "dest", E.string dest ) ]) D.string
        |> BackendTask.allowFatal


move_ : String -> String -> IO a -> IO a
move_ src dest previous =
    previous |> passthrough (move src dest)


doesPathExist : String -> IO Bool
doesPathExist path =
    BackendTask.Custom.run "doesPathExist" (E.string path) D.bool
        |> BackendTask.allowFatal


pathMissing : String -> IO Bool
pathMissing path =
    doesPathExist path |> BackendTask.map not


homeDirectory : IO String
homeDirectory =
    BackendTask.Custom.run "homeDirectory" E.null D.string
        |> BackendTask.allowFatal


symlink : String -> String -> IO String
symlink src dest =
    BackendTask.Custom.run "symlink" (E.object [ ( "src", E.string src ), ( "dest", E.string dest ) ]) D.string
        |> BackendTask.allowFatal


symlink_ : String -> String -> IO a -> IO a
symlink_ src dest previous =
    previous |> passthrough (symlink src dest)

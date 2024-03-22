module IO exposing (..)

import BackendTask exposing (BackendTask)
import BackendTask.Custom
import BackendTask.Http
import FatalError exposing (FatalError)
import IO.Custom
import IO.Disk
import IO.Env
import IO.Exec
import IO.Log
import IO.Util exposing (..)
import Json.Decode as D
import Json.Encode as E
import Pages.Script as Script exposing (Script)



-- Re-exposures


type alias IO a =
    IO.Util.IO a


type alias PassthroughTask a b =
    IO.Util.IO a -> IO.Util.IO b


type alias FilePath =
    IO.Util.FilePath


type alias BackendTask err a =
    BackendTask.BackendTask err a


type alias FatalError =
    FatalError.FatalError


andThen =
    BackendTask.andThen


map =
    BackendTask.map


succeed =
    BackendTask.succeed


{-| This one doesn't follow the same logic as other `_` == passthrough usages
but it is convenient so maybe self evident what it does vs success? Because you'd never
want to passthrough success...
-}
succeed_ res previous =
    previous |> discardAndThen (BackendTask.succeed res)


combine =
    BackendTask.combine


combine_ =
    BackendTask.combine >> passthrough


passthrough =
    IO.Util.passthrough


p_ =
    passthrough


passthroughWhen =
    IO.Util.passthroughWhen


when_ =
    IO.Util.passthroughWhen


passthroughWithVal =
    IO.Util.passthroughWithVal


passthroughWithValWhen =
    IO.Util.passthroughWithValWhen


resultAndThen =
    IO.Util.resultAndThen


discardAndThen =
    IO.Util.discardAndThen


with =
    IO.Util.with


with_ io fn previous =
    previous |> passthrough (IO.Util.with io fn)


with2 =
    IO.Util.with2


with2_ task1 task2 fn prev =
    prev |> passthrough (IO.Util.with2 task1 task2 fn)


with3 =
    IO.Util.with3


iff =
    IO.Util.iff


iff_ =
    IO.Util.iff_



-- -- Disabling temporarily as we can't control the output into writeRunLog with the Script.log setup
-- But we also can't use IO.Log.print as the error type is wrong
-- debug =
--     IO.Log.debug


debug =
    IO.Log.debug


debugNote =
    IO.Log.debugNote


debugNoteFatal =
    IO.Log.debugNoteFatal


debugNote_ =
    IO.Log.debugNote_


log =
    IO.Log.log


log_ =
    IO.Log.log_


print =
    IO.Log.print


print_ =
    IO.Log.print_


printRaw =
    IO.Log.printRaw


onError =
    BackendTask.onError



-- Utilities


map2 : BackendTask err a -> BackendTask err b -> (a -> b -> c) -> BackendTask err c
map2 task1 task2 fn =
    BackendTask.map2 fn task1 task2


fatal =
    IO.Util.fatal


do =
    succeed ()



-- do :
--     BackendTask { error1 | fatal : FatalError } value1
--     -> BackendTask { error2 | fatal : FatalError } value2
--     -> BackendTask { fatal : FatalError } ()
-- do task1 task2 =
--     BackendTask.map2 (\_ _ -> ())
--         (task1 |> stripError)
--         (task2 |> stripError)


stripError :
    BackendTask { error | fatal : FatalError } value
    -> BackendTask { fatal : FatalError } value
stripError io =
    io |> BackendTask.mapError (\err -> { fatal = err.fatal })


exists : String -> BackendTask FatalError Bool
exists =
    IO.Disk.doesPathExist


whenExists_ : String -> BackendTask FatalError a -> BackendTask FatalError b -> BackendTask FatalError b
whenExists_ path io previous =
    previous
        |> passthrough
            (IO.Disk.doesPathExist path
                |> BackendTask.andThen
                    (\exists_ ->
                        if exists_ then
                            io |> discardAndThen (BackendTask.succeed ())

                        else
                            BackendTask.succeed ()
                    )
            )


whenMissing_ : String -> IO a -> IO b -> IO b
whenMissing_ path io previous =
    previous
        |> passthrough
            (IO.Disk.doesPathExist path
                |> BackendTask.andThen
                    (\exists_ ->
                        if exists_ then
                            BackendTask.succeed ()

                        else
                            io |> discardAndThen (BackendTask.succeed ())
                    )
            )


onlyWhen : Bool -> IO () -> IO ()
onlyWhen condition task =
    if condition then
        task

    else
        succeed ()


onlyWhenNot : Bool -> IO () -> IO ()
onlyWhenNot condition task =
    if not condition then
        task

    else
        succeed ()


onlyWhen_ : IO Bool -> IO () -> IO ()
onlyWhen_ conditionTask task =
    conditionTask
        |> BackendTask.andThen
            (\condition ->
                if condition then
                    task

                else
                    succeed ()
            )



-- BackendTask.map2
--     (\condition val ->
--         (if condition then
--             fn val |> discardAndThen (succeed val)
--          else
--             succeed val
--         )
--             |> debug ("🔴  got condition: " ++ Debug.toString condition)
--     )
--     (debug "conditionTask" <| conditionTask)
--     (debug "task task" <| task)


start : IO ()
start =
    BackendTask.succeed ()


end : IO a -> IO ()
end previous =
    previous |> BackendTask.map (\_ -> ())


endWith : b -> IO a -> IO b
endWith val previous =
    previous |> BackendTask.map (\_ -> val)



-- ignoreErrors : IO a -> IO ()
-- ignoreErrors previous =
--     previous |> BackendTask.map (\_ -> ()) |> BackendTask.onError (\err -> succeed ())


ignoreErrors : a -> IO a -> IO a
ignoreErrors default task =
    BackendTask.onError (\_ -> BackendTask.succeed default) task


isMacOS : IO Bool
isMacOS =
    IO.Env.getPlatform
        |> debug "👀💻"
        |> BackendTask.map (\platform -> platform == IO.Env.MacOS)


logErrorDetail functionName err =
    Script.log ("❌ " ++ functionName ++ ":" ++ Debug.toString err)
        |> BackendTask.andThen (\v -> BackendTask.fail err)


logErrorDetail_ identifier previous =
    previous
        |> BackendTask.onError
            (\err ->
                Script.log ("❌ " ++ identifier ++ " : " ++ Debug.toString err)
                    |> BackendTask.andThen (\v -> BackendTask.fail err)
            )



-- IO.Disk


append =
    IO.Disk.append


changeDirectory =
    IO.Disk.changeDirectory


changeDirectory_ =
    IO.Disk.changeDirectory_


currentDirectory =
    IO.Disk.currentDirectory


withinDirectory =
    IO.Disk.withinDirectory


withinDirectory_ =
    IO.Disk.withinDirectory_


copy =
    IO.Disk.copy


copy_ =
    IO.Disk.copy_


copyToCurrent from =
    with currentDirectory
        (\currentDir ->
            -- Both files and directories should end up inside the current directory, not overwriting it
            copy from (currentDir ++ "/")
        )


copyToCurrent_ from =
    passthrough (copyToCurrent from)


doesPathExist =
    IO.Disk.doesPathExist


homeDirectory =
    IO.Disk.homeDirectory


mkdir =
    IO.Disk.mkdir


mkdir_ =
    IO.Disk.mkdir_


mkdirs =
    IO.Disk.mkdirs


mkdirs_ =
    IO.Disk.mkdirs_


move =
    IO.Disk.move


move_ =
    IO.Disk.move_


symlink =
    IO.Disk.symlink


symlink_ =
    IO.Disk.symlink_


nukeAndRecreateDir_ =
    IO.Disk.nukeAndRecreateDir_


pathMissing =
    IO.Disk.pathMissing


read =
    IO.Disk.read


remove =
    IO.Disk.remove


removeAll =
    IO.Disk.removeAll


removeAll_ =
    IO.Disk.removeAll_


removeOrContinue =
    IO.Disk.removeOrContinue


removeOrContinue_ =
    IO.Disk.removeOrContinue_


remove_ =
    IO.Disk.remove_


replaceInFile =
    IO.Disk.replaceInFile


replaceInFile_ =
    IO.Disk.replaceInFile_


touch =
    IO.Disk.touch


touch_ =
    IO.Disk.touch_


withFileIfExists =
    IO.Disk.withFileIfExists


withFileIfExists_ =
    IO.Disk.withFileIfExists_


write =
    IO.Disk.write


write_ =
    IO.Disk.write_



-- IO.Exec


bash =
    IO.Exec.bash


bashStream =
    IO.Exec.bashStream


bashStream_ =
    IO.Exec.bashStream_


bash_ =
    IO.Exec.bash_


die =
    IO.Exec.die


die_ =
    IO.Exec.die_


exec =
    IO.Exec.exec


execStream =
    IO.Exec.execStream


execStream_ =
    IO.Exec.execStream_


exec_ =
    IO.Exec.exec_


exit =
    IO.Exec.exit


exit_ =
    IO.Exec.exit_


sleep =
    IO.Exec.sleep


sleep_ =
    IO.Exec.sleep_



-- IO.Env


requireEnv =
    IO.Env.requireEnv


readEnv =
    IO.Env.readEnv



-- IO.Custom


getFreePort =
    IO.Custom.getFreePort

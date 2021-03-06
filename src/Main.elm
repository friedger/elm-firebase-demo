module Main exposing (main)

import Html
import Firebase.Firebase as FB
import App exposing (..)


main =
    Html.programWithFlags
        { init = init
        , update = update
        , view = view
        , subscriptions =
            always (FB.subscriptions FBMsgHandler)
        }

module Model exposing (..)

import Json.Decode as Json exposing (..)
import Json.Encode as E
import Dict exposing (Dict)
import List as L
import Firebase.Firebase as FB


type Page
    = Loading
    | Login
    | Register
    | Picker


type alias Model =
    { page : Page
    , email : String
    , password : String
    , password2 : String
    , user : FB.FBUser
    , xmas : Dict String UserData
    , userMessage : String
    , editor : Present
    , editorCollapsed : Bool
    , isPhase2 : Bool
    , showSettings : Bool
    }


blank : Model
blank =
    { page = Loading
    , email = ""
    , password = ""
    , password2 = ""
    , user = FB.init
    , xmas = Dict.empty
    , userMessage = ""
    , editor = blankPresent
    , editorCollapsed = True
    , isPhase2 = False
    , showSettings = False
    }


type alias UserData =
    { meta : UserMeta
    , presents : Dict String Present
    }


type alias UserMeta =
    { name : String
    }


type alias Present =
    { uid : Maybe String
    , description : String
    , link : Maybe String
    , takenBy : Maybe String
    }


blankPresent : Present
blankPresent =
    { uid = Nothing
    , description = ""
    , link = Nothing
    , takenBy = Nothing
    }



-- Model update helpers


updateEditor : (Present -> Present) -> Model -> Model
updateEditor fn model =
    { model | editor = fn model.editor }


setDisplayName : String -> Model -> Model
setDisplayName displayName model =
    let
        user =
            model.user
    in
        { model | user = { user | displayName = Just displayName } }



-- DECODER


decoderXmas : Decoder (Dict String UserData)
decoderXmas =
    field "value" <|
        oneOf
            [ keyValuePairs decodeUserData
                |> map (L.map converter >> L.filterMap identity >> Dict.fromList)

            --  handle case where the database starts empty
            , null Dict.empty
            ]


converter : ( a, Maybe b ) -> Maybe ( a, b )
converter ( a, b ) =
    case b of
        Just b_ ->
            Just ( a, b_ )

        Nothing ->
            Nothing


decodeUserData : Decoder (Maybe UserData)
decodeUserData =
    oneOf
        [ map Just <|
            map2 UserData
                (field "meta" decoderMeta)
                (Json.oneOf [ field "presents" decodePresents, Json.succeed Dict.empty ])
        , succeed Nothing
        ]


decodePresents : Decoder (Dict String Present)
decodePresents =
    let
        go ( id, p ) ps =
            case decodeValue decoderPresent p of
                Ok ( des, lnk, tk ) ->
                    Dict.insert id (Present (Just id) des lnk tk) ps

                Err err ->
                    ps
    in
        keyValuePairs value
            |> andThen (L.foldl go Dict.empty >> succeed)


decoderPresent : Decoder ( String, Maybe String, Maybe String )
decoderPresent =
    map3 (,,)
        (field "description" string)
        (maybe <| field "link" string)
        (maybe <| field "takenBy" string)


decoderMeta : Decoder UserMeta
decoderMeta =
    Json.map UserMeta
        -- (field "uid" string)
        (field "name" string)


decoderError : Decoder String
decoderError =
    field "message" string



-- Encoders


encodePresent : Present -> E.Value
encodePresent { description, link, takenBy } =
    let
        commonData =
            [ ( "description", Just description ), ( "takenBy", takenBy ) ]

        dataToEncode =
            case link of
                Just link_ ->
                    ( "link", Just link_ ) :: commonData

                Nothing ->
                    commonData
    in
        dataToEncode
            |> L.filterMap encodeMaybe
            |> E.object


encodeMaybe : ( String, Maybe String ) -> Maybe ( String, E.Value )
encodeMaybe ( s, v ) =
    Maybe.map (E.string >> ((,) s)) v

module Store.Shop (Model, init, Action, update) where

import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import Json.Decode as JD
import Json.Decode.Pipeline as JDP
import ElmFire


--------------------------------------------------------------------------------


type alias Model =
  { name : String }



--------------------------------------------------------------------------------


decoder : JD.Decoder Model
decoder =
  JDP.decode Model
    |>JDP.required "name" JD.string


--------------------------------------------------------------------------------


init : ElmFire.Location -> ( Model, Effects Action )
init location =
  ( { name = "" }
  , ElmFire.once
      (ElmFire.valueChanged ElmFire.noOrder)
      location
      |> Task.toResult
      |> Task.map QueryResult
      |> Effects.task
  )


type Action
  = QueryResult (Result ElmFire.Error ElmFire.Snapshot)


update : Action -> Model -> Model
update action model =
  case action of
    QueryResult (Err error) ->
      always model <|
        Debug.log "Firebase: shop query error" error

    QueryResult (Ok snapshot) ->
      case JD.decodeValue decoder snapshot.value of
        Err error ->
          always model <|
            Debug.log "Firebase: shop decoding error" error

        Ok shop ->
          shop

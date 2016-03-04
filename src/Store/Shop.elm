module Store.Shop
  ( Model, init, Action, update, Shop, shop )
  where

import Signal exposing (Address, message, forwardTo)
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import Json.Encode as JE
import Json.Decode as JD exposing ((:=))
import ElmFire

--------------------------------------------------------------------------------

type alias Model =
  { name : String
  }

--------------------------------------------------------------------------------

decoder : JD.Decoder Model
decoder =
  JD.object1
    Model
      ("name" := JD.string)

--------------------------------------------------------------------------------

init : ElmFire.Location -> (Model, Effects Action)
init location =
  ( { name = ""
    }
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
    QueryResult result ->
      case result of
        Err error ->
          let _ = Debug.log "Firebase: shop query error" error
          in model
        Ok snapshot ->
          case JD.decodeValue decoder snapshot.value of
            Err error ->
              let _ = Debug.log "Firebase: shop decoding error" error
              in model
            Ok shop ->
              shop

type alias Shop = Model

shop : Model -> Shop
shop model =
  model

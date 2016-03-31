module Store.Content (Model, init, Action, update) where

import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import Json.Decode as JD exposing ((:=))
import ElmFire

import Types exposing (..)

--------------------------------------------------------------------------------


type alias Model = Maybe String


decoder : JD.Decoder String
decoder = ("body" := JD.string)


--------------------------------------------------------------------------------


init : ElmFire.Location -> Slug -> ( Model, Effects Action )
init location slug =
  ( Nothing
  , ElmFire.once
      ( ElmFire.valueChanged ElmFire.noOrder )
      ( location |> ElmFire.sub slug )
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
      always Nothing <|
        Debug.log "Firebase: content query error" error

    QueryResult (Ok snapshot) ->
      case JD.decodeValue decoder snapshot.value of
        Err error ->
          always Nothing <|
            Debug.log "Firebase: content decoding error" error

        Ok body ->
          Just body

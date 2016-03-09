module Store.Issues (Model, init, Action, update, Issue, toList) where

import Dict exposing (Dict)
import Signal exposing (Address, message, forwardTo)
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import Json.Encode as JE
import Json.Decode as JD exposing ((:=))

import Debug

import ElmFire
import ElmFire.Dict

import CommonTypes exposing (Slug)

--------------------------------------------------------------------------------

type alias Model = Dict Slug Issue

type alias Issue =
  { title: String
  }


--------------------------------------------------------------------------------

syncConfig : ElmFire.Location -> ElmFire.Dict.Config Issue
syncConfig location =
  { location = location
  , orderOptions = ElmFire.orderByKey ElmFire.noRange ElmFire.noLimit
  , encoder =
      \issue -> JE.object
        [ ("title", JE.string issue.title)
        ]
  , decoder =
      ( JD.object1 Issue
          ("title" := JD.string)
      )
  }

--------------------------------------------------------------------------------

init : Address Action -> ElmFire.Location -> (Model, Effects Action)
init address location =
  ( Dict.empty
  , ElmFire.Dict.getDict
      (syncConfig location)
    |> Task.toResult
    |> Task.map (QueryResult)
    |> Effects.task
  )

type Action
  = QueryResult (Result ElmFire.Error Model)

update : Action -> Model -> Model
update action model =
  case action of

    QueryResult (Err error) ->
      always model <|
        Debug.log "Firebase: issues query error" error

    QueryResult (Ok model1) ->
      model1

toList : Model -> List (Slug, Issue)
toList model =
  Dict.toList model

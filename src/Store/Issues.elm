module Store.Issues
  ( Model, init, Action, update
  , Issue, noIssues, toList, get
  ) where

import Dict exposing (Dict)
import Signal exposing (Address, message, forwardTo)
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import Json.Encode as JE
import Json.Decode as JD exposing ((:=))

import ElmFire
import ElmFire.Dict

import Types exposing (Slug)

--------------------------------------------------------------------------------

type alias Model = Dict Slug Issue

type alias Issue =
  { title : String
  , teaser : Maybe String
  }

noIssues : Model
noIssues = Dict.empty


--------------------------------------------------------------------------------

syncConfig : ElmFire.Location -> ElmFire.Dict.Config Issue
syncConfig location =
  { location = location
  , orderOptions = ElmFire.orderByKey ElmFire.noRange ElmFire.noLimit
  , encoder =
      -- Encoding not in use for now, but let's give an encoder anyway.
      \issue -> JE.object
        [ ( "title", JE.string issue.title )
        , ( "teaser"
          , case issue.teaser of
              Just teaser -> JE.string teaser
              Nothing -> JE.null
          )
        ]
  , decoder =
      ( JD.object2 Issue
          ( "title" := JD.string )
          ( JD.maybe ("teaser" := JD.string) )
      )
  }

--------------------------------------------------------------------------------

init : Address Action -> ElmFire.Location -> (Model, Effects Action)
init address location =
  ( Dict.empty
  , ElmFire.Dict.getDict
      (syncConfig location)
    |> Task.toResult
    |> Task.map QueryResult
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

get : Slug -> Model -> Maybe Issue
get slug model =
  Dict.get slug model

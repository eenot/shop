module Components.Stage (Model, init, Action, update, Context, view) where

import Signal exposing (Address, forwardTo)
import Json.Encode as JE
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import Html.Lazy as HL

import CommonTypes exposing (Slug)
import Store.Issues as Issues exposing (Issue)
import Route exposing (Route)


type alias Model =
  { slug : Slug
  , issue : Issue
  }


init : Slug -> Issue -> Model
init slug issue =
  { slug = slug
  , issue = issue
  }


type Action =
  Dummy


update : Action -> Model -> Model
update action model =
  case action of
    Dummy ->
      model


type alias Context =
  { -- dummy : ()
  }

view : Address Action -> Context -> Model -> Html
view =
  HL.lazy3 viewThunk

viewThunk : Address Action -> Context -> Model -> Html
viewThunk address context { slug, issue } =
  H.div
    [ HA.class "stage" ]
    [ H.div [ HA.class "title" ] [ H.text issue.title ]
    , H.div [ HA.class "slug" ] [ H.text slug ]
    , case issue.teaser of
        Just teaser ->
          H.div
            [ HA.class "teaser"
            , HA.property "innerHTML" <| JE.string teaser
            ]
            []
        Nothing ->
          H.div
            [ HA.class "teaser missing" ]
            [ H.text "No teaser" ]
    ]

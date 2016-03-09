module Components.Catalog (Model, init, Action, update, Context, view, setIssues) where

import Signal exposing (Address, forwardTo)
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE

import CommonTypes exposing (Slug)
import Store.Issues as Issues exposing (Issue)
import Route exposing (Route)


type alias Model =
  { issues : List (Slug, Issues.Issue)
  , total : Int
  , size : Int
  , position: Int
  , visible : List (Slug, Issues.Issue)
  }


init : Int -> Model
init size =
  { issues = []
  , total = 0
  , size = size
  , position = 0
  , visible = []
  }


type Action =
  Scroll Int


update : Action -> Model -> Model
update action model =
  case action of
    Scroll amount ->
      clip { model | position = model.position + amount }


setIssues : Issues.Model -> Model -> Model
setIssues issues model =
  let
    list = Issues.toList issues
  in
    clip
      { model
      | issues = list
      , total = List.length list
      , position = 0x7ffffffffffff
      }


clip : Model -> Model
clip model =
  let
    position = model.position |> min (model.total - model.size) |> max 0
  in
    { model
    | position = position
    , visible = model.issues |> List.drop position |> List.take model.size
    }


type alias Context =
  { route : Route
  , setRouteAddress : Address Route
  }


view : Address Action -> Context -> Model -> Html
view address context model =
  H.div
    [ HA.class "catalog" ]
    [ H.ul
        []
        ( List.map (viewIssue address context) model.visible )
    , H.button
        [ HA.disabled (model.position <= 0)
        , HE.onClick address <| Scroll (0 - model.size)
        ]
        [ H.text "Previous" ]
    , H.button
        [ HA.disabled (model.position >= model.total - model.size)
        , HE.onClick address <| Scroll (0 + model.size) ]
        [ H.text "Next" ]
    ]


viewIssue : Address Action -> Context -> (Slug, Issue) -> Html
viewIssue address context (slug, issue) =
  let
    isCurrentRoute = context.route == Route.Issue slug
  in
    H.li
      [ HA.classList
          [ ("item", True)
          , ("selected", isCurrentRoute)
          ]
      ]
      [ H.button
          [ HA.disabled isCurrentRoute
          , HE.onClick context.setRouteAddress <| Route.Issue slug
          ]
          [ H.text <| slug ]
      ]

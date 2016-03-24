module Components.Catalog
  ( Model, init, Action, update, view
  , setSize, setIssues
  ) where

import Dict exposing (Dict)
import Signal exposing (Address, forwardTo)
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE

import Types exposing (Slug)
import Store.Issues as Issues exposing (Issue)
import Store.Customer as Customer
import Route exposing (Route)


type alias Model =
  { issues : List (Slug, Issues.Issue)
  , total : Int
  , size : Int
  , position: Int
  , visible : List (Slug, Issues.Issue)
  }


init : Model
init =
  { issues = []
  , total = 0
  , size = 0
  , position = 0
  , visible = []
  }


type Action =
  Scroll Int


update : Action -> Model -> Model
update action model =
  case action of
    Scroll amount ->
      adaptVisible { model | position = model.position + amount }


setSize : Int -> Model -> Model
setSize size model =
  adaptVisible
    { model | size = size }


setIssues : Issues.Model -> Model -> Model
setIssues issues model =
  let
    list = Issues.toList issues
  in
    adaptVisible
      { model
      | issues = list
      , total = List.length list
      , position = 0x7ffffffffffff
      }


adaptVisible : Model -> Model
adaptVisible model =
  let
    position = model.position |> min (model.total - model.size) |> max 0
  in
    { model
    | position = position
    , visible = model.issues |> List.drop position |> List.take model.size
    }


type alias Context a =
  { a
  | setRouteAddress : Address Route
  , route : Route
  , customer : Maybe Customer.Model
  }


view : Address Action -> Context a -> Model -> Html
view address context model =
  H.div
    [ HA.class "catalog" ]
    [ H.ul
      [ HA.classList
          [ ("signed-in", context.customer /= Nothing) ]
      ]
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


viewIssue : Address Action -> Context a -> (Slug, Issue) -> Html
viewIssue address context (slug, issue) =
  let
    isCurrentRoute = context.route == Route.Issue slug
    paid =
      case context.customer of
        Just { purchases } ->
          Just (Dict.member slug purchases)
        Nothing ->
          Nothing
  in
    H.li
      [ HA.classList
          [ ("item", True)
          , ("selected", isCurrentRoute)
          , ("paid", paid == Just True)
          , ("unpaid", paid == Just False)
          ]
      ]
      [ H.button
          [ HA.disabled isCurrentRoute
          , HE.onClick context.setRouteAddress <| Route.Issue slug
          ]
          [ H.text <| slug ]
      ]

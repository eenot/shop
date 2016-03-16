module Components.Header (Model, init, Action, update, Context, view) where

import Signal exposing (Address, forwardTo)
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE

import Store.Shop as Shop
import Store.Customer as Customer
import Route exposing (Route)


type alias Model =
  {}


init : Model
init =
  {}


type alias Action =
  ()


update : Action -> Model -> Model
update action model =
  model


type alias Context a =
  { a
  | focusSignInAddress : Address ()
  , setRouteAddress : Address Route
  , signOutAddress : Address ()
  , shop : Shop.Model
  , route : Route
  , customer : Maybe Customer.Model
  }


view : Address Action -> Context a -> Model -> Html
view address context model =
  H.div
    [ HA.class "header" ]
    [ H.div
        [ HA.class "shop-name" ]
        [ H.text context.shop.name ]
    , case context.customer of
        Just customer ->
          H.div
            [ HA.class "email" ]
            [ H.text customer.email ]
        Nothing ->
          H.text ""
    , H.div
        [ HA.class "menu" ]
        [ H.button
            [ HA.disabled (context.route == Route.All)
            , HE.onClick context.setRouteAddress Route.All
            ]
            [ H.text "All issues" ]
        , case context.customer of
            Just customer ->
              H.button
                [ HE.onClick context.signOutAddress ()
                ]
                [ H.text "Sign-out" ]
            Nothing ->
              H.button
                [ HE.onClick context.focusSignInAddress ()
                ]
                [ H.text "Sign-in" ]
        ]
    ]


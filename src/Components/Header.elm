module Components.Header (Model, init, Action, update, Context, view, setShop) where

import Signal exposing (Address, forwardTo)
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE

import Store.Shop as Shop
import Route exposing (Route)


type alias Model =
  { shopName : String }


init : Model
init =
  { shopName = "" }


type alias Action =
  ()


update : Action -> Model -> Model
update action model =
  model


type alias Context =
  { route : Route
  , setRouteAddress : Address Route
  }


view : Address Action -> Context -> Model -> Html
view address context model =
  H.div
    [ HA.class "header" ]
    [ H.div
        [ HA.class "shop-name" ]
        [ H.text model.shopName ]
    , H.div
        [ HA.class "menu" ]
        [ H.button
            [ HA.disabled (context.route == Route.All)
            , HE.onClick context.setRouteAddress <| Route.All
            ]
            [ H.text "All issues" ]
        ]
    ]


-- TODO: Possibly simpler:
--   Don't include shopName in local model. Give it as a context to view function instead.
setShop : Shop.Model -> Model -> Model
setShop shop model =
  { model | shopName = shop.name }

module Components.Header
  ( Model, init, Action, update, view, setShop )
  where

import Signal exposing (Address, forwardTo)
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE

import Store.Shop as Shop

type alias Model =
  { shopName : String
  }

init : Model
init =
  { shopName = ""
  }

type alias Action
  = ()

update : Action -> Model -> Model
update action model =
  model

view : Address Action -> Model -> Html
view address model =
  H.div
    [ HA.class "header" ]
    [ H.text model.shopName ]

setShop : Shop.Shop -> Model -> Model
setShop shop model =
  { model | shopName = shop.name }

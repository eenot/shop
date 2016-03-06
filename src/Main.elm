module Main (..) where

import Signal exposing (Mailbox, Address, mailbox, message, forwardTo)
import Html as H exposing (Html)


-- import Html.Attributes as HA
-- import Html.Events as HE

import StartApp
import Task exposing (Task)
import Effects exposing (Effects, Never)
import ElmFire
import Store.Shop as Shop
import Components.Header as Header


--------------------------------------------------------------------------------


firebaseRoot : ElmFire.Location
firebaseRoot =
  ElmFire.fromUrl "https://plentifulshop-demo.firebaseio.com/"



--------------------------------------------------------------------------------


appConfig : StartApp.Config Model Action
appConfig =
  { init = init
  , update = update
  , view = view
  , inputs = [ serverInput.signal ]
  }


app : StartApp.App Model
app =
  StartApp.start appConfig


serverInput : Mailbox Action
serverInput =
  mailbox NoOp


port runEffects : Signal (Task Never ())
port runEffects =
  app.tasks


main : Signal Html
main =
  app.html



--------------------------------------------------------------------------------


type alias Model =
  { shop : Shop.Model
  , header : Header.Model
  }


init : ( Model, Effects Action )
init =
  let
    ( shopModel, shopEffects ) =
      Shop.init (firebaseRoot |> ElmFire.sub "shop")
  in
    ( { shop = shopModel
      , header = Header.init
      }
    , Effects.map ShopAction shopEffects
    )


type Action
  = NoOp
  | ShopAction Shop.Action
  | HeaderAction Header.Action


update : Action -> Model -> ( Model, Effects Action )
update action model =
  case action of
    NoOp ->
      ( model, Effects.none )

    ShopAction shopAction ->
      let
        shopModel =
          Shop.update shopAction model.shop
      in
        ( { model
            | shop = shopModel
            , header = Header.setShop shopModel model.header
          }
        , Effects.none
        )

    HeaderAction headerAction ->
      ( { model
          | header = Header.update headerAction model.header
        }
      , Effects.none
      )


view : Address Action -> Model -> Html
view address model =
  H.div
    []
    [ Header.view
        (forwardTo address HeaderAction)
        model.header
    ]

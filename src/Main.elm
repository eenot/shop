module Main (main) where

import Signal exposing (Mailbox, Address, mailbox, message, forwardTo)
import Html as H exposing (Html)
import StartApp
import Task exposing (Task)
import Effects exposing (Effects, Never)
import History
import ElmFire

import Store.Shop as Shop
import Store.Issues as Issues
import Components.Page as Page


--------------------------------------------------------------------------------


firebaseRoot : ElmFire.Location
firebaseRoot =
  ElmFire.fromUrl "https://plentifulshop-demo.firebaseio.com/"



--------------------------------------------------------------------------------


appConfig : StartApp.Config Model Action
appConfig =
  { init = init initialPath
  , update = update
  , view = view
  , inputs =
      [ serverInput.signal
      , Signal.map PathChange History.path
      ]
  }


app : StartApp.App Model
app =
  StartApp.start appConfig


serverInput : Mailbox Action
serverInput =
  mailbox NoOp


port initialPath : String


port runEffects : Signal (Task Never ())
port runEffects =
  app.tasks


main : Signal Html
main =
  app.html



--------------------------------------------------------------------------------


type alias Model =
  { shop : Shop.Model
  , issues: Issues.Model
  , page : Page.Model
  }


init : String -> ( Model, Effects Action )
init initialPath =
  let
    ( shopModel, shopEffects ) =
        Shop.init
          (firebaseRoot |> ElmFire.sub "shop")
    ( issuesModel, issuesEffects ) =
        Issues.init
          (forwardTo serverInput.address IssuesAction)
          (firebaseRoot |> ElmFire.sub "issues")
    ( pageModel, pageEffects ) = Page.init
    ( model, effects ) =
      update
        ( PathChange initialPath )
        { shop = shopModel
        , issues = issuesModel
        , page = pageModel
        }
  in
    ( model
    , Effects.batch
        [ Effects.map ShopAction shopEffects
        , Effects.map IssuesAction issuesEffects
        , Effects.map PageAction pageEffects
        , effects
        ]
    )


type Action
  = NoOp
  | PathChange String
  | ShopAction Shop.Action
  | IssuesAction Issues.Action
  | PageAction Page.Action


update : Action -> Model -> ( Model, Effects Action )
update action model =
  case action of
    NoOp ->
      ( model, Effects.none )

    PathChange path ->
      -- TODO: To be implemented. Just loggin for now
      always
        ( model, Effects.none )
        ( Debug.log "PathChange" path )


    ShopAction shopAction ->
      let
        shopModel = Shop.update shopAction model.shop
      in
        ( { model
            | shop = shopModel
            , page = Page.setShop shopModel model.page
          }
        , Effects.none
        )

    IssuesAction issuesAction ->
      let
        issuesModel = Issues.update issuesAction model.issues
      in
        ( { model
            | issues = issuesModel
            , page = Page.setIssues issuesModel model.page
          }
        , Effects.none
        )

    PageAction pageAction ->
      let
        ( pageModel, pageEffects ) =
          Page.update pageAction model.page
      in
        ( { model
            | page = pageModel
          }
        , Effects.map PageAction pageEffects
        )


view : Address Action -> Model -> Html
view address model =
  H.div
    []
    [ Page.view
        (forwardTo address PageAction)
        model.page
    ]

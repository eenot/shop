module Main (main) where

import Signal exposing (Mailbox, Address, mailbox, message, forwardTo)
import Html as H exposing (Html)
import StartApp
import Task exposing (Task)
import Effects exposing (Effects, Never)
import History
import ElmFire

import Config
import Route
import Store.Shop as Shop
import Store.Issues as Issues
import Store.Customer as Customer
import Components.Page as Page


--------------------------------------------------------------------------------


firebaseRoot : ElmFire.Location
firebaseRoot =
  ElmFire.fromUrl Config.firebaseUrl


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

-- Use auxiliary JS code to set the focus to sign-in email field

focusSignIn : Mailbox ()
focusSignIn = mailbox ()

port runFocusSignIn : Signal ()
port runFocusSignIn = focusSignIn.signal

--------------------------------------------------------------------------------


type alias Model =
  { shop : Shop.Model
  , issues : Issues.Model
  , customer : Maybe Customer.Model
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
    ( pageModel, pageEffects ) =
      Page.init (forwardTo serverInput.address PageAction)
    ( model, effects ) =
      update
        ( PathChange initialPath )
        { shop = shopModel
        , issues = issuesModel
        , customer = Nothing
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
  | CustomerAction Customer.Action
  | PageAction Page.Action


update : Action -> Model -> ( Model, Effects Action )
update action model =
  case action of
    NoOp ->
      ( model, Effects.none )

    PathChange path ->
      let
        route =
          Maybe.withDefault
            Route.Home
            (Route.match path)
        ( pageModel, pageEffects ) =
          Page.setRoute route model.page
      in
        ( { model | page = pageModel }
        , Effects.map PageAction pageEffects
        )

    ShopAction shopAction ->
      ( { model | shop = Shop.update shopAction model.shop }
      , Effects.none
      )

    IssuesAction issuesAction ->
      let
        issuesModel =
          Issues.update issuesAction model.issues
        ( pageModel, pageEffects ) =
          Page.setIssues issuesModel model.page
      in
        ( { model
            | issues = issuesModel
            , page = pageModel
          }
        , Effects.map PageAction pageEffects
        )

    CustomerAction customerAction ->
      let
        customerModel =
          Maybe.map (Customer.update customerAction) model.customer
      in
        ( { model
            | customer = customerModel
            , page = Page.setCustomer customerModel model.page
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
        { focusSignInAddress = focusSignIn.address
        , shop = model.shop
        }
        model.page
    ]

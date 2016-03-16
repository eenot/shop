module Components.Page
  ( Model, init, Action, update, view
  , setIssues, setRoute, setCustomer
  ) where

import Signal exposing (Mailbox, Address, mailbox, message, forwardTo)
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import History
import Html as H exposing (Html)
import Html.Attributes as HA

import ElmFire
import ElmFire.Auth

import Types exposing (Slug)
import Config
import Route exposing (Route)
import Store.Shop as Shop
import Store.Issues as Issues
import Store.Customer as Customer
import Components.Header as Header
import Components.Catalog as Catalog
import Components.Stage as Stage


--------------------------------------------------------------------------------


type alias Model =
  { address : Address Action
  , route : Route
  , header : Header.Model
  , catalog : Catalog.Model
  , body : Body
  , issues : Issues.Model
  , customer : Maybe Customer.Model
  }


type Body
  = Stage Stage.Model
  | Missing Slug
  | None


init : Address Action -> ( Model, Effects Action )
init address =
  ( { address = address
    , route = Route.Home
    , header = Header.init
    , catalog = Catalog.init
    , body = None
    , issues = Issues.noIssues
    , customer = Nothing
    }
  , ElmFire.Auth.subscribeAuth
      ( \authMaybe -> Signal.send address (AuthChange authMaybe) )
      (ElmFire.fromUrl Config.firebaseUrl)
    |> Task.toResult
    |> Task.map (LogElmFireError "Firebase: subscribing to authentication state error")
    |> Effects.task
  )


type Action
  = NoOp
  | CustomerAction Customer.Action
  | HeaderAction Header.Action
  | CatalogAction Catalog.Action
  | StageAction Stage.Action
  | SetRoute Route
  | AuthChange (Maybe ElmFire.Auth.Authentication)
  | LogElmFireError String (Result ElmFire.Error ())
  | SignOut ()



update : Action -> Model -> ( Model, Effects Action )
update action model =
  case action of
    NoOp ->
      ( model, Effects.none )

    CustomerAction customerAction ->
      let
        customerModel =
          Maybe.map
            (Customer.update customerAction)
            model.customer
        ( bodyModel, bodyEffects ) =
          case model.body of
            Stage stage ->
              let
                ( stageModel, stageEffects ) =
                  Stage.customerChanged customerModel stage
              in
                ( Stage stageModel
                , Effects.map StageAction stageEffects
                )
            otherBody ->
              ( otherBody, Effects.none )
      in
        ( { model
          | customer = customerModel
          , body = bodyModel
          }
        , bodyEffects
        )

    HeaderAction headerAction ->
      ( { model | header = Header.update headerAction model.header }
      , Effects.none
      )

    CatalogAction catalogAction ->
      ( { model | catalog = Catalog.update catalogAction model.catalog }
      , Effects.none
      )

    StageAction stageAction ->
      case model.body of
        Stage stage ->
          let
            ( stageModel, stageEffects ) =
              Stage.update { customer = model.customer } stageAction stage
          in
            ( { model | body = Stage stageModel }
            , Effects.map StageAction stageEffects
            )
        body ->
          ( model, Effects.none )

    SetRoute route ->
      ( model
      , History.setPath (Route.path route)
          |> Task.map (always NoOp)
          |> Effects.task
      )

    SignOut () ->
      ( model
      , ElmFire.Auth.unauthenticate
          (ElmFire.fromUrl Config.firebaseUrl)
        |> Task.toResult
        |> Task.map (LogElmFireError "Firebase: unauthentication error")
        |> Effects.task
      )

    AuthChange Nothing ->
      ( { model | customer = Nothing }
      , Effects.none
      )

    AuthChange (Just authentication) ->
      let
        ( customerModel, customerEffects ) =
          Customer.init
            ( forwardTo model.address CustomerAction )
            ( ElmFire.fromUrl Config.firebaseUrl
               |> ElmFire.sub "customers"
            )
            authentication.uid
      in
        ( { model | customer = Just customerModel }
        , Effects.map CustomerAction customerEffects
        )

    LogElmFireError description subscriptionResult ->
      let _ = case subscriptionResult of
        Err error ->
          always () <| Debug.log
            description error
        Ok () -> ()
      in
        ( model, Effects.none )

type alias Context a =
  { a
  | focusSignInAddress : Address ()
  , shop : Shop.Model
  }

view : Address Action -> Context a -> Model -> Html
view address context model =
  let
    subContext =
      { focusSignInAddress = context.focusSignInAddress
      , setRouteAddress = forwardTo address SetRoute
      , signOutAddress = forwardTo address SignOut
      , shop = context.shop
      , route = model.route
      , customer = model.customer
      }
  in
    H.div
      []
      [ Header.view
          (forwardTo address HeaderAction)
          subContext
          model.header
      , Catalog.view
          (forwardTo address CatalogAction)
          subContext
          model.catalog
      , case model.body of
          Stage stage ->
            Stage.view
              (forwardTo address StageAction)
              stage
          Missing slug ->
            H.div
              [ HA.class "waiting" ]
              [ H.text <| "Waiting for issue content " ++ slug ]
          None ->
            H.text ""
      ]

setIssues : Issues.Model -> Model -> ( Model, Effects Action )
setIssues issues model =
  { model
  | issues = issues
  , catalog = Catalog.setIssues issues model.catalog
  }
  |> adaptBody

setRoute : Route -> Model -> ( Model, Effects Action )
setRoute route model =
  { model
  | route = route
  , catalog =
      Catalog.setSize
        ( if route == Route.All
          then .showAll Config.catalogSize
          else .besideStage Config.catalogSize
        )
        model.catalog
  }
  |> adaptBody

setCustomer : Maybe Customer.Model -> Model -> Model
setCustomer customer model =
  { model | customer = customer }

adaptBody : Model -> ( Model, Effects Action )
adaptBody model =
  let
    ( bodyModel, bodyEffects ) =
      case model.route of
        Route.Issue slug ->
          case Issues.get slug model.issues of
            Just issue ->
              let
                ( stageModel, stageEffects ) =
                  Stage.init slug issue model.customer
              in
                ( Stage stageModel
                , Effects.map StageAction stageEffects
                )
            Nothing ->
              ( Missing slug, Effects.none )
        _ ->
          ( None, Effects.none )
  in
    ( { model | body = bodyModel }
    , bodyEffects
    )

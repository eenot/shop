module Components.Stage
  ( Model, init, Action, update, view
  , customerChanged
  ) where

import Signal exposing (Address, forwardTo)
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import Json.Encode as JE
import Json.Decode as JD exposing ((:=))
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import Html.Lazy as HL
import ElmFire

import Config
import Types exposing (..)
import Store.Issues as Issues exposing (Issue)
import Store.Customer as Customer
import Store.Content as Content
import Route exposing (Route)
import Components.Checkout as Checkout


type alias Model =
  { slug : Slug
  , issue : Issue
  , content : Maybe Content.Model
  , checkout : Maybe Checkout.Model
  }


init : Slug -> Issue -> Maybe Customer.Model -> ( Model, Effects Action )
init slug issue maybeCustomer =
  customerChanged
    maybeCustomer
    { slug = slug
    , issue = issue
    , content = Nothing
    , checkout = Just Checkout.init
    }


type Action
  = CheckoutAction Checkout.Action
  | ContentAction Content.Action


type alias Context =
  { customer : Maybe Customer.Model
  }


update : Context -> Action -> Model -> ( Model, Effects Action )
update context action model =
  case action of
    CheckoutAction checkoutAction ->
      case model.checkout of
        Just checkout ->
          let
            ( checkoutModel, checkoutEffects ) =
              Checkout.update context checkoutAction checkout
          in
          ( { model | checkout = Just checkoutModel }
          , Effects.map CheckoutAction checkoutEffects
          )
        Nothing ->
          ( model, Effects.none )

    ContentAction contentAction ->
      case model.content of
        Just content ->
          ( { model | content = Just (Content.update contentAction content) }
          , Effects.none
          )
        Nothing ->
          ( model, Effects.none )


customerChanged : Maybe Customer.Model -> Model -> ( Model, Effects Action )
customerChanged maybeCustomer model =
  case maybeCustomer of
    Just customer ->
      case Customer.getIssueKey model.slug customer of
        Just issueKey ->
          case model.content of
            Just content ->
              ( model, Effects.none )
            Nothing ->
              let
                ( contentModel, contentEffects ) =
                  Content.init
                    ( ElmFire.fromUrl Config.firebaseUrl |> ElmFire.sub "content" )
                    model.slug
                    issueKey
              in
                ( { model | content = Just contentModel }
                , Effects.map ContentAction contentEffects
                )
        Nothing ->
          ( { model | content = Nothing }
          , Effects.none
          )
    Nothing ->
      ( { model | content = Nothing }
      , Effects.none
      )

view : Address Action -> Model -> Html
view =
  HL.lazy2 viewThunk

viewThunk : Address Action -> Model -> Html
viewThunk address model =
  H.div
    [ HA.class "stage" ]
    [ H.div [ HA.class "title" ] [ H.text model.issue.title ]
    , H.div [ HA.class "slug" ] [ H.text model.slug ]
    , case model.issue.teaser of
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
    , case model.checkout of
        Just checkout ->
          Checkout.view
            (forwardTo address CheckoutAction)
            checkout
        Nothing ->
          H.text ""
    , case model.content of
        Just (Just content) ->
          H.div
            [ HA.class "content"
            , HA.property "innerHTML" <| JE.string content
            ]
            []
        Just Nothing ->
          H.div
            [ HA.class "content fetching" ]
            []
        Nothing ->
          H.text ""
    ]

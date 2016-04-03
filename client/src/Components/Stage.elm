module Components.Stage
  ( Model, init, Action, update, view
  , customerChanged, stripeResponse
  ) where

import Signal exposing (Address, forwardTo)
import Effects exposing (Effects, Never)
import Json.Encode as JE
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Lazy as HL
import ElmFire

import Config
import Types exposing (..)
import Store.Issues as Issues exposing (Issue)
import Store.Customer as Customer
import Store.Content as Content
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


type alias UpdateContext =
  { stripeRequestsAddress : Address Types.StripeRequest
  , customer : Maybe Customer.Model
  }


update : UpdateContext -> Action -> Model -> ( Model, Effects Action )
update context action model =
  case action of
    CheckoutAction checkoutAction ->
      case model.checkout of
        Just checkout ->
          let
            ( checkoutModel, checkoutEffects ) =
              Checkout.update
                { stripeRequestsAddress = context.stripeRequestsAddress
                , slug = model.slug
                , issue = model.issue
                , customer = context.customer
                }
                checkoutAction checkout
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
  let
    addCheckout model =
      case model.checkout of
        Just _ -> model
        Nothing -> { model | checkout = Just Checkout.init }

    ( model1, effects1 ) =
      case maybeCustomer of
        Just customer ->
          if Customer.getIssuePermission model.slug customer
            then
              case model.content of
                Just content ->
                  ( model, Effects.none )
                Nothing ->
                  let
                    ( contentModel, contentEffects ) =
                      Content.init
                        ( ElmFire.fromUrl Config.firebaseUrl |> ElmFire.sub "content" )
                        model.slug
                  in
                    ( { model
                      | content = Just contentModel
                      , checkout = Nothing
                      }
                    , Effects.map ContentAction contentEffects
                    )
            else
              ( addCheckout { model | content = Nothing }
              , Effects.none
              )
        Nothing ->
          ( addCheckout { model | content = Nothing }
          , Effects.none
          )

    model2 = case model1.checkout of
      Just checkout ->
        { model1 | checkout =
            Just <| Checkout.customerChanged maybeCustomer checkout }
      Nothing ->
        model1
    in
      ( model2, effects1 )


stripeResponse : Types.StripeResponse -> Model -> ( Model, Effects Action )
stripeResponse response model =
  case model.checkout of
    Just checkout ->
      let
        ( checkoutModel, checkoutEffects ) =
          Checkout.stripeResponse response checkout
      in
        ( { model | checkout = Just <| checkoutModel }
        , Effects.map CheckoutAction checkoutEffects
        )
    _ ->
      ( model, Effects.none )


type alias ViewContext =
  { customer : Maybe Customer.Model
  }


view : Address Action -> ViewContext -> Model -> Html
view =
  HL.lazy3 viewThunk

viewThunk : Address Action -> ViewContext -> Model -> Html
viewThunk address context model =
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
            { slug = model.slug
            , issue = model.issue
            , customer = context.customer
            }
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

module Components.Checkout (Model, init, Action, update, view) where

import Signal exposing (Address, forwardTo)
import Task exposing (Task)
import Effects exposing (Effects, Never)
import Json.Encode as JE
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import Html.Lazy as HL

import ElmFire
import ElmFire.Auth

import Form as F exposing (Form)
import Form.Validate as FV exposing (Validation)
import Form.Field as FF exposing (Field)
import Form.Input as FI

import Config
import Types exposing (Slug)
import Store.Customer as Customer


type alias Model =
  { form : Form () FormData
  }


type alias FormData =
  { intent : String
  , email : String
  , password : String
  , card : Maybe Card
  }

type alias Card =
  { number : String
  , expiration : String
  , cvc : String
  }


validateForm : Validation () FormData
validateForm =
  FV.form4 FormData
    (FV.get "intent" FV.string)
    (FV.get "email" FV.email)
    (FV.get "password" FV.string)
    ( (FV.get "intent" FV.string)
      `FV.andThen`
      ( \intent -> case intent of
          "signUp" ->
            (FV.get "card"
              (FV.map Just
                (FV.form3 Card
                  (FV.get "number" (FV.string `FV.andThen` FV.nonEmpty))
                  (FV.get "expiration" (FV.string `FV.andThen` FV.nonEmpty))
                  (FV.get "cvc" (FV.string `FV.andThen` FV.nonEmpty))
                )
              )
            )
          _ ->
            (FV.succeed Nothing)
      )
    )


initForm : Form () FormData
initForm =
  F.initial
    [ ("intent", FF.Text "signIn")
    {- Initialization not necessary for empty fields
    , ("email", FF.Text "")
    , ("password", FF.Text "")
    , ("card", FF.group
        []
      )
    -}
    ]
    validateForm

init : Model
init =
  { form = initForm
  }


type Action
  = FormAction F.Action
  | SwitchIntent String
  | Submit
  | AuthResult (Result ElmFire.Error ElmFire.Auth.Authentication)


type alias Context =
  { customer : Maybe Customer.Model
  }


update : Context -> Action -> Model -> ( Model, Effects Action )
update context action model =
  case action of
    FormAction formAction ->
      ( { model | form = F.update formAction model.form }
      , Effects.none
      )
    SwitchIntent intent ->
      ( let
          form1 = F.update
            ( F.Input "intent" <| FF.Text intent )
            model.form
          {- Initialization not necessary for empty fields
          form2 = case intent of
            "signUp" ->
              F.update
                ( F.Input "card" <|
                    FF.group
                      [ ("number", FF.Text "")
                      ]
                )
                form1
            _ ->
              form1
          -}
        in
          { model | form = form1 }
      , Effects.none
      )
    Submit ->
      let
        _ = Debug.log "form = " model.form
        authEffects = case F.getOutput model.form of
          Nothing -> Effects.none
          Just output ->
            case output.intent of
              "signIn" ->
                ElmFire.Auth.authenticate
                  (ElmFire.fromUrl Config.firebaseUrl)
                  [ElmFire.Auth.rememberDefault]
                  (ElmFire.Auth.withPassword output.email output.password)
                |> Task.toResult
                |> Task.map AuthResult
                |> Effects.task
              _ -> Effects.none
      in
        ( model, authEffects )
    AuthResult authResult ->
      -- TODO: Display possible authentication error
      always
      ( model, Effects.none )
      <| Debug.log "authResult" authResult


view : Address Action -> Model -> Html
view address model =
  let
    formAddress = forwardTo address FormAction
    errorFor field =
      case field.liveError of
        Just error ->
          H.span [ HA.class "invalid" ] [ H.text (toString error) ]
        Nothing ->
          H.text ""
    valid = F.getErrors model.form |> List.isEmpty
    intentState = F.getFieldAsString "intent" model.form
  in
    H.div
      [ HA.class "checkout"
      , HA.id "checkout"
      ]
      [ H.div
          [ HA.class "menu" ]
          [
            H.button
            [ HA.disabled False
            , HE.onClick address (SwitchIntent "signIn")
            ]
            [ H.text "Sign-in" ]
          , H.button
            [ HA.disabled False
            , HE.onClick address (SwitchIntent "signUp")
            ]
            [ H.text "Sign-up and buy" ]
          ]
      , H.form
          [ HA.name "checkout" ]
          (
          {-
            -- TODO: Select input for debugging only
            [ FI.selectInput
                [ ("signIn", "signIn")
                , ("signUp", "signUp")
                ]
                intentState
                formAddress
                []
            ]
          ++
          -}
            [ H.div
                [ HA.class "email" ]
                ( let emailState = F.getFieldAsString "email" model.form
                  in
                    [ FI.textInput
                        emailState
                        formAddress
                        [ HA.placeholder "email"
                        , HA.type' "text"
                        ]
                    , errorFor emailState
                    ]
                )
            , H.div
                [ HA.class "password" ]
                ( let passwordState = F.getFieldAsString "password" model.form
                  in
                    [ FI.textInput
                        passwordState
                        formAddress
                        [ HA.placeholder "password"
                        , HA.type' "password"
                        ]
                    , errorFor passwordState
                    ]
                )
            ]
          ++
            ( case intentState.value of
                Just "signUp" ->
                  [ H.div
                      [ HA.class "card" ]
                      ( let
                          numberState = F.getFieldAsString "card.number" model.form
                          expirationState = F.getFieldAsString "card.expiration" model.form
                          cvcState = F.getFieldAsString "card.cvc" model.form
                        in
                          [ FI.textInput
                              numberState
                              formAddress
                              [ HA.placeholder "card number"
                              , HA.type' "text"
                              ]
                          , errorFor numberState
                          , FI.textInput
                              expirationState
                              formAddress
                              [ HA.placeholder "expiration"
                              , HA.type' "text"
                              ]
                          , errorFor expirationState
                          , FI.textInput
                              cvcState
                              formAddress
                              [ HA.placeholder "cvc"
                              , HA.type' "text"
                              ]
                          , errorFor cvcState

                          ]
                      )
                  ]
                _ -> []
            )
          ++
            [ H.button
                [ HA.class "sign-in"
                , HA.type' "button"
                , HA.disabled (not valid)
                -- TODO: Dispatch F.submit instead?
                -- Cf. https://github.com/etaque/elm-simple-form/blob/b2ab56b8ab0224ab39ef5b83517b1e2b349b2c8d/example/src/View.elm#L57
                , HE.onClick address Submit
                ]
                [ H.text "Submit" ]
            ]
          )
      ]

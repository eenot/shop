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

import Form exposing (Form)
import Form.Validate exposing (Validation)
import Form.Field exposing (Field)
import Form.Input

import Config
import Types exposing (Slug)
import Store.Customer as Customer


type alias Model =
  { signInForm : Form () SignInData
  }


type alias SignInData =
  { email : String
  , password : String
  }

validateSignIn : Validation () SignInData
validateSignIn =
  Form.Validate.form2 SignInData
    (Form.Validate.get "email" Form.Validate.email)
    (Form.Validate.get "password" Form.Validate.string)


init : Model
init =
  { signInForm =
      Form.initial
        [ ("email", Form.Field.Text "")
        , ("password", Form.Field.Text "")
        ]
        validateSignIn
  }


type Action
  = SignInFormAction Form.Action
  | Submit
  | AuthResult (Result ElmFire.Error ElmFire.Auth.Authentication)


type alias Context =
  { customer : Maybe Customer.Model
  }


update : Context -> Action -> Model -> ( Model, Effects Action )
update context action model =
  case action of
    SignInFormAction formAction ->
      ( { model | signInForm = Form.update formAction model.signInForm }
      , Effects.none
      )
    Submit ->
      let
        authEffects =
          case Form.getOutput model.signInForm of
            Just { email, password } ->
              ElmFire.Auth.authenticate
                (ElmFire.fromUrl Config.firebaseUrl)
                [ElmFire.Auth.rememberDefault]
                (ElmFire.Auth.withPassword email password)
              |> Task.toResult
              |> Task.map AuthResult
              |> Effects.task
            Nothing -> -- Form invalid. Should not be reachable.
              Effects.none
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
    form = model.signInForm
    formAddress = forwardTo address SignInFormAction
    emailState = Form.getFieldAsString "email" form
    passwordState = Form.getFieldAsString "password" form
    errorFor field =
      case field.liveError of
        Just error ->
          H.span [ HA.class "invalid" ] [ H.text (toString error) ]
        Nothing ->
          H.text ""
    valid = Form.getErrors form |> List.isEmpty
  in
  H.div
    [ HA.class "checkout"
    , HA.id "checkout"
    ]
    [ H.div
        [ HA.class "login" ]
        [ H.form
            [ HA.name "login"
            ]
            [ Form.Input.textInput
                emailState
                formAddress
                [ HA.class "email"
                , HA.placeholder "email"
                , HA.id "email"
                ]
            , errorFor emailState
            , Form.Input.textInput
                passwordState
                formAddress
                [ HA.class "password"
                , HA.placeholder "password"
                , HA.type' "password"
                ]
            , errorFor passwordState
            , H.button
                [ HA.class "sign-in"
                , HA.type' "button"
                , HA.disabled (not valid)
                -- TODO: Dispatch Form.submit instead?
                -- Cf. https://github.com/etaque/elm-simple-form/blob/b2ab56b8ab0224ab39ef5b83517b1e2b349b2c8d/example/src/View.elm#L57
                , HE.onClick address Submit
                ]
                [ H.text "Sign-in" ]
            ]
        ]
    ]



module Components.Checkout
  ( Model, init, Action, update, view
  , customerChanged, stripeResponse
  ) where

import String
import Dict exposing (Dict)
import Signal exposing (Address, forwardTo)
import Task exposing (Task)
import Effects exposing (Effects, Never)
import Json.Encode as JE
import Json.Decode as JD
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE

import ElmFire
import ElmFire.Auth

import Form as F exposing (Form)
import Form.Validate as FV exposing (Validation)
import Form.Field as FF exposing (Field)
import Form.Input as FI

import Config
import Types exposing (Slug, UId)
import Store.Issues as Issues exposing (Issue)
import Store.Customer as Customer


type alias Model =
  { form : Form String FormData
  , errorMsg : Maybe String
  , busy : Bool
  }


type alias FormData =
  { intent : String
  , email : Maybe String
  , password : Maybe String
  , card : Maybe Card
  }

type alias Card =
  { number : String
  , expiry : String
  , cvc : String
  }

type alias FieldSelection =
  { email : Bool
  , password : Bool
  , card : Bool
  }

showFields : Dict String FieldSelection
showFields =
  Dict.fromList
    [ ("signIn", FieldSelection True True False)
    , ("signUp", FieldSelection True True False)
    , ("signUpAndBuy", FieldSelection True True True)
    , ("newCardBuy", FieldSelection False False True)
    , ("existingCardBuy", FieldSelection False False False)
    , ("resetPw", FieldSelection True False False)
    ]


validateForm : Validation String FormData
validateForm =
  FV.get "intent" FV.string
  `FV.andThen`
  ( \intent ->
      case Dict.get intent showFields of
        Just { email, password, card } ->
          FV.form4 FormData
            (FV.succeed intent)
            ( if email
              then (FV.get "email" FV.string) |> FV.map Just
              else FV.succeed Nothing
            )
            ( if password
              then (FV.get "password" FV.string) |> FV.map Just
              else FV.succeed Nothing
            )
            ( if card
              then
                FV.get "card"
                  ( FV.map Just
                      ( FV.form3 Card
                          ( FV.get "number"
                            ( FV.get "valid" (FV.bool)
                              `FV.andThen` \isValid ->
                                if isValid
                                then FV.get "value" FV.string
                                else FV.fail (FV.customError "invalid credit card number")
                            )
                          )
                          ( FV.get "expiry"
                            ( FV.get "valid" (FV.bool)
                              `FV.andThen` \isValid ->
                                if isValid
                                then FV.get "value" FV.string
                                else FV.fail (FV.customError "invalid expiry date")
                            )
                          )
                          ( FV.get "cvc"
                            ( FV.get "valid" (FV.bool)
                              `FV.andThen` \isValid ->
                                if isValid
                                then FV.get "value" FV.string
                                else FV.fail (FV.customError "invalid cvc code")
                            )
                          )
                      )
                  )
              else FV.succeed Nothing
            )
        Nothing -> -- Should never happen
          always
            (FV.fail <| FV.customError "unkown intent")
            (Debug.log "unknown intent" intent)

  )


initForm : Form String FormData
initForm =
  F.initial
    [ ( "intent", FF.Text "signIn" )
    , ( "email", FF.Text "" )
    , ( "password", FF.Text "" )
    , ( "card", FF.group
          [ ( "number", FF.group
                [ ( "value", FF.Text "" )
                , ( "valid", FF.Check True )
                ]
            )
          , ( "expiry", FF.group
                [ ( "value", FF.Text "" )
                , ( "valid", FF.Check True )
                ]
            )
          , ( "cvc", FF.group
                [ ( "value", FF.Text "" )
                , ( "valid", FF.Check True )
                ]
            )
          ]
      )
    ]
    validateForm

init : Model
init =
  { form = initForm
  , errorMsg = Nothing
  , busy = False
  }


type Action
  = NoOp
  | FormAction F.Action
  | SwitchIntent String
  | Submit
  | AuthResult (Result ElmFire.Error ElmFire.Auth.Authentication)
  | UserOpResult (Result ElmFire.Error (Maybe String))
  | TaskPushResult (Result ElmFire.Error ElmFire.Reference)
  | TaskFeedback ElmFire.Reference (Maybe String)
  | FirebaseResult String (Result ElmFire.Error ())
  | Done
  -- Only for testing purposes
  | TestCardData


type alias UpdateContext =
  { address : Address Action
  , stripeRequestsAddress : Address Types.StripeRequest
  , slug: Slug
  , issue : Issue
  , customer : Maybe Customer.Model
  }


update : UpdateContext -> Action -> Model -> ( Model, Effects Action )
update context action model =
  case action of

    NoOp ->
      ( model, Effects.none )

    FormAction formAction ->
      ( { model | form = F.update formAction model.form }
      , case formAction of
          F.Input fieldPath (FF.Text value) ->
            case String.split "." fieldPath of
              ["card", fieldName, "value"] ->
                Signal.send
                  context.stripeRequestsAddress
                  { request = "validate"
                  , args = [fieldName, value]
                  }
                |> Task.map (always NoOp)
                |> Effects.task
              _ -> Effects.none
          _ -> Effects.none
      )

    SwitchIntent intent ->
      ( { model
        | form = F.update
            ( F.Input "intent" <| FF.Text intent )
            model.form
        }
      , Effects.none
      )

    Submit ->
      let
        location = ElmFire.fromUrl Config.firebaseUrl
      in
        ( { model
          | busy = True
          , errorMsg = Nothing }
        , case F.getOutput model.form of
            Nothing -> -- form is invalid
              Effects.task <| Task.succeed Done
            Just { intent, email, password, card } ->
              Effects.task <|
                case ( intent, email, password, card, context.customer ) of

                  ( "signIn", Just email, Just password, Nothing, Nothing ) ->
                    effectsSignIn email password

                  ( "signUp", Just email, Just password, Nothing, Nothing ) ->
                    effectsSignUp email password

                  ( "signUpAndBuy", Just email, Just password, Just card, Nothing ) ->
                    effectsSignUpAndBuy context email password card

                  ( "resetPw", Just email, Nothing, Nothing, Nothing ) ->
                    effectsResetPw email

                  ( "newCardBuy", Nothing, Nothing, Just card, Just customer ) ->
                    effectsNewCardBuy context customer.uid customer.email card

                  ( "existingCardBuy", Nothing, Nothing, Nothing, Just customer ) ->
                    existingCardBuy context customer.uid customer.email

                  _ ->
                    always (Task.succeed NoOp)
                      (Debug.log "submit cannot handle unknown or inconsistent intent" intent)
        )


    AuthResult authResult ->
      ( { model
        | errorMsg = case authResult of
            Err { description } -> Just description
            Ok _ -> Nothing
        , busy = False
        }
      , Effects.none
      )

    UserOpResult userOpResult ->
      ( { model
        | errorMsg = case userOpResult of
            Err { description } -> Just description
            Ok _ -> Nothing
        , busy = False
        }
      , Effects.none
      )

    FirebaseResult title result ->
      let _ = case result of
        Err { description } ->
          always () <| Debug.log title description
        Ok () -> ()
      in
      ( model, Effects.none )

    TaskPushResult result ->
      case result of
        Err { description } ->
          let _ = Debug.log "Error pushing task to Firebase: " description
          in
            ( { model | busy = False }
            , Effects.none
            )
        Ok taskRef ->
          -- Query task's feedback
          let
            decoder = JD.oneOf [ JD.null Nothing, JD.map Just JD.string ]
          in
          ( { model | errorMsg = Nothing }
          , ElmFire.subscribe
              ( \snapshot ->
                  case JD.decodeValue decoder snapshot.value of
                    Err error ->
                      always (Task.succeed ()) <|
                        Debug.log "Error decoding task feedback: " error
                    Ok feedback ->
                      Signal.send
                        context.address
                          (TaskFeedback taskRef feedback)
              )
              ( always (Task.succeed ()) )
              ( ElmFire.valueChanged ElmFire.noOrder )
              ( taskRef |> ElmFire.location |> ElmFire.sub "feedback" )
            |> Task.map (always ())
            |> Task.toResult
            |> Task.map (FirebaseResult "Error querying task feedback from Firebase: ")
            |> Effects.task
         )

    TaskFeedback taskRef feedback ->
      -- TODO: Subscription should be cancelled (except for (Just ""))
      ( case feedback of
          Nothing ->
            ( { model
              | busy = False
              }
            , Effects.none
            )
          (Just "") ->
            ( model, Effects.none )
          (Just message) ->
            ( { model
              | errorMsg = Just message
              , busy = False
              }
            , ElmFire.remove (ElmFire.location taskRef)
                |> Task.map (always ())
                |> Task.toResult
                |> Task.map (FirebaseResult "Error removing task from Firebase: ")
                |> Effects.task
            )
      )

    Done ->
      ( { model | busy = False } , Effects.none )

    TestCardData ->
      ( { model | form =
          model.form
          |> F.update ( F.Input "card.number.value" <| FF.Text "4242 4242 4242 4242" )
          |> F.update ( F.Input "card.expiry.value" <| FF.Text "2020-12" )
          |> F.update ( F.Input "card.cvc.value" <| FF.Text "123" )
        }
      , Effects.none
      )


customerChanged : Maybe Customer.Model -> Model -> Model
customerChanged customer model =
  let
    intentState = F.getFieldAsString "intent" model.form
    intent = Maybe.withDefault "inconsistent intent field" intentState.value
    intentForCustomer = List.member intent ["newCardBuy", "existingCardBuy"]
    intent1 = case customer of
      Just _ ->
        if intentForCustomer
        then intent
        else "newCardBuy"
      Nothing ->
        if intentForCustomer
        then "signIn"
        else intent
  in
    { model | form =
        F.update ( F.Input "intent" <| FF.Text intent1 ) model.form
    }

effectsSignIn : String -> String -> Task Never Action
effectsSignIn email password =
  ElmFire.Auth.authenticate
    (ElmFire.fromUrl Config.firebaseUrl)
    [ElmFire.Auth.rememberDefault]
    (ElmFire.Auth.withPassword email password)
  |> Task.toResult
  |> Task.map AuthResult


effectsSignUp : String -> String -> Task Never Action
effectsSignUp email password =
  let location = ElmFire.fromUrl Config.firebaseUrl
  in
    ( ElmFire.Auth.userOperation
        location
        (ElmFire.Auth.createUser email password)
      `Task.andThen` \_ ->
        ElmFire.Auth.authenticate
          location
          [ElmFire.Auth.rememberDefault]
          (ElmFire.Auth.withPassword email password)
        `Task.andThen` \authentication ->
          ElmFire.set
            ( JE.string email )
            ( location
              |> ElmFire.sub "customers"
              |> ElmFire.sub authentication.uid
              |> ElmFire.sub "email"
            )
          `Task.andThen` \reference ->
            Task.succeed authentication
    )
    |> Task.toResult
    |> Task.map AuthResult


effectsResetPw : String -> Task Never Action
effectsResetPw email =
  ElmFire.Auth.userOperation
    (ElmFire.fromUrl Config.firebaseUrl)
    (ElmFire.Auth.resetPassword email)
  |> Task.toResult
  |> Task.map UserOpResult


effectsNewCardBuy : UpdateContext -> UId -> String -> Card -> Task Never Action
effectsNewCardBuy context uid email card =
  Signal.send
    context.stripeRequestsAddress
    { request = "createToken"
    , args =
        [ card.number, card.expiry, card.cvc
        , uid, email
        , context.slug
        , toString context.issue.price, context.issue.title
        ]
    }
  |> Task.map (always NoOp)


effectsSignUpAndBuy : UpdateContext -> String -> String -> Card -> Task Never Action
effectsSignUpAndBuy context email password card =
  let
    signUpTask = effectsSignUp email password
  in
    signUpTask
    `Task.andThen` \authResult ->
      case authResult of
        AuthResult (Ok { uid }) ->
          effectsNewCardBuy context uid email card
        _ ->
          Task.succeed authResult


existingCardBuy : UpdateContext -> UId -> String -> Task Never Action
existingCardBuy context uid email =
  logUnimplementedBuy "existingCardBuy" context uid email
    (Task.succeed Done)


logUnimplementedBuy : String -> UpdateContext -> UId -> String -> a -> a
logUnimplementedBuy intent context uid email =
  (flip always)
    ( Debug.log
        ("Submitted intent: " ++ intent ++ " (not yet implemented)")
        { customer = { uid = uid, email = email }
        , slug = context.slug
        , price = context.issue.price
        }
    )


stripeResponse : Types.StripeResponse -> Model -> ( Model, Effects Action )
stripeResponse { request, args, ok } model =
  case (request, args) of
    ("validate", [fieldName, value]) ->
      ( { model | form =
            F.update
              ( F.Input ("card." ++ fieldName ++ ".valid") (FF.Check ok) )
              model.form
        }
      , Effects.none
      )
    ("createToken", [uid, email, slug, price, title, tokenOrMsg]) ->
      if ok
      then
        ( model,
          gatewayRequestEffect
            { uid = uid
            , email = email
            , slug = slug
            , price = price
            , title = title
            , operation = NewCustomer
            , tokenOrCustomer = tokenOrMsg
            }
        )
      else
        ( { model
          | busy = False
          , errorMsg = Just tokenOrMsg
          }
        , Effects.none
        )
    _ -> ( model, Effects.none )


type GatewayOperation = NewCustomer | ExistingCustomer


type alias GatewayRequest =
  { uid : String
  , email : String
  , slug : String
  , price : String
  , title : String
  , operation : GatewayOperation
  , tokenOrCustomer : String
  }


gatewayRequestEffect : GatewayRequest -> Effects Action
gatewayRequestEffect request =
  ElmFire.set
    ( JE.object
        [ ( "uid", JE.string request.uid )
        , ( "email", JE.string request.email )
        , ( "slug", JE.string request.slug )
        , ( "price", JE.string request.price )
        , ( "title", JE.string request.title )
        , ( "operation", JE.string <|
              case request.operation of
                NewCustomer -> "newCustomer"
                ExistingCustomer -> "existingCustomer"
          )
        , ( "tokenOrCustomer", JE.string request.tokenOrCustomer )
        , ( "feedback", JE.string "" )
        ]
    )
    ( ElmFire.fromUrl Config.firebaseUrl
        |> ElmFire.sub "purchases"
        |> ElmFire.sub "queue"
        |> ElmFire.sub "tasks"
        |> ElmFire.push
    )
  |> Task.toResult
  |> Task.map TaskPushResult
  |> Effects.task


type alias ViewContext =
  { slug: Slug
  , issue : Issue
  , customer : Maybe Customer.Model
  }


view : Address Action -> ViewContext -> Model -> Html
view address context model =
  let
    formAddress = forwardTo address FormAction
    errorFor field =
      case field.liveError of
        Just error ->
          H.span [ HA.class "invalid" ] [ H.text (toString error) ]
        Nothing ->
          H.text ""
    valid = List.isEmpty <| F.getErrors model.form
    intentState = F.getFieldAsString "intent" model.form
    intent = Maybe.withDefault "inconsistent intent field" intentState.value
    show = Maybe.withDefault (FieldSelection False False False) (Dict.get intent showFields)
    textInput fieldName placeholder masked =
      let fieldState = F.getFieldAsString fieldName model.form
      in
        [ FI.textInput
            fieldState
            formAddress
            [ HA.placeholder placeholder
            , HA.type' (if masked then "password" else "text")
            ]
        , errorFor fieldState
        ]
    priceText = toString (context.issue.price / 100.0) ++ " bucks"
  in
    H.div
      [ HA.classList
          [ ("checkout", True)
          , ("busy", model.busy)
          ]
      , HA.id "checkout"
      ]
      ( select
          [ ( True -- TODO: Show selectInput for debugging only
            , H.div
                [ HA.class "debug" ]
                [ FI.selectInput
                    [ ("signIn", "intent: signIn")
                    , ("signUp", "intent: signUp")
                    , ("signUpAndBuy", "intent: signUpAndBuy")
                    , ("newCardBuy", "intent: newCardBuy")
                    , ("existingCardBuy", "intent: existingCardBuy")
                    , ("resetPw", "intent: resetPw")
                    ]
                    intentState
                    formAddress
                    []
                , H.button
                    [ HE.onClick address TestCardData ]
                    [ H.text "Use test card data" ]
                ]
            )
          , ( model.errorMsg /= Nothing
            , H.div
                [ HA.class "error" ]
                [ H.text <| Maybe.withDefault "" model.errorMsg ]
            )
          , ( context.customer == Nothing
            , H.div
                [ HA.class "menu" ]
                [ H.button
                  [ HA.disabled <| List.member intent ["signIn", "resetPw"]
                  , HE.onClick address (SwitchIntent "signIn")
                  ]
                  [ H.text "Sign-in" ]
                , H.button
                  [ HA.disabled <| intent == "signUp"
                  , HE.onClick address (SwitchIntent "signUp")
                  ]
                  [ H.text "Sign-up" ]
                , H.button
                  [ HA.disabled <| intent == "signUpAndBuy"
                  , HE.onClick address (SwitchIntent "signUpAndBuy")
                  ]
                  [ H.text "Sign-up and buy" ]
                ]
            )
          , ( context.customer /= Nothing
            , H.div
                [ HA.class "email" ]
                [ H.text "Your email address: "
                , H.text
                  <| Maybe.withDefault ""
                  <| Maybe.map .email context.customer
                ]
            )
          , ( show.email
            , H.div
                [ HA.class "email" ]
                ( textInput "email" "email" False )
            )
          , ( show.password
            , H.div
                [ HA.class "password" ]
                ( textInput "password" "password" True )
            )
          , ( intent == "signIn"
            , H.button
                [ HE.onClick address (SwitchIntent "resetPw") ]
                [ H.text "Forgot your password?" ]
            )
          , ( intent == "resetPw"
            , H.button
                [ HE.onClick address (SwitchIntent "signIn") ]
                [ H.text "Never mind, I know my password" ]
            )
          , ( show.card
            , H.div
                [ HA.class "card" ]
                ( textInput "card.number.value" "card number" False ++
                  textInput "card.expiry.value" "expiry" False ++
                  textInput "card.cvc.value" "cvc" False
                )
            )
          , ( True
            , H.button
                [ HA.class "sign-in"
                , HA.disabled (not valid || model.busy)
                -- TODO: Dispatch F.submit instead?
                -- Cf. https://github.com/etaque/elm-simple-form/blob/b2ab56b8ab0224ab39ef5b83517b1e2b349b2c8d/example/src/View.elm#L57
                , HE.onClick address Submit
                ]
                [ H.text <|
                    case intent of
                      "signIn" -> "Sign-in"
                      "signUp" -> "Sign-up"
                      "signUpAndBuy" -> "Sign-up and Buy for " ++ priceText
                      "newCardBuy" -> "Buy for " ++ priceText
                      "existingCardBuy" -> "Buy for " ++ priceText
                      "resetPw" -> "Reset my Password"
                      _ -> always "Ok" (Debug.log "unknown intent" intent)
                ]
            )
          ]
      )


select : List (Bool, a) -> List a
select list =
  List.foldr
    ( \(take, element) rest -> if take then element::rest else rest )
    []
    list

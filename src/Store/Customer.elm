module Store.Customer
  ( Model, init, Action, update
  , getIssuePermission
  ) where

import Dict exposing (Dict)
import Signal exposing (Address, message, forwardTo)
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import Json.Encode as JE
import Json.Decode as JD exposing ((:=))

import ElmFire
import ElmFire.Dict

import Types exposing (..)

--------------------------------------------------------------------------------

type alias Model =
  { uid : UId
  , email : String
  -- , paymentData : PaymentData
  , purchases : Purchases
  }

type alias PaymentData =
  {
  }

type alias Purchases =
   Dict Slug Permission

type alias Permission =
  { valid : Bool
  }

--------------------------------------------------------------------------------

syncConfigPurchases : ElmFire.Location -> ElmFire.Dict.Config Permission
syncConfigPurchases location =
  { location = location
  , orderOptions = ElmFire.noOrder
  , encoder =
      \perm -> JE.object [ ( "valid", JE.bool perm.valid )]
  , decoder =
      JD.object1 Permission ("valid" := JD.bool)
  }

--------------------------------------------------------------------------------

init : Address Action -> ElmFire.Location -> UId -> (Model, Effects Action)
init address location uid =
  ( { uid = uid
    , email = ""
    , purchases = Dict.empty
    }
  , Effects.batch
      [ ( ElmFire.once
            (ElmFire.valueChanged ElmFire.noOrder)
            (location |> ElmFire.sub "customers" |> ElmFire.sub uid |> ElmFire.sub "email")
          |> Task.toResult
          |> Task.map QueryStaticResult
          |> Effects.task
        )
      , ( ElmFire.Dict.subscribeDelta
            (forwardTo address DeltaPurchases)
            ( syncConfigPurchases
                (location |> ElmFire.sub "permissions" |> ElmFire.sub uid)
            )
          |> Task.toResult
          |> Task.map QueryPurchasesResult
          |> Effects.task
        )
      ]
  )

type Action
  = QueryStaticResult (Result ElmFire.Error ElmFire.Snapshot)
  | QueryPurchasesResult (Result ElmFire.Error (Task ElmFire.Error ()))
  | DeltaPurchases (ElmFire.Dict.Delta Permission)

update : Action -> Model -> Model
update action model =
  case action of
    QueryStaticResult (Err error) ->
      always model <|
        Debug.log "Firebase: customer query error" error

    QueryStaticResult (Ok snapshot) ->
      case JD.decodeValue JD.string snapshot.value of
        Err error ->
          always model <|
            Debug.log "Firebase: customer email decoding error" error

        Ok email ->
          { model | email = email }

    QueryPurchasesResult (Err error) ->
      always model <|
        Debug.log "Firebase: purchases query error" error

    QueryPurchasesResult (Ok unsubscribeTask) ->
      -- No need to execute the unsubscribeTask on sign-out.
      -- After signing out Firebase will stop the subscription with an error,
      -- which is silently ignored by ElmFire.Dict.
      model

    DeltaPurchases delta ->
      { model | purchases = ElmFire.Dict.update delta model.purchases }

getIssuePermission : Slug -> Model -> Bool
getIssuePermission slug model =
  case Dict.get slug model.purchases of
    Nothing -> False
    Just perm -> perm.valid

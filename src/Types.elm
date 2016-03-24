module Types (..) where


type alias Slug = String
type alias UId = String
type alias IssueKey = String

type alias StripeRequest =
  { request: String
  , args: List String
  }

type alias StripeResponse =
  { request: String
  , args: List String
  , result: Bool
  }

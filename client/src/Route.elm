module Route (Route(..), match, path) where

import RouteParser exposing (..)

--------------------------------------------------------------------------------

type Route
  = Home
  | All
  | Issue String

--------------------------------------------------------------------------------

matchers : List (Matcher Route)
matchers =
  [ static Home "/"
  , static All "/all"
  , dyn1 Issue "/" string ""
  ]

match : String -> Maybe Route
match = RouteParser.match matchers

path : Route -> String
path r =
  case r of
    Home -> "/"
    All -> "/all"
    Issue slug -> "/" ++ slug

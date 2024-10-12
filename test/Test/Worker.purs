module Test.Worker where

import Prelude

import Data.Int as Int
import Effect (Effect)
import Node.WorkerBees as Worker

main :: Effect Unit
main = Worker.makeAsMain (Worker.lift (Int.toStringAs Int.decimal))

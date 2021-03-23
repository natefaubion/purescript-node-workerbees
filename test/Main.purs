module Test.Main where

import Prelude

import Data.Array as Array
import Effect (Effect)
import Effect.Aff as Aff
import Effect.Class.Console as Console
import Node.WorkerBees (Worker)
import Node.WorkerBees as Worker
import Node.WorkerBees.Aff.Pool as WorkerPool

worker :: Worker Unit Int String
worker = Worker.make (Worker.lift show)

main :: Effect Unit
main = Aff.launchAff_ do
  Console.log "Main..."
  res <- WorkerPool.poolTraverse worker unit 4 (Array.range 1 100)
  Console.logShow res

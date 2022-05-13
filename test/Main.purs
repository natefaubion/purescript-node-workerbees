module Test.Main where

import Prelude

import Data.Array as Array
import Effect (Effect)
import Effect.Aff as Aff
import Effect.Class.Console as Console
import Node.WorkerBees (Worker)
import Node.WorkerBees as Worker
import Node.WorkerBees.Aff.Pool as WorkerPool

main :: Effect Unit
main = Aff.launchAff_ do
  Console.log "Main..."

  let
    worker :: Worker Number Int String
    worker = Worker.unsafeWorkerFromPath "./output/Test.Worker.js"

  res <- WorkerPool.poolTraverse worker 10.0 1 (Array.range 1 100)
  Console.logShow res

# purescript-node-workerbees

An opinionated, unsafe set of bindings to Node's `worker_threads` API.
Use `workerbees` to distribute work over multiple _actual_ threads instead of
that fiber bullshit `Aff` gives you.

Also, there's has an `Aff`-based API that makes it even more convenient.

## Example

Start by creating a worker module:

```purescript
module Worker where

import Prelude

import Effect (Effect)
import Node.WorkerBees as Worker

main :: Effect Unit
main = Worker.makeAsMain (Worker.lift doSomethingReallyExpensive)
  where
  doSomethingReallyExpensive :: Int -> String
  doSomethingReallyExpensive = ???
```

Then bundle your worker with `spago`:

```sh
spago bundle --bundle-type app --module Worker --outfile worker.js --platform node
```

Write your main module:

``` purescript
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
  let
    worker :: Worker Unit
    worker = Worker.unsafeWorkerFromPath "./worker.js"

  -- Distributes work over 4 threads.
  res <- WorkerPool.poolTraverse worker unit 4 (Array.range 1 100)
  Console.logShow res
```

Run your main module:

```sh
spago run
```

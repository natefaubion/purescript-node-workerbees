# purescript-node-workerbees

An opinionated, convenient set of bindings to Node's `worker_threads` API.
Use `workerbees` to distribute work over multiple _actual_ threads instead of
that fiber bullshit `Aff` gives you.

Also, there's has an `Aff`-based API that makes it even more convenient.

## Example

``` purescript
import Prelude

import Data.Array as Array
import Effect (Effect)
import Effect.Aff as Aff
import Effect.Class.Console as Console
import Node.WorkerBees (Worker)
import Node.WorkerBees as Worker
import Node.WorkerBees.Aff.Pool as WorkerPool

worker :: Worker Unit Int String
worker = Worker.make (Worker.lift ?doSomethingReallyExpensive)

main :: Effect Unit
main = Aff.launchAff_ do
  -- Distributes work over 4 threads.
  res <- WorkerPool.poolTraverse worker unit 4 (Array.range 1 100)
  Console.logShow res
```

## Caveats

* Workers _must_ be top-level, with no other constraints or arguments.
* Workers _must_ be exports.
* Your Node app _must not_ be bundled.

These invariants will be validated at runtime, and if they aren't met will
result in a runtime exception.

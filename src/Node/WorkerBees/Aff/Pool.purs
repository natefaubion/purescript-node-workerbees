module Node.WorkerBees.Aff.Pool
  ( WorkerPool
  , make
  , terminate
  , invoke
  , withPool
  , poolTraverse
  ) where

import Prelude

import Control.Parallel (parTraverse, parTraverse_)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Traversable (class Traversable, for_, sequence)
import Data.Tuple (Tuple(..), fst, snd)
import Effect.AVar (AVar)
import Effect.Aff (Aff, Fiber, bracket, error, forkAff, killFiber)
import Effect.Aff.AVar as AVar
import Effect.Aff.AVar as Aff
import Node.WorkerBees (class Sendable, Worker, WorkerThread)
import Node.WorkerBees.Aff as Worker.Aff

newtype WorkerPool i o = WorkerPool
  { queue :: AVar (Tuple i (AVar o))
  , threads :: Array (Tuple (WorkerThread i) (Fiber Unit))
  }

-- | Creates a new WorkerPool of some size. Worker threads will steal inputs as
-- | they become available to do more work. It's assumed that a worker is only
-- | processing one input, and yielding a corresponding output at a time. If a
-- | worker may yield multiple results for a single input, you should not use
-- | a worker pool.
make :: forall a i o. Sendable a => Sendable i => Worker a i o -> a -> Int -> Aff (WorkerPool i o)
make worker workerData numThreads = do
  queue <- AVar.empty
  threads <- sequence $ Array.replicate numThreads do
    Tuple thread out <- Worker.Aff.spawn worker workerData
    fiber <- forkAff $ workerLoop queue thread out
    pure $ Tuple thread fiber
  pure $ WorkerPool { queue, threads }
  where
  workerLoop :: AVar (Tuple i (AVar o)) -> WorkerThread i -> AVar (Either Int o) -> Aff Unit
  workerLoop queue thread out = do
    Tuple req res <- AVar.take queue
    Worker.Aff.post req thread
    rep <- AVar.take out
    case rep of
      Left code ->
        AVar.kill (error ("Worker exited: " <> show code)) res
      Right value -> do
        AVar.put value res
        workerLoop queue thread out

-- | Terminates the pool and any propagates an exception to any pending invokers.
terminate :: forall i o. WorkerPool i o -> Aff Unit
terminate (WorkerPool { queue, threads }) = do
  let termError = error "Pool terminated"
  parTraverse_ (killFiber termError <<< snd) threads
  parTraverse_ (Worker.Aff.terminate <<< fst) threads
  pending <- Aff.tryRead queue
  AVar.kill termError queue
  for_ pending (AVar.kill termError <<< snd)

-- | Submits a new input to the worker pool, and waits for the reply.
invoke :: forall i o. Sendable i => WorkerPool i o -> i -> Aff o
invoke (WorkerPool { queue }) i = do
  res <- AVar.empty
  AVar.put (Tuple i res) queue
  AVar.take res

-- | Creates a new pool of some size, terminating the pool when the scope exits.
withPool
  :: forall a i o b
   . Sendable a
  => Sendable i
  => Worker a i o
  -> a
  -> Int
  -> (WorkerPool i o -> Aff b)
  -> Aff b
withPool worker workerData numThreads =
  bracket (make worker workerData numThreads) terminate

-- | Traverses some input using a pool of some size.
poolTraverse
  :: forall f a i o
   . Sendable a
  => Sendable i
  => Traversable f
  => Worker a i o
  -> a
  -> Int
  -> f i
  -> Aff (f o)
poolTraverse worker workerData numThreads fs =
  withPool worker workerData numThreads (flip parTraverse fs <<< invoke)

module Node.WorkerBees.Aff where

import Prelude

import Data.Either (Either(..))
import Data.Tuple (Tuple(..))
import Effect.AVar (AVar)
import Effect.AVar as EffectAVar
import Effect.Aff (Aff, error, invincible, makeAff)
import Effect.Aff.AVar as AVar
import Effect.Class (liftEffect)
import Node.WorkerBees (class Sendable, Worker, WorkerThread)
import Node.WorkerBees as Worker

-- | Instantiates a new worker thread. If this worker subscribes to input, it
-- | will need to be cleaned up with `terminate`, otherwise it will hold your
-- | process open. Yields a WorkerThread instance, and an AVar which can be
-- | polled for results. Polling the AVar may result in an exception, and
-- | if the worker has just exited, will yield an exit code.
spawn
  :: forall a i o
   . Sendable a
  => Worker a i o
  -> a
  -> Aff (Tuple (WorkerThread i) (AVar (Either Int o)))
spawn worker workerData = do
  output <- AVar.empty
  thread <- makeAff \k -> do
    Worker.spawn worker
      { onMessage: \value ->
          void $ EffectAVar.put (Right value) output mempty
      , onError: \err ->
          EffectAVar.kill err output
      , onExit: \code -> do
          _ <- EffectAVar.put (Left code) output mempty
          EffectAVar.kill (error ("Worker exited: " <> show code)) output
      , workerData
      }
      k
    pure mempty
  pure (Tuple thread output)

-- | Sends some input to a worker thread to process.
post :: forall i. Sendable i => i -> WorkerThread i -> Aff Unit
post i = liftEffect <<< Worker.post i

-- | Terminates the worker thread.
terminate :: forall i. WorkerThread i -> Aff Unit
terminate worker = invincible $ makeAff \k -> do
  Worker.terminate worker k
  pure mempty

module Node.WorkerBees
  ( WorkerContext
  , WorkerThread
  , WorkerOptions
  , Worker
  , ThreadId(..)
  , threadId
  , makeAsMain
  , unsafeWorkerFromPath
  , lift
  , liftReader
  , liftEffect
  , liftReaderT
  , spawn
  , post
  , terminate
  , class Sendable
  , class SendableRowList
  , SendWrapper
  , wrap
  , unsafeWrap
  , unwrap
  ) where

import Prelude

import Control.Monad.Reader (Reader, ReaderT, runReader, runReaderT)
import Data.Argonaut.Core (Json)
import Data.ArrayBuffer.Types (ArrayBuffer)
import Data.Either (Either(..))
import Data.Newtype (class Newtype)
import Data.Variant (Variant)
import Effect (Effect)
import Effect.Exception (Error)
import Effect.Uncurried (EffectFn2, EffectFn4, EffectFn5, runEffectFn2, runEffectFn4, runEffectFn5)
import Foreign.Object (Object)
import Prim.RowList (class RowToList, RowList)
import Prim.RowList as Row
import Prim.TypeError (class Fail, Beside, Quote, Text)

newtype ThreadId = ThreadId Int

derive instance eqThreadId :: Eq ThreadId
derive instance ordThreadId :: Ord ThreadId

type WorkerContext a i o =
  { exit :: Effect Unit
  , receive :: (i -> Effect Unit) -> Effect Unit
  , reply :: o -> Effect Unit
  , threadId :: ThreadId
  , workerData :: a
  }

type WorkerOptions a o =
  { onError :: Error -> Effect Unit
  , onExit :: Int -> Effect Unit
  , onMessage :: o -> Effect Unit
  , workerData :: a
  }

type WorkerConstructor a i o = WorkerContext a i o -> Effect Unit

foreign import data Worker :: Type -> Type -> Type -> Type

foreign import data WorkerThread :: Type -> Type

foreign import unsafeMakeImpl :: forall a i o. { filePath :: String } -> Worker a i o

foreign import mainImpl :: forall a i o. WorkerConstructor a i o -> Effect Unit

foreign import spawnImpl :: forall a i o. EffectFn5 (forall x y. x -> Either x y) (forall x y. y -> Either x y) (Worker a i o) (WorkerOptions a o) (Either Error (WorkerThread i) -> Effect Unit) Unit

foreign import postImpl :: forall i. EffectFn2 i (WorkerThread i) Unit

foreign import terminateImpl :: forall i. EffectFn4 (forall x y. x -> Either x y) (forall x y. y -> Either x y) (WorkerThread i) (Either Error Unit -> Effect Unit) Unit

foreign import threadId :: forall i. WorkerThread i -> Effect ThreadId

-- | Implements the worker code that can later be called via the
-- | `unsafeWorkerFromPath` function. This code _must_ be bundled such that
-- | `main` is actually called in the file.
makeAsMain :: forall a i o. Sendable o => WorkerConstructor a i o -> Effect Unit
makeAsMain = mainImpl

-- | Builds a new worker given a path to the compiled code constituting the `main`
-- | function that should execute in the worker. The worker code should be created
-- | using `makeAsMain`. The path must be either an absolute path or a relative
-- | path that begins with ./ or ../
-- |
-- | ```purs
-- | unsafeWorkerFromPath "./output/My.Bundled.Output/index.js"
-- | ```
unsafeWorkerFromPath :: forall a i o. Sendable o => String -> Worker a i o
unsafeWorkerFromPath = unsafeMakeImpl <<< { filePath: _ }

-- | Instantiates a new worker thread. If this worker subscribes to input, it
-- | will need to be cleaned up with `terminate`, otherwise it will hold your
-- | process open.
spawn :: forall a i o. Sendable a => Worker a i o -> WorkerOptions a o -> (Either Error (WorkerThread i) -> Effect Unit) -> Effect Unit
spawn = runEffectFn5 spawnImpl Left Right

-- | Sends some input to a worker thread to process.
post :: forall i. Sendable i => i -> WorkerThread i -> Effect Unit
post = runEffectFn2 postImpl

-- | Terminates the worker thread.
terminate :: forall i. WorkerThread i -> (Either Error Unit -> Effect Unit) -> Effect Unit
terminate = runEffectFn4 terminateImpl Left Right

-- | Only Sendable things can be sent back and forth between a worker thread and
-- | its parent. These include things that are represented by JavaScript primitives.
-- | Arbitrary PureScript values cannot be sent, but variants, records and newtypes
-- | of these things can. If you have a newtype of some Sendable, you must wrap it.
class Sendable (a :: Type)

instance sendableInt :: Sendable Int
else instance sendableNumber :: Sendable Number
else instance sendableString :: Sendable String
else instance sendableBoolean :: Sendable Boolean
else instance sendableArray :: Sendable a => Sendable (Array a)
else instance sendableObject :: Sendable a => Sendable (Object a)
else instance sendableRecord :: (RowToList r rl, SendableRowList rl) => Sendable (Record r)
else instance sendableVariant :: (RowToList r rl, SendableRowList rl) => Sendable (Variant r)
else instance sendableSendWrap :: Sendable (SendWrapper a)
else instance sendableJson :: Sendable Json
else instance sendableUnit :: Sendable Unit
else instance sendableVoid :: Sendable Void
else instance sendableArrayBuffer :: Sendable ArrayBuffer
else instance sendableFail :: Fail (Beside (Quote a) (Text " is not known to be Sendable")) => Sendable a

class SendableRowList (rl :: RowList Type)

instance sendableRowListNil :: SendableRowList Row.Nil
instance sendableRowListCons :: (Sendable a, SendableRowList rest) => SendableRowList (Row.Cons sym a rest)

-- | For newtypes that are otherwise Sendable.
newtype SendWrapper a = SendWrapper a

wrap :: forall a b. Newtype a b => Sendable b => a -> SendWrapper a
wrap = SendWrapper

unwrap :: forall a. SendWrapper a -> a
unwrap (SendWrapper a) = a

-- | Use with care. If you send something that isn't actually Sendable, it
-- | will raise an exception.
unsafeWrap :: forall a. a -> SendWrapper a
unsafeWrap = SendWrapper

lift :: forall e a b. (a -> b) -> WorkerConstructor e a b
lift k { receive, reply } = receive (reply <<< k)

liftReader :: forall e a b. (a -> Reader e b) -> WorkerConstructor e a b
liftReader k { receive, reply, workerData } = receive (reply <<< flip runReader workerData <<< k)

liftEffect :: forall e a b. (a -> Effect b) -> WorkerConstructor e a b
liftEffect k { receive, reply } = receive (reply <=< k)

liftReaderT :: forall e a b. (a -> ReaderT e Effect b) -> WorkerConstructor e a b
liftReaderT k { receive, reply, workerData } = receive (reply <=< flip runReaderT workerData <<< k)

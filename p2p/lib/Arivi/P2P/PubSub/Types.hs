{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}

module Arivi.P2P.PubSub.Types
  ( NodeTimer(..)
  , Subscribers(..)
  , Notifiers(..)
 -- , Inbox(..)
 -- , Cache(..)
  , Status(..)
  , Timer
  , subscribersForTopic
  , notifiersForTopic
  --, notifiersForMessage
  , newSubscriber
  , newNotifier
  ) where

import Arivi.P2P.MessageHandler.HandlerTypes

import Codec.Serialise (Serialise)
import Control.Applicative ()

--import           Control.Concurrent.MVar
import Control.Concurrent.STM

--import Control.Concurrent.STM.TVar (TVar)
import Control.Lens ()
import Data.Hashable

import Control.Monad.Trans

--import           Data.HashMap.Strict           as HM
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Time.Clock
import GHC.Generics (Generic)
import qualified STMContainers.Map as H

type Timer = Integer

data NodeTimer =
  NodeTimer
    { timerNodeId :: NodeId
    , timer :: UTCTime -- time here is current time added with the nominaldifftime in the message
    }
  deriving (Eq, Ord, Show, Generic, Serialise)

newtype Subscribers t =
  Subscribers (H.Map t (Set NodeId))

newtype Notifiers t =
  Notifiers (H.Map t (Set NodeId))

-- newtype Inbox msg = Inbox (H.Map msg (TVar (Set NodeId)))
--
-- newtype Cache msg = Cache (H.Map msg (MVar Status))
data Status
  = Ok
  | Error
  deriving (Eq, Ord, Show, Generic, Serialise)

subscribersForTopic ::
     (Eq t, Hashable t) => t -> Subscribers t -> IO (Set NodeId)
subscribersForTopic t (Subscribers subs) = do
  yy <- atomically $ (H.lookup t subs)
  case yy of
    Just x -> do
      atomically $ H.insert x t subs
      return x
    Nothing -> return Set.empty

notifiersForTopic :: (Eq t, Hashable t) => t -> Notifiers t -> IO (Set NodeId)
notifiersForTopic t (Notifiers notifs) = do
  yy <- liftIO $ atomically $ (H.lookup t notifs)
  case yy of
    Just x -> return x
    Nothing -> return Set.empty

-- notifiersForMessage
--   :: (Eq msg, Hashable msg, Eq t, Hashable t)
--   => Inbox msg
--   -> Subscribers t
--   -> msg
--   -> t
--   -> IO (Set NodeId)
-- notifiersForMessage (Inbox inbox) subs msg t = case inbox ^. at msg of
--   Just x  -> liftA2 (Set.\\) (subscribersForTopic t subs) (readTVarIO x)
--   -- |Invariant this branch is never reached.
--   -- If no one sent a msg, you can't have a message
--   -- to ask who sent it. Returning all subscribers.
--   Nothing -> subscribersForTopic t subs
newSubscriber ::
     (Ord t, Hashable t)
  => NodeId
  -> Subscribers t
  -> Set t
  -> Integer -- Timer
  -> t
  -> IO Bool
newSubscriber nid (Subscribers subs) _topics _ t = do
  yy <- liftIO $ atomically $ (H.lookup t subs)
  case yy of
    Just x
      --atomically $ modifyTVar x (Set.insert nid)
     -> do
      let nx = Set.insert nid x
      atomically $ H.insert nx t subs
      liftIO $ print ("modifying")
      return (True)
    Nothing
      --z <- liftIO $ atomically $ newTVar (Set.singleton nid)
      --liftIO $ atomically $ H.insert z t subs
     -> do
      let z = Set.singleton nid
      atomically $ H.insert z t subs
      liftIO $ print ("insert-new")
      return True
  -- newSubscriber nid (Subscribers subs) topics _ t = if Set.member t topics
  --   then case subs ^. at t of
  --     Just x -> do
  --       atomically $ modifyTVar x (Set.insert nid)
  --       return True
  --     -- |Invariant this branch is never reached.
  --     -- 'initPubSub' should statically make empty
  --     -- sets for all topics in the map. Returning False.
  --     Nothing -> return False
  --   else return False

newNotifier :: (Ord t, Hashable t) => NodeId -> Notifiers t -> t -> IO ()
newNotifier nid (Notifiers notifs) t = do
  yy <- liftIO $ atomically $ (H.lookup t notifs)
  case yy of
    Just x --atomically $ modifyTVar x (Set.insert nid)
     -> do
      let nx = Set.insert nid x
      atomically $ H.insert nx t notifs
    -- |Invariant this branch is never reached.
    -- 'initPubSub' should statically make empty
    -- sets for all topics in the map.
    Nothing -> return ()

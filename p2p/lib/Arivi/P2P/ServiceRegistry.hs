{-# LANGUAGE RankNTypes #-}

module Arivi.P2P.ServiceRegistry
  ( mkP2PEnv
  )
where

import           Arivi.Env
import qualified Arivi.P2P.Config              as Config
import           Arivi.P2P.PubSub.Handler
import           Arivi.P2P.PubSub.Env
import           Arivi.P2P.PubSub.Types
import           Arivi.P2P.Kademlia.MessageHandler
import           Arivi.P2P.P2PEnv
import           Arivi.P2P.RPC.Handler
import           Arivi.P2P.RPC.Env
import           Arivi.P2P.Types
import           Arivi.Utils.Statsd
--import           Codec.Serialise
import           Data.Hashable

mkHandlers :: Handlers
mkHandlers =
  Handlers rpcHandler kademliaMessageHandler optionsHandler pubSubHandler

mkP2PEnv
  :: (Ord r, Hashable r)
  => Config.Config
  -> (rmsg -> m (Maybe rmsg))
  -> (pmsg -> m Status)
  -> [r]
  -> [t]
  -> IO (P2PEnv m r t rmsg pmsg)
mkP2PEnv config rh psH resources topics = do
  let nc = NetworkConfig (Config.myNodeId config)
                         (Config.myIp config)
                         (Config.tcpPort config)
                         (Config.udpPort config)
  let networkEnv = mkAriviEnv (read $ show $ Config.tcpPort config)
                              (read $ show $ Config.udpPort config)
                              (Config.secretKey config)
  nep  <- mkNodeEndpoint nc mkHandlers networkEnv
  nrpc <- mkRpc resources
  nps  <- mkPubSub topics
  nk   <- mkKademlia nc
                     (Config.sbound config)
                     (Config.pingThreshold config)
                     (Config.kademliaConcurrencyFactor config)
          -- (Config.hopBound config)
  ncsc <- createStatsdClient "127.0.0.1" 8080 "statsdPrefix"
  nprt <- mkPRTEnv
  return P2PEnv
    { nodeEndpointEnv = nep
    , rEnv            = nrpc
    , psEnv           = nps
    , kademliaEnv     = nk
    , statsdClient    = ncsc
    , prtEnv          = nprt
    , rHandler        = rh
    , psHandler       = psH
    }

-- makeP2Pinstance ::
--        NodeId
--     -> IP
--     -> Port
--     -> Port
--     -> IP
--     -> Port
--     -> String
--     -> SecretKey
--     -> Int
--     -> Int
--     -> Int
--     -> IO (P2PEnv r t rmsg pmsg)
-- makeP2Pinstance nodeid mIp tcpport udpport statsdIP statsdPort statsdPrefix sk sbound pingThreshold kademliaConcurrencyFactor = do
--     let netENV = mkAriviEnv (read $ show tcpport) (read $ show udpport) sk
--         nc = NetworkConfig nodeid mIp tcpport udpport
--     -- TODO:  need to make port consistent
--     P2PEnv <$> mkNodeEndpoint nc mkHandlers netENV
--            <*> mkRpcEnv
--            <*> mkPubSub
--            <*> mkKademlia nc sbound pingThreshold kademliaConcurrencyFactor
--            <*> createStatsdClient statsdIP statsdPort statsdPrefix

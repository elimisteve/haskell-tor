-- |Various options for running a Tor node
module Tor.Options(
         -- * Options for running Tor
         TorOptions(..),         defaultTorOptions
       , TorEntranceOptions(..), defaultTorEntranceOptions
       , TorRelayOptions(..),    defaultTorRelayOptions
       , TorExitOptions(..),     defaultTorExitOptions
       , ExitRule(..), AddrSpec(..), PortSpec(..)
         -- * Handy utilities
       , makeLogger
       )
 where

import Data.Hourglass
import Data.Hourglass.Now
import Data.Word
import Tor.RouterDesc

-- |How the node should be set up during initialization. For each of these
-- items, 'Nothing' means that the node will not operate in that capacity, while
-- Just of the option type will initialize that system with those options.
--
-- Note that while we will do our best to make it work, it doesn't make a whole
-- lot of sense to be an Exit node and not be a Relay node.
data TorOptions = TorOptions {
       torLog             :: String -> IO ()
     , torEntranceOptions :: Maybe TorEntranceOptions
     , torRelayOptions    :: Maybe TorRelayOptions
     , torExitOptions     :: Maybe TorExitOptions
     }

-- |A reasonable default set of options for a Tor node. Sets the node up as an
-- entrance and relay node with their standard options, and logging output
-- printed to stdout.
defaultTorOptions :: TorOptions
defaultTorOptions = TorOptions {
    torLog             = makeLogger putStrLn
  , torEntranceOptions = Just defaultTorEntranceOptions
  , torRelayOptions    = Just defaultTorRelayOptions
  , torExitOptions     = Nothing
  }

-- |Options for allowing circuits that originated at this node.
data TorEntranceOptions = TorEntranceOptions {
       -- |The number of intermediate hops to use between this node and
       -- the exit node. To be clear, created circuits will have an entrance
       -- node, this number of nodes, and then the exit node.
       torInternalCircuitLength :: Int
       -- |The target number of external connections to keep alive for
       -- outgoing connections. Note that this is a target, rather than a hard
       -- minimum or limit.
     , torTargetLinks :: Int
     }

-- |A reasonable set of entrance options. The internal circuit length is set to
-- 4, and a target number of links of 5.
defaultTorEntranceOptions :: TorEntranceOptions
defaultTorEntranceOptions  = TorEntranceOptions {
    torInternalCircuitLength = 4
  , torTargetLinks           = 5
  }

-- |Options for allowing circuits that pass through this node.
data TorRelayOptions = TorRelayOptions {
      -- |The port to listen on. By default, this is 9374, but there are
      -- compelling reasons to have it be some other wel-known port, like
      -- 80.
      torOnionPort :: Word16
      -- |The nickname for this node. This is completely optional, but can
      -- be helpful in finding yourself in node lists.
    , torNickname  :: String
      -- |A contact email address. If not provided, we will either provide
      -- no email address or just include a junk address.
    , torContact   :: Maybe String
      -- |If you're setting up a number of nodes within the same operating
      -- environment, you might want to provide a "family" identifier. That way,
      -- those building circuits can limit what percentage of their hops might
      -- go through this group. A node can be a member of zero, one, or more
      -- families, thus the list.
    , torFamilies  :: [NodeFamily]
      -- |The maximum number of links from this node. Note that this should be
      -- greater than or equal to torTargetLinks if this node is also to be used
      -- as an entrance node.
    , torMaximumLinks :: Int
    }

-- |A reasonable set of relay options. The onion port is set to 9374, the
-- nickname is set to "", and no contact information is provided. These options
-- set the maximum number of links to 50.
defaultTorRelayOptions :: TorRelayOptions
defaultTorRelayOptions  = TorRelayOptions {
    torOnionPort    = 9374
  , torNickname     = ""
  , torContact      = Nothing
  , torFamilies     = []
  , torMaximumLinks = 50
  }

-- |Options for allowing circuits that end at this node.
data TorExitOptions = TorExitOptions {
      -- |The rules for allowing or rejecting traffic leaving this node.
      torExitRules :: [ExitRule]
      -- |The ports to disallow (Left) or allow (Right) when forwarding
      -- IPv6 traffic.
    , torIPv6Policy :: Either [PortSpec] [PortSpec]
      -- |Set this flag if you want to allow single-hop exits. These are
      -- usually not advisable, but according to the spec they may be
      -- usefule for "specialized controllers desgined to support perspective
      -- access and such."
    , torAllowSingleHopExits :: Bool
    }

-- |A reasonable default exit node options. This allows all outgoing
-- traffic to ports 22 (SSH), 80 (HTTP), 443 (HTTPS), 465 (SMTPS), and
-- 993 (IMAPS), and disallows single hop exits.
defaultTorExitOptions :: TorExitOptions
defaultTorExitOptions  = TorExitOptions {
    torExitRules = map (\ p -> ExitRuleAccept AddrSpecAll (PortSpecSingle p))
                       allowPorts
  , torIPv6Policy = Right (map PortSpecSingle allowPorts)
  , torAllowSingleHopExits = False
  }
 where allowPorts = [22, 80, 443, 465, 993]

-- -----------------------------------------------------------------------------

-- |If you like the output format of the default log function, but want to
-- send it to your own output stream, this is the function for you! This
-- function takes an outgoing logger and a string to log, and adds a nicely-
-- formatted and easily-sortable timestamp to the front of it.
--
-- NOTE: The default value for the logger is (makeLogger putStrLn).
makeLogger :: (String -> IO ()) -> String -> IO ()
makeLogger out msg =
  do now <- getCurrentTime
     out (timePrint timeFormat now ++ msg)
 where
   timeFormat = [Format_Text '[', Format_Year4, Format_Text '-', Format_Month2,
                 Format_Text '-', Format_Day2, Format_Text ' ', Format_Hour,
                 Format_Text ':', Format_Minute, Format_Text ']',
                 Format_Text ' ']



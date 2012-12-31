{-# LANGUAGE DeriveFunctor  #-}
{-# LANGUAGE KindSignatures #-}

-- | This module exports common types used throughout
-- @"Control.Proxy.Attoparsec".*@

module Control.Proxy.Attoparsec.Types
  ( -- * Proxy control
    ParserStatus(..)
  , SupplyUse(..)
  , ParserSupply
    -- * Error types
  , BadInput(..)
    -- * Attoparsec integration
  , AttoparsecInput(..)
  , ParserError(..)
  ) where

import qualified Data.Attoparsec.ByteString as ABS
import qualified Data.Attoparsec.Text       as AT
import           Data.Attoparsec.Types
import qualified Data.ByteString            as BS
import qualified Data.Text                  as T



-- | Status of a parsing 'Proxy'.
data ParserStatus a
  -- | There is a 'Parser' running and waiting for more @a@ input.
  --
  -- Receiving @('Resume', a)@ from upstream would feed input @a@ to the 'Parser'
  -- waiting for more input.
  = Parsing
    { psLength :: Int -- ^Length of input consumed so far.
    }
  -- | A 'Parser' has failed parsing.
  --
  -- Receiving @('Resume', a)@ from upstream would feed input @a@ to a newly
  -- started 'Parser'.
  | Failed
    { psLeftover :: a -- ^Input not yet consumed when the failure occurred.
    , psError    :: ParserError -- ^Error found while parsing.
    }
  deriving (Show, Eq)


data ParserError = ParserError
    { errorContexts :: [String]  -- ^ Contexts where the error occurred.
    , errorMessage  :: String    -- ^ Error message.
    } deriving (Show, Eq)


-- | Indicates how should a parsing 'Proxy' use new input.
data SupplyUse
  -- | Start a new parser and fed any new input to it.
  = Start
  -- | Resume feeding any new input to the current parser waiting for input.
  | Resume
  deriving (Eq, Show)


-- | Input supplied to a parsing 'Proxy'.
--
-- The 'SupplyUse' value indicates how the @a@ input chunk should be used.
type ParserSupply a = (SupplyUse, a)


-- | Reasons for an input value to be unnaceptable.
data BadInput
  = InputTooLong
    { itlLength :: Int -- ^ Length of the input.
    }
  | MalformedInput
    { miParserErrror :: ParserError -- ^ Error found while parsing.
    }
  deriving (Show, Eq)


-- | A class for valid Attoparsec input types.
class Eq a => AttoparsecInput a where
    -- | Run a 'Parser' with input @a@.
    parse :: Parser a b -> a -> IResult a b
    -- | Tests whether @a@ is empty.
    null :: a -> Bool
    -- | Skips the first @n@ elements from @a@ and returns the rest.
    drop :: Int -> a -> a
    -- | Number of elements in @a@.
    length :: a -> Int

instance AttoparsecInput BS.ByteString where
    parse = ABS.parse
    null = BS.null
    drop = BS.drop
    length = BS.length

instance AttoparsecInput T.Text where
    parse = AT.parse
    null = T.null
    drop = T.drop
    length = T.length

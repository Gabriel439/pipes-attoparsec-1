-- | This module allows you to run Attoparsec parsers on input flowing
-- downstream through 'Proxy' streams, possibly interleaving other stream
-- effects while doing so.
--
-- This Module builds on top of the @pipes@ and @pipes-parse@ package and
-- assumes you understand how to use those libraries.

module Pipes.Attoparsec
  ( -- * Parsing
    -- $parsing
    parse
  , parseMany
  , isEndOfParserInput
    -- * Types
  , I.ParserInput(I.null)
  , I.ParsingError(..)
  ) where

--------------------------------------------------------------------------------

import           Pipes
import qualified Pipes.Parse                       as P
import qualified Pipes.Lift                        as P
import qualified Pipes.Attoparsec.Internal         as I
import qualified Control.Monad.Trans.State.Strict  as S
import qualified Control.Monad.Trans.Error         as E
import           Data.Attoparsec.Types             (Parser)
import           Data.Foldable                     (mapM_)
import           Prelude                           hiding (mapM_)

--------------------------------------------------------------------------------

-- | Run an Attoparsec 'Parser' on input from the underlying 'Producer',
-- returning either a 'I.ParsingError' on failure, or a pair with the parsed
-- entity together with the length of input consumed in order to produce it.
--
-- Use this function only if 'isEndOfParserInput' returns 'False', otherwise
-- you'll get unexpected parsing errors.
parse
  :: (Monad m, I.ParserInput a)
  => Parser a b
  -> S.StateT (Producer a m r) m (Either I.ParsingError (Int, b))
parse attoparser = do
    (eb, mlo) <- I.parseWithMay P.draw attoparser
    mapM_ P.unDraw mlo
    return eb
{-# INLINABLE parse #-}

-- | Continuously run an Attoparsec 'Parser' on input from the given 'Producer',
-- sending downstream pairs of each successfully parsed entities together with
-- the length of input consumed in order to produce them.
--
-- This 'Producer' runs until it either runs out of input, in which case
-- it returns '()', or until a parsing failure occurs, in which case it throws
-- an error in the 'E.ErrorT' monad transformer indicating the 'I.ParsingError'
-- and providing a 'Producer' with any leftovers.
parseMany
  :: (Monad m, I.ParserInput a)
  => Parser a b
  -> Producer a m r
  -> Producer (Int, b) (E.ErrorT (I.ParsingError, Producer a m r) m) ()
parseMany attoparser src = do
    r <- hoist lift (P.runStateP src prod)
    case r of
      (Just e,  p) -> lift (E.throwError (e, p))
      (Nothing, _) -> lift (return ())
  where
    prod = do
        eof <- lift isEndOfParserInput
        if eof
          then return Nothing
          else do
            eb <- lift (parse attoparser)
            case eb of
              Left e  -> return (Just e)
              Right b -> yield b >> prod

--------------------------------------------------------------------------------

-- | Like 'P.isEndOfInput', except it also consumes and discards leading
-- empty 'I.ParserInput' chunks.
isEndOfParserInput
  :: (I.ParserInput a, Monad m)
  => S.StateT (Producer a m r) m Bool
isEndOfParserInput = do
    ma <- P.draw
    case ma of
      Just a
        | I.null a  -> isEndOfParserInput
        | otherwise -> P.unDraw a >> return False
      Nothing       -> return True
{-# INLINABLE isEndOfParserInput #-}


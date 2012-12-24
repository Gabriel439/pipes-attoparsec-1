> {-# LANGUAGE OverloadedStrings #-}

| In this tutorial you will learn how to use this library. The
"Simple example#example-simple" section should be enough to get you
going, but you can keep reading if you want to better understand how
to deal with complex parsing scenarios.

You may import this module and try the subsequent examples as you go.


> module Control.Proxy.Attoparsec.Tutorial
>   (-- * Simple example
>    -- $example-simple
>
>    -- * Handling parsing errors
>    -- $example-errors
>
>    -- * Composing control
>    -- $example-compose-control
>
>    -- * Try for yourself
>    -- $example-try
>     Name(..)
>   , hello
>   , input1
>   , input2
>   , helloPipe1
>   , helloPipe2
>   , helloPipe3
>   , helloPipe4
>   , helloPipe5
>   ) where
>
> import Control.Proxy
> import Control.Proxy.Attoparsec
> import Control.Proxy.Trans.Either
> import Data.Attoparsec.Text
> import Data.Text
>
> data Name = Name Text
>           deriving (Show)
>
> hello :: Parser Name
> hello = fmap Name $ "Hello " .*> char ' ' >> skipSpace >> takeWhile1 (/='.') <*. "."
>
> input1 :: [Text]
> input1 =
>   [ "Hello Kate."
>   , "Hello Mary."
>   ]
>
> input2 :: [Text]
> input2 =
>   [ "Hello Amy."
>   , "Hello, Hello Tim."
>   , "Hello Bob."
>   , "Hello James"
>   , "Hello"
>   , "Hello World."
>   , "HexHello Jon."
>   , "H"
>   , "ello Ann"
>   , "."
>   , "Hello Jean-Luc."
>   ]
>
> helloPipe1 :: (Proxy p, Monad m) => () -> Pipe (EitherP BadInput p) Text Name m r
> helloPipe1 = defaultParsingPipe hello
>
> helloPipe2 :: (Proxy p, Monad m) => () -> Pipe p Text Name m r
> helloPipe2 = parsingPipe skipMalformedChunks $ parserD hello
>
> helloPipe3 :: (Proxy p, Monad m) => () -> Pipe p Text Name m r
> helloPipe3 = parsingPipe skipMalformedInput $ parserD hello
>
> helloPipe4 :: (Proxy p, Monad m) => () -> Pipe (EitherP BadInput p) Text Name m r
> helloPipe4 = parsingPipe (limitInputLength 10) $ parserD hello
>
> helloPipe5 :: (Proxy p, Monad m) => () -> Pipe (EitherP BadInput p) Text Name m r
> helloPipe5 = parsingPipe (limitInputLength 10 >-> skipMalformedInput) $ parserD hello



$example-simple

We'll write a simple 'Parser' that turns 'Text' like /“Hello John Doe.”/
into @'Name' \"John Doe\"@, and then make a 'Pipe' that turns
those 'Text' values flowing downstream into 'Name' values flowing
downstream.

In this example we are using 'Text', but we may as well use 'ByteString'.
Also, the 'OverloadedStrings' language extension lets us write our parser
easily.

  > {-# LANGUAGE OverloadedStrings #-}
  >
  > import Control.Proxy
  > import Control.Proxy.Attoparsec
  > import Control.Proxy.Trans.Either
  > import Data.Attoparsec.Text
  > import Data.Text
  >
  > data Name = Name Text
  >           deriving (Show)
  >
  > hello :: Parser Name
  > hello = fmap Name $ "Hello " .*> char ' ' >> skipSpace >> takeWhile1 (/='.') <*. "."


We are done with our parser, now lets make a simple 'Pipe' out of it.

  > helloPipe1 :: (Proxy p, Monad m) => () -> Pipe (EitherP BadInput p) Text Name m r
  > helloPipe1 = defaultParsingPipe hello


As the type indicates, this 'Pipe' recieves 'Text' values from upstream and
sends 'Name' values downstream. Through the 'EitherP' proxy transformer we
report upstream errors due to bad input.

We need some sample input.

  > input1 :: [Text]
  > input1 =
  >   [ "Hello Kate."
  >   , "Hello Mary."
  >   ]

Now we can try our parsing pipe. We'll use @'fromListS' input1@ as our
input source, which sends downstream one element from the list at a time.
We'll call each of these elements a /chunk/. So, @'fromListS' input1@ sends
two /chunks/ of 'Text' downstream.

  >>> runProxy . runEitherK $ fromListS input1 >-> helloPipe1 >-> printD
  Name "Kate"
  Name "Mary"
  Right ()

We have acomplished our goal.


$example-errors

Let's try with some more complex input.

  > input2 :: [Text]
  > input2 =
  >   [ "Hello Amy."
  >   , "Hello, Hello Tim."
  >   , "Hello Bob."
  >   , "Hello James"
  >   , "Hello"
  >   , "Hello World."
  >   , "HexHello Jon."
  >   , "H"
  >   , "ello Ann"
  >   , "."
  >   , "Hello Jean-Luc."
  >   ]

  >>> runProxy . runEitherK $ fromListS input2 >-> helloPipe1 >-> printD
  Name "Amy"
  Left (MalformedInput {miParserErrror = ParserError {errorContexts = [], errorMessage = "Failed reading: takeWith"}})

The simple @helloPipe1@ we built aborts its execution by throwing a
'MalformedInput' value in the 'EitherP' proxy transformer when a
parsing error is arises. That might be enough if you are certain your
input is always well-formed, but sometimes you may prefer to act
differently on these extraordinary situations.

Instead of simply using 'defaultParsingPipe' to build @helloPipe1@,
we could use 'parsingPipe' and provide an additional error handler
that would, for example, skip malformed /chunks/.

  > parsingPipe :: (Monad m, Proxy p, AttoparsecInput a)
  >             => (ParsingStatus a -> ParsingControl p a m r)
  >             -> (() -> ParsingProxy p a b m r)
  >             -> () -> Pipe p a b m r

This is how 'defaultParsingPipe' made use of 'parsingPipe' for us:

  > defaultParsingPipe parser = parsingPipe throwParsingErrors $ parserD parser

The function 'parserD' takes a @'Parser' a b@ and turns it into the
'ParsingProxy' which does the actual parsing. This proxy gets input
from upstream after reporting its current status, which among other
things, says whether the 'Parser' has failed processing the last
input it was provided. The upstream 'Proxy', which we call
'ProxyControl', is then free to act upon this reported status. The
'parsingPipe' function takes a 'ProxyControl' and a 'ParsingProxy',
and compose them together into a simple 'Pipe' receiving @a@ values
from upstream and sending @b@ value downstream.

In 'defaultParsingPipe' we use 'throwParsingErrors' as our
'ProxyControl', which turns parsing failures into 'EitherP' errors.
Some other handlers for common scenarios are provided, you can use
them to build your parsing pipe using 'parsingPipe', or roll your own
as you'll learn in "Custom ProxyControl#custom-proxy-control".

You can learn more details about these handlers in
"Control.Proxy.Attoparsec". Here we'll see some usage examples.

['skipMalformedChunks']
  Skips the malformed /chunk/ being parsed and requests a new chunk to be
  parsed from start.

  > helloPipe2 :: (Proxy p, Monad m) => () -> Pipe p Text Name m r
  > helloPipe2 = parsingPipe skipMalformedChunks $ parserD hello

  >>> runProxy $ fromListS input2 >-> helloPipe2 >-> printD
  Name "Amy"
  Name "Bob"
  Name "JamesHelloHello World"
  Name "Ann"
  Name "Jean-Luc"

['skipMalformedInput']
  Skips single pieces of the malformed /chunk/, one at a time, until parsing
  succeds. It requests a new /chunk/ if needed.

  > helloPipe3 :: (Proxy p, Monad m) => () -> Pipe p Text Name m r
  > helloPipe3 = parsingPipe skipMalformedInput $ parserD hello

  >>> runProxy $ fromListS input2 >-> helloPipe3 >-> printD
  Name "Amy"
  Name "Tim"
  Name "Bob"
  Name "JamesHelloHello World"
  Name "Jon"
  Name "Ann"
  Name "Jean-Luc"

[@'limitInputLength' n@]
  If a @'Parser' a b@ has consumed input @a@ of length longer than
  @n@ without producing a @b@ value and it's still requesting more
  input,  then consider that an error and throw 'InputTooLong' in the
  'EitherP' proxy transformer.

  > helloPipe4 :: (Proxy p, Monad m) => () -> Pipe (EitherP BadInput p) Text Name m r
  > helloPipe4 = parsingPipe (limitInputLength 10) $ parserD hello

  >>> runProxy . runEitherK $ fromListS input2 >-> helloPipe4 >-> printD
  Name "Amy"
  Name "Bob"
  Left (InputTooLong {itlLenght = 11})

  Notice that by default parsing errors are ignored, that's why we
  didn't get any complaint about the malformed input between /“Amy”/
  and /“Bob”/.


$example-compose-control

These handlers are just 'Proxy' values, so they can be easily
composed together with @('>->')@. Suppose you want to limit the
length of your input to 10 and you also want to skip malformed bits
of input.

  > helloPipe5 :: (Proxy p, Monad m) => () -> Pipe (EitherP BadInput p) Text Name m r
  > helloPipe5 = parsingPipe (limitInputLength 10 >-> skipMalformedInput) $ parserD hello

  >>> runProxy . runEitherK $ fromListS input2 >-> helloPipe5 >-> printD
  Name "Amy"
  Name "Tim"
  Name "Bob"
  Left (InputTooLong {itlLenght = 11})


$example-try

This module exports the following aforementioned examples so
that you can try them.
module Reaction where

import Control.Comonad
import Data.Functor
import Effect

newtype Reaction w a = Reaction
  { runReaction :: w a -> Effect ()
  }

cmapF :: Functor w => (w a -> w b) -> Reaction w b -> Reaction w a
cmapF f reaction = Reaction $ runReaction reaction . f

cmap :: Functor w => (a -> b) -> Reaction w b -> Reaction w a
cmap f reaction = Reaction $ \w -> runReaction reaction $ fmap f w

liftK :: Comonad w => (a -> Effect b) -> Reaction w b -> Reaction w a
liftK f reaction =
  Reaction $ \w -> do
    x <- f (extract w)
    runReaction reaction $ fmap (const x) w

ignore :: Comonad w => Reaction w a
ignore = Reaction (const $ return ())

ignoreNothing :: Comonad w => Reaction w a -> Reaction w (Maybe a)
ignoreNothing = maybeReaction ignore

maybeReaction ::
     Comonad w => Reaction w () -> Reaction w a -> Reaction w (Maybe a)
maybeReaction nothingReaction justReaction =
  Reaction $ \x ->
    case extract x of
      Just x' -> runReaction justReaction $ fmap (const x') x
      Nothing -> runReaction nothingReaction $ void x

eitherReaction ::
     Comonad w => Reaction w a -> Reaction w b -> Reaction w (Either a b)
eitherReaction leftReaction rightReaction =
  Reaction $ \x ->
    case extract x of
      Left a -> runReaction leftReaction $ fmap (const a) x
      Right b -> runReaction rightReaction $ fmap (const b) x

ignoreLeft :: Comonad w => Reaction w b -> Reaction w (Either a b)
ignoreLeft = eitherReaction ignore

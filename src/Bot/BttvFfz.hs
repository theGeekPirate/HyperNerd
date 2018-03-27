{-# LANGUAGE OverloadedStrings #-}
module Bot.BttvFfz (bttvCommand, ffzCommand) where

import           Bot.Replies
import           Data.Aeson
import           Data.Aeson.Types
import           Data.List
import qualified Data.Text as T
import           Effect
import           Events
import           Network.HTTP.Simple
import           Safe
import           Text.Printf

requestEmoteList :: T.Text -> String -> (Object -> Either String [T.Text]) -> Effect ()
requestEmoteList sender url emoteListExtractor =
    maybe (logMsg $ T.pack $ printf "Couldn't parse URL %s" url)
          (\request ->
               do response <- eitherDecode
                                <$> getResponseBody
                                <$> httpRequest request
                  case response >>= emoteListExtractor of
                    Left err -> logMsg
                                  $ T.pack
                                  $ printf "Couldn't parse Emote List response: %s" err
                    Right emotes -> replyToUser sender
                                      $ T.pack
                                      $ printf "Available emotes: %s"
                                      $ T.concat $ intersperse " "
                                      $ emotes)
          (parseRequest url)

bttvApiResponseAsEmoteList :: Object -> Either String [T.Text]
bttvApiResponseAsEmoteList =
    parseEither $ \obj ->
        obj .: "emotes" >>= sequence . map (.: "code")

ffzApiResponseAsEmoteList :: Object -> Either String [T.Text]
ffzApiResponseAsEmoteList =
    parseEither $ \obj ->
        do room <- obj .: "room"
           sets <- obj .: "sets"
           setId <- (room .: "set") :: Parser Int
           roomSet <- sets .: (T.pack $ show $ setId)
           emoticons <- roomSet .: "emoticons"
           sequence $ map (.: "name") emoticons

ffzCommand :: Sender -> T.Text -> Effect ()
ffzCommand sender _ = requestEmoteList (senderName sender) url ffzApiResponseAsEmoteList
    where
      url = maybe "tsoding"
                  (printf "https://api.frankerfacez.com/v1/room/%s")
                  (tailMay $ T.unpack $ senderChannel sender)

bttvCommand :: Sender -> T.Text -> Effect ()
bttvCommand sender _ = requestEmoteList (senderName sender) url bttvApiResponseAsEmoteList
    where
      url = maybe "tsoding"
                  (printf "https://api.betterttv.net/2/channels/%s")
                  (tailMay $ T.unpack $ senderChannel sender)

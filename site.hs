{-# LANGUAGE OverloadedStrings #-}

import Data.Time.Format (defaultTimeLocale)
import Data.Text (Text)
import Hakyll
import qualified Text.DocTemplates as DocTemplates
import Text.Pandoc.Options
    ( WriterOptions (writerTableOfContents, writerTemplate)
    )

siteTitle :: String
siteTitle = "λ θ β ζ"

siteCtx :: Context String
siteCtx =
    constField "siteTitle" siteTitle <>
    defaultContext

postCtx :: Context String
postCtx =
    dateFieldWith defaultTimeLocale "date" "%d/%m/%Y" <>
    defaultContext

loadTocTemplate :: IO (DocTemplates.Template Text)
loadTocTemplate = do
    result <- DocTemplates.compileTemplate "toc" templateSource
    either fail pure result
  where
    templateSource =
        "<div class=\"toc\">\n" <>
        "<h2>Índice</h2>\n" <>
        "$toc$\n" <>
        "</div>\n" <>
        "$body$"

tocWriterOptions :: DocTemplates.Template Text -> WriterOptions
tocWriterOptions tocTemplate =
    defaultHakyllWriterOptions
        { writerTableOfContents = True
        , writerTemplate = Just tocTemplate
        }

postCompiler :: DocTemplates.Template Text -> Compiler (Item String)
postCompiler tocTemplate = do
    identifier <- getUnderlying
    hasToc <- (== Just "true") <$> getMetadataField identifier "toc"
    let writerOptions =
            if hasToc
                then tocWriterOptions tocTemplate
                else defaultHakyllWriterOptions
    pandocCompilerWith defaultHakyllReaderOptions writerOptions

main :: IO ()
main = do
  tocTemplate <- loadTocTemplate
  hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["contact.md"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" siteCtx
            >>= relativizeUrls

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ postCompiler tocTemplate
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" (siteCtx <> postCtx)
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) <>
                    constField "title" "Arquivo" <>
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" (archiveCtx <> siteCtx)
                >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) <>
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" (indexCtx <> siteCtx)
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

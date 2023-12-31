module Main (main) where

import Plutarch.Benchmark (decodeBenchmarks, diffBenchmarks, renderDiffTable)

import qualified Data.ByteString.Lazy as BSL
import System.Environment (getArgs)
import qualified Text.PrettyPrint.Boxes as B

--------------------------------------------------------------------------------

main :: IO ()
main =
  getArgs >>= \case
    [oldPath, newPath] -> do
      Right old <- decodeBenchmarks <$> BSL.readFile oldPath
      Right new <- decodeBenchmarks <$> BSL.readFile newPath

      putStrLn . B.render . renderDiffTable $ diffBenchmarks old new
    _ -> usage

usage :: IO ()
usage =
  putStrLn "usage: benchmark-diff [old] [new]"

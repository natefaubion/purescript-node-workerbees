{ name = "node-workerbees"
, dependencies =
  [ "aff"
  , "argonaut-core"
  , "arraybuffer-types"
  , "arrays"
  , "avar"
  , "console"
  , "effect"
  , "either"
  , "exceptions"
  , "foldable-traversable"
  , "foreign-object"
  , "newtype"
  , "parallel"
  , "prelude"
  , "transformers"
  , "tuples"
  , "variant"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}

{ name = "node-workerbees"
, dependencies =
  [ "aff"
  , "argonaut-core"
  , "arraybuffer-types"
  , "avar"
  , "console"
  , "effect"
  , "either"
  , "exceptions"
  , "maybe"
  , "newtype"
  , "parallel"
  , "variant"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}

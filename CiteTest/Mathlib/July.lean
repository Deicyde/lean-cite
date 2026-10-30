import Lean

/-!
The API of Mathlib's `Mathlib/Tactic/CrossRefAttribute.lean` from 2026-07-04 (at 1c3e8f34a8), cut to what `#cite_export`
reads: the database type, its names and addresses, `Tag` and `tagExt`. Mathlib is Apache-2.0.
-/

open Lean

namespace Mathlib.CrossRef

inductive Database where
  | kerodon
  | lmfdb
  | stacks
  | wikidata
  deriving BEq, Hashable

namespace Database

def url : Database → String
  | .kerodon => "https://kerodon.net/tag/"
  | .lmfdb => "https://www.lmfdb.org/knowledge/show/"
  | .stacks => "https://stacks.math.columbia.edu/tag/"
  | .wikidata => "https://www.wikidata.org/wiki/"

def label : Database → String
  | .kerodon => "Kerodon Tag"
  | .lmfdb => "LMFDB"
  | .stacks => "Stacks Tag"
  | .wikidata => "Wikidata"

def shortName : Database → String
  | .kerodon => "kerodon"
  | .lmfdb => "lmfdb"
  | .stacks => "stacks"
  | .wikidata => "wikidata"

end Database

structure Tag where
  declName : Name
  database : Database
  tag : String
  comment : String
  deriving BEq, Hashable

initialize tagExt : SimplePersistentEnvExtension Tag (Array (Array Tag)) ←
  registerSimplePersistentEnvExtension {
    addImportedFn tags := tags
    addEntryFn tags _ := tags
  }

end Mathlib.CrossRef

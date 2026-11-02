/-
Copyright (c) 2024 Damiano Testa. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Damiano Testa
-/
import Lean

/-!
The API of Mathlib's `Mathlib/Tactic/CrossRefAttribute.lean` from 2026-09-01 (at 981fa8f557), cut to what `#cite_export`
reads: the database type, its names and addresses, `Tag` and `tagExt`. Mathlib is Apache-2.0.
-/

open Lean

namespace Mathlib.CrossRef

inductive PiBaseTopic where
  | topology
  deriving BEq, Hashable, Ord

def PiBaseTopic.urlSubdomain : PiBaseTopic → String
  | topology => "topology"

def PiBaseTopic.shortName : PiBaseTopic → String
  | topology => "topology"

inductive Database where
  | dlmf
  | kerodon
  | lmfdb
  | pibase (topic : PiBaseTopic)
  | stacks
  | wikidata
  deriving BEq, Hashable, Ord

namespace Database

-- Mathlib picks the π-Base path from the identifier's first letter with `String.take`
def url : Database → String → String
  | .dlmf, id => s!"https://dlmf.nist.gov/{id}"
  | .kerodon, id => s!"https://kerodon.net/tag/{id}"
  | .lmfdb, id => s!"https://www.lmfdb.org/knowledge/show/{id}"
  | .pibase topic, id =>
    let path := if id.startsWith "P" then "properties" else if id.startsWith "S" then "spaces"
      else if id.startsWith "T" then "theorems" else ""
    s!"https://{topic.urlSubdomain}.pi-base.org/{path}/{id}"
  | .stacks, id => s!"https://stacks.math.columbia.edu/tag/{id}"
  | .wikidata, id => s!"https://www.wikidata.org/wiki/{id}"

def shortName : Database → String
  | .dlmf => "dlmf"
  | .kerodon  => "kerodon"
  | .lmfdb    => "lmfdb"
  | .pibase topic => s!"pibase-{topic.shortName}"
  | .stacks   => "stacks"
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

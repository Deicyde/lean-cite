/-
Copyright (c) 2024 Damiano Testa. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Damiano Testa
-/
import Lean

/-!
The API of Mathlib's `Mathlib/Tactic/CrossRefAttribute.lean` from 2026-05-13 (at 6d6fafce1d), cut to what `#cite_export`
reads: the database type, its names and addresses, `Tag` and `tagExt`. Mathlib is Apache-2.0.
-/

open Lean

namespace Mathlib.CrossRef

inductive Database where
  | kerodon
  | stacks
  | wikidata
  deriving BEq, Hashable

def databaseURL : Database → String
  | .kerodon => "https://kerodon.net/tag/"
  | .stacks => "https://stacks.math.columbia.edu/tag/"
  | .wikidata => "https://www.wikidata.org/wiki/"

def databaseLabel : Database → String
  | .kerodon => "Kerodon Tag"
  | .stacks => "Stacks Tag"
  | .wikidata => "Wikidata"

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

/-
Copyright (c) 2024 Damiano Testa. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Damiano Testa
-/
import Lean

/-!
The API of Mathlib's `Mathlib/Tactic/StacksAttribute.lean` to 2026-05-12 (at 5450b53), cut to what `#cite_export`
reads: the database type, its names and addresses, `Tag` and `tagExt`. Mathlib is Apache-2.0.
-/

open Lean

namespace Mathlib.StacksTag

inductive Database where
  | kerodon
  | stacks
  deriving BEq, Hashable

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

end Mathlib.StacksTag

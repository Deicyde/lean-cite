import Lean

/-! A layout no reader knows: `Mathlib.CrossRef.tagExt` holds a `Tag` with no database. -/

open Lean

namespace Mathlib.CrossRef

structure Tag where
  declName : Name
  tag : String
  deriving BEq, Hashable

initialize tagExt : SimplePersistentEnvExtension Tag (Array (Array Tag)) ←
  registerSimplePersistentEnvExtension {
    addImportedFn tags := tags
    addEntryFn tags _ := tags
  }

end Mathlib.CrossRef

import Lean
open Lean

/-- `.sync`: the role runs on a theorem's asynchronous branch, where a `mainOnly` extension panics. -/
initialize tagsExt : SimplePersistentEnvExtension (Name × String) (Array (Name × String)) ←
  registerSimplePersistentEnvExtension {
    addImportedFn := fun xs => xs.flatten
    addEntryFn := Array.push
    asyncMode := .sync
  }


import LinearAlgebraDoneRightLean.Section_1A
import LinearAlgebraDoneRightLean.Section_1B
import LinearAlgebraDoneRightLean.Section_1C
import LinearAlgebraDoneRightLean.Section_6A

open Lean

/-! Each constant of the modules the chapter 1 tags touch, with its whole type and value as raw
expressions, for `compare_terms.py`. Run from a checkout of the demo, on each branch:
`TERMS_OUT=main.tsv lake env lean <this file>`. -/

run_cmd do
  let env ← getEnv
  let some path ← IO.getEnv "TERMS_OUT" | throwError "TERMS_OUT is not set"
  let mods := #[`LinearAlgebraDoneRightLean.Section_1A, `LinearAlgebraDoneRightLean.Section_1B,
    `LinearAlgebraDoneRightLean.Section_1C, `LinearAlgebraDoneRightLean.Section_6A]
  IO.FS.withFile path .write fun h => do
    for m in mods do
      let some idx := env.getModuleIdx? m | throw (IO.userError s!"no module {m}")
      let some data := env.header.moduleData[idx.toNat]? | throw (IO.userError s!"no data for {m}")
      for n in data.constNames do
        let some ci := env.find? n | continue
        let v := (ci.value? (allowOpaque := true)).map toString |>.getD ""
        h.putStrLn s!"{n}\t{(toString ci.type).quote}\t{v.quote}"

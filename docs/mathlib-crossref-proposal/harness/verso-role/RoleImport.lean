import RoleDecls
open Lean
run_cmd do
  logInfo m!"imported roleThm: {repr (← findDocString? (← getEnv) ``roleThm)}"
  logInfo m!"imported roleDef: {repr (← findDocString? (← getEnv) ``roleDef)}"
  logInfo m!"imported tags: {(PersistentEnvExtension.getState tagsExt (← getEnv)).2}"

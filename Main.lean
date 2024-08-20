/-
Copyright (c) 2024 BICMR@PKU. All rights reserved.
Released under the Apache 2.0 license as described in the file LICENSE.
Authors: Tony Beta Lambda
-/
import Analyzer.Types
import Analyzer.Load
import Analyzer.Process
import Cli

open System Cli
open Lean hiding Options
open Parser hiding mkIdent ident
open Elab Command Term
open Analyzer

def parseFlag (p : Parsed) (s : String) : PluginOption :=
  match p.flag? s with
  | none => .ignore
  | some f => .json <| .mk <| f.as! String

elab "impl_parseOptions" : term => do
  let param ← mkFreshBinderName
  let fields ← Process.plugins.mapM fun (name, _) => do
    let lval ← `(structInstLVal| $(mkIdent name):ident)
    let nameStr := Syntax.mkStrLit name.getString!
    let val ← `(parseFlag $(mkIdent param) $nameStr)
    return ← `(structInstField| $lval := $val)
  let val ← `(fun $(mkIdent param) => { $fields* })
  let type ← `(Parsed → Options)
  elabTerm val (← elabTerm type none)

unsafe def runCommand (p : Parsed) : IO UInt32 := do
  let file := FilePath.mk <| p.positionalArg! "file" |>.as! String
  let options := impl_parseOptions p
  if p.hasFlag "initializer" then
    enableInitializersExecution
  withFile' file do
    run options
    let messages := (← get).commandState.messages
    messages.forM fun message => do
      IO.eprint (← message.toString)
  return 0

unsafe def jixiaCommand : Cmd := `[Cli|
  jixia VIA runCommand;
  "A static analysis tool for Lean 4."

  FLAGS:
    m, «import» : String;  "Import info"
    d, declaration : String;  "Declaration info"
    s, symbol : String;  "Symbol info"
    t, tactic : String;  "Tactic info"
    a, ast : String;  "AST"
    i, initializer;  "Execute initializers"

  ARGS:
    file : String;  "File to process"
]

unsafe def main (args : List String) : IO UInt32 :=
  jixiaCommand.validate args

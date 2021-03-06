(**
   Derive a javascript AST from a tree-sitter typescript CST.

   This is derived from generated code 'typescript/lib/Boilerplate.ml'
   in ocaml-tree-sitter-lang and reuse functions from
   Parse_javascript_tree_sitter since the typescript tree-sitter grammar
   itself extends the tree-sitter javascript grammar.
*)

open Common
module AST = Ast_js
module H = Parse_tree_sitter_helpers
module G = AST_generic
module PI = Parse_info
open Ast_js

(*
   Development notes

   - Try to change the structure of this file as little as possible,
     since it's derived from generated code and we'll have to merge
     updates as the grammar changes.
   - Typescript is a superset of javascript.
   - We started by ignoring typescript-specific constructs and mapping
     the rest to a javascript AST.
   - The 'todo' function raises an exception. Make sure it can't be called,
     for example by writing 'let _v () = todo ()' instead of
     'let _v = todo ()'.
   - Alternatively, prefix the containing function with 'todo_' so we know it
     should not be called for the time being. Remove the 'todo_' prefix
     once it's safe to call. It's ok if returns an empty result, as long
     as it doesn't raise an exception.
*)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

type env = H.env
let fb = G.fake_bracket

exception TODO

(*
   This is a 'todo' that was already reviewed and should not be called by the
   current implementation.
*)
let todo (_env : env) _ =
  raise TODO

(*****************************************************************************)
(* Boilerplate converter *)
(*****************************************************************************)

(* Disable warnings against unused variables *)
[@@@warning "-26-27"]

(*
   We extend the javascript parsing module. Types are
   partially compatible.
*)
module JS_CST = Parse_javascript_tree_sitter.CST
module JS = Parse_javascript_tree_sitter
module CST = CST_tree_sitter_typescript (* typescript+tsx, merged *)

let accessibility_modifier (env : env) (x : CST.accessibility_modifier) =
  (match x with
  | `Public tok -> JS.token env tok (* "public" *)
  | `Priv tok -> JS.token env tok (* "private" *)
  | `Prot tok -> JS.token env tok (* "protected" *)
  )

let predefined_type (env : env) (x : CST.predefined_type) =
  (match x with
  | `Any tok -> JS.identifier env tok (* "any" *)
  | `Num tok -> JS.identifier env tok (* "number" *)
  | `Bool tok -> JS.identifier env tok (* "boolean" *)
  | `Str tok -> JS.identifier env tok (* "string" *)
  | `Symb tok -> JS.identifier env tok (* "symbol" *)
  | `Void tok -> JS.identifier env tok (* "void" *)
  )

let anon_choice_PLUSPLUS (env : env) (x : CST.anon_choice_PLUSPLUS) =
  (match x with
  | `PLUSPLUS tok -> G.Incr, JS.token env tok (* "++" *)
  | `DASHDASH tok -> G.Decr, JS.token env tok (* "--" *)
  )

let anon_choice_type (env : env) (x : CST.anon_choice_type) =
  (match x with
  | `Type tok -> JS.token env tok (* "type" *)
  | `Typeof tok -> JS.token env tok (* "typeof" *)
  )

let automatic_semicolon (env : env) (tok : CST.automatic_semicolon) =
  JS.token env tok (* automatic_semicolon *)

let anon_choice_get (env : env) (x : CST.anon_choice_get) =
  (match x with
  | `Get tok -> Get, JS.token env tok (* "get" *)
  | `Set tok -> Get, JS.token env tok (* "set" *)
  | `STAR tok -> Get, JS.token env tok (* "*" *)
  )

let reserved_identifier (env : env) (x : CST.reserved_identifier) =
  (match x with
  | `Decl tok -> JS.identifier env tok (* "declare" *)
  | `Name tok -> JS.identifier env tok (* "namespace" *)
  | `Type tok -> JS.identifier env tok (* "type" *)
  | `Public tok -> JS.identifier env tok (* "public" *)
  | `Priv tok -> JS.identifier env tok (* "private" *)
  | `Prot tok -> JS.identifier env tok (* "protected" *)
  | `Read tok -> JS.identifier env tok (* "readonly" *)
  | `Module tok -> JS.identifier env tok (* "module" *)
  | `Any tok -> JS.identifier env tok (* "any" *)
  | `Num tok -> JS.identifier env tok (* "number" *)
  | `Bool tok -> JS.identifier env tok (* "boolean" *)
  | `Str tok -> JS.identifier env tok (* "string" *)
  | `Symb tok -> JS.identifier env tok (* "symbol" *)
  | `Void tok -> JS.identifier env tok (* "void" *)
  | `Export tok -> JS.identifier env tok (* "export" *)
  | `Choice_get x ->
      (match x with
      | `Get tok -> JS.identifier env tok (* "get" *)
      | `Set tok -> JS.identifier env tok (* "set" *)
      | `Async tok -> JS.identifier env tok (* "async" *)
      | `Static tok -> JS.identifier env tok (* "static" *)
      )
  )

let anon_choice_COMMA (env : env) (x : CST.anon_choice_COMMA) =
  (match x with
  | `COMMA tok -> JS.token env tok (* "," *)
  | `Choice_auto_semi x -> JS.semicolon env x
  )

(* TODO: types *)
let import_export_specifier (env : env) ((v1, v2, v3) : CST.import_export_specifier) =
  let _v1 () =
    (match v1 with
    | Some x -> anon_choice_type env x
    | None -> todo env ())
  in
  JS.import_export_specifier env (v2, v3)

let rec anon_choice_type_id (env : env) (x : CST.anon_choice_type_id) : ident list =
  (match x with
  | `Id tok -> [JS.identifier env tok] (* identifier *)
  | `Nested_id x -> nested_identifier env x
  )

and nested_identifier (env : env) ((v1, v2, v3) : CST.nested_identifier) =
  let v1 = anon_choice_type_id env v1 in
  let v2 = JS.token env v2 (* "." *) in
  let v3 = JS.identifier env v3 (* identifier *) in
  v1 @ [v3]

let concat_nested_identifier env (idents : ident list) : ident =
  let str = idents |> List.map fst |> String.concat "." in
  let tokens = List.map snd idents in
  let x, xs =
    match tokens with
    | [] -> assert false
    | x :: xs -> x, xs
  in
  str, PI.combine_infos x xs

(* TODO: 'require(...)' to AST?

   example:
      import zip = require("./ZipCodeValidator");

   Treating 'require' like assignment and function application for now.
 *)
let import_require_clause (env : env) ((v1, v2, v3, v4, v5, v6) : CST.import_require_clause) =
  let v1 = JS.identifier env v1 (* identifier *) |> JS.idexp in
  let v2 = JS.token env v2 (* "=" *) in
  let v3 = JS.identifier env v3 (* "require" *) |> JS.idexp in
  let v4 = JS.token env v4 (* "(" *) in
  let v5 = JS.string_ env v5 in
  let v6 = JS.token env v6 (* ")" *) in
  [] (* TODO *)

(* TODO types *)
let todo_literal_type (env : env) (x : CST.literal_type) =
  (match x with
  | `Num_ (v1, v2) ->
      let v1 =
        (match v1 with
        | `DASH tok -> JS.token env tok (* "-" *)
        | `PLUS tok -> JS.token env tok (* "+" *)
        )
      in
      let v2 = JS.token env v2 (* number *) in
      todo env (v1, v2)
  | `Num tok -> JS.token env tok (* number *)
  | `Str x -> todo env (JS.string_ env x)
  | `True tok -> JS.token env tok (* "true" *)
  | `False tok -> JS.token env tok (* "false" *)
  )

(* TODO types *)
let todo_nested_type_identifier (env : env) ((v1, v2, v3) : CST.nested_type_identifier) =
  let v1 = anon_choice_type_id env v1 in
  let v2 = JS.token env v2 (* "." *) in
  let v3 = JS.token env v3 (* identifier *) in
  todo env (v1, v2, v3)

let todo_anon_choice_type_id2 (env : env) (x : CST.anon_choice_type_id2) =
  (match x with
  | `Id tok -> JS.token env tok (* identifier *)
  | `Nested_type_id x -> todo_nested_type_identifier env x
  )

let anon_choice_rese_id (env : env) (x : CST.anon_choice_rese_id) : ident =
  (match x with
  | `Choice_decl x -> reserved_identifier env x
  | `Id tok -> JS.identifier env tok (* identifier *)
  )

let identifier_reference (env : env) (x : CST.identifier_reference) : ident =
  (match x with
  | `Id tok -> JS.identifier env tok (* identifier *)
  | `Choice_decl x -> reserved_identifier env x
  )

let anon_import_export_spec_rep_COMMA_import_export_spec (env : env) ((v1, v2) : CST.anon_import_export_spec_rep_COMMA_import_export_spec) =
  let v1 = import_export_specifier env v1 in
  let v2 =
    List.map (fun (v1, v2) ->
      let _v1 = JS.token env v1 (* "," *) in
      let v2 = import_export_specifier env v2 in
      v2
    ) v2
  in
  v1::v2

let export_clause (env : env) ((v1, v2, v3, v4) : CST.export_clause) =
  let _v1 = JS.token env v1 (* "{" *) in
  let v2 =
    (match v2 with
    | Some x ->
        anon_import_export_spec_rep_COMMA_import_export_spec env x
    | None -> [])
  in
  let _v3 =
    (match v3 with
    | Some tok -> Some (JS.token env tok) (* "," *)
    | None -> None)
  in
  let _v4 = JS.token env v4 (* "}" *) in
  v2

let named_imports (env : env) ((v1, v2, v3, v4) : CST.named_imports) =
  let _v1 = JS.token env v1 (* "{" *) in
  let v2 =
    (match v2 with
    | Some x ->
        anon_import_export_spec_rep_COMMA_import_export_spec env x
    | None -> [])
  in
  let _v3 =
    (match v3 with
    | Some tok -> Some (JS.token env tok) (* "," *)
    | None -> None)
  in
  let _v4 = JS.token env v4 (* "}" *) in
  (fun tok path ->
    v2 |> List.map (fun (n1, n2opt) -> Import (tok, n1, n2opt, path))
  )

let import_clause (env : env) (x : CST.import_clause) =
  (match x with
  | `Name_import x -> JS.namespace_import env x
  | `Named_imports x -> named_imports env x
  | `Id_opt_COMMA_choice_name_import (v1, v2) ->
      let v1 = JS.identifier env v1 (* identifier *) in
      let v2 =
        (match v2 with
        | Some (v1, v2) ->
            let v1 = JS.token env v1 (* "," *) in
            let v2 =
              (match v2 with
              | `Name_import x -> JS.namespace_import env x
              | `Named_imports x -> named_imports env x
              )
            in
            v2
        | None ->
            (fun _t _path -> [])
        )
      in
      (fun t path ->
         let default = Import (t, (default_entity, snd v1), Some v1, path) in
         default :: v2 t path
      )
  )

let rec decorator_member_expression (env : env) ((v1, v2, v3) : CST.decorator_member_expression) : ident list =
  let v1 = anon_choice_id_ref env v1 in
  let _v2 = JS.token env v2 (* "." *) in
  let v3 = JS.identifier env v3 (* identifier *) in
  v1 @ [v3]

and anon_choice_id_ref (env : env) (x : CST.anon_choice_id_ref) : ident list =
  (match x with
  | `Choice_id x -> [identifier_reference env x]
  | `Deco_member_exp x ->
      decorator_member_expression env x
  )

(* TODO don't ignore type annotation *)
let rec parenthesized_expression (env : env) ((v1, v2, v3) : CST.parenthesized_expression) =
  let _v1 = JS.token env v1 (* "(" *) in
  let v2 =
    (match v2 with
    | `Exp_opt_type_anno (v1, v2) ->
        let v1 = expression env v1 in
        let _v2 =
          (match v2 with
          | Some x -> Some (type_annotation env x)
          | None -> None)
        in
        v1
    | `Seq_exp x -> sequence_expression env x
    )
  in
  let _v3 = JS.token env v3 (* ")" *) in
  v2

and jsx_opening_element (env : env) ((v1, v2, v3, v4) : CST.jsx_opening_element) =
  let _v1 = JS.token env v1 (* "<" *) in
  let v2 : ident =
    (match v2 with
     | `Choice_choice_jsx_id x -> JS.jsx_attribute_name env x
     | `Choice_id_opt_type_args (v1, v2) ->
         let v1 = anon_choice_type_id env v1 in
         let id = concat_nested_identifier env v1 in
         let _v2 () =
           (match v2 with
            | Some x -> todo_type_arguments env x
            | None -> todo env ())
         in
         id
    )
  in
  let v3 = List.map (jsx_attribute_ env) v3 in
  let _v4 = JS.token env v4 (* ">" *) in
  v2, v3

and jsx_fragment (env : env) ((v1, v2, v3, v4, v5, v6) : CST.jsx_fragment)
 : xml =
  let v1 = JS.token env v1 (* "<" *) in
  let _v2 = JS.token env v2 (* ">" *) in
  let v3 = List.map (jsx_child env) v3 in
  let _v4 = JS.token env v4 (* "<" *) in
  let _v5 = JS.token env v5 (* "/" *) in
  let _v6 = JS.token env v6 (* ">" *) in
  { xml_tag = "", v1; xml_attrs = []; xml_body = v3 }

and jsx_expression (env : env) ((v1, v2, v3) : CST.jsx_expression) : expr bracket =
  let v1 = JS.token env v1 (* "{" *) in
  let v2 =
    (match v2 with
     | Some x ->
         (match x with
          | `Exp x -> expression env x
          | `Seq_exp x -> sequence_expression env x
          | `Spread_elem x ->
              let (t, e) = spread_element env x in
              Apply (IdSpecial (Spread, t), fb [e])
         )
     (* abusing { } in XML to just add comments, e.g. { /* lint-ignore */ } *)
     | None ->
         IdSpecial (Null, v1)
    )
  in
  let v3 = JS.token env v3 (* "}" *) in
  v1, v2, v3

and jsx_attribute_ (env : env) (x : CST.jsx_attribute_) : xml_attribute =
  (match x with
   | `Jsx_attr (v1, v2) ->
       let v1 = JS.jsx_attribute_name env v1 in
       let v2 =
         match v2 with
         | Some (v1, v2) ->
             let _v1bis = JS.token env v1 (* "=" *) in
             let v2 = jsx_attribute_value env v2 in
             v2
         (* see https://www.reactenlightenment.com/react-jsx/5.7.html *)
         | None -> Bool (true, snd v1)
       in
       XmlAttr (v1, v2)
   (* less: we could enforce that it's only a Spread operation *)
   | `Jsx_exp x ->
       let e = jsx_expression env x in
       XmlAttrExpr e
  )

and jsx_attribute_value (env : env) (x : CST.jsx_attribute_value) =
  (match x with
   | `Str x ->
       let s = JS.string_ env x in
       String s
   | `Jsx_exp x ->
       let (_, e, _) = jsx_expression env x in
       e
   (* an attribute value can be a jsx element? *)
   | `Choice_jsx_elem x ->
       let xml = jsx_element_ env x in
       Xml xml
   | `Jsx_frag x ->
       let xml = jsx_fragment env x in
       Xml xml
  )

and jsx_child (env : env) (x : CST.jsx_child) : xml_body =
  (match x with
   | `Jsx_text tok ->
       let s = JS.str env tok (* pattern [^{}<>]+ *) in
       XmlText s
   | `Choice_jsx_elem x ->
       let xml = jsx_element_ env x in
       XmlXml xml
   | `Jsx_exp x ->
       let (_, e, _) = jsx_expression env x in
       XmlExpr e
  )

and jsx_element_ (env : env) (x : CST.jsx_element_) : xml =
  (match x with
   | `Jsx_elem (v1, v2, v3) ->
       let v1 = jsx_opening_element env v1 in
       let v2 = List.map (jsx_child env) v2 in
       let v3 = JS.jsx_closing_element env v3 in
       { xml_tag = fst v1; xml_attrs = snd v1;
         xml_body = v2 }
   | `Jsx_self_clos_elem (v1, v2, v3, v4, v5) ->
       let v1 = JS.token env v1 (* "<" *) in
       let v2 = JS.jsx_element_name env v2 in
       let v3 = List.map (jsx_attribute_ env) v3 in
       let v4 = JS.token env v4 (* "/" *) in
       let v5 = JS.token env v5 (* ">" *) in
       { xml_tag = v2; xml_attrs = v3; xml_body = [] }
  )

and destructuring_pattern (env : env) (x : CST.destructuring_pattern) : expr =
  (match x with
  | `Obj x -> let o = object_ env x in Obj o
  | `Array x -> array_ env x
  )

and variable_declaration (env : env) ((v1, v2, v3, v4) : CST.variable_declaration) : var list =
  let v1 = Var, JS.token env v1 (* "var" *) in
  let v2 = variable_declarator env v2 in
  let v3 =
    List.map (fun (v1, v2) ->
      let _v1 = JS.token env v1 (* "," *) in
      let v2 = variable_declarator env v2 in
      v2
    ) v3
  in
  let _v4 = JS.semicolon env v4 in
  let vars = v2::v3 in
  JS.build_vars v1 vars

and function_ (env : env) ((v1, v2, v3, v4, v5) : CST.function_) : fun_ * ident option =
  let v1 =
    (match v1 with
    | Some tok -> [Async, JS.token env tok] (* "async" *)
    | None -> [])
  in
  let _v2 = JS.token env v2 (* "function" *) in
  let v3 =
    (match v3 with
    | Some tok -> Some (JS.identifier env tok) (* identifier *)
    | None -> None)
  in
  let v4 = call_signature env v4 in
  let v5 = statement_block env v5 in
  { f_props = v1; f_params = v4; f_body = v5 }, v3

(* TODO types *)
and todo_generic_type (env : env) ((v1, v2) : CST.generic_type) =
  let v1 = todo_anon_choice_type_id2 env v1 in
  let v2 = todo_type_arguments env v2 in
  todo env (v1, v2)

(* TODO types: 'implements' *)
and todo_implements_clause (env : env) ((v1, v2, v3) : CST.implements_clause) =
  let v1 = JS.token env v1 (* "implements" *) in
  let v2 = todo_type_ env v2 in
  let v3 =
    List.map (fun (v1, v2) ->
      let v1 = JS.token env v1 (* "," *) in
      let v2 = todo_type_ env v2 in
      todo env (v1, v2)
    ) v3
  in
  todo env (v1, v2, v3)

and anon_choice_exp (env : env) (x : CST.anon_choice_exp) =
  (match x with
  | `Exp x -> expression env x
  | `Spread_elem x ->
      let (t, e) = spread_element env x in
      Apply (IdSpecial (Spread, t), fb [e])
  )

and switch_default (env : env) ((v1, v2, v3) : CST.switch_default) =
  let v1 = JS.token env v1 (* "default" *) in
  let _v2 = JS.token env v2 (* ":" *) in
  let v3 = List.map (statement env) v3 |> List.flatten in
  Default (v1, stmt_of_stmts v3)

and binary_expression (env : env) (x : CST.binary_expression) : expr =
  (match x with
  | `Exp_AMPAMP_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "&&" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.And, v2), fb [v1; v3])
  | `Exp_BARBAR_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "||" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Or, v2), fb [v1; v3])
  | `Exp_GTGT_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* ">>" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.LSR, v2), fb [v1; v3])
  | `Exp_GTGTGT_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* ">>>" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.ASR, v2), fb [v1; v3])
  | `Exp_LTLT_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "<<" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.LSL, v2), fb [v1; v3])
  | `Exp_AMP_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "&" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.BitAnd, v2), fb [v1; v3])
  | `Exp_HAT_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "^" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.BitXor, v2), fb [v1; v3])
  | `Exp_BAR_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "|" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.BitOr, v2), fb [v1; v3])
  | `Exp_PLUS_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "+" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Plus, v2), fb [v1; v3])
  | `Exp_DASH_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "-" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Minus, v2), fb [v1; v3])
  | `Exp_STAR_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "*" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Mult, v2), fb [v1; v3])
  | `Exp_SLASH_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "/" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Div, v2), fb [v1; v3])
  | `Exp_PERC_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "%" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Mod, v2), fb [v1; v3])
  | `Exp_STARSTAR_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "**" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Pow, v2), fb [v1; v3])
  | `Exp_LT_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "<" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Lt, v2), fb [v1; v3])
  | `Exp_LTEQ_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "<=" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.LtE, v2), fb [v1; v3])
  | `Exp_EQEQ_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "==" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Eq, v2), fb [v1; v3])
  | `Exp_EQEQEQ_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "===" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.PhysEq, v2), fb [v1; v3])
  | `Exp_BANGEQ_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "!=" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.NotEq, v2), fb [v1; v3])
  | `Exp_BANGEQEQ_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "!==" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.NotPhysEq, v2), fb [v1; v3])
  | `Exp_GTEQ_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* ">=" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.GtE, v2), fb [v1; v3])
  | `Exp_GT_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* ">" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Gt, v2), fb [v1; v3])
  | `Exp_QMARKQMARK_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "??" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (ArithOp G.Nullish, v2), fb [v1; v3])
  | `Exp_inst_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "instanceof" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (Instanceof, v2), fb [v1; v3])
  | `Exp_in_exp (v1, v2, v3) ->
      let v1 = expression env v1 in
      let v2 = JS.token env v2 (* "in" *) in
      let v3 = expression env v3 in
      Apply (IdSpecial (In, v2), fb [v1; v3])
  )

and arguments (env : env) ((v1, v2, v3) : CST.arguments) : arguments =
  let v1 = JS.token env v1 (* "(" *) in
  let v2 =
    anon_opt_opt_choice_exp_rep_COMMA_opt_choice_exp env v2
  in
  let v3 = JS.token env v3 (* ")" *) in
  v1, v2, v3

and generator_function_declaration (env : env) ((v1, v2, v3, v4, v5, v6, v7) : CST.generator_function_declaration) : var list =
  let v1 =
    (match v1 with
    | Some tok -> [Async, JS.token env tok] (* "async" *)
    | None -> [])
  in
  let v2 = JS.token env v2 (* "function" *) in
  let v3 = [Generator, JS.token env v3] (* "*" *) in
  let v4 = JS.identifier env v4 (* identifier *) in
  let v5 = call_signature env v5 in
  let v6 = statement_block env v6 in
  let _v7 =
    (match v7 with
    | Some tok -> Some (JS.token env tok) (* automatic_semicolon *)
    | None -> None)
  in
  let f = { f_props = v1 @ v3; f_params = v5; f_body = v6 } in
  [{ v_name = v4; v_kind = Const, v2;
     v_type = None;
     v_init = Some (Fun (f, None)); v_resolved = ref NotResolved }]

and variable_declarator (env : env) ((v1, v2, v3) : CST.variable_declarator) =
  let v1 = anon_choice_type_id_ env v1 in
  let v2 =
    (match v2 with
    | Some x -> Some (type_annotation env x)
    | None -> None)
  in
  let v3 =
    (match v3 with
    | Some x -> Some (initializer_ env x)
    | None -> None)
  in
  v1, v2, v3

and sequence_expression (env : env) ((v1, v2, v3) : CST.sequence_expression) =
  let v1 = expression env v1 in
  let v2 = JS.token env v2 (* "," *) in
  let v3 =
    (match v3 with
    | `Seq_exp x -> sequence_expression env x
    | `Exp x -> expression env x
    )
  in
  Apply (IdSpecial (Seq, v2), fb [v1; v3])

(* TODO: types *)
and todo_type_arguments (env : env) ((v1, v2, v3, v4, v5) : CST.type_arguments) =
  let v1 = JS.token env v1 (* "<" *) in
  let v2 = todo_type_ env v2 in
  let v3 =
    List.map (fun (v1, v2) ->
      let v1 = JS.token env v1 (* "," *) in
      let v2 = todo_type_ env v2 in
      todo env (v1, v2)
    ) v3
  in
  let v4 =
    (match v4 with
    | Some tok -> JS.token env tok (* "," *)
    | None -> todo env ())
  in
  let v5 = JS.token env v5 (* ">" *) in
  todo env (v1, v2, v3, v4, v5)

(* TODO: decorators (@) *)
(* TODO: types - class body can be just a signature. *)
and class_body (env : env) ((v1, v2, v3) : CST.class_body) : property list bracket =
  let v1 = JS.token env v1 (* "{" *) in
  let v2 =
    List.filter_map (fun x ->
      (match x with
      | `Deco x ->
          (* TODO: decorators *)
          let _v () = decorator env x in
          None
      | `Meth_defi_opt_choice_auto_semi (v1, v2) ->
          let v1 = method_definition env v1 in
          let _v2 =
            (match v2 with
            | Some x -> Some (JS.semicolon env x)
            | None -> None)
          in
          Some v1
      | `Choice_abst_meth_sign_choice_choice_auto_semi (v1, v2) ->
          let v1 =
            (match v1 with
            | `Abst_meth_sign x ->
                (* TODO: types *)
                let _v () = todo_abstract_method_signature env x in
                None
            | `Index_sign x ->
                (* TODO: types *)
                let _v () = todo_index_signature env x in
                None
            | `Meth_sign x ->
                (* TODO: types *)
                let _v () = todo_method_signature env x in
                None
            | `Public_field_defi x -> Some (public_field_definition env x)
            )
          in
          let _v2 =
            (match v2 with
            | `Choice_auto_semi x -> JS.semicolon env x
            | `COMMA tok -> JS.token env tok (* "," *)
            )
          in
          v1
      )
    ) v2
  in
  let v3 = JS.token env v3 (* "}" *) in
  v1, v2, v3

(* TODO: types *)
and todo_type_parameter (env : env) ((v1, v2, v3) : CST.type_parameter) =
  let v1 = JS.token env v1 (* identifier *) in
  let v2 =
    (match v2 with
    | Some x -> todo_constraint_ env x
    | None -> todo env ())
  in
  let v3 =
    (match v3 with
    | Some x -> todo_default_type env x
    | None -> todo env ())
  in
  todo env (v1, v2, v3)

and member_expression (env : env) ((v1, v2, v3) : CST.member_expression) : expr =
  let v1 =
    (match v1 with
    | `Exp x -> expression env x
    | `Id tok -> JS.identifier env tok |> JS.idexp (* identifier *)
    | `Super tok -> JS.super env tok (* "super" *)
    | `Choice_decl x -> reserved_identifier env x |> JS.idexp
    )
  in
  let v2 = JS.token env v2 (* "." *) in
  let v3 = JS.identifier env v3 (* identifier *) in
  ObjAccess (v1, v2, PN v3)

and anon_choice_pair (env : env) (x : CST.anon_choice_pair) : property =
  (match x with
  | `Pair (v1, v2, v3) ->
      let v1 = property_name env v1 in
      let _v2 = JS.token env v2 (* ":" *) in
      let v3 = expression env v3 in
      Field {fld_name = v1; fld_props = []; fld_type = None; fld_body =Some v3}
  | `Spread_elem x ->
      let (t, e) = spread_element env x in
      FieldSpread (t, e)
  | `Meth_defi x -> method_definition env x

  | `Assign_pat (v1, v2, v3) ->
      let v1 =
        (match v1 with
        | `Choice_choice_decl x -> anon_choice_rese_id env x |> JS.idexp
        | `Choice_obj x -> destructuring_pattern env x
        )
      in
      let v2 = JS.token env v2 (* "=" *) in
      let v3 = expression env v3 in
      FieldPatDefault (v1, v2, v3)

  (* { x } shorthand for { x: x }, like in OCaml *)
  | `Choice_id x ->
      let id = identifier_reference env x in
      Field {fld_name = PN id; fld_props = []; fld_type = None;
             fld_body = Some (JS.idexp id) }
  )

and subscript_expression (env : env) ((v1, v2, v3, v4) : CST.subscript_expression) : expr =
  let v1 =
    (match v1 with
    | `Exp x -> expression env x
    | `Super tok -> JS.super env tok (* "super" *)
    )
  in
  let v2 = JS.token env v2 (* "[" *) in
  let v3 = expressions env v3 in
  let v4 = JS.token env v4 (* "]" *) in
  ArrAccess (v1, (v2, v3, v4))

and initializer_ (env : env) ((v1, v2) : CST.initializer_) =
  let _v1 = JS.token env v1 (* "=" *) in
  let v2 = expression env v2 in
  v2

and constructable_expression (env : env) (x : CST.constructable_expression) : expr =
  (match x with
  | `This tok -> JS.this env tok (* "this" *)
  | `Id tok -> JS.identifier_exp env tok (* identifier *)
  | `Choice_decl x ->
      let id = reserved_identifier env x in
      JS.idexp id
  | `Num tok ->
      let n = JS.number env tok (* number *) in
      Num n
  | `Str x ->
      let s = JS.string_ env x in
      String s
  | `Temp_str x ->
      let t1, xs, t2 = template_string env x in
      Apply (IdSpecial (Encaps false, t1), (t1, xs, t2))
  | `Regex (v1, v2, v3, v4) ->
      let v1 = JS.token env v1 (* "/" *) in
      let s, t = JS.str env v2 (* regex_pattern *) in
      let v3 = JS.token env v3 (* "/" *) in
      let v4 =
        (match v4 with
        | Some tok -> [JS.token env tok] (* pattern [a-z]+ *)
        | None -> [])
      in
      let tok = PI.combine_infos v1 ([t; v3] @ v4) in
      Regexp (s, tok)
  | `True tok -> Bool (true, JS.token env tok) (* "true" *)
  | `False tok -> Bool (false, JS.token env tok) (* "false" *)
  | `Null tok -> IdSpecial (Null, JS.token env tok) (* "null" *)
  | `Unde tok -> IdSpecial (Undefined, JS.token env tok) (* "undefined" *)
  | `Import tok -> JS.identifier env tok (* import *) |> JS.idexp
  | `Obj x -> let o = object_ env x in Obj o
  | `Array x -> array_ env x
  | `Func x ->
      let f, idopt = function_ env x in
      Fun (f, idopt)
  | `Arrow_func (v1, v2, v3, v4) ->
      let v1 =
        (match v1 with
        | Some tok -> [Async, JS.token env tok] (* "async" *)
        | None -> [])
      in
      let v2 =
        (match v2 with
        | `Choice_choice_decl x ->
            let id = anon_choice_rese_id env x in
            [ParamClassic { p_name = id; p_default = None;
                            p_dots = None; p_type = None }]
        | `Call_sign x -> call_signature env x
        )
      in
      let v3 = JS.token env v3 (* "=>" *) in
      let v4 =
        (match v4 with
        | `Exp x ->
            let e = expression env x in
            Return (v3, Some e)
        | `Stmt_blk x -> statement_block env x
        )
      in
      let f = { f_props = v1; f_params = v2; f_body = v4 } in
      Fun (f, None)
  | `Gene_func (v1, v2, v3, v4, v5, v6) ->
      let v1 =
        (match v1 with
        | Some tok -> [Async, JS.token env tok] (* "async" *)
        | None -> [])
      in
      let _v2 = JS.token env v2 (* "function" *) in
      let v3 = [Generator, JS.token env v3] (* "*" *) in
      let v4 =
        (match v4 with
        | Some tok -> Some (JS.identifier env tok) (* identifier *)
        | None -> None)
      in
      let v5 = call_signature env v5 in
      let v6 = statement_block env v6 in
      let f = { f_props = v1@v3; f_params = v5; f_body = v6 } in
      Fun (f, v4)
  | `Class (v1, v2, v3, v4, v5, v6) ->
      (* TODO decorators *)
      let _v1 () = List.map (decorator env) v1 in
      let v2 = JS.token env v2 (* "class" *) in
      let v3 =
        (match v3 with
        | Some tok -> Some (JS.identifier env tok) (* identifier *)
        | None -> None)
      in
      (* TODO types *)
      let _v4 () =
        (match v4 with
        | Some x -> todo_type_parameters env x
        | None -> todo env ())
      in
      let v5 =
        (match v5 with
        | Some x -> class_heritage env x
        | None -> None)
      in
      let v6 = class_body env v6 in
      let class_ = { c_tok = v2;  c_extends = v5; c_body = v6 } in
      Class (class_, v3)
  | `Paren_exp x -> parenthesized_expression env x
  | `Subs_exp x -> subscript_expression env x
  | `Member_exp x -> member_expression env x
  | `Meta_prop (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "new" *) in
      let v2 = JS.token env v2 (* "." *) in
      let v3 = JS.token env v3 (* "target" *) in
      let t = PI.combine_infos v1 [v2;v3] in
      IdSpecial (NewTarget, t)
  | `New_exp (v1, v2, v3, v4) ->
      let v1 = JS.token env v1 (* "new" *) in
      let v2 = constructable_expression env v2 in
      (* TODO types *)
      let _v3 () =
        match v3 with
        | Some x -> Some (todo_type_arguments env x)
        | None -> None
      in
      let t1, xs, t2 =
        (match v4 with
        | Some x -> arguments env x
        | None -> JS.fb [])
      in
      (* less: we should remove the extra Apply but that's what we do in pfff*)
      let newcall = Apply (IdSpecial (New, v1), fb [v2]) in
      Apply (newcall, (t1, xs, t2))
  )

(* TODO: enum type *)
and todo_anon_choice_prop_name (env : env) (x : CST.anon_choice_prop_name) =
  (match x with
  | `Prop_name x -> property_name env x
  | `Enum_assign (v1, v2) ->
      let v1 = property_name env v1 in
      let v2 = initializer_ env v2 in
      todo env (v1, v2)
  )

and module__ (env : env) ((v1, v2) : CST.module__) =
  let v1 = (* module identifier *)
    (match v1 with
    | `Str x -> JS.string_ env x
    | `Id tok -> JS.identifier env tok (* identifier *)
    | `Nested_id x ->
        nested_identifier env x
        |> concat_nested_identifier env
    )
  in
  let v2 = (* optional module body *)
    (match v2 with
    | Some x -> Some (statement_block env x)
    | None -> None)
  in
  (v1, v2)

and expression_statement (env : env) ((v1, v2) : CST.expression_statement) =
  let v1 = expressions env v1 in
  let v2 = JS.semicolon env v2 in
  (v1, v2)

and catch_clause (env : env) ((v1, v2, v3) : CST.catch_clause) =
  let v1 = JS.token env v1 (* "catch" *) in
  let v3 = statement_block env v3 in
  let v2 =
    (match v2 with
    | Some (v1bis, v2, v3bis) ->
        let _v1 = JS.token env v1bis (* "(" *) in
        let v2 = anon_choice_type_id_ env v2 in
        let _v3 = JS.token env v3bis (* ")" *) in
        let pat =
          match v2 with
          | Left id -> JS.idexp id
          | Right pat -> pat
         in
        BoundCatch (v1, pat, v3)
    | None -> UnboundCatch (v1, v3))
  in
  v2

(* TODO: types *)
and todo_object_type (env : env) ((v1, v2, v3) : CST.object_type) =
  let v1 =
    (match v1 with
    | `LCURL tok -> JS.token env tok (* "{" *)
    | `LCURLBAR tok -> JS.token env tok (* "{|" *)
    )
  in
  let v2 =
    (match v2 with
    | Some (v1, v2, v3, v4) ->
        let v1 =
          (match v1 with
          | Some x ->
              (match x with
              | `COMMA tok -> JS.token env tok (* "," *)
              | `SEMI tok -> JS.token env tok (* ";" *)
              )
          | None -> todo env ())
        in
        let v2 = todo_anon_choice_export_stmt env v2 in
        let v3 =
          List.map (fun (v1, v2) ->
            let v1 = anon_choice_COMMA env v1 in
            let v2 = todo_anon_choice_export_stmt env v2 in
            todo env (v1, v2)
          ) v3
        in
        let v4 =
          (match v4 with
          | Some x -> anon_choice_COMMA env x
          | None -> todo env ())
        in
        todo env (v1, v2, v3, v4)
    | None -> todo env ())
  in
  let v3 =
    (match v3 with
    | `RCURL tok -> JS.token env tok (* "}" *)
    | `BARRCURL tok -> JS.token env tok (* "|}" *)
    )
  in
  todo env (v1, v2, v3)

and anon_choice_type_id_ (env : env) (x : CST.anon_choice_type_id_) =
  (match x with
  | `Id tok -> Left (JS.identifier env tok (* identifier *))
  | `Choice_obj x -> Right (destructuring_pattern env x)
  )

and template_string (env : env) ((v1, v2, v3) : CST.template_string) : expr list bracket =
  let v1 = JS.token env v1 (* "`" *) in
  let v2 =
    List.map (fun x ->
      (match x with
      | `Temp_chars tok -> String (JS.str env tok) (* template_chars *)
      | `Esc_seq tok -> String (JS.str env tok) (* escape_sequence *)
      | `Temp_subs x -> template_substitution env x
      )
    ) v2
  in
  let v3 = JS.token env v3 (* "`" *) in
  v1, v2, v3

and decorator (env : env) ((v1, v2) : CST.decorator) =
  let v1 = JS.token env v1 (* "@" *) in
  let v2 =
    (match v2 with
    | `Choice_id x ->
        let id = identifier_reference env x in
        [id], None
    | `Deco_member_exp x ->
        let ids = decorator_member_expression env x in
        ids, None
    | `Deco_call_exp x ->
        let ids, args = decorator_call_expression env x in
        ids, Some args
    )
  in
  (v1, v2)

and internal_module (env : env) ((v1, v2) : CST.internal_module) =
  let _v1 = JS.token env v1 (* "namespace" *) in
  let v2 = module__ env v2 in
  v2

and anon_opt_opt_choice_exp_rep_COMMA_opt_choice_exp (env : env) (opt : CST.anon_opt_opt_choice_exp_rep_COMMA_opt_choice_exp) =
  (match opt with
  | Some (v1, v2) ->
      let v1 =
        (match v1 with
        | Some x -> [anon_choice_exp env x]
        | None -> [])
      in
      let v2 = anon_rep_COMMA_opt_choice_exp env v2 in
      v1 @ v2
  | None -> [])

and for_header (env : env) ((v1, v2, v3, v4, v5, v6) : CST.for_header) =
  let v1 = JS.token env v1 (* "(" *) in
  let v2 =
    (match v2 with
    | Some x ->
        Some (match x with
        | `Var tok -> Var, JS.token env tok (* "var" *)
        | `Let tok -> Let, JS.token env tok (* "let" *)
        | `Const tok -> Const, JS.token env tok (* "const" *)
        )
    | None -> None)
  in
  let v3 = anon_choice_paren_exp env v3 in
  let var_or_expr =
    match v2 with
    | None -> Right v3
    | Some vkind ->
        let var = Ast_js.var_pattern_to_var vkind v3 (snd vkind) None in
        Left var
  in
  let v5 = expressions env v5 in
  let _v6 = JS.token env v6 (* ")" *) in
  let v4 =
    (match v4 with
    | `In tok -> ForIn (var_or_expr, JS.token env tok, v5) (* "in" *)
    | `Of tok -> ForOf (var_or_expr, JS.token env tok, v5) (* "of" *)
    )
  in
  v4

and expression (env : env) (x : CST.expression) : expr =
  (match x with
  | `As_exp (v1, v2, v3) ->
      (* type assertion of the form 'exp as type' *)
      (* TODO types *)
      let v1 = expression env v1 in
      let _v2 = JS.token env v2 (* "as" *) in
      let _v3 () =
        (match v3 with
        | `Type x -> todo_type_ env x
        | `Temp_str x -> todo env (template_string env x)
        )
      in
      v1
  | `Non_null_exp (v1, v2) ->
      (* non-null assertion operator *)
      (* TODO types *)
      let v1 = expression env v1 in
      let _v2 = JS.token env v2 (* "!" *) in
      v1

  | `Inte_module x ->
      (* namespace (deprecated in favor of ES modules) *)
      (* TODO represent namespaces properly in the AST instead of the nonsense
         below. *)
      let name, opt_body = internal_module env x in
      (match opt_body with
       | Some body ->
           let fun_ = {
             f_props = []; f_params = []; f_body = body;
           } in
           Apply (Fun (fun_, Some name), fb [])
       | None ->
           JS.idexp name
      )

  | `Super tok -> JS.super env tok (* "super" *)

  | `Type_asse (v1, v2) ->
      (* type assertion of the form <string>someValue *)
      (* TODO: types *)
      let _v1 () = todo_type_arguments env v1 in
      let v2 = expression env v2 in
      v2
  | `Choice_this x -> constructable_expression env x

  | `Choice_jsx_elem x ->
      let xml = jsx_element_ env x in
      Xml xml

  | `Jsx_frag x ->
      let xml = jsx_fragment env x in
      Xml xml

  | `Assign_exp (v1, v2, v3) ->
      let v1 = anon_choice_paren_exp env v1 in
      let v2 = JS.token env v2 (* "=" *) in
      let v3 = expression env v3 in
      Assign (v1, v2, v3)
  | `Augm_assign_exp (v1, v2, v3) ->
      let v1 =
        (match v1 with
        | `Member_exp x -> member_expression env x
        | `Subs_exp x -> subscript_expression env x
        | `Choice_decl x ->
                let id = reserved_identifier env x in
                JS.idexp id
        | `Id tok ->
                let id = JS.identifier env tok (* identifier *) in
                JS.idexp id
        | `Paren_exp x -> parenthesized_expression env x
        )
      in
      let (op, tok) =
        (match v2 with
        | `PLUSEQ tok -> G.Plus, JS.token env tok (* "+=" *)
        | `DASHEQ tok -> G.Minus, JS.token env tok (* "-=" *)
        | `STAREQ tok -> G.Mult, JS.token env tok (* "*=" *)
        | `SLASHEQ tok -> G.Div, JS.token env tok (* "/=" *)
        | `PERCEQ tok -> G.Mod, JS.token env tok (* "%=" *)
        | `HATEQ tok -> G.BitXor, JS.token env tok (* "^=" *)
        | `AMPEQ tok -> G.BitAnd, JS.token env tok (* "&=" *)
        | `BAREQ tok -> G.BitOr, JS.token env tok (* "|=" *)
        | `GTGTEQ tok -> G.LSR, JS.token env tok (* ">>=" *)
        | `GTGTGTEQ tok -> G.ASR, JS.token env tok (* ">>>=" *)
        | `LTLTEQ tok -> G.LSL, JS.token env tok (* "<<=" *)
        | `STARSTAREQ tok -> G.Pow, JS.token env tok (* "**=" *)
        )
      in
      let v3 = expression env v3 in
      (* less: should use intermediate instead of repeating v1 *)
      Assign (v1, tok, Apply (IdSpecial (ArithOp op, tok), fb [v1;v3]))
  | `Await_exp (v1, v2) ->
      let v1 = JS.token env v1 (* "await" *) in
      let v2 = expression env v2 in
      Apply (IdSpecial (Await, v1), fb [v2])
  | `Un_exp x -> unary_expression env x
  | `Bin_exp x -> binary_expression env x
  | `Tern_exp (v1, v2, v3, v4, v5) ->
      let v1 = expression env v1 in
      let _v2 = JS.token env v2 (* "?" *) in
      let v3 = expression env v3 in
      let _v4 = JS.token env v4 (* ":" *) in
      let v5 = expression env v5 in
      Conditional (v1, v3, v5)
  | `Update_exp x -> update_expression env x
  | `Call_exp (v1, v2, v3) ->
      let v1 =
        (match v1 with
        | `Exp x -> expression env x
        | `Super tok -> JS.super env tok (* "super" *)
        | `Func x ->
                let (f, idopt) = function_ env x in
                Fun (f, idopt)
        )
      in
      (* TODO: types *)
      let _v2 () =
        (match v2 with
        | Some x -> Some (todo_type_arguments env x)
        | None -> None)
      in
      let v3 =
        (match v3 with
        | `Args x ->
                let args = arguments env x in
                Apply (v1, args)
        | `Temp_str x ->
                let (t1, xs, t2) = template_string env x in
                Apply (IdSpecial (Encaps true, t1),
                  (t1, v1::xs, t2))
        )
      in
      v3
  | `Yield_exp (v1, v2) ->
      let v1 = JS.token env v1 (* "yield" *) in
      let v2 =
        (match v2 with
        | `STAR_exp (v1bis, v2) ->
            let v1bis = JS.token env v1bis (* "*" *) in
            let v2 = expression env v2 in
            Apply (IdSpecial (YieldStar, v1), fb [v2])
        | `Opt_exp opt ->
            (match opt with
            | Some x ->
                let x = expression env x in
                Apply (IdSpecial (Yield, v1), fb [x])
            | None ->
                Apply (IdSpecial (Yield, v1), fb [])
          )
        )
      in
      v2
  )

and anon_choice_paren_exp (env : env) (x : CST.anon_choice_paren_exp) =
  (match x with
  | `Paren_exp x -> parenthesized_expression env x
  | `Choice_member_exp x -> lhs_expression env x
  )

(* TODO: types *)
and todo_primary_type (env : env) (x : CST.primary_type) : type_ =
  (match x with
  | `Paren_type (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "(" *) in
      let v2 = todo_type_ env v2 in
      let v3 = JS.token env v3 (* ")" *) in
      todo env (v1, v2, v3)
  | `Pred_type x ->
        let id = predefined_type env x in
        (* less: could also be a G.TyBuiltin *)
        G.TyName (G.name_of_id id)
  | `Id tok ->
        let id = JS.identifier env tok (* identifier *) in
        G.TyName (G.name_of_id id)
  | `Nested_type_id x -> todo env (todo_nested_type_identifier env x)
  | `Gene_type x -> todo env (todo_generic_type env x)
  | `Type_pred (v1, v2, v3) ->
      let v1 = JS.token env v1 (* identifier *) in
      let v2 = JS.token env v2 (* "is" *) in
      let v3 = todo_type_ env v3 in
      todo env (v1, v2, v3)
  | `Obj_type x -> todo env (todo_object_type env x)
  | `Array_type (v1, v2, v3) ->
      let v1 = todo_primary_type env v1 in
      let v2 = JS.token env v2 (* "[" *) in
      let v3 = JS.token env v3 (* "]" *) in
      todo env (v1, v2, v3)
  | `Tuple_type (v1, v2, v3, v4) ->
      let v1 = JS.token env v1 (* "[" *) in
      let v2 = todo_type_ env v2 in
      let v3 =
        List.map (fun (v1, v2) ->
          let v1 = JS.token env v1 (* "," *) in
          let v2 = todo_type_ env v2 in
          todo env (v1, v2)
        ) v3
      in
      let v4 = JS.token env v4 (* "]" *) in
      todo env (v1, v2, v3, v4)
  | `Flow_maybe_type (v1, v2) ->
      let v1 = JS.token env v1 (* "?" *) in
      let v2 = todo_primary_type env v2 in
      todo env (v1, v2)
  | `Type_query (v1, v2) ->
      let v1 = JS.token env v1 (* "typeof" *) in
      let v2 = anon_choice_type_id env v2 in
      todo env (v1, v2)
  | `Index_type_query (v1, v2) ->
      let v1 = JS.token env v1 (* "keyof" *) in
      let v2 = todo_anon_choice_type_id2 env v2 in
      todo env (v1, v2)
  | `This tok -> todo env (JS.token env tok) (* "this" *)
  | `Exis_type tok -> todo env (JS.token env tok) (* "*" *)
  | `Lit_type x -> todo env (todo_literal_type env x)
  | `Lookup_type (v1, v2, v3, v4) ->
      let v1 = todo_primary_type env v1 in
      let v2 = JS.token env v2 (* "[" *) in
      let v3 = todo_type_ env v3 in
      let v4 = JS.token env v4 (* "]" *) in
      todo env (v1, v2, v3, v4)
  )

(* TODO: types *)
and todo_index_signature (env : env) ((v1, v2, v3, v4) : CST.index_signature) =
  let v1 = JS.token env v1 (* "[" *) in
  let v2 =
    (match v2 with
    | `Choice_id_COLON_pred_type (v1, v2, v3) ->
        let v1 = identifier_reference env v1 in
        let v2 = JS.token env v2 (* ":" *) in
        let v3 = predefined_type env v3 in
        todo env (v1, v2, v3)
    | `Mapped_type_clause x -> todo_mapped_type_clause env x
    )
  in
  let v3 = JS.token env v3 (* "]" *) in
  let v4 = type_annotation env v4 in
  todo env (v1, v2, v3, v4)

and unary_expression (env : env) (x : CST.unary_expression) =
  (match x with
  | `BANG_exp (v1, v2) ->
      let v1 = JS.token env v1 (* "!" *) in
      let v2 = expression env v2 in
      Apply (IdSpecial (ArithOp G.Not, v1), fb [v2])
  | `TILDE_exp (v1, v2) ->
      let v1 = JS.token env v1 (* "~" *) in
      let v2 = expression env v2 in
      Apply (IdSpecial (ArithOp G.BitNot, v1), fb [v2])
  | `DASH_exp (v1, v2) ->
      let v1 = JS.token env v1 (* "-" *) in
      let v2 = expression env v2 in
      Apply (IdSpecial (ArithOp G.Minus, v1), fb [v2])
  | `PLUS_exp (v1, v2) ->
      let v1 = JS.token env v1 (* "+" *) in
      let v2 = expression env v2 in
      Apply (IdSpecial (ArithOp G.Plus, v1), fb [v2])
  | `Typeof_exp (v1, v2) ->
      let v1 = JS.token env v1 (* "typeof" *) in
      let v2 = expression env v2 in
      Apply (IdSpecial (Typeof, v1), fb [v2])
  | `Void_exp (v1, v2) ->
      let v1 = JS.token env v1 (* "void" *) in
      let v2 = expression env v2 in
      Apply (IdSpecial (Void, v1), fb [v2])
  | `Delete_exp (v1, v2) ->
      let v1 = JS.token env v1 (* "delete" *) in
      let v2 = expression env v2 in
      Apply (IdSpecial (Delete, v1), fb [v2])
  )

(* TODO: don't ignore decorators (@...) *)
and formal_parameters (env : env) ((v1, v2, v3) : CST.formal_parameters) : parameter list=
  let _v1 = JS.token env v1 (* "(" *) in
  let v2 =
    (match v2 with
    | Some (v1, v2, v3, v4) ->
        let _v1 = List.map (decorator env) v1 in
        let v2 = anon_choice_requ_param env v2 in
        let v3 =
          List.map (fun (v1, v2, v3) ->
            let _v1 = JS.token env v1 (* "," *) in
            let _v2 = List.map (decorator env) v2 in
            let v3 = anon_choice_requ_param env v3 in
            v3
          ) v3
        in
        let v4 =
          (match v4 with
          | Some tok -> Some (JS.token env tok) (* "," *)
          | None -> None)
        in
        v2 :: v3
    | None -> [])
  in
  let _v3 = JS.token env v3 (* ")" *) in
  v2

(* TODO types *)
(* class Component<Props = any, State = any> { ... *)
and todo_default_type (env : env) ((v1, v2) : CST.default_type) =
  let v1 = JS.token env v1 (* "=" *) in
  let v2 = todo_type_ env v2 in
  todo env (v1, v2)

and switch_body (env : env) ((v1, v2, v3) : CST.switch_body) =
  let _v1 = JS.token env v1 (* "{" *) in
  let v2 =
    List.map (fun x ->
      (match x with
      | `Switch_case x -> switch_case env x
      | `Switch_defa x -> switch_default env x
      )
    ) v2
  in
  let _v3 = JS.token env v3 (* "}" *) in
  v2

(* TODO: types *)
and todo_mapped_type_clause (env : env) ((v1, v2, v3) : CST.mapped_type_clause) =
  let v1 = JS.token env v1 (* identifier *) in
  let v2 = JS.token env v2 (* "in" *) in
  let v3 = todo_type_ env v3 in
  todo env (v1, v2, v3)

and statement1 (env : env) (x : CST.statement) : stmt =
  statement env x |> Ast_js.stmt_of_stmts

(* TODO: types *)
and statement (env : env) (x : CST.statement) : stmt list =
  (match x with
  | `Export_stmt x -> export_statement env x
  | `Import_stmt (v1, v2, v3, v4) ->
      let v1 = JS.token env v1 (* "import" *) in
      let tok = v1 in
      let _v2 () = (* 'type' or 'typeof' *)
        (match v2 with
        | Some x -> Some (anon_choice_type env x)
        | None -> None)
      in
      let v3 =
        (match v3 with
        | `Import_clause_from_clause (v1, v2) ->
            let f = import_clause env v1 in
            let _t, path = JS.from_clause env v2 in
            f tok path
        | `Import_requ_clause x ->
            import_require_clause env x
        | `Str x ->
            let file = JS.string_ env x in
            if (fst file =~ ".*\\.css$")
            then [(ImportCss (tok, file))]
            else [(ImportEffect (tok, file))]
        )
      in
      let _v4 = JS.semicolon env v4 in
      v3 |> List.map (fun m -> M m)
  | `Debu_stmt (v1, v2) ->
      let v1 = JS.identifier env v1 (* "debugger" *) in
      let v2 = JS.semicolon env v2 in
      [ExprStmt (JS.idexp v1, v2)]
  | `Exp_stmt x ->
      let (e, t) = expression_statement env x in
      [ExprStmt (e, t)]
  | `Decl x ->
      let vars = declaration env x in
      vars |> List.map (fun x -> VarDecl x)
  | `Stmt_blk x -> [statement_block env x]
  | `If_stmt (v1, v2, v3, v4) ->
      let v1 = JS.token env v1 (* "if" *) in
      let v2 = parenthesized_expression env v2 in
      let v3 = statement1 env v3 in
      let v4 =
        (match v4 with
        | Some (v1, v2) ->
            let _v1 = JS.token env v1 (* "else" *) in
            let v2 = statement1 env v2 in
            Some v2
        | None -> None)
      in
      [If (v1, v2, v3, v4)]
  | `Switch_stmt (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "switch" *) in
      let v2 = parenthesized_expression env v2 in
      let v3 = switch_body env v3 in
      [Switch (v1, v2, v3)]
  | `For_stmt (v1, v2, v3, v4, v5, v6, v7) ->
      let v1 = JS.token env v1 (* "for" *) in
      let _v2 = JS.token env v2 (* "(" *) in
      let v3 =
        (match v3 with
        | `Lexi_decl x ->
            let vars = lexical_declaration env x in
            Left vars
        | `Var_decl x ->
            let vars = variable_declaration env x in
            Left vars
        | `Exp_stmt x ->
            let (e, _t) = expression_statement env x in
            Right e
        | `Empty_stmt tok ->
            let _x = JS.token env tok (* ";" *) in
            Left []
        )
      in
      let v4 =
        (match v4 with
        | `Exp_stmt x ->
            let (e, _t) = expression_statement env x in
            Some e
        | `Empty_stmt tok ->
            let _x = JS.token env tok (* ";" *) in
            None
        )
      in
      let v5 =
        (match v5 with
        | Some x -> Some (expressions env x)
        | None -> None)
      in
      let v6 = JS.token env v6 (* ")" *) in
      let v7 = statement1 env v7 in
      [For (v1, ForClassic (v3, v4, v5), v7)]
  | `For_in_stmt (v1, v2, v3, v4) ->
      let v1 = JS.token env v1 (* "for" *) in
      let _v2TODO =
        (match v2 with
        | Some tok -> Some (JS.token env tok) (* "await" *)
        | None -> None)
      in
      let v3 = for_header env v3 in
      let v4 = statement1 env v4 in
      [For (v1, v3, v4)]
  | `While_stmt (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "while" *) in
      let v2 = parenthesized_expression env v2 in
      let v3 = statement1 env v3 in
      [While (v1, v2, v3)]
  | `Do_stmt (v1, v2, v3, v4, v5) ->
      let v1 = JS.token env v1 (* "do" *) in
      let v2 = statement1 env v2 in
      let v3 = JS.token env v3 (* "while" *) in
      let v4 = parenthesized_expression env v4 in
      let v5 = JS.semicolon env v5 in
      [Do (v1, v2, v4)]
  | `Try_stmt (v1, v2, v3, v4) ->
      let v1 = JS.token env v1 (* "try" *) in
      let v2 = statement_block env v2 in
      let v3 =
        (match v3 with
        | Some x -> Some (catch_clause env x)
        | None -> None)
      in
      let v4 =
        (match v4 with
        | Some x -> Some (finally_clause env x)
        | None -> None)
      in
      [Try (v1, v2, v3, v4)]
  | `With_stmt (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "with" *) in
      let v2 = parenthesized_expression env v2 in
      let v3 = statement1 env v3 in
      [With (v1, v2, v3)]
  | `Brk_stmt (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "break" *) in
      let v2 =
        (match v2 with
        | Some tok -> Some (JS.identifier env tok) (* identifier *)
        | None -> None)
      in
      let _v3 = JS.semicolon env v3 in
      [Break (v1, v2)]
  | `Cont_stmt (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "continue" *) in
      let v2 =
        (match v2 with
        | Some tok -> Some (JS.identifier env tok) (* identifier *)
        | None -> None)
      in
      let _v3 = JS.semicolon env v3 in
      [Continue (v1, v2)]
  | `Ret_stmt (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "return" *) in
      let v2 =
        (match v2 with
        | Some x -> Some (expressions env x)
        | None -> None)
      in
      let _v3 = JS.semicolon env v3 in
      [Return (v1, v2)]
  | `Throw_stmt (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "throw" *) in
      let v2 = expressions env v2 in
      let v3 = JS.semicolon env v3 in
      [Throw (v1, v2)]
  | `Empty_stmt tok ->
      [JS.empty_stmt env tok (* ";" *)]
  | `Labe_stmt (v1, v2, v3) ->
      let v1 = identifier_reference env v1 in
      let v2 = JS.token env v2 (* ":" *) in
      let v3 = statement1 env v3 in
      [Label (v1, v3)]
  )

(* TODO: accessibility modifier (public/private/protected) *)
(* TODO: 'readonly' *)
and method_definition (env : env) ((v1, v2, v3, v4, v5, v6, v7, v8, v9) : CST.method_definition) : property =
  let _v1 () =
    (match v1 with
    | Some x -> accessibility_modifier env x
    | None -> todo env ())
  in
  let v2 =
    (match v2 with
    | Some tok -> [Static, JS.token env tok] (* "static" *)
    | None -> [])
  in
  let _v3 =
    (match v3 with
    | Some tok -> [(*TODO*) JS.token env tok] (* "readonly" *)
    | None -> [])
  in
  let v4 =
    (match v4 with
    | Some tok -> [Async, JS.token env tok] (* "async" *)
    | None -> [])
  in
  let v5 =
    (match v5 with
    | Some x -> [anon_choice_get env x]
    | None -> [])
  in
  let v6 = property_name env v6 in
  let _v7 =
    (match v7 with (* indicates optional method? *)
    | Some tok -> Some (JS.token env tok) (* "?" *)
    | None -> None)
  in
  let v8 = call_signature env v8 in
  let v9 = statement_block env v9 in
  let f = { f_props = v4 @ v5; f_params = v8; f_body = v9 } in
  let e = Fun (f, None) in
  let ty = None in
  Field {fld_name = v6; fld_props = v2; fld_type = ty; fld_body = Some e }

(* TODO types: type_parameters *)
and class_declaration (env : env) ((v1, v2, v3, v4, v5, v6, v7) : CST.class_declaration) : var list =
  let _v1TODO = List.map (decorator env) v1 in
  let v2 = JS.token env v2 (* "class" *) in
  let v3 = JS.identifier env v3 (* identifier *) in
  let _v4 () =
    (match v4 with
    | Some x -> todo_type_parameters env x
    | None -> todo env ())
  in
  let v5 =
    (match v5 with
    | Some x -> class_heritage env x
    | None -> None)
  in
  let v6 = class_body env v6 in
  let _v7 =
    (match v7 with
    | Some tok -> Some (JS.token env tok) (* automatic_semicolon *)
    | None -> None)
  in
  let c = { c_tok = v2; c_extends = v5; c_body = v6 } in
  let ty = None in
  [{ v_name = v3; v_kind = Const, v2; v_type = ty;
     v_init = Some (Class (c, None)); v_resolved = ref NotResolved }]

and array_ (env : env) ((v1, v2, v3) : CST.array_) =
  let v1 = JS.token env v1 (* "[" *) in
  let v2 =
    anon_opt_opt_choice_exp_rep_COMMA_opt_choice_exp env v2
  in
  let v3 = JS.token env v3 (* "]" *) in
  Arr (v1, v2, v3)

and export_statement (env : env) (x : CST.export_statement) =
  (match x with
  | `Choice_export_choice_STAR_from_clause_choice_auto_semi x ->
      (match x with
      | `Export_choice_STAR_from_clause_choice_auto_semi (v1, v2) ->
          let tok = JS.token env v1 (* "export" *) in
          let v2 =
            (match v2 with
            | `STAR_from_clause_choice_auto_semi (v1, v2, v3) ->
                let v1 = JS.token env v1 (* "*" *) in
                let tok2, path = JS.from_clause env v2 in
                let _v3 = JS.semicolon env v3 in
                [M (ReExportNamespace (tok, v1, tok2, path))]
            | `Export_clause_from_clause_choice_auto_semi (v1, v2, v3) ->
                let v1 = export_clause env v1 in
                let (tok2, path) = JS.from_clause env v2 in
                let _v3 = JS.semicolon env v3 in
                v1 |> List.map (fun (n1, n2opt) ->
                  let tmpname = "!tmp_" ^ fst n1, snd n1 in
                  let import = Import (tok2, n1, Some tmpname, path) in
                  let e = JS.idexp tmpname in
                  match n2opt with
                  | None ->
                      let v = Ast_js.mk_const_var n1 e in
                      [M import; VarDecl v; M (Export (tok, n1))]
                  | Some (n2) ->
                      let v = Ast_js.mk_const_var n2 e in
                      [M import; VarDecl v; M (Export (tok, n2))]
                ) |> List.flatten
            | `Export_clause_choice_auto_semi (v1, v2) ->
                let v1 = export_clause env v1 in
                let _v2 = JS.semicolon env v2 in
                v1 |> List.map (fun (n1, n2opt) ->
                  (match n2opt with
                   | None -> [M (Export (tok, n1))]
                   | Some n2 ->
                       let v = Ast_js.mk_const_var n2 (JS.idexp n1) in
                       [VarDecl v; M (Export (tok, n2))]
                  )
                ) |> List.flatten
            )
          in
          v2
      | `Rep_deco_export_choice_decl (v1, v2, v3) ->
          let _v1TODO = List.map (decorator env) v1 in
          let tok = JS.token env v2 (* "export" *) in
          let v3 =
            (match v3 with
            | `Decl x ->
                let vars = declaration env x in
                vars |> List.map (fun var ->
                  let n = var.v_name in
                  [VarDecl var; M (Export (tok, n))]
                ) |> List.flatten
            | `Defa_exp_choice_auto_semi (v1, v2, v3) ->
                let v1 = JS.token env v1 (* "default" *) in
                let v2 = expression env v2 in
                let _v3 = JS.semicolon env v3 in
                let var, n = Ast_js.mk_default_entity_var v1 v2 in
                [VarDecl var; M (Export (v1, n))]
            )
          in
          v3
      )
  | `Export_EQ_id_choice_auto_semi (v1, v2, v3, v4) ->
      let v1 = JS.token env v1 (* "export" *) in
      let v2 = JS.token env v2 (* "=" *) in
      let v3 = JS.token env v3 (* identifier *) in
      let v4 = JS.semicolon env v4 in
      (* TODO 'export = ZipCodeValidator;' *)
      []

  | `Export_as_name_id_choice_auto_semi (v1, v2, v3, v4, v5) ->
      let v1 = JS.token env v1 (* "export" *) in
      let v2 = JS.token env v2 (* "as" *) in
      let v3 = JS.token env v3 (* "namespace" *) in
      let v4 = JS.token env v4 (* identifier *) in
      let v5 = JS.semicolon env v5 in
      (* TODO 'export as namespace mathLib;' *)
      []
  )


and type_annotation (env : env) ((v1, v2) : CST.type_annotation) =
  let v1 = JS.token env v1 (* ":" *) in
  let v2 =
    try
      todo_type_ env v2
    with TODO ->
      G.OtherType (G.OT_Todo, [G.Tk v1])
  in
  v2

and anon_rep_COMMA_opt_choice_exp (env : env) (xs : CST.anon_rep_COMMA_opt_choice_exp) =
  List.filter_map (fun (v1, v2) ->
    let v1 = JS.token env v1 (* "," *) in
    let v2 =
      (match v2 with
      | Some x -> Some (anon_choice_exp env x)
      | None -> None)
    in
    v2
  ) xs

and decorator_call_expression (env : env) ((v1, v2) : CST.decorator_call_expression) =
  let v1 = anon_choice_id_ref env v1 in
  let v2 = arguments env v2 in
  v1, v2

and update_expression (env : env) (x : CST.update_expression) =
  (match x with
  | `Exp_choice_PLUSPLUS (v1, v2) ->
      let v1 = expression env v1 in
      let op, t = anon_choice_PLUSPLUS env v2 in
      Apply (IdSpecial (IncrDecr (op, G.Postfix), t), fb [v1])
  | `Choice_PLUSPLUS_exp (v1, v2) ->
      let op, t = anon_choice_PLUSPLUS env v1 in
      let v2 = expression env v2 in
      Apply (IdSpecial (IncrDecr (op, G.Prefix), t), fb [v2])
  )

(* TODO: types *)
and todo_anon_choice_export_stmt (env : env) (x : CST.anon_choice_export_stmt) =
  (match x with
  | `Export_stmt x -> export_statement env x
  | `Prop_sign (v1, v2, v3, v4, v5, v6) ->
      let v1 =
        (match v1 with
        | Some x -> accessibility_modifier env x
        | None -> todo env ())
      in
      let v2 =
        (match v2 with
        | Some tok -> JS.token env tok (* "static" *)
        | None -> todo env ())
      in
      let v3 =
        (match v3 with
        | Some tok -> JS.token env tok (* "readonly" *)
        | None -> todo env ())
      in
      let v4 = property_name env v4 in
      let v5 =
        (match v5 with
        | Some tok -> JS.token env tok (* "?" *)
        | None -> todo env ())
      in
      let v6 =
        (match v6 with
        | Some x -> type_annotation env x
        | None -> todo env ())
      in
      todo env (v1, v2, v3, v4, v5, v6)
  | `Call_sign_ x ->
      let _ = call_signature env x in
      todo env ()
  | `Cons_sign (v1, v2, v3, v4) ->
      let v1 = JS.token env v1 (* "new" *) in
      let v2 =
        (match v2 with
        | Some x -> todo_type_parameters env x
        | None -> todo env ())
      in
      let v3 = formal_parameters env v3 in
      let v4 =
        (match v4 with
        | Some x -> type_annotation env x
        | None -> todo env ())
      in
      todo env (v1, v2, v3, v4)
  | `Index_sign x -> todo_index_signature env x
  | `Meth_sign x -> todo_method_signature env x
  )

(* TODO accessibility modifiers (public/private/protected *)
(* TODO 'readonly' *)
(* TODO 'abstract' *)
and public_field_definition (env : env) ((v1, v2, v3, v4, v5, v6) : CST.public_field_definition) =
  let _v1 () =
    (match v1 with
    | Some x -> accessibility_modifier env x
    | None -> todo env ())
  in
  let v2 =
    (match v2 with
    | `Opt_static_opt_read (v1, v2) ->
        let _v1 () =
          (match v1 with
          | Some tok -> [Static, JS.token env tok] (* "static" *)
          | None -> [])
        in
        let _v2 () =
          (match v2 with
          | Some tok -> JS.token env tok (* "readonly" *)
          | None -> todo env ())
        in
        [] (* v1 @ v2 *)
    | `Opt_abst_opt_read (v1, v2)
    | `Opt_read_opt_abst (v2, v1) ->
        let _v1 () =
          (match v1 with
          | Some tok -> JS.token env tok (* "abstract" *)
          | None -> todo env ())
        in
        let _v2 () =
          (match v2 with
          | Some tok -> JS.token env tok (* "readonly" *)
          | None -> todo env ())
        in
        [] (* v1 @ v2 *)
    )
  in
  let v3 = property_name env v3 in
  let _v4 () =
    (match v4 with
    | Some x ->
        (match x with
        | `QMARK tok -> Some (JS.token env tok) (* "?" *)
        | `BANG tok -> Some (JS.token env tok) (* "!" *)
        )
    | None -> None)
  in
  let v5 =
    (match v5 with
    | Some x -> Some (type_annotation env x)
    | None -> None)
  in
  let v6 =
    (match v6 with
    | Some x -> Some (initializer_ env x)
    | None -> None)
  in
  Field {fld_name = v3; fld_props = v2; fld_type = v5; fld_body = v6 }

(* TODO types: return either an expression like in javascript or a type. *)
and anon_choice_choice_type_id (env : env) (x : CST.anon_choice_choice_type_id): expr option =
  (match x with
  | `Choice_id x -> (* type to be extended *)
      let _v () = todo_anon_choice_type_id3 env x in
      None
  | `Exp x -> (* class expression to be extended *)
      Some (expression env x)
  )

and lexical_declaration (env : env) ((v1, v2, v3, v4) : CST.lexical_declaration) : var list =
  let v1 =
    (match v1 with
    | `Let tok -> Let, JS.token env tok (* "let" *)
    | `Const tok -> Const, JS.token env tok (* "const" *)
    )
  in
  let v2 = variable_declarator env v2 in
  let v3 =
    List.map (fun (v1, v2) ->
      let _v1 = JS.token env v1 (* "," *) in
      let v2 = variable_declarator env v2 in
      v2
    ) v3
  in
  let _v4 = JS.semicolon env v4 in
  JS.build_vars v1 (v2::v3)

(* TODO types *)
and extends_clause (env : env) ((v1, v2, v3) : CST.extends_clause) : expr list =
  let v1 = JS.token env v1 (* "extends" *) in
  let v2 = anon_choice_choice_type_id env v2 in
  let v3 =
    List.map (fun (v1, v2) ->
      let _v1 = JS.token env v1 (* "," *) in
      let v2 = anon_choice_choice_type_id env v2 in
      v2
    ) v3
  in
  List.filter_map (fun x -> x) (v2 :: v3)

(* TODO: don't ignore type annotations *)
(* TODO: don't ignore initializer *)
(* This function is similar to 'formal_parameter' in the js grammar. *)
and anon_choice_requ_param (env : env) (x : CST.anon_choice_requ_param) : parameter =
  (match x with
  | `Requ_param (v1, v2, v3) ->
      let v1 = parameter_name env v1 in
      let v2 =
        (match v2 with
        | Some x -> Some (type_annotation env x)
        | None -> None)
      in
      let v3 =
        (match v3 with
        | Some x -> Some (initializer_ env x)
        | None -> None)
      in
      (match v1 with
      | Left id -> ParamClassic
          { p_name = id; p_default = v3; p_type = v2; p_dots = None }
      (* TODO: can have types and defaults on patterns? *)
      | Right pat -> ParamPattern pat
      )

  | `Rest_param (v1, v2, v3) ->
      let v1 = JS.token env v1 (* "..." *) in
      let id = JS.identifier env v2 (* identifier *) in
      let v3 =
        (match v3 with
        | Some x -> Some (type_annotation env x)
        | None -> None)
      in
      ParamClassic { p_name = id; p_default = None; p_type = v3;
                     p_dots = Some v1; }

  | `Opt_param (v1, v2, v3, v4) ->
      let v1 = parameter_name env v1 in
      let v2 = JS.token env v2 (* "?" *) in
      let _v3 () =
        (match v3 with
        | Some x -> type_annotation env x
        | None -> todo env ())
      in
      let _v4 () =
        (match v4 with
        | Some x -> initializer_ env x
        | None -> todo env ())
      in
      (match v1 with
      | Left id -> ParamClassic
          { p_name = id; p_default = None; p_type = None; p_dots = None }
      (* TODO: can have types and defaults on patterns? *)
      | Right pat -> ParamPattern pat
      )
  )

(* TODO: types *)
and todo_enum_body (env : env) ((v1, v2, v3) : CST.enum_body) =
  let v1 = JS.token env v1 (* "{" *) in
  let v2 =
    (match v2 with
    | Some (v1, v2, v3) ->
        let v1 = todo_anon_choice_prop_name env v1 in
        let v2 =
          List.map (fun (v1, v2) ->
            let v1 = JS.token env v1 (* "," *) in
            let v2 = todo_anon_choice_prop_name env v2 in
            todo env (v1, v2)
          ) v2
        in
        let v3 =
          (match v3 with
          | Some tok -> JS.token env tok (* "," *)
          | None -> todo env ())
        in
        todo env (v1, v2, v3)
    | None -> todo env ())
  in
  let v3 = JS.token env v3 (* "}" *) in
  todo env (v1, v2, v3)

(* TODO: 'implements' *)
(* TODO: support multiple inheritance (which isn't supported by javascript) *)
and class_heritage (env : env) (x : CST.class_heritage) : expr option =
  (match x with
  | `Extends_clause_opt_imples_clause (v1, v2) ->
      let v1 = extends_clause env v1 in
      let _v2 () =
        (match v2 with
        | Some x -> todo_implements_clause env x
        | None -> todo env ())
      in
      (match v1 with
       | [] -> None
       | x :: _shouldnt_be_dropped -> Some x)
  | `Imples_clause x ->
      let _v () = todo_implements_clause env x in
      None
  )

and property_name (env : env) (x : CST.property_name) =
  (match x with
  | `Choice_id x ->
      let id = identifier_reference env x in
      PN id
  | `Str x ->
      let s = JS.string_ env x in
      PN s
  | `Num tok ->
      let n = JS.number env tok (* number *) in
      PN n
  | `Comp_prop_name (v1, v2, v3) ->
      let _v1 = JS.token env v1 (* "[" *) in
      let v2 = expression env v2 in
      let _v3 = JS.token env v3 (* "]" *) in
      PN_Computed v2
  )

and switch_case (env : env) ((v1, v2, v3, v4) : CST.switch_case) =
  let v1 = JS.token env v1 (* "case" *) in
  let v2 = expressions env v2 in
  let _v3 = JS.token env v3 (* ":" *) in
  let v4 = List.map (statement env) v4 |> List.flatten in
  Case (v1, v2, stmt_of_stmts v4)

and spread_element (env : env) ((v1, v2) : CST.spread_element) =
  let v1 = JS.token env v1 (* "..." *) in
  let v2 = expression env v2 in
  v1, v2

and expressions (env : env) (x : CST.expressions) : expr =
  (match x with
  | `Exp x -> expression env x
  | `Seq_exp x -> sequence_expression env x
  )

(* TODO: types *)
and todo_abstract_method_signature (env : env) ((v1, v2, v3, v4, v5, v6) : CST.abstract_method_signature) =
  let v1 =
    (match v1 with
    | Some x -> accessibility_modifier env x
    | None -> todo env ())
  in
  let v2 = JS.token env v2 (* "abstract" *) in
  let v3 =
    (match v3 with
    | Some x -> anon_choice_get env x
    | None -> todo env ())
  in
  let v4 = property_name env v4 in
  let v5 =
    (match v5 with
    | Some tok -> JS.token env tok (* "?" *)
    | None -> todo env ())
  in
  let v6 = call_signature env v6 in
  todo env (v1, v2, v3, v4, v5, v6)

and finally_clause (env : env) ((v1, v2) : CST.finally_clause) =
  let v1 = JS.token env v1 (* "finally" *) in
  let v2 = statement_block env v2 in
  v1, v2

(* TODO don't ignore the type annotations *)
and call_signature (env : env) ((v1, v2, v3) : CST.call_signature) : parameter list =
  let _v1 () =
    (match v1 with
    | Some x -> todo_type_parameters env x
    | None -> todo env ())
  in
  let v2 = formal_parameters env v2 in
  let _v3 () =
    (match v3 with
    | Some x -> type_annotation env x
    | None -> todo env ())
  in
  v2

and object_ (env : env) ((v1, v2, v3) : CST.object_) : obj_ =
  let v1 = JS.token env v1 (* "{" *) in
  let v2 =
    (match v2 with
    | Some (v1, v2) ->
        let v1 =
          (match v1 with
          | Some x -> [anon_choice_pair env x]
          | None -> [])
        in
        let v2 =
          List.filter_map (fun (v1, v2) ->
            let _v1 = JS.token env v1 (* "," *) in
            let v2 =
              (match v2 with
              | Some x -> Some (anon_choice_pair env x)
              | None -> None)
            in
            v2
          ) v2
        in
        v1 @ v2
    | None -> [])
  in
  let v3 = JS.token env v3 (* "}" *) in
  v1, v2, v3

(* TODO: types! *)
and todo_type_ (env : env) (x : CST.type_) : type_ =
  (match x with
  | `Prim_type x -> todo_primary_type env x
  | `Union_type (v1, v2, v3) ->
      let v1 =
        (match v1 with
        | Some x -> todo_type_ env x
        | None -> todo env ())
      in
      let v2 = JS.token env v2 (* "|" *) in
      let v3 = todo_type_ env v3 in
      todo env (v1, v2, v3)
  | `Inte_type (v1, v2, v3) ->
      let v1 =
        (match v1 with
        | Some x -> todo_type_ env x
        | None -> todo env ())
      in
      let v2 = JS.token env v2 (* "&" *) in
      let v3 = todo_type_ env v3 in
      todo env (v1, v2, v3)
  | `Func_type (v1, v2, v3, v4) ->
      let _v1 () =
        (match v1 with
        | Some x -> todo_type_parameters env x
        | None -> todo env ())
      in
      let v2 = formal_parameters env v2 in
      let v3 = JS.token env v3 (* "=>" *) in
      let v4 = todo_type_ env v4 in
      todo env (v1, v2, v3, v4)
  | `Cons_type (v1, v2, v3, v4, v5) ->
      let v1 = JS.token env v1 (* "new" *) in
      let v2 =
        (match v2 with
        | Some x -> todo_type_parameters env x
        | None -> todo env ())
      in
      let v3 = formal_parameters env v3 in
      let v4 = JS.token env v4 (* "=>" *) in
      let v5 = todo_type_ env v5 in
      todo env (v1, v2, v3, v4, v5)
  )

(* TODO: types *)
and todo_type_parameters (env : env) ((v1, v2, v3, v4, v5) : CST.type_parameters) =
  let v1 = JS.token env v1 (* "<" *) in
  let v2 = todo_type_parameter env v2 in
  let v3 =
    List.map (fun (v1, v2) ->
      let v1 = JS.token env v1 (* "," *) in
      let v2 = todo_type_parameter env v2 in
      todo env (v1, v2)
    ) v3
  in
  let v4 =
    (match v4 with
    | Some tok -> JS.token env tok (* "," *)
    | None -> todo env ())
  in
  let v5 = JS.token env v5 (* ">" *) in
  todo env (v1, v2, v3, v4, v5)

(* TODO: types *)
and todo_constraint_ (env : env) ((v1, v2) : CST.constraint_) =
  let _v1 () =
    (match v1 with
    | `Extends tok -> JS.token env tok (* "extends" *)
    | `COLON tok -> JS.token env tok (* ":" *)
    )
  in
  let _v2 () = todo_type_ env v2 in
  todo env (v1, v2)

(* TODO don't ignore accessibility modifier (public/private/proteced)
        and "readonly" *)
and parameter_name (env : env) ((v1, v2, v3) : CST.parameter_name) : (ident, pattern) Common.either =
  let _v1 () =
    (match v1 with
    | Some x -> accessibility_modifier env x
    | None -> todo env ())
  in
  let _v2 () =
    (match v2 with
    | Some tok -> JS.token env tok (* "readonly" *)
    | None -> todo env ())
  in
  let v3 =
    (match v3 with
    | `Id tok ->
        let id = JS.identifier env tok (* identifier *) in
        Left id
    | `Choice_decl x ->
        let id = reserved_identifier env x in
        Left id
    | `Choice_obj x ->
        let pat = destructuring_pattern env x in
        Right pat
    | `This tok ->
        (* treating 'this' as a regular identifier for now *)
        let id = JS.identifier env tok (* "this" *) in
        Left id
    )
  in
  v3

and lhs_expression (env : env) (x : CST.lhs_expression) =
  (match x with
  | `Member_exp x -> member_expression env x
  | `Subs_exp x -> subscript_expression env x
  | `Id tok -> JS.identifier env tok |> JS.idexp (* identifier *)
  | `Choice_decl x -> reserved_identifier env x |> JS.idexp
  | `Choice_obj x -> destructuring_pattern env x
  )

and statement_block (env : env) ((v1, v2, v3, v4) : CST.statement_block) =
  let v1 = JS.token env v1 (* "{" *) in
  let v2 = List.map (statement env) v2 |> List.flatten in
  let v3 = JS.token env v3 (* "}" *) in
  let v4 =
    (match v4 with
    | Some tok -> Some (automatic_semicolon env tok) (* automatic_semicolon *)
    | None -> None)
  in
  Block (v1, v2, v3)

and function_declaration (env : env) ((v1, v2, v3, v4, v5, v6) : CST.function_declaration) : var list =
  let v1 =
    (match v1 with
     | Some tok -> [Async, JS.token env tok] (* "async" *)
     | None -> [])
  in
  let v2 = JS.token env v2 (* "function" *) in
  let v3 = JS.identifier env v3 (* identifier *) in
  let v4 = call_signature env v4 in
  let v5 = statement_block env v5 in
  let _v6 =
    (match v6 with
    | Some tok -> Some (JS.token env tok) (* automatic_semicolon *)
    | None -> None)
  in
  let f = { f_props = v1; f_params = v4; f_body = v5 } in
  [{ v_name = v3; v_kind = Const, v2; v_type = None;
     v_init = Some (Fun (f, None)); v_resolved = ref NotResolved }]

(* TODO: types *)
and todo_anon_choice_type_id3 (env : env) (x : CST.anon_choice_type_id3) =
  (match x with
  | `Id tok -> JS.token env tok (* identifier *)
  | `Nested_type_id x -> todo_nested_type_identifier env x
  | `Gene_type x -> todo_generic_type env x
  )

and template_substitution (env : env) ((v1, v2, v3) : CST.template_substitution) =
  let _v1 = JS.token env v1 (* "${" *) in
  let v2 = expressions env v2 in
  let _v3 = JS.token env v3 (* "}" *) in
  v2

(* TODO: types *)
and todo_method_signature (env : env) ((v1, v2, v3, v4, v5, v6, v7, v8) : CST.method_signature) =
  let v1 =
    (match v1 with
    | Some x -> accessibility_modifier env x
    | None -> todo env ())
  in
  let v2 =
    (match v2 with
    | Some tok -> JS.token env tok (* "static" *)
    | None -> todo env ())
  in
  let v3 =
    (match v3 with
    | Some tok -> JS.token env tok (* "readonly" *)
    | None -> todo env ())
  in
  let v4 =
    (match v4 with
    | Some tok -> JS.token env tok (* "async" *)
    | None -> todo env ())
  in
  let v5 =
    (match v5 with
    | Some x -> anon_choice_get env x
    | None -> todo env ())
  in
  let v6 = property_name env v6 in
  let v7 =
    (match v7 with
    | Some tok -> JS.token env tok (* "?" *)
    | None -> todo env ())
  in
  let v8 = call_signature env v8 in
  todo env (v1, v2, v3, v4, v5, v6, v7, v8)

(* TODO: types *)
(* This covers mostly type definitions but includes also javascript constructs
   like function parameters, so it will be called even if we ignore types. *)
and declaration (env : env) (x : CST.declaration) : var list =
  (match x with
  | `Choice_func_decl x ->
      (match x with
      | `Func_decl x -> function_declaration env x
      | `Gene_func_decl x ->
          generator_function_declaration env x
      | `Class_decl x -> class_declaration env x
      | `Lexi_decl x -> lexical_declaration env x
      | `Var_decl x -> variable_declaration env x
      )
  | `Func_sign (v1, v2, v3, v4, v5) ->
      let _v1 =
        (match v1 with
        | Some tok -> [Async, JS.token env tok] (* "async" *)
        | None -> [])
      in
      let _v2 = JS.token env v2 (* "function" *) in
      let _v3 = JS.identifier env v3 (* identifier *) in
      let _v4 () = call_signature env v4 in
      let _v5 = JS.semicolon env v5 in
      [] (* TODO *)
  | `Abst_class_decl (v1, v2, v3, v4, v5, v6) ->
      (* TODO currently treated as a regular class. Does it matter? *)
      let _v1 = JS.token env v1 (* "abstract" *) in
      let v2 = JS.token env v2 (* "class" *) in
      let v3 = JS.identifier env v3 (* identifier *) in
      let _v4 () =
        (match v4 with
        | Some x -> todo_type_parameters env x
        | None -> todo env ())
      in
      let v5 =
        (match v5 with
        | Some x -> class_heritage env x
        | None -> None)
      in
      let v6 = class_body env v6 in
      let c = { c_tok = v2; c_extends = v5; c_body = v6 } in
      [{ v_name = v3; v_kind = Const, v2; v_type = None;
         v_init = Some (Class (c, None)); v_resolved = ref NotResolved }]
  | `Module (v1, v2) ->
      (* does this exist only in .d.ts files? *)
      let _v1 = JS.token env v1 (* "module" *) in
      let id, opt_body = module__ env v2 in
      [] (* TODO *)

  | `Inte_module x ->
      (* namespace *)
      let _x = internal_module env x in
      [] (* TODO *)

  | `Type_alias_decl (v1, v2, v3, v4, v5, v6) ->
      let _v1 = JS.token env v1 (* "type" *) in
      let _v2 = JS.token env v2 (* identifier *) in
      let _v3 () =
        (match v3 with
        | Some x -> todo_type_parameters env x
        | None -> [])
      in
      let _v4 = JS.token env v4 (* "=" *) in
      let _v5 () = todo_type_ env v5 in
      let _v6 = JS.semicolon env v6 in
      [] (* TODO *)

  | `Enum_decl (v1, v2, v3, v4) ->
      let _v1 () =
        (match v1 with
        | Some tok -> JS.token env tok (* "const" *)
        | None -> todo env ())
      in
      let _v2 = JS.token env v2 (* "enum" *) in
      let _v3 = JS.identifier env v3 (* identifier *) in
      let _v4 () = todo_enum_body env v4 in
      [] (* TODO *)

  | `Inte_decl (v1, v2, v3, v4, v5) ->
      let v1 = JS.token env v1 (* "interface" *) in
      let v2 = JS.identifier env v2 (* identifier *) in
      let _v3 () =
        (match v3 with
        | Some x -> todo_type_parameters env x
        | None -> [])
      in
      let _v4 () =
        (match v4 with
        | Some x -> extends_clause env x
        | None -> todo env ())
      in
      let _v5 () = todo_object_type env v5 in
      [] (* TODO *)

  | `Import_alias (v1, v2, v3, v4, v5) ->
      let _v1 = JS.token env v1 (* "import" *) in
      let _v2 = JS.identifier env v2 (* identifier *) in
      let _v3 = JS.token env v3 (* "=" *) in
      let _v4 () = anon_choice_type_id env v4 in
      let _v5 = JS.semicolon env v5 in
      [] (* TODO *)

  | `Ambi_decl (v1, v2) ->
      let _v1 = JS.token env v1 (* "declare" *) in
      let _v2 () =
        (match v2 with
        | `Decl x -> declaration env x
        | `Global_stmt_blk (v1, v2) ->
            let v1 = JS.token env v1 (* "global" *) in
            let v2 = statement_block env v2 in
            todo env (v1, v2)
        | `Module_DOT_id_COLON_type (v1, v2, v3, v4, v5) ->
            let v1 = JS.token env v1 (* "module" *) in
            let v2 = JS.token env v2 (* "." *) in
            let v3 = JS.token env v3 (* identifier *) in
            let v4 = JS.token env v4 (* ":" *) in
            let v5 = todo_type_ env v5 in
            todo env (v1, v2, v3, v4, v5)
        )
      in
      [] (* TODO *)
  )

let toplevel env x = statement env x

let program (env : env) ((v1, v2) : CST.program) : program =
  let _v1 =
    (match v1 with
    | Some tok -> Some (JS.token env tok) (* pattern #!.* *)
    | None -> None)
  in
  let v2 = List.map (toplevel env) v2 |> List.flatten in
  v2

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

type dialect = [ `Typescript | `TSX ]

let parse dialect file =
  let debug = false in
  let cst =
    Parallel.backtrace_when_exn := false;
    match dialect with
    | `Typescript ->
        let cst = Parallel.invoke Tree_sitter_typescript.Parse.file file () in
        (cst :> CST.program)
    | `TSX ->
        let cst = Parallel.invoke Tree_sitter_tsx.Parse.file file () in
        (cst :> CST.program)
  in
  let env = { H.file; conv = H.line_col_to_pos file } in

  if debug then (
    Printexc.record_backtrace true;
    CST.dump_tree cst;
  );

  try
    program env cst
  with
    TODO as exn ->
      if debug then (
        (* This debugging output is not JSON and breaks core output *)

        let s = Printexc.get_backtrace () in
        pr2 "Some constructs are not handled yet";
        pr2 "CST was:";
        CST.dump_tree cst;
        pr2 "Original backtrace:";
        pr2 s;
      );
      failwith "not implemented"

(** Html module: converts a value to its html represenation (based on module TODO).

    Work in progress.
*)

(*
    For type declaration [type ('a,'b,...) typ = ...] it will create a transformation
    function with type

    [(Format.formatter -> 'a -> unit) -> (Format.formatter -> 'b -> unit) -> ... ->
     Format.formatter -> ('a,'b,...) typ -> unit ]

    Inherited attributes' type (both default and for type parameters) is
    [Format.formatter].
    Synthesized attributes' type (both default and for type parameters) is [unit].
*)

(*
 * OCanren: syntax extension.
 * Copyright (C) 2016-2017
 *   Dmitrii Kosarev aka Kakadu
 * St.Petersburg State University, JetBrains Research
 *)

(* NOT IMPELEMENTED YET *)
open Base
open Ppxlib
open HelpersBase
open Printf

let trait_name = "html"

module Make(AstHelpers : GTHELPERS_sig.S) = struct

let plugin_name = trait_name

module P = Plugin.Make(AstHelpers)
open AstHelpers

let app_format_sprintf ~loc arg =
  Exp.app ~loc
    (Exp.of_longident ~loc (Ldot(Lident "Format", "sprintf")))
    arg

module H = struct
  type elt = Exp.t
  let wrap ~loc s = Exp.of_longident ~loc (Ldot (Lident "HTML", s))
  let pcdata ~loc s = Exp.(app ~loc (wrap ~loc "string") (string_const ~loc s))
  let div ~loc xs =
    Exp.app ~loc (wrap ~loc "list") @@
    Exp.list ~loc xs

  let to_list_e ~loc xs =
    List.fold_right xs ~init:(Exp.construct ~loc (lident "[]") [])
      ~f:(fun x acc ->
          Exp.construct ~loc (lident "::") [x; acc]
        )

  let li ~loc xs =
    Exp.app ~loc (wrap ~loc "li") @@ Exp.app ~loc (wrap ~loc "seq") @@ to_list_e ~loc xs
  (* let ol ~loc xs =
   *   Exp.app ~loc (wrap ~loc "ol") @@ Exp.app ~loc (wrap ~loc "seq") @@ to_list_e ~loc xs *)
  let ul ~loc xs =
    Exp.app ~loc (wrap ~loc "ul") @@ Exp.app ~loc (wrap ~loc "seq") @@ to_list_e ~loc xs
  let checkbox ~loc name =
    let open Exp in
    app ~loc
      (app_lab ~loc (wrap ~loc "input")
         "attrs" (string_const ~loc @@ Printf.sprintf "type=\"checkbox\" id=\"%s\"" name))
      (app ~loc (wrap ~loc "unit") (unit ~loc))
end

class g args = object(self)
  inherit [loc, Typ.t, type_arg, Ctf.t, Cf.t, Str.t, Sig.t] Plugin_intf.typ_g
  inherit P.generator args
  inherit P.no_inherit_arg

  method plugin_name = trait_name
  method default_inh ~loc _tdecl = Typ.ident ~loc "unit"
  method default_syn ~loc ?extra_path _tdecl = self#syn_of_param ~loc "dummy"

  method syn_of_param ~loc _     =
    Typ.constr ~loc (Ldot (Lident "HTML", "er")) []

  method inh_of_param tdecl _name = self#default_inh ~loc:noloc tdecl

  method plugin_class_params tdecl =
    (* TODO: reuse prepare_inherit_typ_params_for_alias here *)
    let ps =
      List.map tdecl.ptype_params ~f:(fun (t,_) -> typ_arg_of_core_type t)
    in
    ps @
    [ named_type_arg ~loc:(loc_from_caml tdecl.ptype_loc) @@
      Naming.make_extra_param tdecl.ptype_name.txt
    ]

  method prepare_inherit_typ_params_for_alias ~loc tdecl rhs_args =
    List.map rhs_args ~f:Typ.from_caml

  method on_tuple_constr ~loc ~is_self_rec ~mutal_decls ~inhe constr_info ts =
    let constr_name = match constr_info with
      | `Poly s -> sprintf "`%s" s
      | `Normal s -> s
    in

    let names = List.map ts ~f:fst in
    Exp.fun_list ~loc
      (List.map names ~f:(Pat.sprintf ~loc "%s"))
      (if List.length ts = 0
       then H.(ul ~loc [pcdata ~loc constr_name])
       else
         H.ul ~loc @@ (
           (H.li ~loc [H.pcdata ~loc constr_name]) ::
           (List.map ts ~f:(fun (name, typ) ->
              H.li ~loc
                [ self#app_transformation_expr ~loc
                    (self#do_typ_gen ~loc ~is_self_rec ~mutal_decls typ)
                    (Exp.assert_false ~loc)
                    (Exp.ident ~loc name)
                ]
              ))
         )
      )

  method on_record_declaration ~loc ~is_self_rec ~mutal_decls tdecl labs =
    let pat = Pat.record ~loc @@
      List.map labs ~f:(fun l ->
          (Lident l.pld_name.txt, Pat.var ~loc l.pld_name.txt)
        )
    in
    let methname = sprintf "do_%s" tdecl.ptype_name.txt in
    [ Cf.method_concrete ~loc methname @@
      Exp.fun_ ~loc (Pat.unit ~loc) @@
      Exp.fun_ ~loc pat @@

      let ds = List.map labs
          ~f:(fun {pld_name; pld_type} ->
            H.li ~loc
              [ H.pcdata ~loc pld_name.txt
              ; self#app_transformation_expr ~loc
                  (self#do_typ_gen ~loc ~is_self_rec ~mutal_decls pld_type)
                  (Exp.assert_false ~loc)
                  (Exp.ident ~loc pld_name.txt)
              ]
            )
      in
      H.ul ~loc @@ (H.pcdata ~loc tdecl.ptype_name.txt) :: ds
    ]

  method! on_record_constr: loc:loc ->
    is_self_rec:(core_type -> bool) ->
    mutal_decls:type_declaration list ->
    inhe:Exp.t ->
    [ `Normal of string | `Poly of string ] ->
    (string * _ * core_type) list ->
    label_declaration list ->
    Exp.t = fun  ~loc ~is_self_rec ~mutal_decls ~inhe info bindings labs ->
    let constr_name = match info with
      | `Poly s -> sprintf "`%s" s
      | `Normal s -> s
    in

    Exp.fun_list ~loc (List.map bindings ~f:(fun (s,_,_) -> Pat.sprintf ~loc "%s" s)) @@
    let open H  in
    ul ~loc @@
    [pcdata ~loc constr_name] @
    List.map bindings
      ~f:(fun (pname, lname, typ) ->
          H.li ~loc
              [ H.pcdata ~loc lname
              ; self#app_transformation_expr ~loc
                  (self#do_typ_gen ~loc ~is_self_rec ~mutal_decls typ)
                  (Exp.assert_false ~loc)
                  (Exp.ident ~loc pname)
              ]
        )


end

let g = (new g :> (Plugin_intf.plugin_args ->
                   (loc, Typ.t, type_arg, Ctf.t, Cf.t, Str.t, Sig.t) Plugin_intf.typ_g) )
end

let register () =
  Expander.register_plugin trait_name (module Make: Plugin_intf.PluginRes)

let () = register ()

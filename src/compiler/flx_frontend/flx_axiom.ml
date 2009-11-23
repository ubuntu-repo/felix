open Flx_util
open Flx_ast
open Flx_types
open Flx_print
open Flx_set
open Flx_mtypes2
open Flx_typing
open Flx_mbind
open List
open Flx_unify
open Flx_treg
open Flx_generic
open Flx_maps
open Flx_exceptions
open Flx_use
open Flx_child
open Flx_typeclass

let string_of_bvs bvs =
  catmap "," (fun (s,i)->s^"<"^si i^">") bvs

let verify syms sym_table bsym_table csr e =
  let xx = ref [] in
  iter
  ( fun (id, axsr, parent, axiom_kind, bvs, (bpl,precond), x) ->
    match x with | `BEquation _ -> () | `BPredicate x ->
    (*
    print_endline ("Checking for cases of axiom " ^ id);
    *)
    let param = match bpl with
      | [] -> BEXPR_tuple [],BTYP_tuple []
      | [{pindex=i;ptyp=t}] -> BEXPR_name (i,[]),t
      | ls ->
        let xs = map (fun {pindex=i; ptyp=t}->BEXPR_name (i,[]),t) ls in
        let ts = map snd xs in
        BEXPR_tuple xs,BTYP_tuple ts
    in
    let tvars = map (fun (_,i) -> i) bvs in
    let evars = map (fun {pindex=i} -> i) bpl in
    let result = expr_maybe_matches syms.counter sym_table tvars evars param e in
    match result with
    | None -> ()
    | Some (tmgu, emgu) ->
      (*
      print_endline (sbe sym_table e ^  " MATCHES AXIOM " ^ id);
      print_endline ("Axiom vs =" ^ string_of_bvs bvs);
      print_endline ("TMgu=" ^ string_of_varlist sym_table tmgu);
      *)
      let ok = match parent with
      | None -> true
      | Some i ->
        try
          let tcid,_,sr,entry = Flx_bsym_table.find bsym_table i in
          match entry with
          | BBDCL_typeclass (_,tcbvs) ->
            begin
              (*
              print_endline ("Axiom "^id^" is owned by typeclass " ^ tcid);
              print_endline ("Typeclass bvs=" ^ string_of_bvs tcbvs);
              *)
              let ts =
                try
                  Some (map (fun (s,i) -> assoc i tmgu) tcbvs)
                with Not_found ->
                  (*
                  print_endline "Can't instantiate typeclass vars- FAIL";
                  *)
                  None
              in
              match ts with None -> false | Some ts ->
              let insts =
                try
                  Some (Hashtbl.find syms.instances_of_typeclass i)
                with Not_found ->
                  (*
                  print_endline "Typeclass has no instances";
                  *)
                  None
              in
              match insts with | None -> false | Some insts ->
              try
                iter (fun (instidx,(inst_bvs, inst_traint, inst_ts)) ->
                  match tcinst_chk syms sym_table bsym_table true i ts sr (inst_bvs, inst_traint, inst_ts, instidx) with
                  | None -> ()
                  | Some _ -> raise Not_found
                )
                insts;
                (*
                print_endline "Couldn't find instance";
                *)
                false
              with Not_found ->
                (*
                print_endline "FOUND INSTANCE";
                *)
                true
            end
          | _ -> true
        with
          Not_found ->
          (*
          print_endline "Wha .. can't find axiom's parent";
          *)
          true
      in
      if not ok then () else
      let xsub x = fold_left (fun x (i,e) -> expr_term_subst x i e) x emgu in
      let tsub t = list_subst syms.counter tmgu t in
      (*
      print_endline ("tmgu= " ^ catmap ", " (fun (i,t) -> si i ^ "->" ^ sbt sym_table t) tmgu);
      *)
      let ident x = x in
      let rec aux x = map_tbexpr ident aux tsub x in
      let cond = aux (xsub x) in
      let precond = match precond with
      | Some x -> Some (aux (xsub x))
      | None -> None
      in
      let comment = BEXE_comment (csr,"Check " ^ id) in
      let ax = BEXE_assert2 (csr,axsr,precond,cond) in
      (*
      print_endline ("Assertion: " ^ tsbe sym_table cond);
      *)
      xx := ax :: comment :: !xx
  )
  syms.axioms
  ;
  !xx

let fixup_exes syms sym_table bsym_table bexes =
  let rec aux inx outx = match inx with
  | [] -> rev outx
  | BEXE_axiom_check (sr,e) :: t ->
    (*
    print_endline ("Axiom check case "  ^ sbe sym_table e);
    *)
    aux t ((verify syms sym_table bsym_table sr e) @ outx)

  | h :: t -> aux t (h::outx)
  in
  aux bexes []

let axiom_check syms sym_table bsym_table =
  Flx_bsym_table.iter
  (fun i (id,sr,parent,entry) ->
    match entry with
    | BBDCL_function (ps,bvs,bpar,bty,bexes) ->
      let bexes = fixup_exes syms sym_table bsym_table bexes in
      let entry = BBDCL_function (ps,bvs,bpar,bty,bexes) in
      Flx_bsym_table.add bsym_table i (id,sr,parent,entry)

    | BBDCL_procedure (ps,bvs,bpar,bexes) ->
      let bexes = fixup_exes syms sym_table bsym_table bexes in
      let entry = BBDCL_procedure (ps,bvs,bpar,bexes) in
      Flx_bsym_table.add bsym_table i (id,sr,parent,entry)

    | _ -> ()
  )
  bsym_table

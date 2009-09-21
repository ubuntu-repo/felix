(** C++ code generator *)

val gen_function_names:
  Flx_mtypes2.sym_state_t ->
  (Flx_types.bid_t, Flx_types.bid_t list) Hashtbl.t *
  Flx_types.fully_bound_symbol_table_t ->
  string

val gen_functions:
  Flx_mtypes2.sym_state_t ->
  (Flx_types.bid_t, Flx_types.bid_t list) Hashtbl.t *
  Flx_types.fully_bound_symbol_table_t ->
  string

val gen_execute_methods:
  string ->
  Flx_mtypes2.sym_state_t ->
  (Flx_types.bid_t, Flx_types.bid_t list) Hashtbl.t *
  Flx_types.fully_bound_symbol_table_t ->
  Flx_label.label_map_t * Flx_label.label_usage_t ->
  int ref ->
  out_channel ->
  out_channel ->
  unit

val find_members:
  Flx_mtypes2.sym_state_t ->
  (Flx_types.bid_t, Flx_types.bid_t list) Hashtbl.t *
  Flx_types.fully_bound_symbol_table_t ->
  int ->
  Flx_types.btypecode_t list ->
  string

val gen_biface_headers:
  Flx_mtypes2.sym_state_t ->
  Flx_types.fully_bound_symbol_table_t ->
  Flx_types.biface_t list ->
  string

val gen_biface_bodies:
  Flx_mtypes2.sym_state_t ->
  Flx_types.fully_bound_symbol_table_t ->
  Flx_types.biface_t list ->
  string

val format_vars:
  Flx_mtypes2.sym_state_t ->
  Flx_types.fully_bound_symbol_table_t ->
  Flx_types.bid_t list ->
  Flx_types.btypecode_t list ->
  string

val is_gc_pointer:
  Flx_mtypes2.sym_state_t ->
  Flx_types.fully_bound_symbol_table_t ->
  Flx_srcref.t ->
  Flx_types.btypecode_t ->
  bool

val gen_python_module:
  string ->
  Flx_mtypes2.sym_state_t ->
  Flx_types.fully_bound_symbol_table_t ->
  Flx_types.biface_t list ->
  string

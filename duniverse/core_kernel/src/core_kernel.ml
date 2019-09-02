open! Import

(**/**)

module Std = struct
  include Std_kernel  (** @inline *)

  (** {1 Std}

      [Std] defines modules exposed by [Core_kernel] that are overridden by [Core].  *)

  (** {2 Modules imported from Base without modification} *)

  module Caml = Caml

  (** {2 Modules that extend Base} *)

  module Container_intf = Container_intf
  module Int_replace_polymorphic_compare = Int_replace_polymorphic_compare

  (** {2 Modules added by Core_kernel} *)

  module Bigstring = Bigstring
  module Command = Command
  module Core_kernel_stable = Stable
  module Date = Date
  module Filename = Filename
  module Map_intf = Map_intf
  module Digest = Md5 [@@ocaml.deprecated "[since 2017-05] Use Md5 instead."]
  module Optional_syntax_intf = Optional_syntax_intf
  module Set_intf = Set_intf
  module Sys = Sys
  module Time = Time_float
  module Time_ns = Time_ns
  module Timing_wheel_ns_intf = Timing_wheel_ns_intf
  module Version_util = Version_util

  (** To be used in implementing Core, but not by end users. *)
  module Core_kernel_private = struct
    module Digit_string_helpers = Digit_string_helpers
    module Time_zone = Zone
    module Ofday_helpers = Ofday_helpers
    module Span_float = Span_float

    module Bigbuffer_internal = Bigbuffer_internal
    module Stable_internal = Stable_internal
    module Std_internal = Std_internal

    (** [Std_kernel] defines modules exposed by [Core_kernel] that are not overridden by
        [Core].  It is used in [core.ml] to re-export these modules. *)
    module Std_kernel = Std_kernel

    module Time_ns_alternate_sexp = Time_ns_alternate_sexp
  end
end
[@@deprecated "[since 2018-03] Use Core_kernel directly instead"]

(**/**)

include Std [@@warning "-3"]  (** @inline *)

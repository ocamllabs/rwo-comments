#require "core,core.top,ppx_jane";;
#require "ctypes";;
#require "ctypes.top";;
#require "ctypes-foreign.threaded";;

open Base
open Ctypes
open PosixTypes
open Foreign

let () = Printexc.record_backtrace false

package require hexchat

package provide dasbrain::isupport 1.0

namespace eval ::dasbrain::isupport {
	if {![info exists support]} {
		variable support [dict create]
	}
	if {![info exists hook_005]} {
		variable hook_005 [::hexchat::hook_server 005 ::dasbrain::isupport::005]
	}
	namespace export isupport ircsplit
	namespace ensemble create -command ::dasbrain::isupport::isupport -map {get iget isset isset}
}

proc ::dasbrain::isupport::ircsplit {str} {
	set res {}
	if {[string index $str 0] eq ":"} {
		lappend res [string range $str 1 [set first [string first " " $str]]-1]
		set str [string range $str 1+$first end]
	} else {
		lappend res {}
	}
	if {[set pos [string first " :" $str]] != -1} {
		lappend res {*}[split [string range $str 0 ${pos}-1]]
		lappend res [string range $str 2+$pos end]
	} else {
		lappend res {*}[split $str]
	}
	return $res
}

# :osmium.libera.chat 005 DasBrain WHOX FNC KNOCK SAFELIST ELIST=CTU CALLERID=g MONITOR=100 ETRACE CHANTYPES=# EXCEPTS INVEX CHANMODES=eIbq,k,flj,CFLMPQScgimnprstuz :are supported by this server
proc ::dasbrain::isupport::005 {word word_eol} {
	variable support
	set toks [ircsplit [lindex $word_eol 1]]
	set sid [::hexchat::prefs id]
	foreach tok [lrange $toks 3 end-1] {
		set eqidx [string first = $tok]
		set value {}
		if {$eqidx != -1} {
			set value [string range $tok $eqidx+1 end]
			set tok [string range $tok 0 $eqidx-1]
		}
		if {[string index $tok 0] eq {-}} {
			dict unset support $sid [string range $tok 1 end]
		} else {
			dict set support $sid $tok $value
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::isupport::iget {args} {
	variable support
	return [dict get $support [::hexchat::prefs id] {*}$args]
}

proc ::dasbrain::isupport::isset {key} {
	variable support
	return [dict exists $support [::hexchat::prefs id] $key]
}

apply {{} {
	set origctx [::hexchat::getcontext]
	set cfields [::hexchat::list_fields channels]
	set ctxidx [lsearch $cfields context]
	set typeidx [lsearch $cfields type]
	set flagsidx [lsearch $cfields flags]
	foreach chan [::hexchat::getlist channels] {
		if {[lindex $chan $typeidx] == 1 && ([lindex $chan $flagsidx] & 8) != 0} {
			::hexchat::setcontext [lindex $chan $ctxidx]
			::hexchat::command "QUOTE VERSION"
		}
	}
	::hexchat::setcontext $origctx
}}
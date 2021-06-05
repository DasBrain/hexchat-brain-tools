package require hexchat
package require dasbrain::isupport
package require dasbrain::modeparse
package require dasbrain::chanopt

package provide dasbrain::channels 1.0

namespace eval ::dasbrain::channels {
	namespace import ::dasbrain::isupport::ircsplit ::dasbrain::isupport::isupport
	if {![info exists channels]} {
		variable channels [dict create]
	}
	if {![info exists on-join]} {
		variable on-join [list]
	}
	if {![info exists on-djoin]} {
		variable on-djoin [list]
	}
	if {![info exists on-userchg]} {
		variable on-userchg [list]
	}
	if {![info exists join_hook]} {
		variable join_hook [::hexchat::hook_server JOIN ::dasbrain::channels::JOIN]
	}
	if {![info exists part_hook]} {
		variable part_hook [::hexchat::hook_server PART ::dasbrain::channels::PART]
	}
	if {![info exists quit_hook]} {
		variable quit_hook [::hexchat::hook_server QUIT ::dasbrain::channels::QUIT]
	}
	if {![info exists kick_hook]} {
		variable kick_hook [::hexchat::hook_server KICK ::dasbrain::channels::KICK]
	}
	if {![info exists nick_hook]} {
		variable nick_hook [::hexchat::hook_server NICK ::dasbrain::channels::NICK]
	}
	if {![info exists 354_hook]} {
		variable 354_hook [::hexchat::hook_server 354 ::dasbrain::channels::354]
	}
	if {![info exists 352_hook]} {
		variable 352_hook [::hexchat::hook_server 352 ::dasbrain::channels::352]
	}
	if {![info exists 353_hook]} {
		variable 353_hook [::hexchat::hook_server 353 ::dasbrain::channels::353]
	}
	if {![info exists ACCOUNT_hook]} {
		variable ACCOUNT_hook [::hexchat::hook_server ACCOUNT ::dasbrain::channels::ACCOUNT]
	}
	if {![info exists AWAY_hook]} {
		variable AWAY_hook [::hexchat::hook_server AWAY ::dasbrain::channels::AWAY]
	}
	if {![info exists CHGHOST_hook]} {
		variable CHGHOST_hook [::hexchat::hook_server CHGHOST ::dasbrain::channels::CHGHOST]
	}
	if {![info exists Disconnected_hook]} {
		variable Disconnected_hook [::hexchat::hook_print Disconnected ::dasbrain::channels::Disconnected]
	}
	if {![info exists 324_hook]} {
		variable 324_hook [::hexchat::hook_server 324 ::dasbrain::channels::324]
	}
	nopt register account-host-regexp string {}
	::dasbrain::modeparse::handler ::dasbrain::channels::mode-change
	namespace export on-join on-djoin on-userchg
}

proc ::dasbrain::channels::on-join {cmd} {
	variable on-join
	if {$cmd ni ${on-join}} {
		lappend on-join $cmd
	}
}

proc ::dasbrain::channels::on-djoin {cmd} {
	variable on-djoin
	if {$cmd ni ${on-djoin}} {
		lappend on-djoin $cmd
	}
}

proc ::dasbrain::channels::on-userchg {cmd} {
	variable on-userchg
	if {$cmd ni ${on-userchg}} {
		lappend on-userchg $cmd
	}
}

proc ::dasbrain::channels::emit-join {chan userrec} {
	variable on-join
	foreach h ${on-join} {
		try {
			{*}$h $chan $userrec
		} on error {- opt} {
			::hexchat::print "JOIN $h $chan $userrec\t[dict get $opt -errorinfo]"
		}
	}
}

proc ::dasbrain::channels::emit-djoin {chan userrec} {
	variable on-djoin
	foreach h ${on-djoin} {
		try {
			{*}$h $chan $userrec
		} on error {- opt} {
			::hexchat::print "DJOIN $h $chan $userrec\t[dict get $opt -errorinfo]"
		}
	}
}

proc ::dasbrain::channels::emit-userchg {chan userrec} {
	variable on-userchg
	foreach h ${on-userchg} {
		try {
			{*}$h $chan $userrec
		} on error {- opt} {
			::hexchat::print "USERCHG $h $chan $userrec\t[dict get $opt -errorinfo]"
		}
	}
}

proc ::dasbrain::channels::nuh2nick {nuh} {
	set bangidx [string first ! $nuh]
	if {$bangidx != -1} {
		return [string range $nuh 0 $bangidx-1]
	} else {
		return $nuh
	}
}


proc ::dasbrain::channels::JOIN {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set sid [::hexchat::prefs id]
	set chan [lindex $line 2]
	set from [lindex $line 0]
	set userrec [dict create prefix [dict create] flags [dict create H {}] jointime [clock seconds]]
	set bangidx [string first ! $from]
	if {$bangidx != -1} {
		set nick [string range $from 0 $bangidx-1]
		dict set userrec uhost [string range $from $bangidx+1 end]
	} else {
		set nick $from
	}
	dict set userrec nick $nick
	if {[llength $line] >= 5} {
		# extended join
		dict set userrec account [lindex $line 3]
		dict set userrec realname [lindex $line 4]
	} else {
		set acchost [cnopt get account-host]
		if {$acchost ne {} && [regexp $acchost [dict get $userrec uhost] - account]} {
			dict set userrec account $account
		}
	}
	variable channels
	dict for {k v} $userrec {
		dict set channels $sid $chan users $nick $k $v
	}
	emit-join $chan $userrec
	if {[llength $line] >= 5 && ![dict exists $channels $sid $chan users $nick djoin-done]} {
		emit-djoin $chan $userrec
		dict set channels $sid $chan users $nick djoin-done 1
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::remuser {chan nick how reason src} {
	variable channels
	# TODO: add a hook
	if {[::hexchat::nickcmp $nick [::hexchat::getinfo nick]] == 0} {
		# We leave.
		dict unset channels [::hexchat::prefs id] $chan
	} else {
		dict unset channels [::hexchat::prefs id] $chan users $nick
	}
}

proc ::dasbrain::channels::PART {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set nick [nuh2nick [lindex $line 0]]
	remuser [lindex $line 2] $nick PART [lindex $line 3] [lindex $line 0]
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::QUIT {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set nick [nuh2nick [lindex $line 0]]
	variable channels
	dict for {chan info} [dict get $channels [::hexchat::prefs id]] {
		if {[dict exists $info users $nick]} {
			remuser $chan $nick QUIT [lindex $line 2] [lindex $line 0]
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::KICK {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set reason {}
	lassign $line src - chan target reason
	remuser $chan $target KICK $reason $src
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::NICK {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set nick [nuh2nick [lindex $line 0]]
	set newnick [lindex $line 2]
	variable channels
	set sid [::hexchat::prefs id]
	dict for {chan info} [dict get $channels $sid] {
		if {[dict exists $info users $nick]} {
			dict set channels $sid $chan users $newnick [dict get $info users $nick]
			dict unset channels $sid $chan users $nick
			dict set channels $sid $chan users $newnick nick $newnick
		}
	}
	return $::hexchat::EAT_NONE
}

#<< WHO #eggdrop %chtsunfra,152
#>> :adrift.sg.quakenet.org 354 DasBrain 152 #eggdrop TheQBot CServe.quakenet.org *.quakenet.org Q H*@d Q :The Q Bot
proc ::dasbrain::channels::354 {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	switch -exact -- [lindex $line 3] {
		152 {
			# Hexchat query
			lassign $line - - - - chan user host server nick flags account realname
			variable channels
			set sid [::hexchat::prefs id]
			if {$account eq {0}} {
				set account *
			}
			dict set channels $sid $chan users $nick uhost ${user}@${host}
			dict set channels $sid $chan users $nick realname $realname
			dict set channels $sid $chan users $nick account $account
			dict set channels $sid $chan users $nick server $server
			dict set channels $sid $chan users $nick nick $nick
			set nflags [dict create]
			foreach c [split $flags {}] {
				dict set nflags $c 1
				if {$c eq {+}} {
					# Special case + (voice), as quakenet/undernet doesn't have multi-prefix.
					dict set $sid $chan users $nick prefix + 1
				}
			}
			dict set channels $sid $chan users $nick flags $nflags
			if {![dict exists $channels $sid $chan users $nick djoin-done]} {
				emit-djoin $chan [dict get $channels $sid $chan users $nick]
				dict set $sid $chan users $nick djoin-done 1
			}
			return $::hexchat::EAT_NONE
		}
	}
	return $::hexchat::EAT_NONE
}

#<< WHO #YATC
#>> :irc.lim.de.euirc.net 352 DasBrain #YATC ~DasBrain DasBrain.euirc.net irc.lim.de.euirc.net DasBrain H@ :0 DasBrain
proc ::dasbrain::channels::352 {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	lassign $line - - - chan user host server nick flags realname
	# Realname contains hops. Who (pun not intendet) got that idea?
	set rnspace [string first { } $realname]
	if {$rnspace != -1 && [string is integer -strict [string range $realname 0 $rnspace-1]]} {
		set realname [string range $realname $rnspace+1 end]
	}
	variable channels
	set sid [::hexchat::prefs id]
	dict set channels $sid $chan users $nick uhost ${user}@${host}
	dict set channels $sid $chan users $nick realname $realname
	dict set channels $sid $chan users $nick server $server
	dict set channels $sid $chan users $nick nick $nick
	set nflags [dict create]
	foreach c [split $flags {}] {
		dict set nflags $c 1
		if {$c eq {+}} {
			# Special case + (voice), as quakenet/undernet doesn't have multi-prefix.
			dict set $sid $chan users $nick prefix + 1
		}
	}
	dict set channels $sid $chan users $nick flags $nflags
	if {![dict exists $channels $sid $chan users $nick djoin-done]} {
		emit-djoin $chan [dict get $channels $sid $chan users $nick]
		dict set $sid $chan users $nick djoin-done 1
	}
	return $::hexchat::EAT_NONE
}

#>> :tungsten.libera.chat 353 DasBrain = ###test :DasBrain karthik BOFH @ChanServ
proc ::dasbrain::channels::353 {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	lassign $line - - - - chan users
	variable channels
	set sid [::hexchat::prefs id]
	set prefixes [isupport get PREFIX]
	set prefixes [split [string range $prefixes [string first ) $prefixes]+1 end] {}]
	foreach u [split $users] {
		set userrec [dict create]
		set bangidx [string first ! $u]
		if {$bangidx != -1} {
			# we have userhost-in-names
			dict set userrec uhost [string range $u $bangidx+1 end]
			set u [string range $u 0 $bangidx-1]
		}
		while {[string index $u 0] in $prefixes} {
			dict set userrec prefix [string index $u 0] 1
			set u [string range $u 1 end]
		}
		dict set userrec nick $u
		dict for {k v} $userrec {
			dict set channels $sid $chan users $u $k $v
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::ACCOUNT {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	lassign line from - account
	set nick [nuh2nick $from]
	variable channels
	set sid [::hexchat::prefs id]
	dict for {chan info} [dict get $channels $sid] {
		if {[dict exists $info users $nick]} {
			dict set channels $sid $chan users $nick account $account
			emit-userchg $chan [dict get $channels $sid $chan users $nick]
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::AWAY {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	if {[llength $line] == 2} {
		set away 0
	} else {
		set away 1
		set away-reason [lindex $line 2]
	}
	set nick [nuh2nick [lindex $line 0]]
	variable channels
	set sid [::hexchat::prefs id]
	dict for {chan info} [dict get $channels $sid] {
		if {[dict exists $info users $nick]} {
			if {$away} {
				dict unset channels $sid $chan users $nick flags H
				dict set channels $sid $chan users $nick flags G 1
				dict set channels $sid $chan users $nick away-reason ${away-reason}
			} else {
				dict unset channels $sid $chan users $nick flags G
				dict set channels $sid $chan users $nick flags H 1
				dict unset channels $sid $chan users $nick away-reason
			}
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::CHGHOST {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	lassign line from - user host
	set nick [nuh2nick $from]
	set newuhost ${user}@${host}
	variable channels
	set sid [::hexchat::prefs id]
	dict for {chan info} [dict get $channels $sid] {
		if {[dict exists $info users $nick]} {
			dict set channels $sid $chan users $nick uhost $newuhost
			emit-userchg $chan [dict get $channels $sid $chan users $nick]
		}
	}
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::Disconnected {word} {
	variable channels
	dict unset channels [::hexchat::prefs id]
	return ::hexchat::EAT_NONE
}

#>> :tulip.eu.ix.undernet.org 324 DasBrain #computertech +mtnRl 33
proc ::dasbrain::channels::324 {word word_eol} {
	set line [ircsplit [lindex $word_eol 1]]
	set args [lassign $line - - - chan mode]
	set chanmodes [split [isupport get CHANMODES] ,]
	foreach cms $chanmodes type {A B C D} {
		set $type [split $cms {}]
	}
	set pm +
	set chanmodes [dict create]
	foreach mc [split $mode {}] {
		if {$mc in {+ -}} {
			set pm $mc
		} elseif {$mc in $A} {
			::hexchat::print "channels\tWarning: List-Mode $mc in 324 nummeric, ignoring"
		} elseif {$mc in $B || $mc in $C} {
			set args [lassign $args param]
			dict set chanmodes $mc $param
		} elseif {$mc in $D} {
			dict set chanmodes $mc 1
		} else {
			::hexchat::print "channels\tWarning: Unknown mode $mc in 324 nummeric, assuming no parameter"
			dict set chanmodes $mc 1
		}
	}
	if {[llength $args] > 0} {
		::hexchat::print "channels\tWarning: Non-consumed arguments [list $args] in 324 nummeric, ignoring"
	}
	variable channels
	dict set channels [::hexchat::prefs id] $chan mode $chanmodes
	return $::hexchat::EAT_NONE
}

proc ::dasbrain::channels::mode-change {from chan mode arg} {
	set chanmodes [split [isupport get CHANMODES] ,]
	foreach cms $chanmodes type {A B C D} {
		set $type [split $cms {}]
	}
	set prefixmodes [isupport get PREFIX]
	set prefixpos [string first ) $prefixmodes]
	set prefixchars [split [string range $prefixmodes $prefixpos+1 end] {}]
	set prefixmodes [split [string range $prefixmodes 1 $prefixpos-1] {}]
	
	set pm [string index $mode 0]
	set mc [string index $mode 1]
	variable channels
	if {$mc in $A} {
		# Ignore
	} elseif {$mc in $B || $mc in $C} {
		if {$pm eq {+}} {
			dict set channels [::hexchat::prefs id] $chan mode $mc $arg
		} else {
			dict unset channels [::hexchat::prefs id] $chan mode $mc
		}
	} elseif {$mc in $prefixmodes} {
		set pc [lindex $prefixchars [lsearch $prefixmodes $mc]]
		if {$pm eq {+}} {
			dict set channels [::hexchat::prefs id] $chan users $arg prefix $pc 1
		} else {
			dict unset channels [::hexchat::prefs id] $chan users $arg prefix $pc
		}
	} else {
		# If not in type D, then modeparse already emitted a warning
		if {$pm eq {+}} {
			dict set channels [::hexchat::prefs id] $chan mode $mc 1
		} else {
			dict unset channels [::hexchat::prefs id] $chan mode $mc
		}
	}
}

apply {{} {
	variable channels

	set cfields [::hexchat::list_fields channels]
	set ctxidx [lsearch $cfields context]
	set chanidx [lsearch $cfields channel]
	set typeidx [lsearch $cfields type]
	set ididx [lsearch $cfields id]
	
	set ufields [::hexchat::list_fields users]
	set accidx [lsearch $ufields account]
	set awayidx [lsearch $ufields away]
	set nickidx [lsearch $ufields nick]
	set uhostidx [lsearch $ufields host]
	set prefixidx [lsearch $ufields prefix]
	set realnameidx [lsearch $ufields realname]
	
	set origctx [::hexchat::getcontext]
	
	foreach chan [::hexchat::getlist channels] {
		if {[lindex $chan $typeidx] == 2 && [lindex $chan $chanidx] ne {}} {
			::hexchat::setcontext [lindex $chan $ctxidx]
			set sid [lindex $chan $ididx]
			set channel [lindex $chan $chanidx]
			::dasbrain::channels::324 {} [list {} ":server.local 324 * $channel [::hexchat::getinfo modes]"]
			foreach u [::hexchat::getlist users] {
				set ur [dict create]
				set nick [lindex $u $nickidx]
				
				dict set ur nick $nick
				dict set ur account [lindex $u $accidx]
				if {[lindex $u $awayidx]} {
					dict set ur flags G 1
				} else {
					dict set ur flags H 1
				}
				dict set ur uhost [lindex $u $uhostidx]
				dict set ur prefix [lindex $u $prefixidx] 1
				dict set ur realname [lindex $u $realnameidx]
				
				dict set channels $sid $channel users $nick $ur
			}
		}
	}
	
	::hexchat::setcontext $origctx
} ::dasbrain::channels}
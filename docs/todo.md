# TODO

## auto-open support
#feature #popup 
- see historical impl

## cleanup for release
#chore
- put logs etc to a reasonable place

## update readme how section 
#chore
- cc fallback missing
- two backends missing
- explain why keys, because works inside REPLs, unlike e.g. fifo

## Serious lag in dev harness
#bug #dev
- maybe expensive reads in dev harness status? does it read from shell via osc maybe?
- or is there some event firing often? some cursormove or textchange?
- or is the cursor being updated from shell?
- whatever it is, it happened in the last few commits
- maybe it was zsh vi mode?

## add support for reading multi-line commands via shell integration
#feature #api #shell-integration
- fish supports natively
- zsh support PREBUFFER
- bash does not seem to support
- this would make reading multi-line commands with completion

## edits with modifiable and non-modifiable should clamp to zone
#feature #integrated #enhancement
- at least if trailing non-mod zone since it actually happens quite often on accident

## sync overlay more often
#feature #enhancement
- can get rid of some jitter

## expose status to users
#feature 

## add log levels
#feature #enhancement
- number based, python scicomp style

## add simple markers to tab complete
#feature #maybe
- not really needed(?) now since we read from zsh shell directly


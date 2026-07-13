# TODO

## 'submit strips PS2 continuation prompt' flaky test
#bug #tests
- failed in full run once, could not reproduce

## symmetric on last line movements
#enhancement #popup
- currently upward movements like k in popup window go to target window
- downward movements do not
- not very useful(?) but intuitive

## open on hover
#feature #popup #overlay
- so when enter editable area, open editor
- makes open on prompt not needed
- makes open passthrough keys not needed(?)
    - should still keep old functionality

## cursor placement should be updated in the target terminal
- e.g. if you spam cr in overlay, the cursor stays in some earlier row in the target

## research if TextChangedT could improve wait_for_command
#enhancement


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

## open on prompt support
#feature #popup 
- see stash

## emit prompt from shell integration
#feature #auto-open #enhancement
- faster than reading from buffer after render
- maybe causes issues if prompt marker comes before the command output has rendered?
- see stash

## expose status to users
#feature 

## add log levels
#feature #enhancement
- number based, python scicomp style

## add simple markers to tab complete
#feature #maybe
- not really needed(?) now since we read from zsh shell directly


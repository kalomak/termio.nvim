# TODO

## Research background C-e C-a for probing the command start and end
#probe #research
- the only issue here really are the cursor jitter
- make absolutely sure there is no way to somehow make this work without it

## Fifo write
#shell-integration
- re-enable fifo write in shell integration for smoother experience
- gets rid of some cursor jitters
- not sure if needed if advanced sync gets implemented

## Command start and end tracking without shell integration
#nointegration

### start
- refactor: use the wait command from minimal-api branch
- basically, after C-u, if the cursor does not go to the command start position, we can assume that the cursor position is now the correct command start position
- mimimal-api branch has this basically implemented
- add config opt to only use this

### end 
- Tracking the command end location is all that is needed for ignoring completions and autosuggestions without shell integration
- C-e achieves this but moves cursor (unless hidden?)

## Advanced sync
### sync more often
#enhancement
- can get rid of some jitter
- shell cursor can be synced without any interruption, even for 'integrated'
- debounce would make the most sense for syncing more often

### hide cursor jitter from all events
- always sync cursor before changing back to terminal mode

### does debounce unsubscribe from debounce when focus somewhere else?

## symmetric on last line movements
#enhancement #popup
- currently upward movements like k in popup window go to target window
- downward movements do not
- not very useful(?) but intuitive

## use nvim softwrapping for integrated 
#integrated
- currently paste in integrated will 'overflow', since wrap is false in terminals due to performance.

## cursor placement should be updated in the target terminal
#enhancement
- e.g. if you spam cr in overlay, the cursor stays in some earlier row in the target

## research if TextChangedT could improve wait_for_command
#enhancement

## edits with modifiable and non-modifiable should clamp to zone
#enhancement #integrated
- at least if trailing non-mod zone since it actually happens quite often on accident

## open on prompt support
#enhancement #popup #nodemand
- this enhancement would open the window after prompt is rendered
- osc 133 AB markers come before actual prompt render so need to watch terminal buffer
    - is this actually already covered? do we have event for prompt rendered already?
- open on focus covers this and more cases

## emit prompt from shell integration
#enhancement #auto-open
- faster than reading from buffer after render
- maybe causes issues if prompt marker comes before the command output has rendered?
- see stash

## expose status to users
#enhancement #nodemand

## get path to shell integration script
#enhancement #nodemand
- this allows users to rsync the shell integration to a remote ssh

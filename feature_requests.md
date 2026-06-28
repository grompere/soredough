# Sore Dough — Feature Requests

_Last updated: June 28, 2026_

## FR-1: Exercise autocomplete when adding to an active workout
When adding a new exercise during a live session, suggest matching names
from existing workout history as the user types. Reduces typos and prevents
the name-fork problem that splits progress timelines (e.g. "RDL" vs
"Romanian Deadlift").

## FR-2: Exercise-level comments / notes
Allow free-text notes on an individual exercise within a session
(e.g. "felt easy", "left shoulder twinge"). Optionally support
session-level notes as well for general logging.

## FR-3: Exercise-level tags
Let users tag individual exercises, not just whole sessions. Currently
exercise tags are copied from the session at completion; this would make
them independently editable for finer-grained progress filtering.

## FR-4: Rep entry via keyboard, not just stepper
The rep field should accept a typed number directly, in addition to the
existing dropdown/stepper. Faster entry for large rep counts.

## FR-5: Pick from existing exercises when pre-baking templates
When building a template ("Pre-Baked" workouts), let users select from
their library of previously-used exercise names instead of retyping,
keeping names consistent across templates and history.

## FR-6: Progress arrows should compare against absolute max, not same-set
The "last time" indicator currently compares set-to-set by position. Change
it to compare against the user's absolute best (max weight / est. 1RM) for
that exercise, so the arrow reflects true progress.

## FR-7: One-tap "update targets to last max"
In a template or active session, a single action that sets each exercise's
target weight/reps to the user's most recent best for that exercise.
Removes manual re-entry of progressive-overload targets.

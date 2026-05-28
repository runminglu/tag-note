# Autosave Notes Design

## Goal

Add autosave while editing notes in the focus editor. Autosave should persist
valid note edits in the background without removing the existing explicit
`Save note` action.

The first version should cover:

- Editing an existing note.
- Creating a new note once the draft has content and at least one tag.
- Guest mode, using the existing guest storage API path.
- Clear save status feedback in the editor header.
- Dirty-close behavior that understands autosaved changes.

## Current System

The note editor lives in `web/app.js` as the focus overlay flow:

- `openFocus(mode, note)` opens the create/edit editor.
- `focusEditor` is an EasyMDE instance created by `createEasyMDE`.
- `focusChips` owns the note tag chip input.
- `focus-submit` currently saves manually with:
  - `POST /api/v1/notes` for create.
  - `PUT /api/v1/notes/:id` for edit.
- `hasFocusChanges()` compares the current editor state to the state captured
  when the editor was opened.
- Guest mode is routed through `api()` into `guestApiHandler`, which already
  supports note create and update.

The backend already supports the required persistence operations:

- `POST /api/v1/notes`
- `PUT /api/v1/notes/:id`

No backend change is required for the first implementation.

## User Experience

Autosave should be quiet and predictable:

- Save after the user stops typing or changing tags for about 1.5 seconds.
- Do not create empty or tagless notes.
- Keep `Save note` as "save now and close".
- Show a compact status in the focus header:
  - `Unsaved`
  - `Saving...`
  - `Saved`
  - `Add content and a tag to autosave`
  - `Save failed`
- After autosave succeeds, closing the editor should not show the discard
  warning for already-saved changes.
- If autosave fails, keep the editor open and preserve the unsaved-change
  warning.

Avoid EasyMDE's built-in `autosave` option. It only writes editor content to
`localStorage`, while TagNote needs server persistence, tag persistence,
create-note behavior, guest-mode routing, and app-specific status handling.

## State Model

Add autosave state near the existing focus globals in `web/app.js`:

```js
let focusAutosaveTimer = null;
let focusAutosaveInFlight = null;
let focusAutosaveQueued = false;
let focusLastSavedContent = '';
let focusLastSavedTags = [];
let focusAutosaveStatus = 'idle';
const FOCUS_AUTOSAVE_DELAY_MS = 1500;
```

`focusLastSavedContent` and `focusLastSavedTags` become the dirty-check
baseline. They should be updated only after a successful save.

## DOM Changes

Add a status element to the focus header in `web/index.html`:

```html
<span id="focus-save-status" class="focus-save-status" aria-live="polite"></span>
```

Place it between the title and header actions so it is visible but secondary.

Add compact styling in `web/style.css`:

```css
.focus-save-status {
    color: var(--text-muted);
    font-size: 0.85rem;
    white-space: nowrap;
}
```

Use existing theme variables. The indicator should not look like a primary
control.

## Frontend Helpers

Add helpers in `web/app.js`:

- `getFocusDraft(options)`
  - Returns `{ content, tags }`.
  - Trims content consistently with the existing save behavior.
  - Does not commit pending tag input during background autosave.
  - Commits pending tag input for explicit save.
- `sameTags(a, b)`
  - Compares tags in their stored order.
- `focusDraftChangedFromLastSave(draft)`
  - Compares the draft to `focusLastSavedContent` and `focusLastSavedTags`.
- `setFocusAutosaveStatus(status, message)`
  - Updates `focusAutosaveStatus` and the header status element.
- `scheduleFocusAutosave()`
  - Debounces background saves.
- `flushFocusAutosave(options)`
  - Performs the actual create/update.
  - Accepts `{ closeAfterSave: boolean, commitPendingTag: boolean }`.
- `resetFocusAutosaveState(note)`
  - Initializes the saved baseline and status when opening the editor.

## Save Algorithm

`scheduleFocusAutosave()`:

1. Clear any existing debounce timer.
2. Read the draft without committing pending tag input.
3. If unchanged from the last saved baseline, set `Saved` and return.
4. If content or tags are missing, set `Add content and a tag to autosave` and
   return.
5. Set `Unsaved`.
6. Start a debounce timer for `FOCUS_AUTOSAVE_DELAY_MS`.

`flushFocusAutosave()`:

1. Read the draft.
2. If unchanged from the saved baseline, optionally close and return.
3. Validate content and tags.
4. If another save is in flight:
   - Set `focusAutosaveQueued = true`.
   - Return the in-flight promise.
5. Set status to `Saving...`.
6. If `focusMode === 'edit'` and `focusEditId` exists:
   - `PUT /notes/:id` with `{ content, tags }`.
7. Otherwise:
   - `POST /notes` with `{ content, tags }`.
   - Store the returned `short_id` or `id` in `focusEditId`.
   - Switch `focusMode` to `edit`.
   - Update the title/button labels from create mode to edit mode.
8. On success:
   - Update `focusLastSavedContent` and `focusLastSavedTags`.
   - Set status to `Saved`.
   - If `closeAfterSave`, close the editor and refresh the feed.
9. On failure:
   - Set status to `Save failed`.
   - Leave the saved baseline unchanged.
   - Keep dirty-close protection active.
10. In `finally`:
   - Clear the in-flight marker.
   - If `focusAutosaveQueued` is true and the editor is still open, run another
     save pass.

## Event Wiring

Wire autosave scheduling from the same inputs users already edit:

- EasyMDE CodeMirror `change` event.
- Fallback textarea `input` event if EasyMDE is unavailable.
- `focusChips` `onChange` callback.

The chip input should keep using its existing behavior. Background autosave
should save committed chips, not partially typed tag text. Explicit save should
commit pending tag text before validation.

## Open And Close Behavior

When opening an existing note:

- Set `focusMode = 'edit'`.
- Set `focusEditId = note.short_id`.
- Set `focusLastSavedContent = note.content.trim()`.
- Set `focusLastSavedTags = note.tags.slice()`.
- Show `Saved`.

When opening a new note:

- Set `focusMode = 'create'`.
- Clear `focusEditId`.
- Clear `focusLastSavedContent` and `focusLastSavedTags`.
- Show an empty status until the user starts editing.

Update `hasFocusChanges()` to compare against the last saved baseline instead
of the initial-open baseline. Autosaved edits should not produce an unsaved
changes warning.

On close:

- If no changes exist beyond the saved baseline, close immediately.
- If an autosave is currently in flight for the current draft, wait for it when
  practical and then close.
- If there are unsaved changes or a failed save, keep the existing discard
  confirmation behavior.

## Explicit Save Button

Refactor the current `focus-submit` click handler so manual save and autosave
share the same persistence path:

1. Commit pending tag input.
2. Validate content and tags.
3. Cancel any pending debounce timer.
4. Call `flushFocusAutosave({ closeAfterSave: true, commitPendingTag: true })`.
5. Keep the existing loading state on the button while the save runs.

This keeps manual save semantics unchanged while avoiding duplicate create and
update code.

## Feed Refresh

Do not call `refresh()` after every background autosave. Refreshing on each
save can reorder cards and create distracting UI movement while the editor is
open.

Refresh the feed only when:

- The user explicitly saves and closes.
- The user closes after a successful autosave.

A later optimization can update `lastNotes` in memory after each autosave, but
that is not required for the first version.

## Failure Handling

Network or API failures should not lose local editor state.

On failure:

- Show `Save failed`.
- Leave `focusLastSavedContent` and `focusLastSavedTags` unchanged.
- Keep the close confirmation active.
- Retry only after the next user edit or explicit save.

The existing `api()` behavior already handles `401` by clearing auth and showing
the auth view.

## Backend And Concurrency

The first version can use the current last-write-wins API behavior.

Future improvement:

- Add optimistic concurrency with `updated_at`, an integer revision, or an
  entity tag.
- Return a conflict response when another tab or device saved a newer version.
- Show a merge/reload prompt in the editor.

That is intentionally out of scope for the first implementation.

## Test Plan

Add Playwright coverage for the browser behavior:

- Creating a note autosaves after content and at least one tag are entered.
- Closing after a successful autosave does not show a discard warning.
- Editing an existing note autosaves changed content without clicking
  `Save note`.
- A failed autosave keeps the unsaved-change warning active.
- Guest mode autosaves through local storage.
- Manual `Save note` still saves immediately and closes the editor.

Backend tests are not required for the first version because the feature uses
existing note create and update endpoints.

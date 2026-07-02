---
name: form-js-schema
description: >
  Use when the user asks to create, generate, or edit a form-js (bpmn-io
  @bpmn-io/form-js) form schema — e.g. "create me a login form", "make a
  create and edit form for the <resource> resource", "add validation to this
  form-js schema". Produces a valid form-js JSON schema (type: "default",
  schemaVersion 19) that the @bpmn-io/form-js-viewer can import and render.
  Do NOT use for HTML <form> markup, React form libraries, or JSON Schema
  (draft-07) validation documents — those are different things.
---

# Authoring form-js schemas

A form-js form is a single JSON object. Everything below is taken from
`@bpmn-io/form-js` v1.21.3 (`packages/form-json-schema`).

## 1. The form envelope

`type` and `components` are the only **required** top-level keys.

```json
{
  "type": "default",
  "schemaVersion": 19,
  "id": "Form_login",
  "components": []
}
```

- `type` is always the literal string `"default"`.
- `schemaVersion` is an integer 1–19. The current library stamps **19**. Always emit 19.
- `id` is optional, a free string.
- `components` is the ordered array of fields.

You render it like this (for context — don't generate this unless asked):

```js
import { Form } from '@bpmn-io/form-js-viewer';

const form = new Form({ container: document.querySelector('#form') });
await form.importSchema(schema, initialData);
form.on('submit', (e) => console.log(e.data, e.errors));
```

`importSchema(schema, data)` is how an **edit form** gets prefilled — the
second argument is a data object keyed by each field's `key`.

## 2. Field types

Every field is an object with a `type`. There are two classes, and the class
decides which properties are legal.

**Input fields** — hold a value, **require a `key`**, and may have
`label`, `description`, `defaultValue`, `validate`, `disabled`, `readonly`:

| type | notes |
|---|---|
| `textfield` | single-line text |
| `textarea` | multi-line text |
| `number` | numeric |
| `checkbox` | single boolean |
| `datetime` | date / time / datetime (see `subtype`) |
| `radio` | pick one from `values` |
| `select` | dropdown, pick one from `values` |
| `checklist` | pick many from `values` |
| `taglist` | pick many from `values`, tag UI |
| `filepicker` | file upload |
| `expression` | computed, not user-editable (see §7) |

**Non-input fields** — **must NOT have a `key`**:

| type | purpose | key extra props |
|---|---|---|
| `text` | static text / markdown | `text` |
| `html` | raw HTML | `content` |
| `image` | image | `source`, `alt` |
| `button` | submit/reset | `action` |
| `spacer` | vertical gap | `height` |
| `separator` | horizontal rule | — |
| `iframe` | embed | `url`, `height` |
| `group` | static container | `components`, `path`, `showOutline`, `verticalAlignment` |
| `dynamiclist` | repeating container | `components`, `path`, `isRepeating`, `defaultRepetitions`, `allowAddRemove` |
| `table` | data table | `dataSource` + (`columns` or `columnsExpression`), `rowCount` |
| `documentPreview` | document viewer | `dataSource` |

### `key` rules (inputs only)

The `key` binds the field to a data variable. It must match
`^\w+(\.\w+)*$` — word chars, optionally dot-separated for nesting:

```json
{ "type": "textfield", "key": "email", "label": "Email" }
{ "type": "textfield", "key": "address.city", "label": "City" }
```

A `button` is **not** an input — give it `action`, never `key`:

```json
{ "type": "button", "label": "Sign in", "action": "submit" }
{ "type": "button", "label": "Reset", "action": "reset" }
```

## 3. Validation

`validate` is only allowed on input fields. Which sub-keys are legal depends
on the field type — putting the wrong one on the wrong type makes the schema
invalid.

| validate key | allowed on |
|---|---|
| `required` (bool) | any input |
| `minLength`, `maxLength` (int) | `textfield`, `textarea` |
| `min`, `max` (number) | `number` |
| `validationType` (`"email"`/`"phone"`/`"custom"`) | `textfield` |
| `pattern` (regex string), `patternErrorMessage` | `textfield` |

```json
{
  "type": "textfield",
  "key": "email",
  "label": "Email",
  "validate": { "required": true, "validationType": "email" }
}
```

```json
{
  "type": "textfield",
  "key": "invoiceNumber",
  "label": "Invoice Number",
  "description": "Format: C-123",
  "validate": { "pattern": "^C-[0-9]+$", "patternErrorMessage": "Use the form C-123" }
}
```

```json
{ "type": "number", "key": "qty", "label": "Quantity", "validate": { "required": true, "min": 1, "max": 99 } }
```

## 4. Options (radio / select / checklist / taglist)

Static options go in `values` (array of `{ label, value }`):

```json
{
  "type": "select",
  "key": "country",
  "label": "Country",
  "searchable": true,
  "values": [
    { "label": "United Kingdom", "value": "gb" },
    { "label": "Germany", "value": "de" }
  ]
}
```

`searchable` is **select-only**. For dynamic options instead of `values`, use
`valuesExpression` (a FEEL expression resolving to a list) or `valuesKey` (an
input-data key). Use exactly one of `values` / `valuesExpression` / `valuesKey`.

```json
{ "type": "radio", "key": "ship", "label": "Ship", "valuesExpression": "=ships" }
```

## 5. Layout — putting fields side by side

By default each field is its own row. To place fields on the same row, give
them the same `layout.row` string. `columns` is the width, an integer **2–16**;
a row totals 16. Two `columns: 8` fields fill one row.

```json
{
  "type": "default",
  "schemaVersion": 19,
  "components": [
    { "type": "textfield", "key": "firstName", "label": "First name", "layout": { "row": "row1", "columns": 8 } },
    { "type": "textfield", "key": "lastName",  "label": "Last name",  "layout": { "row": "row1", "columns": 8 } }
  ]
}
```

Omit `columns` to let a field auto-size to the remaining space.

## 6. Conditional visibility

`conditional.hide` takes a **FEEL expression** (prefixed `=`) — when it
evaluates truthy the field is hidden and its value is cleared.

```json
{
  "type": "textfield",
  "key": "otherReason",
  "label": "Please specify",
  "conditional": { "hide": "=reason != \"other\"" }
}
```

`readonly` and `disabled` accept either a boolean or a FEEL expression:

```json
{ "type": "textfield", "key": "total", "label": "Total", "readonly": "=role = \"viewer\"" }
```

## 7. FEEL expressions & computed fields

Anywhere a value can be dynamic (`conditional.hide`, `readonly`, `disabled`,
`valuesExpression`, `expression`), the string starts with `=` and the rest is
FEEL. Bare field keys reference other fields' current values.

The `expression` field is read-only and computed; it requires `expression` and
`computeOn` (`"change"`, `"load"`, or `"presubmit"`):

```json
{ "type": "expression", "key": "fullName", "expression": "=firstName + \" \" + lastName", "computeOn": "change" }
```

## 8. Cosmetic touches

- `text` field content is plain text, markdown, or templating (`{{ }}`):
  `{ "type": "text", "text": "## Sign in\nUse your work email." }`
- `appearance.prefixAdorner` / `appearance.suffixAdorner` — **textfield and
  number only** — render a fixed affix:
  `{ "type": "number", "key": "price", "label": "Price", "appearance": { "prefixAdorner": "£" } }`
- `spacer` takes `height` (number); `separator` takes nothing.

---

## Worked example A — login form

"create me a login form":

```json
{
  "type": "default",
  "schemaVersion": 19,
  "id": "Form_login",
  "components": [
    { "type": "text", "text": "## Sign in" },
    {
      "type": "textfield",
      "key": "email",
      "label": "Email",
      "validate": { "required": true, "validationType": "email" }
    },
    {
      "type": "textfield",
      "key": "password",
      "label": "Password",
      "validate": { "required": true, "minLength": 8 }
    },
    { "type": "checkbox", "key": "rememberMe", "label": "Remember me" },
    { "type": "button", "label": "Sign in", "action": "submit" }
  ]
}
```

Note: form-js has no native password-masking field type — a password is a
`textfield`. If masking matters, say so to the user rather than inventing a
property the schema doesn't support.

---

## Worked example B — create vs edit forms for a resource

"make a create and an edit form for the `product` resource".

Build the field list once, then produce two variants. They share fields; the
differences are:

- **Edit** carries the record's `id` (often a `readonly` field or just supplied
  via `importSchema(schema, data)`), and is rendered prefilled.
- **Create** starts empty and may use `defaultValue` for sensible defaults.

**Create — `Form_product_create`:**

```json
{
  "type": "default",
  "schemaVersion": 19,
  "id": "Form_product_create",
  "components": [
    { "type": "text", "text": "## New product" },
    { "type": "textfield", "key": "name", "label": "Name", "validate": { "required": true, "maxLength": 120 },
      "layout": { "row": "r1", "columns": 10 } },
    { "type": "textfield", "key": "sku", "label": "SKU", "validate": { "required": true, "pattern": "^[A-Z0-9-]+$" },
      "layout": { "row": "r1", "columns": 6 } },
    { "type": "number", "key": "price", "label": "Price", "validate": { "required": true, "min": 0 },
      "appearance": { "prefixAdorner": "£" }, "layout": { "row": "r2", "columns": 8 } },
    { "type": "number", "key": "stock", "label": "Stock", "defaultValue": 0, "validate": { "min": 0 },
      "layout": { "row": "r2", "columns": 8 } },
    { "type": "select", "key": "category", "label": "Category", "validate": { "required": true },
      "values": [
        { "label": "Hardware", "value": "hardware" },
        { "label": "Software", "value": "software" }
      ] },
    { "type": "checkbox", "key": "active", "label": "Active", "defaultValue": true },
    { "type": "textarea", "key": "description", "label": "Description", "validate": { "maxLength": 2000 } },
    { "type": "button", "label": "Create", "action": "submit" }
  ]
}
```

**Edit — `Form_product_edit`:** same fields, plus a readonly `id`, button
relabelled. Prefill at render time with `importSchema(schema, productRecord)`.

```json
{
  "type": "default",
  "schemaVersion": 19,
  "id": "Form_product_edit",
  "components": [
    { "type": "text", "text": "## Edit product" },
    { "type": "textfield", "key": "id", "label": "ID", "readonly": true },
    { "type": "textfield", "key": "name", "label": "Name", "validate": { "required": true, "maxLength": 120 },
      "layout": { "row": "r1", "columns": 10 } },
    { "type": "textfield", "key": "sku", "label": "SKU", "validate": { "required": true, "pattern": "^[A-Z0-9-]+$" },
      "layout": { "row": "r1", "columns": 6 } },
    { "type": "number", "key": "price", "label": "Price", "validate": { "required": true, "min": 0 },
      "appearance": { "prefixAdorner": "£" }, "layout": { "row": "r2", "columns": 8 } },
    { "type": "number", "key": "stock", "label": "Stock", "validate": { "min": 0 },
      "layout": { "row": "r2", "columns": 8 } },
    { "type": "select", "key": "category", "label": "Category", "validate": { "required": true },
      "values": [
        { "label": "Hardware", "value": "hardware" },
        { "label": "Software", "value": "software" }
      ] },
    { "type": "checkbox", "key": "active", "label": "Active" },
    { "type": "textarea", "key": "description", "label": "Description", "validate": { "maxLength": 2000 } },
    { "type": "button", "label": "Save", "action": "submit" }
  ]
}
```

When you don't know a resource's real fields, ask for them or infer a minimal
plausible set and say which you assumed — don't fabricate columns.

---

## Validity checklist before returning a schema

1. Top level has `"type": "default"` and a `components` array.
2. Every **input** field has a `key`; no non-input field (button, text, image,
   spacer, separator, html, group, dynamiclist) has a `key`.
3. Each `key` matches `^\w+(\.\w+)*$` and keys are unique within a data scope.
4. `validate` sub-keys match the field type (table in §3).
5. `values`/`valuesExpression`/`valuesKey` only on radio/select/checklist/taglist,
   and only one of the three is present.
6. `searchable` only on select; `min`/`max` only on number; `appearance`
   adorners only on textfield/number; `action` only on button.
7. FEEL strings (`conditional.hide`, expressions, dynamic `readonly`/`disabled`)
   start with `=`.
8. `layout.columns` is 2–16; same-row fields share `layout.row`.

---

## Verify the schema by running the validator

The checklist above is a manual self-check. To actually confirm a schema is
valid, run it through the `form-js-validator` CLI, which checks the form against
the official form-js JSON Schema (`@bpmn-io/form-json-schema`) via Ajv. It runs
straight from the repo — no install, no clone:

```bash
npx -y github:n-at-han-k/form-js-validator path/to/form.json
# validate several at once
npx -y github:n-at-han-k/form-js-validator forms/*.json
```

Write the generated schema to a `.json` file first, then point the command at
it. Valid output:

```
✓ login.json — valid form-js schema
```

Invalid output names the exact offending path and reason, e.g. a button that
wrongly carries a `key`:

```
✗ bad.json — 1 error
    • components.0.key — property is not allowed on this field type
```

Exit code is `0` when every file is valid, `1` if any form is invalid, `2` on
usage error — so it can gate a script or CI step:

```bash
npx -y github:n-at-han-k/form-js-validator form.json && echo "ok, safe to import"
```

If you'd rather validate in-process instead of shelling out, install it as a
dependency and call the API:

```bash
npm install github:n-at-han-k/form-js-validator
```

```js
const { validateForm } = require('form-js-validator');

const { valid, errors } = validateForm(generatedSchema);
if (!valid) {
  console.error(errors); // readable strings; regenerate or fix, then re-check
}
```

Treat a failing validation as a signal to fix the schema and re-run — don't hand
back a form that doesn't pass.

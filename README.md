# Catalyst v0.17 Type Regression: `map(object({...}))` in Bundle Inputs

Minimal reproduction for two related type-system regressions introduced in
Catalyst **v0.17.0-beta13** that were not flagged as breaking changes in the
release notes.

Both inputs are in `bundles/demo/bundle.tm.hcl`.

---

## Reproduction

**Requirements:** Catalyst v0.17.0-beta13

```bash
git clone https://github.com/SumerSports/catalyst-v017-regression
cd catalyst-v017-regression
catalyst scaffold
```

Select `demo` from the bundle menu. The error fires when Catalyst loads the bundle.

---

## Errors

### Error 1 — `map(object)` type is not parsed correctly

**Input:** `account_map` in `bundles/demo/bundle.tm.hcl`

```hcl
input "account_map" {
  type = map(object({
    account_id     = string
    name           = string
    region         = optional(string)
    clusters = map(object({
      oidc_provider = string
      region        = string
    }))
  }))
  default = {
    dev = {
      account_id = "123456789012"
      name       = "development"
      region     = "us-east-1"
      clusters = {
        my-cluster = {
          oidc_provider = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
          region        = "us-east-1"
        }
      }
    }
  }
}
```

This type expression is valid HCL and was accepted by v0.16.0-beta12. Under
v0.17.0-beta13 the new type parser does not handle `map(object({...}))` with
`optional()` attribute modifiers or nested `map(object)` values. The default
value is structurally correct — the error is in parsing the type expression itself.

### Error 2 — Default value validated strictly against type; produces malformed error message

**Input:** `providers` in `bundles/demo/bundle.tm.hcl`

```hcl
input "providers" {
  type    = map(string)
  default = {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**Actual error output captured from our codebase:**

```
* .terramate/bundles/a9a02a72a3840d2bd1f29194f9d304f5/_tmgen-data-providers.tm.hcl:5,15-16,6:
providers: failed to validate input type: map value error: %!w(MISSING): expected string, got object
```

Two issues here:

1. **Behavioral regression**: v0.16.0-beta12 accepted a `map(string)` type with a
   complex object default without error. v0.17.0-beta13 now validates the default
   strictly against the declared type, which is arguably correct behavior — but it
   was not flagged as a breaking change.

2. **Malformed error message**: `%!w(MISSING)` is a Go format string artifact. A
   `%w` verb was used in a `fmt.Errorf` call with no corresponding error argument,
   so Go emits `%!w(MISSING)` literally. The error message is missing the underlying
   cause.

---

## What Changed in v0.17.0-beta13

From the [release notes](https://github.com/terramate-io/terramate-catalyst/releases/tag/v0.17.0-beta13):

```
## Changed
* (BREAKING) The `allowed_values` attribute ... renamed to `options`.

## Added
* New type system to specify type constraints for inputs in bundles and components.
  It extends the types known from Terraform with support for reusable object schemas.
```

The `allowed_values` rename was correctly flagged as `(BREAKING)`. The new type
system was listed only under `Added`. The type system changes caused both errors
above without any documented migration path.

---

## Impact

In our codebase (`SumerSports/terramate-bundles`), upgrading from v0.16.0-beta12 to
v0.17.0-beta13 required:

- Replacing all `map(object({...}))` component inputs with `type = any` (loss of
  type safety)
- Replacing incorrectly typed `map(string)` inputs that had object defaults with
  `map(schemas.X)` using the new schema system
- Fixing all `allowed_values` → `options` renames across 10+ bundle and object files

None of the type-related changes were called out as breaking in the release notes.

Relevant PRs:
- [PR #56](https://github.com/SumerSports/terramate-bundles/pull/56) — `allowed_values` → `options` (explicitly quoted the `(BREAKING)` note)
- [PR #72](https://github.com/SumerSports/terramate-bundles/pull/72) — complex type workarounds for v0.17 compat

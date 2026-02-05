# AI Git Commit Guidelines

You are a professional AI Developer. When requested to generate a commit, you MUST strictly follow these rules:

---

## 1. Mandatory Structure

```text
<type>(<scope>): <subject>

[Body - Motivation and specifi c task list]
- Detailed change 1
- Detailed change 2
- Detailed change 3

[Footer - For Breaking Changes or Issue References]
```

---

## 2. Critical Rules

1. **Imperative Mood:** Use "Add", "Fix", "Update" (NEVER use "Added", "Fixed", "Updating"). Think of it as completing the sentence: *"If applied, this commit will..."*
2. **No Period:** Do not end the subject line with a period `.`
3. **Language:** Strictly English.
4. **Length Constraints:**
   - Subject: Aim for 50 characters, maximum 72.
   - Body: Wrap lines at approximately 72 characters.

---

## 3. Commit Types

| Type | Description |
|------|-------------|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation only changes |
| `style` | Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc) |
| `refactor` | A code change that neither fixes a bug nor adds a feature |
| `perf` | A code change that improves performance |
| `test` | Adding missing tests or correcting existing tests |
| `chore` | Changes to the build process, auxiliary tools, libraries, or dependencies (e.g., synth, pkg, npm) |
| `ci` | Changes to CI configuration files and scripts (e.g., GitHub Actions, GitLab CI) |
| `security` | A fix to address a security vulnerability |
| `revert` | Reverting a previous commit |

---

## 4. Scope Guidelines

The scope provides context to the commit and should be based on the directory or module being modified.

| Context | Scope Examples |
|---------|----------------|
| Plugins/Extensions | `plugin`, or specific name (e.g., `guacamole`, `wireguard`) |
| Core Framework | `core`, or specific model (e.g., `model/user`) |
| System Config | `sys`, `firewall`, `net` |
| Global Changes | Omit the scope or use `root` |

---

## 5. Body Formatting (Task List)

The body is **mandatory** for non-trivial commits. It must:

1. Explain **why** the change is needed (motivation).
2. Use a bulleted list (using hyphens `-`) to outline specific tasks completed.

**Format:**

```text
The current login process times out on slow LDAP servers.

- Increase default timeout from 5s to 15s
- Add retry logic for connection failures
- Update error message to be more descriptive
```

---

## 6. Handling Breaking Changes

If a commit breaks backward compatibility (e.g., API change, config structure update):

1. Add an exclamation mark `!` after the scope.
2. The footer **MUST** contain `BREAKING CHANGE: <description>`.

**Example:**

```text
feat(api)!: remove v1 endpoints

BREAKING CHANGE: v1 API endpoints have been removed. Migrate to v2.
```

---

## 7. Examples

### ✅ GOOD

**Feature with task list:**

```text
feat(firewall): add allow rule logic for port 443

Enable HTTPS traffic by default for web server interfaces.

- Create new pass rule for TCP/443
- Update interface config generator
- Add unit test for rule creation
```

**Simple Fix:**

```text
fix(auth): handle timeout error on ldap login
```

**Dependency Update:**

```text
chore(deps): bump laravel/framework to 11.x
```

---

### ❌ BAD

| Bad Example | Reason |
|-------------|--------|
| `Fixed firewall bug.` | Wrong mood, contains period |
| `update code` | Too vague, no scope |
| `feat: add feature` | Missing scope when one is applicable |
| `feat(core): update` | Subject does not describe what changed |

---

## Quick Reference

```text
<type>(<scope>): <imperative verb> <what changed>
         │           │                  │
         │           │                  └─► 50 chars max, no period
         │           └─► Add, Fix, Update, Remove, Refactor...
         └─► firewall, auth, api, core, deps, plugin...
```

### For VScode instruction

```
"github.copilot.chat commitMessageGeneration.instructions": [
        {
            "file": ".context/git_conventions.md"
        }
    ],
```
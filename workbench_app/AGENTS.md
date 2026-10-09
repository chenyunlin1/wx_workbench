# Repository Guidelines

## Online HarmonyOS Skill Routing

Use the entire `HarmonyOS_Skills/harmonyos-agent-skills` repository as the online skill catalog for this project, including nested skills and future additions. Select skills for the actual task; a small fixed list of local skill names must not limit discovery.

Sources:

- Repository: https://gitcode.com/HarmonyOS_Skills/harmonyos-agent-skills
- Current index: https://raw.gitcode.com/HarmonyOS_Skills/harmonyos-agent-skills/raw/main/README.md
- Root directory API: https://api.gitcode.com/api/v5/repos/HarmonyOS_Skills/harmonyos-agent-skills/git/trees/main?recursive=0&per_page=100&page=1
- Raw document base: https://raw.gitcode.com/HarmonyOS_Skills/harmonyos-agent-skills/raw/main/

For each new HarmonyOS development, investigation, review, or verification task:

1. Fetch the current index and root directory metadata in memory. Match the request against all relevant areas: design, ArkTS/ArkUI, SDK capabilities, architecture, stability, performance, testing, device tools, and release workflows. Follow new categories found upstream as well. Reuse fetched content within the same task and refresh discovery when its scope changes.
2. Browse relevant directories through the tree API. For each entry with `type: tree`, request `/git/trees/{entry.sha}?recursive=0&per_page=100&page=N`; preserve the parent path because child `path` values are relative to that tree. Read pages until a page contains fewer than 100 entries. The API's default page contains only 20 entries, and a `path=` query does not select a subtree. Do not mistake either result for the whole catalog.
3. Discover actual `SKILL.md` files, including skills nested under another skill's references or SDK collection. The README is a navigation aid; use the live directory tree when a skill is missing from it or a listed link returns 404. A request for a full catalog requires traversing every directory and page; ordinary work only requires traversing the branches relevant to that task.
4. Fetch the selected `SKILL.md` from the raw document base plus its repository-relative path. Read its description and instructions, then fetch the relevant referenced documents, indexes, examples, or dependent skills. Resolve relative URLs against the document that contains them. Read enough dependencies to use the skill correctly, without downloading the entire repository.
5. Apply the project constraints below: HarmonyOS 6.0+ / minimum API 20, target API 26, ArkUI V2, phone (including foldables), tablet and 2in1 targets, existing architecture. Check API-version annotations against the installed SDK; APIs introduced after 20 require a version guard and a working fallback. An upstream sample or general workflow does not authorize adding unrelated features, changing project conventions, or repeating approvals already given by the user.
6. Match upstream tool names to available operations, including `check_ets_files` / `arkts_check`, `build_project`, `init_project_path`, `start_app`, and UI/log tools. Inspect the actual tool schema; a different MCP server prefix does not require another server installation. Diagnose and report any genuinely missing executable or dependency.
7. Briefly identify the selected online skills and cite the URLs actually read when explaining technical decisions. Distinguish a guide being available from its workflow having been executed or validated.

Use an available web reader, `Invoke-WebRequest`, or `Invoke-RestMethod` with a finite timeout. Parse directory responses as JSON and retrieve reference text in memory. Do not clone, reinstall, cache, or back up the online knowledge catalog into project or user skill directories. If a task genuinely needs an upstream executable/template, inspect it and materialize only the necessary files in a task-specific temporary location; remove temporary downloads after use while retaining intended project outputs. Local SDKs, compilers, and project-owned test tools remain execution dependencies.

If online discovery is unavailable, report the failed source and the resulting coverage limit. Continue using supplied evidence and installed SDK diagnostics where sufficient; do not claim the online catalog was refreshed.

## Build & Run Flow

Prefer the provided MCP tools when the session has them; otherwise use the raw commands below.

1. **`arkts_check`** on changed `.ets` files — catches ArkTS strict-mode violations faster than full build
2. **`build_project`** — incremental build by default; only pass `clean=true` if cache corruption is suspected
3. **`start_app`** — launch on device/emulator; requires prior successful build

Before a release build, verify the selected SDK's `sdk/default/sdk-pkg.json` reports `releaseType: Release`. HarmonyOS Hvigor ignores `hwsdk.dir` in `local.properties`; select the SDK through `DEVECO_SDK_HOME` and use the matching IDE tools. If the MCP build tool is bound to a Beta IDE and cannot select the Release installation, use the Release IDE's Node/Hvigor CLI with `--no-daemon`. Check the produced HAR/HAP/APP metadata rather than treating build success as proof of the SDK channel.

Raw commands:

- `ohpm install` — install HarmonyOS deps from `oh-package.json5`
- `hvigorw assembleHap --mode module -p product=default` — debug HAP
- `hvigorw assembleHap --mode module -p product=release` — release HAP
- `hvigorw clean` — remove build artifacts

## ArkTS Strict-Mode Constraints

ArkTS is **not** TypeScript. These rules trip up agents most often:

- **No `any` or `unknown`** — use explicit types
- **No `as` type assertions** — use explicit class constructors or conversion methods
- **No structural typing** — use explicit `class extends` / `implements`
- **No dynamic property access** (`obj[dynamicKey]`) — use typed accessors
- **Object literals must have explicit type context** — assign to typed variable or pass as typed parameter
- **Use `class` not `interface` for data carriers** — ArkTS requires instantiable types
- Before the first `.ets` edit, use the online routing above to read the applicable ArkTS grammar and ArkUI guidance.

## ArkUI V2 Only

Never mix V1 and V2 decorators:

- **Use**: `@ComponentV2`, `@Local`, `@Param`, `@Event`, `@ObservedV2`, `@Trace`
- **Never use**: `@Component`, `@State`, `@Prop`, `@Link`, `@Provide`, `@Consume`, `@Watch`, `@ObjectLink`

Pages hold `@Local` state + Service singletons. No V1 viewmodel layer exists.

## Critical Coding Rules

- **Loading indicators**: always set `.color(AppColor.Brand)` — never rely on HarmonyOS default brand blue
- **Long lists**: `LazyForEach` + stable keys (e.g. a record id). Never use index as key
- **UI copy**: all copy lives in `entry/src/main/resources/base/element/string.json`; no Chinese literals in `.ets` code
- **Colors**: use `theme/Theme.ets` tokens or `sys.color.*` resources; keep `base` / `dark` color key sets identical
- **Newer APIs**: gate with `PlatformCompat.supports(apiVersion)` and provide a working fallback (floating tabs 23+, immersive material and alternate icons 26+)

## Project Structure

Single HarmonyOS module (`entry/`):

- `entry/src/main/ets/entryability/` — `EntryAbility` (immersive window, preference bootstrap)
- `entry/src/main/ets/pages/` — routed screens (`Index` holds the route table; `MainPage` hosts the four tabs)
- `entry/src/main/ets/components/` — reusable widgets (appearance settings, immersive controls, placeholder tab, menu transition)
- `entry/src/main/ets/service/` — business services (`PreferenceService`, `AppIconService`, `UpdateService`)
- `entry/src/main/ets/model/` — domain state (`AppAppearance` reactive singleton)
- `entry/src/main/ets/theme/` — design tokens (`AppColor`, `AppMaterial`, `AppSpace`, `AppFont`, `AppRadius`, `HomeTheme`)
- `entry/src/main/ets/utils/` — `WindowUtils`, `PlatformCompat`, `AdaptiveLayout`, `HdsCompat`
- `entry/src/main/resources/base|dark/element/` — strings and colors (dual light/dark copies)
- `AppScope/` — app-level config (`app.json5`, alternate icon declarations, icon media)

Generated dirs (never edit, never commit): `build/`, `.hvigor/`, `oh_modules/`, `entry/build/`

## Testing

- No build/test CI exists; never rely on CI to catch errors
- App unit tests (Hypium) live in `entry/src/test/`; device tests in `entry/src/ohosTest/` (both currently not populated by the template)
- After changing tabs / settings / appearance: verify on a real device — tab switching and double-tap-to-top, theme mode / material / accent apply immediately and survive restart, default-tab preference restores on next launch
- After changing the icon theme: verify alternate icon switching on API 26+ and the graceful unsupported state on older systems
- Resizing (foldable/tablet/2in1) must preserve layout and safe-area handling

## Security & Config

- **`build-profile.json5` contains signing secrets** (key passwords, cert paths) and is git-tracked — never commit changes to this file; signing is machine-specific and configured via DevEco Studio. `build-profile.template.json5` is the shareable template; `signing/` is gitignored
- `code-linter.json5` enforces crypto security rules (no unsafe AES/RSA/DSA/DH/3DES) on all `.ets` files
- The App must not gain an implicit runtime dependency on external projects; add new network endpoints or services only with an explicit product decision
- `obfuscation-rules.txt` (root) is applied to release builds; when adding JSON-serialized fields, add `-keep-property-name` entries

## Conventions

- **Commits**: Conventional Commits (`feat:`, `fix:`, `fix(player):`, `feat(server):` …); Chinese or English summaries OK
- **Naming**: `XxxPage`, `XxxService`, `XxxComponent` (PascalCase + suffix); camelCase for fields/methods
- **SDK**: HarmonyOS 6.0+; `targetSdkVersion = 26.0.0`, `compatibleSdkVersion = 6.0.0(20)`. Build with a verified Release SDK; Beta/Canary artifacts must not be published. Use `PlatformCompat` for newer APIs and lazy imports for newer system modules.
- **Device types**: phone (including foldables), tablet and 2in1 (`deviceTypes: ["phone", "tablet", "2in1"]`). Layout follows the actual container/window in vp, not device type or default display size.

## Language

- **回复语言**: 始终使用中文回复用户

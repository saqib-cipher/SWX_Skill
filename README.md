# 🧩 SWX_Skill — Sketchware Project System Reference & AI Skill

[![Sketchware Pro](https://img.shields.io/badge/Sketchware-Pro%20%7C%20DayGreen%20%7C%20DesktopX-00B0FF?style=for-the-badge&logo=android)](https://github.com/saqib-cipher/SWX_Skill)
[![Security](https://img.shields.io/badge/Security-AES--128--CBC-4CAF50?style=for-the-badge&logo=lock)](https://github.com/saqib-cipher/SWX_Skill)
[![Skill Format](https://img.shields.io/badge/Antigravity-Agent%20Skill-7C4DFF?style=for-the-badge&logo=google)](https://github.com/saqib-cipher/SWX_Skill)

Complete architectural manual, operational specification, and AI agent skill for **Sketchware, Sketchware Pro, SketchwareX, and Desktop SketchwareX** project systems.

---

## 📖 Overview

Most LLMs and AI coding assistants fail when generating Sketchware logic because they attempt to reverse-engineer standard Java code into blocks using lossy Abstract Syntax Tree (AST) converters. This typically results in:
* Falling back to raw text blocks (`addSourceDirectly`) instead of real visual blocks.
* Generating invalid block IDs (e.g., `id: 0`), triggering validation and editor crashes (`Invalid block id 0`).
* Corrupting encrypted project files due to missing or mismatched AES-128-CBC routines.

**SWX_Skill solves this by establishing the ground truth of Sketchware's data architecture.** It enables AI agents, CLI tools, and developers to directly inspect, create, modify, encrypt, and compile project files with **100% native block fidelity**.

---

## ⚡ Quick Start / Installation

### Using in Antigravity (Google DeepMind)
Clone or copy this repository into your project's `.agents/skills/` directory or your global skills folder:

```bash
# Project-level skill:
mkdir -p .agents/skills/sketchware-project-system
cp -r * .agents/skills/sketchware-project-system/

# Or Global-level skill:
mkdir -p ~/.gemini/config/skills/sketchware-project-system
cp -r * ~/.gemini/config/skills/sketchware-project-system/
```

### Using with Cursor, Claude Code, or Other AI Tools
Reference [**`SKILL.md`**](SKILL.md) in your system prompt or custom instructions:
> *"When creating or modifying Sketchware projects, always consult and strictly follow the operational specifications defined in `SKILL.md`."*

---

## 🗂️ Project Directory Structure

```
/.sketchware/
├── data/
│   ├── system/                         <-- Global custom events, listeners, components
│   └── <sc_id>/                        <-- Core project data directory (e.g. 601)
│       ├── project                     <-- [ENCRYPTED] Project metadata & configuration
│       ├── file                        <-- [ENCRYPTED] Activity, Fragment & Custom View list
│       ├── logic                       <-- [ENCRYPTED] All blocks, events, variables & functions
│       ├── view                        <-- [ENCRYPTED] View hierarchy & widget properties
│       ├── resource                    <-- [ENCRYPTED] Image, sound, and font registries
│       ├── library                     <-- [ENCRYPTED] Library configurations (AppCompat, Firebase, Supabase)
│       ├── project_config              <-- [PLAINTEXT] Hey Studios / Pro build & SDK settings
│       ├── DataDayDream.json           <-- [PLAINTEXT] DayDream settings (native C++, activity packages)
│       ├── custom_blocks               <-- [PLAINTEXT] Project-specific custom blocks
│       ├── permission                  <-- [PLAINTEXT] Declared Android permissions
│       ├── import                      <-- [PLAINTEXT] Injected Java imports
│       ├── proguard-rules.pro          <-- [PLAINTEXT] Custom ProGuard/R8 rules
│       └── files/                      <-- Project custom source & assets
│           ├── java/                   <-- Custom Java & Kotlin source files
│           ├── assets/                 <-- Direct APK assets
│           ├── resource/               <-- Custom Android resources (res/values/, res/drawable/)
│           └── native_libs/            <-- Prebuilt native .so libraries
├── mysc/
│   ├── <sc_id>/                        <-- Project cache & launcher icon (icon.png)
│   └── list/<sc_id>/project            <-- [ENCRYPTED] Quick-read project listing metadata
└── resources/                          <-- Global shared media assets
    ├── icons/<sc_id>/
    ├── images/<sc_id>/
    ├── sounds/<sc_id>/
    └── fonts/<sc_id>/
```

---

## 🔐 Cryptographic Specification (AES-128-CBC)

Sketchware encrypts core project files on disk to prevent unauthorized modification or accidental corruption:

* **Algorithm**: `AES` (128-bit key)
* **Cipher Mode**: `CBC` (Cipher Block Chaining)
* **Padding**: `PKCS5Padding` (PKCS#7 compatible)
* **Key & IV**: `sketchwaresecure` (16 ASCII bytes: `0x73, 0x6b, 0x65, 0x74, 0x63, 0x68, 0x77, 0x61, 0x72, 0x65, 0x73, 0x65, 0x63, 0x75, 0x72, 0x65`)

### File Encryption Matrix
| Encrypted (AES-128-CBC) | Plaintext JSON / Text |
| :--- | :--- |
| `data/<sc_id>/project` | `data/<sc_id>/project_config` |
| `data/<sc_id>/file` | `data/<sc_id>/DataDayDream.json` |
| `data/<sc_id>/logic` | `data/<sc_id>/custom_blocks` |
| `data/<sc_id>/view` | `data/<sc_id>/proguard-rules.pro` |
| `data/<sc_id>/resource` | `data/<sc_id>/permission`, `import` |
| `data/<sc_id>/library` | `data/<sc_id>/files/*` (all custom code & assets) |
| `mysc/list/<sc_id>/project` | `data/system/*.json` |

---

## 🧱 Logic File & Block JSON Grammar

In `.sketchware/data/<sc_id>/logic`, each event is marked by an `@` section header, followed by single-line JSON objects representing blocks:

```text
@MainActivity.java_var
1:isReady
2:scoreCount

@MainActivity.java_onCreate_initializeLogic
{"color":-16354097,"id":"10","nextBlock":11,"opCode":"setVisible","parameters":["textview1","visible"],"spec":"%m.view setVisible %m.visible","subStack1":-1,"subStack2":-1,"type":" ","typeName":"setVisible"}
{"color":-16354097,"id":"11","nextBlock":-1,"opCode":"setEnable","parameters":["button1","@12"],"spec":"%m.view setEnable %b","subStack1":-1,"subStack2":-1,"type":" ","typeName":"setEnable"}
{"color":-16729254,"id":"12","nextBlock":-1,"opCode":"true","parameters":[],"spec":"true","subStack1":-1,"subStack2":-1,"type":"b","typeName":"true"}
```

### Core Block Rules
1. **Block IDs**: Must always be non-zero positive strings (`"10"`, `"11"`, `"12"`). **Never use `"0"` or invalid IDs.**
2. **Linear Chaining**: Sequential statements are linked using `nextBlock` (set to `-1` on the final block).
3. **Nesting**:
   * `subStack1`: First nested body (`then` branch of `if`, loop body of `repeat`/`forever`, or listener callbacks).
   * `subStack2`: Second nested body (`else` branch of `ifElse`).
4. **Expression Embedding**: Reporter blocks (math, boolean conditions, variables) are referenced via the `@<id>` syntax inside the parent's `parameters` array (e.g., `parameters: ["button1", "@12"]`).

---

## 📦 SWB (`.swb`) Backup Archive System

An `.swb` file is a standard ZIP archive that packages a complete project for backup, sharing, and cross-platform restoration:

```text
my_backup.swb (ZIP Archive)
├── project                         <-- [ENCRYPTED] Root project metadata
├── data/                           <-- Project data files (file, view, logic, etc.)
├── resources/                      <-- Project binary media (images, sounds, fonts, icons)
│   ├── images/
│   │   └── .nomedia
│   ├── sounds/
│   │   └── .nomedia
│   ├── fonts/
│   │   └── .nomedia
│   └── icons/
│       └── icon.png
└── local_libs/                     <-- (Optional) Bundled local AAR/JAR libraries
```

---

## 🛠️ Included Automation Tools

### 1. `scripts/SketchwareCrypto.ps1`
Byte-for-byte verified AES-128-CBC encryption and decryption tool:

```powershell
# Decrypt a core project file:
powershell -ExecutionPolicy Bypass -File scripts/SketchwareCrypto.ps1 `
    -Action decrypt `
    -InputPath "data/601/logic" `
    -OutputPath "decrypted_logic.txt"

# Re-encrypt a modified file:
powershell -ExecutionPolicy Bypass -File scripts/SketchwareCrypto.ps1 `
    -Action encrypt `
    -InputPath "decrypted_logic.txt" `
    -OutputPath "data/601/logic"
```

### 2. `scripts/SwbTool.ps1`
Automated packaging and extraction of `.swb` archives:

```powershell
# Pack a project into an encrypted .swb archive:
powershell -ExecutionPolicy Bypass -File scripts/SwbTool.ps1 `
    -Action pack `
    -ScId 601 `
    -WorkspaceRoot "C:/path/to/.sketchware" `
    -SwbPath "C:/path/to/backup.swb"

# Unpack and inspect an .swb archive:
powershell -ExecutionPolicy Bypass -File scripts/SwbTool.ps1 `
    -Action unpack `
    -SwbPath "C:/path/to/backup.swb" `
    -OutputDir "C:/path/to/unpacked_folder"
```

---

## 📚 Complete Technical Specification

For the full operational specification including ViewBean layout parameters, 50+ widget types, DayDream C/C++ settings, and compiler safeguards, read [**`SKILL.md`**](SKILL.md).

---

## 📄 License & Credits

Created by **[saqib-cipher](https://github.com/saqib-cipher)** for the Sketchware Pro, and Desktop SketchwareX developer community.
Open source under the [MIT License](LICENSE).

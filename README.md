# SayWhat 💬

A generic, schema-driven **Terminal User Interface (TUI)** wizard runner built natively on Bash and `dialog`. Think of it as a **TUI-first Cookiecutter** for Bash scripts.

Define your questionnaire, menu branches, checklist steps, and text forms in a single JSON schema. `SayWhat` parses it dynamically, runs the interactive wizard in the console, handles back-navigation tracking, and outputs a structured JSON results object directly to `stdout` for downstream provisioning, templates, or installers to consume.

---

## Key Features

- ⚙️ **Schema-Driven Flows:** No hardcoded wizard loops in Bash. Define screens, menus, options, and conditional page branching in JSON.
- 📦 **Zero Runtime Dependencies:** Requires only standard `bash` and the native `dialog` C utility. No Python, Node.js, or heavyweight libraries required.
- 🔙 **Navigation History Stack:** Native support for back-navigation footprints (`"back_button": true`) so users can step backwards and change previous responses.
- 🗃️ **Support for all major Dialog widgets:**
  - Standard inputs and password forms (`msgbox`, `yesno`, `inputbox`, `passwordbox`, `form`)
  - Selections (`menu`, `checklist` (multi-select), `radiolist` (single-select))
  - Multi-select results automatically compile into native JSON Arrays
  - Large document readouts (`textbox`)
- 🎨 **Visual Builder included:** A self-contained, offline HTML/JS [Visual Builder page](./builder.html) with a premium dark-mode interface to visually design your dialog schemas and export configuration JSONs instantly.

---

## Getting Started

### 1. Requirements

Make sure `dialog` and `jq` are installed on your host system:

```bash
# Debian / Ubuntu
sudo apt install dialog jq

# macOS
brew install dialog jq
```

### 2. Run the Demo Flow

Run the default project wizard showcasing all supported dialog types:

```bash
./saywhat
```

To run a custom schema starting at a specific node:

```bash
./saywhat path/to/your_schema.json initial_node_id
```

---

## Schema Syntax Example

A sample configuration from [demo_flow.json](./demo_flow.json):

```json
[
  {
    "id": "welcome",
    "type": "msgbox",
    "text": "Welcome to the agbuild TUI Wizard Demonstration!",
    "next": "project_type"
  },
  {
    "id": "project_type",
    "type": "menu",
    "back_button": true,
    "text": "Select project template to build:",
    "options": [
      {"tag": "web", "item": "Web Application (Node.js/Vite)", "next": "web_config"},
      {"tag": "python", "item": "Python CLI tool / Service", "next": "py_config"}
    ]
  },
  {
    "id": "web_config",
    "type": "form",
    "back_button": true,
    "text": "Web Application Properties:",
    "options": [
      {
        "tag": "Project Name:",
        "variable": "name",
        "default": "my-web-app"
      },
      {
        "tag": "Port:",
        "variable": "port",
        "default": "3000"
      }
    ],
    "next": ""
  }
]
```

### Output Pipeline

Upon completion, the wizard writes a clean JSON string to `stdout` containing the collected results, which you can redirect or parse:

```json
{
  "project_type_val": "web",
  "project_type_btn": "ok",
  "web_config_name": "my-custom-app",
  "web_config_port": "8080",
  "web_config_btn": "ok"
}
```

---

## Designing Schemas Visually

Open [builder.html](./builder.html) directly in any browser to use the drag-and-drop flow builder offline. Define nodes, configure properties, select dropdown types, and download your finished `dialogs.json` configuration file immediately.

---

## License

This project is licensed under the Apache-2.0 License. See the [LICENSE](./LICENSE) file for details.

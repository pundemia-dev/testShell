pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ── Session security ──────────────────────────────────────────────
    readonly property string sessionToken: {
        // Only in QML memory — never written to disk.
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let t = ""
        for (let i = 0; i < 40; i++)
            t += chars.charAt(Math.floor(Math.random() * chars.length))
        return t
    }

    // Per-session socket in XDG_RUNTIME_DIR (0700) — a fixed /tmp path is
    // predictable and lets stale servers from previous sessions collide.
    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
        + "/quickshell-ai-" + Math.random().toString(36).slice(2, 8) + ".sock"

    // Script paths (relative to this file; resolved at runtime)
    readonly property string _serverScript: Qt.resolvedUrl("../scripts/ai_server.py").toString().replace("file://", "")
    readonly property string _clientScript: Qt.resolvedUrl("../scripts/ai_client.py").toString().replace("file://", "")

    // ── Server lifecycle ──────────────────────────────────────────────
    property bool serverReady: false

    Process {
        id: serverProc
        command: [root._serverScript]
        environment: ({
            "QS_AI_TOKEN":  root.sessionToken,
            "QS_AI_SOCKET": root.socketPath,
            "PATH": "/usr/bin:/bin:/usr/local/bin",
        })
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("ready:"))
                    root.serverReady = true
            }
        }
        onRunningChanged: {
            if (!running && root.serverReady) {
                // Restart on unexpected exit
                root.serverReady = false
                serverRestartTimer.restart()
            }
        }
    }

    Timer {
        id: serverRestartTimer
        interval: 2000
        repeat: false
        onTriggered: serverProc.running = true
    }

    Component.onCompleted: {
        serverProc.running = true
        keysFile.reload()
    }

    // ── API key storage (chmod-600 JSON file) ─────────────────────────
    property var apiKeys: ({})

    FileView {
        id: keysFile
        path: `${Quickshell.env("HOME")}/.config/pShell/apikeys.json`
        blockLoading: true
        watchChanges: false
        // Missing file is the normal first-run state; onLoadFailed handles it.
        printErrors: false
        onLoadedChanged: {
            if (!loaded) return
            try {
                root.apiKeys = JSON.parse(text())
            } catch(e) {
                root.apiKeys = ({})
            }
        }
        onLoadFailed: root.apiKeys = ({})
    }

    function setApiKey(provider: string, key: string) {
        const updated = Object.assign({}, root.apiKeys, { [provider]: key })
        root.apiKeys = updated
        keysFile.setText(JSON.stringify(updated, null, 2))
        // Ensure 600 permissions
        restrictKeysFile.running = true
    }

    function getApiKey(provider: string): string {
        return root.apiKeys[provider] ?? ""
    }

    Process {
        id: restrictKeysFile
        command: ["chmod", "600",
                  `${Quickshell.env("HOME")}/.config/pShell/apikeys.json`]
    }

    // ── Model registry ────────────────────────────────────────────────
    readonly property list<var> builtinModels: [
        // ── Gemini ────────────────────────────────────────────────────
        { id: "gemini-2.5-flash",   name: "Gemini 2.5 Flash",
          icon: "", format: "openai", keyId: "gemini", category: "api",
          endpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
          model: "gemini-2.5-flash" },
        { id: "gemini-2.0-flash",   name: "Gemini 2.0 Flash",
          icon: "", format: "openai", keyId: "gemini", category: "api",
          endpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
          model: "gemini-2.0-flash" },
        { id: "gemini-1.5-pro",     name: "Gemini 1.5 Pro",
          icon: "", format: "openai", keyId: "gemini", category: "api",
          endpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
          model: "gemini-1.5-pro" },

        // ── Anthropic ─────────────────────────────────────────────────
        { id: "claude-opus-4-8",    name: "Claude Opus 4.8",
          icon: "", format: "anthropic", keyId: "anthropic", category: "api",
          endpoint: "", model: "claude-opus-4-8" },
        { id: "claude-sonnet-4-6",  name: "Claude Sonnet 4.6",
          icon: "", format: "anthropic", keyId: "anthropic", category: "api",
          endpoint: "", model: "claude-sonnet-4-6" },
        { id: "claude-haiku-4-5",   name: "Claude Haiku 4.5",
          icon: "", format: "anthropic", keyId: "anthropic", category: "api",
          endpoint: "", model: "claude-haiku-4-5-20251001" },
        { id: "claude-3-5-sonnet",  name: "Claude 3.5 Sonnet",
          icon: "", format: "anthropic", keyId: "anthropic", category: "api",
          endpoint: "", model: "claude-3-5-sonnet-20241022" },

        // ── OpenAI ────────────────────────────────────────────────────
        { id: "gpt-4o",             name: "GPT-4o",
          icon: "", format: "openai", keyId: "openai", category: "api",
          endpoint: "https://api.openai.com/v1/chat/completions",
          model: "gpt-4o" },
        { id: "gpt-4o-mini",        name: "GPT-4o mini",
          icon: "", format: "openai", keyId: "openai", category: "api",
          endpoint: "https://api.openai.com/v1/chat/completions",
          model: "gpt-4o-mini" },
        { id: "o1-mini",            name: "o1-mini",
          icon: "", format: "openai", keyId: "openai", category: "api",
          endpoint: "https://api.openai.com/v1/chat/completions",
          model: "o1-mini" },

        // ── Mistral ───────────────────────────────────────────────────
        { id: "mistral-medium-3",   name: "Mistral Medium 3",
          icon: "", format: "openai", keyId: "mistral", category: "api",
          endpoint: "https://api.mistral.ai/v1/chat/completions",
          model: "mistral-medium-2505" },
        { id: "mistral-small",      name: "Mistral Small 3.2",
          icon: "", format: "openai", keyId: "mistral", category: "api",
          endpoint: "https://api.mistral.ai/v1/chat/completions",
          model: "mistral-small-2506" },

        // ── DeepSeek ──────────────────────────────────────────────────
        { id: "deepseek-v3",        name: "DeepSeek V3",
          icon: "", format: "openai", keyId: "deepseek", category: "api",
          endpoint: "https://api.deepseek.com/v1/chat/completions",
          model: "deepseek-chat" },
        { id: "deepseek-r1",        name: "DeepSeek R1",
          icon: "", format: "openai", keyId: "deepseek", category: "api",
          endpoint: "https://api.deepseek.com/v1/chat/completions",
          model: "deepseek-reasoner" },

        // ── xAI ───────────────────────────────────────────────────────
        { id: "grok-2",             name: "Grok 2",
          icon: "", format: "openai", keyId: "xai", category: "api",
          endpoint: "https://api.x.ai/v1/chat/completions",
          model: "grok-2" },

        // ── Groq ──────────────────────────────────────────────────────
        { id: "groq-llama3-70b",    name: "Groq LLaMA 3.1 70B",
          icon: "", format: "openai", keyId: "groq", category: "api",
          endpoint: "https://api.groq.com/openai/v1/chat/completions",
          model: "llama-3.1-70b-versatile" },
        { id: "groq-llama3-8b",     name: "Groq LLaMA 3.1 8B",
          icon: "", format: "openai", keyId: "groq", category: "api",
          endpoint: "https://api.groq.com/openai/v1/chat/completions",
          model: "llama-3.1-8b-instant" },

        // ── Perplexity ────────────────────────────────────────────────
        { id: "perplexity-sonar",   name: "Perplexity Sonar",
          icon: "", format: "openai", keyId: "perplexity", category: "api",
          endpoint: "https://api.perplexity.ai/chat/completions",
          model: "llama-3.1-sonar-large-128k-online" },

        // ── OpenRouter ────────────────────────────────────────────────
        { id: "openrouter-auto",    name: "OpenRouter Auto",
          icon: "", format: "openai", keyId: "openrouter", category: "api",
          endpoint: "https://openrouter.ai/api/v1/chat/completions",
          model: "openai/auto" },
        { id: "openrouter-deepseek-r1", name: "OpenRouter DeepSeek R1",
          icon: "", format: "openai", keyId: "openrouter", category: "api",
          endpoint: "https://openrouter.ai/api/v1/chat/completions",
          model: "deepseek/deepseek-r1" },
    ]

    // Ollama models discovered at runtime
    property list<var> ollamaModels: []
    property list<var> g4fModels: []

    // Heal a stale saved selection (e.g. legacy attribute-style names like
    // "o4_mini_high") once the real list arrives — without toggling useG4f.
    onG4fModelsChanged: {
        if (g4fModels.length === 0 || currentG4fModel === "") return
        if (!g4fModels.some(m => m.id === currentG4fModel)) {
            root.currentG4fModel = g4fModels[0].id
            Config.ai.g4fModel = root.currentG4fModel
        }
    }

    // G4F selection state
    property bool useG4f: Config.ai.useG4f
    property string currentG4fModel: Config.ai.g4fModel

    // Current model (null when G4F group is active but no specific model picked yet)
    property string currentModelId: Config.ai.model
    readonly property var currentModel: {
        if (root.useG4f) return {
            id: "g4f/" + root.currentG4fModel,
            name: "G4F: " + root.currentG4fModel,
            model: root.currentG4fModel,
            icon: "", format: "g4f", category: "free",
        }
        return root.allModels.find(m => m.id === root.currentModelId) ?? root.builtinModels[0]
    }

    readonly property list<var> allModels: [...builtinModels, ...ollamaModels]

    function setModel(id: string) {
        root.currentModelId = id
        root.useG4f = false
        Config.ai.model = id
        Config.ai.useG4f = false
    }

    function setG4fModel(modelName: string) {
        root.useG4f = true
        root.currentG4fModel = modelName
        Config.ai.useG4f = true
        Config.ai.g4fModel = modelName
    }

    // ── Ollama + G4F discovery ────────────────────────────────────────
    // Each client gets its request on stdin and the token via environment:
    // a shared request file races between concurrent clients, and argv is
    // world-readable through /proc/*/cmdline.
    Process {
        id: ollamaDiscover
        command: ["python3", root._clientScript, root.socketPath]
        environment: ({ "QS_AI_TOKEN": root.sessionToken })
        stdinEnabled: true
        onStarted: write(JSON.stringify({ action: "models_ollama" }) + "\n")
        stdout: SplitParser {
            onRead: line => {
                if (!line) return
                try {
                    const obj = JSON.parse(line)
                    if (obj.type === "models") {
                        root.ollamaModels = obj.models.map(name => ({
                            id: "ollama/" + name,
                            name: name,
                            icon: "",
                            format: "openai",
                            keyId: null,
                            category: "local",
                            endpoint: "http://localhost:11434/v1/chat/completions",
                            model: name,
                        }))
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: g4fDiscover
        command: ["python3", root._clientScript, root.socketPath]
        environment: ({ "QS_AI_TOKEN": root.sessionToken })
        stdinEnabled: true
        onStarted: write(JSON.stringify({ action: "models_g4f" }) + "\n")
        stdout: SplitParser {
            onRead: line => {
                if (!line) return
                try {
                    const obj = JSON.parse(line)
                    if (obj.type === "models") {
                        root.g4fModels = obj.models.map(name => ({ id: name, name: name }))
                    }
                } catch(e) {}
            }
        }
    }

    // Trigger discovery once server is ready
    onServerReadyChanged: {
        if (!serverReady) return
        _restart(ollamaDiscover)
        _restart(g4fDiscover)
    }

    function _restart(proc: Process) {
        proc.running = false
        proc.running = true
    }

    // ── Message storage ───────────────────────────────────────────────
    property list<string> messageIds: []
    property var messageById: ({})
    property bool requesting: false

    readonly property int messageCount: messageIds.length

    // Factory for message objects
    property Component _msgComp: Component {
        QtObject {
            property string role: "user"
            property string content: ""
            property string rawContent: ""
            property bool thinking: false
            property bool done: true
            property string model: ""
        }
    }

    function _addMessage(role: string, content: string, extra: var): string {
        const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 8)
        const msg = _msgComp.createObject(root, Object.assign(
            { role, content, rawContent: content }, extra ?? {}))
        // Reassign the map (in-place mutation emits no change signal) and do it
        // BEFORE messageIds — the Repeater instantiates the delegate the moment
        // messageIds changes, and its `msg` binding must resolve right away.
        root.messageById = Object.assign({}, root.messageById, { [id]: msg })
        root.messageIds = [...root.messageIds, id]
        return id
    }

    function addUserMessage(text: string) {
        _addMessage("user", text, { done: true, thinking: false })
        _sendRequest()
    }

    function removeMessage(id: string) {
        root.messageIds = root.messageIds.filter(i => i !== id)
        const copy = Object.assign({}, root.messageById)
        delete copy[id]
        root.messageById = copy
    }

    function clearMessages() {
        root.messageIds = []
        root.messageById = ({})
    }

    function addInfoMessage(text: string) {
        _addMessage("interface", text, { done: true })
    }

    // ── Request machinery ─────────────────────────────────────────────
    property string _activeAssistantId: ""

    Process {
        id: clientProc
        property string pendingRequest: ""
        command: ["python3", root._clientScript, root.socketPath]
        environment: ({ "QS_AI_TOKEN": root.sessionToken })
        stdinEnabled: true
        onStarted: write(pendingRequest + "\n")

        stdout: SplitParser {
            onRead: line => {
                if (!line) return
                try {
                    const obj  = JSON.parse(line)
                    const aMsg = root.messageById[root._activeAssistantId]
                    if (!aMsg) return

                    if (obj.type === "delta") {
                        if (aMsg.thinking) aMsg.thinking = false
                        aMsg.rawContent += obj.text
                        aMsg.content    += obj.text
                    } else if (obj.type === "done") {
                        aMsg.done       = true
                        aMsg.thinking   = false
                        root.requesting = false
                        root._activeAssistantId = ""
                    } else if (obj.type === "error") {
                        aMsg.rawContent += `\n\n**Error:** ${obj.message}`
                        aMsg.content    += `\n\n**Error:** ${obj.message}`
                        aMsg.done       = true
                        aMsg.thinking   = false
                        root.requesting = false
                        root._activeAssistantId = ""
                    }
                } catch(e) {}
            }
        }

        onExited: {
            const aMsg = root.messageById[root._activeAssistantId]
            if (aMsg && !aMsg.done) {
                aMsg.done       = true
                aMsg.thinking   = false
            }
            root.requesting = false
            root._activeAssistantId = ""
        }
    }

    function _sendRequest() {
        if (!serverReady) {
            addInfoMessage("AI server is starting up, please wait…")
            return
        }
        if (requesting) return

        const model = root.currentModel
        const apiKey = model.keyId ? root.getApiKey(model.keyId) : ""

        // Guard before hitting the network — an empty Bearer header is an
        // httpx error ("Illegal header value"), not a readable message.
        if (model.keyId && !apiKey) {
            addInfoMessage(`No API key for "${model.keyId}". Add it to `
                + `~/.config/pShell/apikeys.json as {"${model.keyId}": "<key>"}.`)
            return
        }

        // Build messages array (exclude interface messages)
        const msgs = root.messageIds
            .map(id => root.messageById[id])
            .filter(m => m.role !== "interface")
            .map(m => ({ role: m.role === "assistant" ? "assistant" : "user",
                         content: m.rawContent }))

        // Prepend system prompt
        const systemPrompt = Config.ai.systemPrompt
        if (systemPrompt) msgs.unshift({ role: "system", content: systemPrompt })

        const reqObj = {
            action:      "chat",
            format:      model.format,
            model:       model.model ?? model.id,
            endpoint:    model.endpoint ?? "",
            apiKey:      apiKey,
            messages:    msgs,
            temperature: Config.ai.temperature,
        }

        // Create placeholder assistant message
        const aId = _addMessage("assistant", "", {
            thinking: true, done: false, model: model.id
        })
        root._activeAssistantId = aId
        root.requesting = true

        clientProc.pendingRequest = JSON.stringify(reqObj)
        _restart(clientProc)
    }

    function regenerate(messageId: string) {
        // Remove all messages from this assistant message onward
        const idx = root.messageIds.indexOf(messageId)
        if (idx < 0) return
        const copy = Object.assign({}, root.messageById)
        root.messageIds.slice(idx).forEach(id => delete copy[id])
        root.messageById = copy
        root.messageIds = root.messageIds.slice(0, idx)
        _sendRequest()
    }
}

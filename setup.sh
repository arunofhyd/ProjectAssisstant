#!/bin/bash

# --- UNIVERSAL MAC FORMATTING ---
VERSION="v1.0"
BOLD='\033[1m'
BLUE='\033[38;5;33m'
GRAY='\033[38;5;244m'
GREEN='\033[38;5;46m'
NC='\033[0m'

clear
printf "\n${BOLD}   Project Assistant Setup ${VERSION}${NC}\n"
printf "${GRAY}  Designed by Arun Thomas${NC}\n"
printf "  --------------------------------------------------\n\n"

# 1. ASSETS
printf "  ${BLUE}▶${NC} Generating application assets...\n"
cat << 'EOF' > brain.svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="512" height="512">
  <rect width="100" height="100" rx="22" fill="#ffffff" stroke="#e5e5e5" stroke-width="1"/>
  <g fill="none" stroke="#007aff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">
    <path d="M 50 85 C 30 85, 15 70, 15 50 C 15 35, 25 20, 40 15 C 45 15, 50 25, 50 25" />
    <path d="M 50 85 C 70 85, 85 70, 85 50 C 85 35, 75 20, 60 15 C 55 15, 50 25, 50 25" />
    <circle cx="50" cy="25" r="4" fill="#007aff" stroke="none" />
    <circle cx="50" cy="85" r="4" fill="#007aff" stroke="none" />
  </g>
</svg>
EOF

# 2. BACKEND
printf "  ${BLUE}▶${NC} Building Knowledge Engine ${VERSION}...\n"
cat << 'EOF' > main.py
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import HTMLResponse
import pandas as pd
from langchain_community.document_loaders import PyPDFLoader, TextLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_chroma import Chroma
from langchain_ollama import OllamaEmbeddings, OllamaLLM
from langchain_core.documents import Document
import os, shutil
from datetime import datetime

app = FastAPI()
DB_PATH, TEMP_DIR = "./chroma_db", "./temp_uploads"
os.makedirs(TEMP_DIR, exist_ok=True)

embeddings = OllamaEmbeddings(model="nomic-embed-text")
llm = OllamaLLM(model="llama3.2")
vectorstore = Chroma(persist_directory=DB_PATH, embedding_function=embeddings)

@app.get("/", response_class=HTMLResponse)
async def read_index():
    with open("index.html", "r") as f: return f.read()

@app.get("/files")
async def list_files():
    results = vectorstore.get()
    files = {}
    if results['metadatas']:
        for meta in results['metadatas']:
            src = meta.get('source', 'Unknown')
            if src not in files:
                files[src] = {"session": meta.get('session', 'General'), "timestamp": meta.get('timestamp', 'N/A')}
    return files

@app.post("/upload")
async def upload_file(session_name: str = Form(...), file: UploadFile = File(...)):
    path = os.path.join(TEMP_DIR, file.filename)
    with open(path, "wb") as buffer: shutil.copyfileobj(file.file, buffer)
    tm = datetime.now().strftime("%d %b, %Y")
    try:
        if file.filename.endswith('.pdf'): loader = PyPDFLoader(path); docs = loader.load()
        else: loader = TextLoader(path); docs = loader.load()
        for doc in docs: doc.metadata.update({"session": session_name, "timestamp": tm, "source": file.filename})
        chunks = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200).split_documents(docs)
        vectorstore.add_documents(chunks)
        return {"message": f"Learned {file.filename}"}
    except Exception as e: raise HTTPException(status_code=500, detail=str(e))

@app.post("/chat")
async def chat(message: str = Form(...)):
    greetings = ["hi", "hello", "hey", "who are you"]
    if message.lower().strip() in greetings:
        return {"reply": "Hello! I am your Project Assistant. I am running 100% locally on your Mac. How can I help you with your documents today?"}

    results = vectorstore.similarity_search(message, k=5)
    context = "\n\n".join([f"[Source: {d.metadata.get('source')}]\n{d.page_content}" for d in results])
    
    prompt = f"""
    SYSTEM: YOU ARE A LOCAL PROJECT ASSISTANT RUNNING OFFLINE.
    IDENTITY: DESIGNED BY ARUN THOMAS. 
    
    CRITICAL INSTRUCTIONS:
    1. PRIVACY: You are 100% offline. No data is shared with the cloud.
    2. CONTEXT ONLY: Answer based ONLY on the Context below.
    3. NO HALLUCINATION: If information is missing from the context, say "Data not found in local memory."
    4. CITATION: Always mention the source filename.

    CONTEXT:
    {context}

    QUESTION: {message}
    """
    return {"reply": llm.invoke(prompt)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
EOF

# 3. FRONTEND (IMPROVED ALIGNMENT & FONT SIZES)
printf "  ${BLUE}▶${NC} Creating UI Interface ${VERSION}...\n"
cat << 'EOF' > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Project Assistant v1.0</title>
    <script src="https://unpkg.com/lucide@latest"></script>
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <style>
        :root { --bg: #ffffff; --side: #f2f2f7; --text: #1c1c1e; --mute: #8e8e93; --accent: #007aff; --border: rgba(0,0,0,0.08); --msg-bot: #f2f2f7; --modal-bg: rgba(255, 255, 255, 0.98); }
        body.dark { --bg: #000000; --side: #121212; --text: #ffffff; --mute: #8e8e93; --accent: #0a84ff; --border: rgba(255,255,255,0.15); --msg-bot: #1c1c1e; --modal-bg: rgba(18, 18, 18, 0.98); }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        body { background: var(--bg); color: var(--text); height: 100vh; display: flex; transition: background 0.3s; }
        
        .sidebar { width: 300px; background: var(--side); border-right: 1px solid var(--border); display: flex; flex-direction: column; transition: transform 0.3s ease; z-index: 50; }
        .sidebar-header { padding: 40px 24px 20px; }
        .sidebar-scroll { flex: 1; overflow-y: auto; padding: 0 16px; }
        .section-label { font-size: 0.75rem; font-weight: 700; color: var(--mute); text-transform: uppercase; margin: 20px 0 10px 8px; }
        
        .nav-item { padding: 12px 16px; border-radius: 12px; cursor: pointer; font-size: 1rem; display: flex; align-items: center; justify-content: space-between; margin-bottom: 4px; transition: 0.2s; }
        .nav-item span { display: flex; align-items: center; gap: 12px; line-height: 1; }
        .nav-item:hover { background: rgba(128,128,128,0.1); }
        .nav-item.active { background: var(--accent); color: white; }
        .delete-btn { opacity: 0; padding: 4px; border-radius: 6px; }
        .nav-item:hover .delete-btn { opacity: 1; }

        .main { flex: 1; display: flex; flex-direction: column; position: relative; }
        header { padding: 20px 30px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; background: var(--bg); }
        .chat-area { flex: 1; padding: 40px 12%; overflow-y: auto; display: flex; flex-direction: column; gap: 20px; }
        .msg { max-width: 80%; padding: 14px 20px; border-radius: 18px; line-height: 1.5; font-size: 1rem; }
        .msg.user { align-self: flex-end; background: var(--accent); color: white; border-bottom-right-radius: 4px; }
        .msg.bot { align-self: flex-start; background: var(--msg-bot); border-bottom-left-radius: 4px; }

        .input-wrap { padding: 20px 12% 40px; }
        .input-pill { display: flex; align-items: center; background: var(--msg-bot); border-radius: 28px; padding: 8px 12px 8px 24px; border: 1px solid var(--border); }
        input[type="text"] { flex: 1; border: none; background: transparent; padding: 10px 0; outline: none; color: var(--text); font-size: 1.05rem; }
        .icon-btn { background: transparent; border: none; color: var(--mute); cursor: pointer; padding: 10px; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
        
        .modal { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.3); backdrop-filter: blur(15px); z-index: 100; display: none; justify-content: center; align-items: center; }
        .modal.active { display: flex; }
        .modal-card { background: var(--modal-bg); border: 1px solid var(--border); width: 520px; padding: 40px; border-radius: 24px; box-shadow: 0 30px 60px rgba(0,0,0,0.25); text-align: left; }
        
        .how-it-works { font-size: 0.95rem; line-height: 1.6; color: var(--text); margin-bottom: 25px; }
        .how-it-works b { color: var(--accent); }
        .step-box { background: rgba(128,128,128,0.05); padding: 15px; border-radius: 12px; margin-bottom: 12px; border-left: 4px solid var(--accent); }
    </style>
</head>
<body class="light">
    <div class="sidebar" id="sidebar">
        <div class="sidebar-header"><h1 style="font-size: 1.5rem; font-weight: 800; letter-spacing: -0.5px;">Assistant</h1></div>
        <div class="sidebar-scroll"><div class="section-label">Sessions</div><div id="sessionList"></div></div>
        <div style="padding: 24px;"><button onclick="createNewSession()" style="width:100%; padding:16px; border-radius:14px; border:none; background:var(--accent); color:white; font-weight:700; font-size: 1.05rem; cursor:pointer;">+ New Session</button></div>
    </div>
    <div class="main" id="main">
        <header>
            <div style="display:flex; align-items:center; gap:15px;"><button class="icon-btn" onclick="toggleSidebar()"><i data-lucide="sidebar"></i></button><span id="currentSessionDisplay" style="font-weight: 600; font-size: 1.1rem; color: var(--mute);">General</span></div>
            <div style="display:flex; gap:14px;">
                <button class="icon-btn" onclick="toggleTheme()"><i data-lucide="sun" id="tIcon"></i></button>
                <button class="icon-btn" onclick="openModal('memoryModal')"><i data-lucide="database"></i></button>
                <button class="icon-btn" onclick="openModal('infoModal')"><i data-lucide="info"></i></button>
            </div>
        </header>
        <div class="chat-area" id="chats"></div>
        <div class="input-wrap"><div class="input-pill"><input type="text" id="userInput" placeholder="Ask anything..." onkeypress="if(event.key=='Enter') send()"><button onclick="send()" class="icon-btn" style="background:var(--accent); color:white;"><i data-lucide="arrow-up" style="width:20px;"></i></button></div></div>
        
        <div class="modal" id="infoModal"><div class="modal-card">
            <h2 style="margin-bottom: 5px;">Project Assistant v1.0</h2>
            <p style="color:var(--mute); margin-bottom: 25px;">Advanced Private Intelligence</p>
            
            <div class="how-it-works">
                <div class="step-box">
                    <b>1. Ingestion:</b> Your files are broken into chunks and turned into mathematical vectors using <b>Nomic Embed</b>.
                </div>
                <div class="step-box">
                    <b>2. Local Storage:</b> These vectors are saved to <b>ChromaDB</b> on your Mac. No data is ever uploaded to a server.
                </div>
                <div class="step-box">
                    <b>3. Retrieval:</b> When you ask a question, the app finds the most relevant chunks in your SSD memory.
                </div>
                <div class="step-box">
                    <b>4. Reasoning:</b> <b>Llama 3.2</b> reads those specific chunks and provides a grounded answer locally.
                </div>
            </div>

            <div style="padding:18px; background:rgba(0,122,255,0.08); border-radius:12px; font-weight:700; color:var(--accent); text-align:center; font-size: 1.1rem;">Designed by Arun Thomas</div>
            <button onclick="closeModal('infoModal')" style="margin-top:25px; width:100%; padding:14px; border-radius:12px; border:none; background:var(--text); color:var(--bg); cursor:pointer; font-weight:700; font-size:1rem;">Close Information</button>
        </div></div>
        
        <div class="modal" id="memoryModal"><div class="modal-card"><h2>Memory Bank</h2><div id="fileList" style="max-height:300px; overflow-y:auto; margin: 20px 0; text-align:left;"></div><input type="file" id="fileIn" style="display:none" onchange="upload()"><button onclick="document.getElementById('fileIn').click()" style="width:100%; padding:16px; border-radius:14px; border:1px solid var(--accent); color:var(--accent); background:transparent; font-weight:700; font-size: 1.05rem; cursor:pointer;">+ Add Document</button><button onclick="closeModal('memoryModal')" style="margin-top:15px; width:100%; border:none; background:transparent; color:var(--mute); cursor:pointer; font-weight:600;">Done</button></div></div>
    </div>
    <script>
        lucide.createIcons();
        let currentSession = localStorage.getItem('lastSession') || 'General';
        marked.setOptions({ breaks: true });
        function getHistory(session) { return JSON.parse(localStorage.getItem(`chat_${session}`)) || [{ type: 'bot', text: `Session ${session} active.` }]; }
        function saveHistory(session, history) { localStorage.setItem(`chat_${session}`, JSON.stringify(history)); }
        async function loadUI() {
            const sessions = JSON.parse(localStorage.getItem('sessions') || '["General"]');
            const sList = document.getElementById('sessionList'); sList.innerHTML = '';
            sessions.forEach(s => {
                const div = document.createElement('div');
                div.className = `nav-item ${s === currentSession ? 'active' : ''}`;
                div.innerHTML = `<span><i data-lucide="hash" style="width:18px;"></i>${s}</span><i data-lucide="trash-2" class="delete-btn" onclick="deleteSession(event, '${s}')" style="width:16px"></i>`;
                div.onclick = () => { currentSession = s; localStorage.setItem('lastSession', s); renderChat(); loadUI(); };
                sList.appendChild(div);
            });
            const res = await fetch('/files'); const files = await res.json();
            const fList = document.getElementById('fileList'); fList.innerHTML = '';
            for (const [name, meta] of Object.entries(files)) { fList.innerHTML += `<div style="border-bottom:1px solid var(--border); padding:12px 0;"><div style="font-size:1rem; font-weight:600;">${name}</div><div style="font-size:0.8rem; color:var(--mute)">Added ${meta.timestamp}</div></div>`; }
            document.getElementById('currentSessionDisplay').innerText = currentSession;
            lucide.createIcons();
        }
        function renderChat() { const chatBox = document.getElementById('chats'); chatBox.innerHTML = ''; getHistory(currentSession).forEach(msg => { chatBox.innerHTML += `<div class="msg ${msg.type}">${marked.parse(msg.text)}</div>`; }); chatBox.scrollTop = chatBox.scrollHeight; }
        function toggleSidebar() { document.getElementById('sidebar').classList.toggle('hidden'); }
        function createNewSession() { const name = prompt("Session Name:"); if (name) { const sess = JSON.parse(localStorage.getItem('sessions') || '["General"]'); if (!sess.includes(name)) sess.push(name); localStorage.setItem('sessions', JSON.stringify(sess)); currentSession = name; localStorage.setItem('lastSession', name); renderChat(); loadUI(); } }
        function deleteSession(e, name) { e.stopPropagation(); if (name === 'General') return; if (confirm("Delete session history?")) { let sess = JSON.parse(localStorage.getItem('sessions')).filter(s => s !== name); localStorage.setItem('sessions', JSON.stringify(sess)); localStorage.removeItem(`chat_${name}`); if (currentSession === name) currentSession = 'General'; renderChat(); loadUI(); } }
        async function upload() { const file = document.getElementById('fileIn').files[0]; if(!file) return; const fd = new FormData(); fd.append('file', file); fd.append('session_name', currentSession); await fetch('/upload', { method: 'POST', body: fd }); loadUI(); }
        async function send() {
            const input = document.getElementById('userInput'); const msg = input.value; if(!msg) return;
            const history = getHistory(currentSession); history.push({ type: 'user', text: msg });
            saveHistory(currentSession, history); renderChat(); input.value = '';
            const loadingId = "loading-" + Date.now();
            document.getElementById('chats').innerHTML += `<div class="msg bot" id="${loadingId}">...</div>`;
            document.getElementById('chats').scrollTop = document.getElementById('chats').scrollHeight;
            const fd = new FormData(); fd.append('message', msg);
            try {
                const res = await fetch('/chat', { method: 'POST', body: fd });
                const data = await res.json(); history.push({ type: 'bot', text: data.reply });
                saveHistory(currentSession, history); renderChat();
            } catch (err) { document.getElementById(loadingId).innerText = "Error."; }
        }
        function toggleTheme() { document.body.classList.toggle('dark'); const isDark = document.body.classList.contains('dark'); localStorage.setItem('theme', isDark ? 'dark' : 'light'); document.getElementById('tIcon').setAttribute('data-lucide', isDark ? 'sun' : 'moon'); lucide.createIcons(); }
        function openModal(id) { document.getElementById(id).classList.add('active'); }
        function closeModal(id) { document.getElementById(id).classList.remove('active'); }
        if(localStorage.getItem('theme') === 'dark') toggleTheme();
        loadUI(); renderChat();
    </script>
</body>
</html>
EOF

# 4. SILENT STARTUP
printf "  ${BLUE}▶${NC} Powering up local hardware...\n"
ollama serve > /dev/null 2>&1 &
sleep 2
ollama pull nomic-embed-text > /dev/null 2>&1
ollama pull llama3.2 > /dev/null 2>&1
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip > /dev/null 2>&1
pip install fastapi uvicorn python-multipart pandas openpyxl pypdf langchain-community langchain-chroma langchain-ollama > /dev/null 2>&1

# 5. POLISHED DESKTOP LAUNCHER
SHORTCUT_PATH="$HOME/Desktop/Project Assistant.command"
ABS_PROJECT_DIR=$(pwd)
cat << EOT > "$SHORTCUT_PATH"
#!/bin/bash
BOLD='\033[1m'
BLUE='\033[38;5;33m'
GREEN='\033[38;5;46m'
NC='\033[0m'
clear
printf "\n\${BOLD}   Project Assistant v1.0\${NC}\n"
printf "  ----------------------------------------\n"
printf "  \${BLUE}▶\${NC} Starting Neural Engine...\n"
ollama serve > /dev/null 2>&1 &
cd "$ABS_PROJECT_DIR"
source venv/bin/activate
(while ! nc -z 127.0.0.1 8000; do sleep 0.2; done; printf "  \${GREEN}✓\${NC} Server Online\n\n"; open http://127.0.0.1:8000) &
python3 main.py
EOT
chmod +x "$SHORTCUT_PATH"
printf "\n  ${GREEN}✓ Setup Complete.${NC}\n"
printf "  ${BOLD}LAUNCH THE APP FROM THE DESKTOP SHORTCUT.${NC}\n\n"

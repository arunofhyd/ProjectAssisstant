#!/bin/bash

# --- UNIVERSAL MAC FORMATTING ---
VERSION="v1.0"
BOLD='\033[1m'
BLUE='\033[38;5;33m'
GRAY='\033[38;5;244m'
GREEN='\033[38;5;46m'
RED='\033[38;5;196m'
NC='\033[0m'

clear
printf "\n${BOLD}   Project Assistant Setup ${VERSION}${NC}\n"
printf "${GRAY}  Designed by Arun Thomas${NC}\n"
printf "  --------------------------------------------------\n\n"

# 1. PREREQUISITE CHECKS
printf "  ${BLUE}▶${NC} Verifying system requirements...\n"
if ! command -v python3 > /dev/null 2>&1; then
    printf "  ${GRAY}Python 3 is missing. Preparing to install...${NC}\n"
    if ! command -v brew > /dev/null 2>&1; then
        printf "  ${GRAY}Homebrew not found. Installing Homebrew...${NC}\n"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -x "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
    printf "  ${GRAY}Installing Python 3...${NC}\n"
    brew install python
    printf "  ${GREEN}✓ Python 3 installed successfully.${NC}\n"
else
    printf "  ${GREEN}✓ Python 3 detected.${NC}\n"
fi

if ! command -v ollama > /dev/null 2>&1; then
    printf "  ${GRAY}Ollama Neural Engine is missing. Installing...${NC}\n"
    curl -fsSL https://ollama.com/install.sh | sh
    printf "  ${GREEN}✓ Ollama installed successfully.${NC}\n"
else
    printf "  ${GREEN}✓ Ollama detected.${NC}\n"
fi

# 2. ASSETS
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

# 3. BACKEND (Global Memory Bank)
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
DB_PATH, DOCS_DIR = "./chroma_db", "./assistant_vault"
os.makedirs(DOCS_DIR, exist_ok=True)

try:
    embeddings = OllamaEmbeddings(model="nomic-embed-text", base_url="http://127.0.0.1:11434")
    llm = OllamaLLM(model="llama3.2", base_url="http://127.0.0.1:11434")
    vectorstore = Chroma(persist_directory=DB_PATH, embedding_function=embeddings)
except Exception as e:
    print(f"Error initializing models: {e}")

@app.get("/", response_class=HTMLResponse)
async def read_index():
    with open("index.html", "r") as f: return f.read()

@app.get("/files")
async def list_files():
    try:
        results = vectorstore.get()
        learned_files = {}
        if results.get('metadatas'):
            for meta in results['metadatas']:
                src = meta.get('source', 'Unknown')
                learned_files[src] = meta.get('timestamp', 'N/A')
        
        def build_tree(current_dir):
            items = []
            for entry in sorted(os.scandir(current_dir), key=lambda e: (not e.is_dir(), e.name.lower())):
                if entry.name.startswith('.'): continue
                rel_path = os.path.relpath(entry.path, DOCS_DIR).replace('\\', '/')
                
                if entry.is_dir():
                    items.append({
                        "type": "folder", 
                        "name": entry.name, 
                        "path": rel_path, 
                        "children": build_tree(entry.path)
                    })
                else:
                    items.append({
                        "type": "file", 
                        "name": entry.name, 
                        "path": rel_path, 
                        "learned": rel_path in learned_files,
                        "timestamp": learned_files.get(rel_path, "")
                    })
            return items
            
        return {"tree": build_tree(DOCS_DIR)}
    except Exception as e:
        return {"tree": []}

@app.post("/create_folder")
async def create_folder(path: str = Form(...)):
    full_path = os.path.join(DOCS_DIR, path)
    os.makedirs(full_path, exist_ok=True)
    return {"message": "Folder created"}

@app.post("/upload")
async def upload_file(path: str = Form(""), file: UploadFile = File(...)):
    full_dir = os.path.join(DOCS_DIR, path)
    os.makedirs(full_dir, exist_ok=True)
    file_path = os.path.join(full_dir, file.filename)
    
    try:
        with open(file_path, "wb") as buffer: shutil.copyfileobj(file.file, buffer)
        return {"message": "Stored"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/learn")
async def learn_file(filepath: str = Form(...)):
    full_path = os.path.join(DOCS_DIR, filepath)
    if not os.path.exists(full_path): raise HTTPException(status_code=404, detail="File not found")
    
    tm = datetime.now().strftime("%d %b, %Y")
    try:
        if filepath.lower().endswith('.pdf'): loader = PyPDFLoader(full_path); docs = loader.load()
        else: loader = TextLoader(full_path); docs = loader.load()
        
        # Removed session tagging so it's globally available
        for doc in docs: doc.metadata.update({"timestamp": tm, "source": filepath})
        chunks = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200).split_documents(docs)
        vectorstore.add_documents(chunks)
        return {"message": f"Learned {filepath}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/delete_item")
async def delete_item(path: str = Form(...), is_folder: str = Form(...)):
    full_path = os.path.join(DOCS_DIR, path)
    
    try:
        results = vectorstore.get()
        ids_to_del = []
        if results and results.get('metadatas'):
            for idx, meta in enumerate(results['metadatas']):
                src = meta.get('source', '')
                if is_folder == "true":
                    if src.startswith(path + '/'): ids_to_del.append(results['ids'][idx])
                else:
                    if src == path: ids_to_del.append(results['ids'][idx])
        if ids_to_del: vectorstore.delete(ids=ids_to_del)
    except Exception:
        pass

    if is_folder == "true":
        if os.path.exists(full_path): shutil.rmtree(full_path)
    else:
        if os.path.exists(full_path): os.remove(full_path)
        
    return {"message": "Deleted"}

@app.post("/chat")
async def chat(message: str = Form(...), session_name: str = Form(...)):
    try:
        greetings = ["hi", "hello", "hey", "who are you"]
        if message.lower().strip() in greetings:
            return {"reply": f"Hello! I am your Project Assistant. I am operating in the **{session_name}** session. How can I help you today?"}

        # THE FIX: Removed the session filter so it searches the Global Brain
        try:
            results = vectorstore.similarity_search(message, k=5)
        except Exception:
            results = []

        if not results:
            return {"reply": "I don't have any learned documents in my global memory to answer that. Please open the Memory Bank, add files, and click **Learn** first."}

        context = "\n\n".join([f"Document Name: {d.metadata.get('source')}\nContent: {d.page_content}" for d in results])
        
        prompt = f"""
        SYSTEM: YOU ARE A LOCAL PROJECT ASSISTANT RUNNING OFFLINE.
        IDENTITY: DESIGNED BY ARUN THOMAS. 
        
        CRITICAL INSTRUCTIONS:
        1. PRIVACY: You are 100% offline. No data is shared with the cloud.
        2. NO HALLUCINATION: If the answer is not in the context, explicitly state: "This information is not available in my active memory."
        3. FORMATTING: Use clean Markdown. Use bullet points for lists, bold text for emphasis, and structured paragraphs. Do not output raw text blocks.
        4. CITATION: Synthesize your answer naturally and mention the source document seamlessly (e.g., "According to document.txt..."). Do not print raw source brackets.

        CONTEXT:
        {context}

        QUESTION: {message}
        """
        return {"reply": llm.invoke(prompt)}
    except Exception as e:
        return {"reply": f"An error occurred while processing: {str(e)}"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
EOF

# 4. FRONTEND
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
        
        .sidebar { width: 300px; background: var(--side); border-right: 1px solid var(--border); display: flex; flex-direction: column; transition: transform 0.3s ease; z-index: 50; flex-shrink: 0; }
        .sidebar.hidden { transform: translateX(-300px); position: absolute; }
        .sidebar-header { padding: 40px 24px 20px; }
        .sidebar-header h1 { font-size: 1.5rem; font-weight: 800; letter-spacing: -0.5px; }
        .sidebar-scroll { flex: 1; overflow-y: auto; padding: 0 16px; }
        .section-label { font-size: 0.75rem; font-weight: 700; color: var(--mute); text-transform: uppercase; margin: 20px 0 10px 8px; }
        
        .nav-item { padding: 12px 16px; border-radius: 12px; cursor: pointer; font-size: 1rem; display: flex; align-items: center; justify-content: space-between; margin-bottom: 4px; transition: 0.2s; }
        .nav-item-content { display: flex; align-items: center; gap: 10px; }
        .nav-item-content svg { width: 18px; height: 18px; flex-shrink: 0; }
        .nav-item:hover { background: rgba(128,128,128,0.1); }
        .nav-item.active { background: var(--accent); color: white; }
        .delete-btn { opacity: 0; padding: 6px; border-radius: 6px; display: flex; align-items: center; justify-content: center; border: none; background: transparent; color: inherit; cursor: pointer; transition: 0.2s; }
        .nav-item:hover .delete-btn { opacity: 1; }
        .delete-btn:hover { background: rgba(0,0,0,0.1); }
        body.dark .delete-btn:hover { background: rgba(255,255,255,0.2); }
        
        .new-btn { width: 100%; padding: 16px; border-radius: 14px; border: none; background: var(--accent); color: white; font-weight: 700; font-size: 1.05rem; cursor: pointer; transition: opacity 0.2s; }
        .new-btn:hover { opacity: 0.9; }

        .main { flex: 1; display: flex; flex-direction: column; position: relative; min-width: 0; }
        header { padding: 20px 30px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; background: var(--bg); }
        .chat-area { flex: 1; padding: 40px 12%; overflow-y: auto; display: flex; flex-direction: column; gap: 20px; scroll-behavior: smooth; }
        
        /* Markdown Styling Fixes */
        .msg { max-width: 85%; padding: 14px 20px; border-radius: 18px; line-height: 1.6; font-size: 1rem; }
        .msg p { margin-bottom: 10px; }
        .msg p:last-child { margin-bottom: 0; }
        .msg ul, .msg ol { margin-left: 20px; margin-bottom: 10px; }
        .msg strong { color: inherit; font-weight: 700; }
        
        .msg.user { align-self: flex-end; background: var(--accent); color: white; border-bottom-right-radius: 4px; }
        .msg.bot { align-self: flex-start; background: var(--msg-bot); border-bottom-left-radius: 4px; }

        .empty-state { display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; opacity: 0.9; margin-top: 20px; }
        .empty-icon { width: 80px; height: 80px; margin-bottom: 24px; border-radius: 24px; background: var(--msg-bot); display: flex; align-items: center; justify-content: center; }
        .empty-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; width: 100%; max-width: 600px; text-align: left; margin-top: 30px; }
        .empty-card { background: var(--msg-bot); padding: 20px; border-radius: 16px; }
        .empty-card h3 { font-size: 1rem; margin-bottom: 8px; font-weight: 600; }
        .empty-card p { font-size: 0.85rem; color: var(--mute); line-height: 1.5; }

        .input-wrap { padding: 20px 12% 40px; }
        .input-pill { display: flex; align-items: center; background: var(--msg-bot); border-radius: 28px; padding: 8px 12px 8px 24px; border: 1px solid var(--border); }
        input[type="text"] { flex: 1; border: none; background: transparent; padding: 10px 0; outline: none; color: var(--text); font-size: 1.05rem; }
        .icon-btn { background: transparent; border: none; color: var(--mute); cursor: pointer; padding: 10px; border-radius: 50%; display: flex; align-items: center; justify-content: center; transition: 0.2s; }
        .icon-btn:hover { background: rgba(128,128,128,0.1); color: var(--accent); }
        .send-btn { background: var(--accent); color: white; border: none; border-radius: 50%; width: 40px; height: 40px; display: flex; align-items: center; justify-content: center; cursor: pointer; margin-left: 8px; transition: 0.2s; }
        
        .modal { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.3); backdrop-filter: blur(15px); z-index: 100; display: none; justify-content: center; align-items: center; }
        .modal.active { display: flex; }
        .modal-card { background: var(--modal-bg); border: 1px solid var(--border); width: 600px; padding: 40px; border-radius: 24px; box-shadow: 0 30px 60px rgba(0,0,0,0.25); text-align: left; }
        
        .how-it-works { font-size: 0.95rem; line-height: 1.6; color: var(--text); margin-bottom: 25px; }
        .step-box { background: var(--msg-bot); padding: 16px; border-radius: 12px; margin-bottom: 12px; display: flex; gap: 16px; align-items: flex-start; }
        .step-box strong { display: block; margin-bottom: 4px; font-size: 1rem; color: var(--text); }
        .step-box span { color: var(--mute); font-size: 0.85rem; }
        
        .btn-outline { padding: 12px 20px; border-radius: 12px; border: 1px dashed var(--accent); color: var(--accent); background: transparent; font-weight: 700; font-size: 0.9rem; cursor: pointer; transition: 0.2s; display: flex; align-items: center; gap: 8px;}
        .btn-outline:hover { background: rgba(0, 122, 255, 0.05); }
        .btn-close { margin-top: 25px; width: 100%; padding: 14px; border-radius: 12px; border: none; background: var(--text); color: var(--bg); cursor: pointer; font-weight: 700; font-size: 1rem; transition: 0.2s; }

        .tree-row { display: flex; justify-content: space-between; align-items: center; padding: 12px 8px; border-radius: 12px; cursor: pointer; transition: 0.2s; border-bottom: 1px solid transparent; }
        .tree-row:hover { background: rgba(128,128,128,0.06); border-bottom-color: var(--border); }
        .tree-row-left { display: flex; align-items: center; gap: 8px; overflow: hidden; flex: 1; }
        .tree-row-actions { display: flex; align-items: center; gap: 6px; opacity: 0; transition: 0.2s; }
        .tree-row:hover .tree-row-actions, .tree-row-actions.always-show { opacity: 1; }
        
        .file-name-container { overflow: hidden; flex: 1; }
        .file-name { font-size: 1rem; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; display: flex; align-items: center; gap: 8px; }
        .file-meta { font-size: 0.75rem; color: var(--mute); margin-top: 4px; padding-left: 28px; }
        
        .btn-icon-small { padding: 6px; background: transparent; border: none; color: var(--mute); cursor: pointer; border-radius: 6px; display: flex; align-items: center; justify-content: center; transition: 0.2s; }
        .btn-icon-small:hover { background: rgba(128,128,128,0.1); color: var(--accent); }
        
        .btn-learn { padding: 8px 16px; background: var(--accent); color: white; border: none; border-radius: 8px; cursor: pointer; font-weight: 700; font-size: 0.85rem; transition: 0.2s; box-shadow: 0 2px 4px rgba(0,122,255,0.2);}
        .btn-learn:hover { opacity: 0.8; }
        .badge-active { padding: 8px 12px; background: rgba(52, 199, 89, 0.1); color: #34c759; border-radius: 8px; font-size: 0.8rem; font-weight: 700; display: flex; align-items: center; gap: 6px; }
        .btn-trash { padding: 8px; background: rgba(255, 59, 48, 0.1); color: #ff3b30; border: none; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: 0.2s; }
        .btn-trash:hover { background: rgba(255, 59, 48, 0.2); }
    </style>
</head>
<body class="light">
    <div class="sidebar" id="sidebar">
        <div class="sidebar-header"><h1>Assistant</h1></div>
        <div class="sidebar-scroll"><div class="section-label">Sessions</div><div id="sessionList"></div></div>
        <div style="padding: 24px;"><button class="new-btn" onclick="createNewSession()">+ New Session</button></div>
    </div>
    <div class="main" id="main">
        <header>
            <div style="display:flex; align-items:center; gap:15px;">
                <button class="icon-btn" onclick="toggleSidebar()"><i data-lucide="sidebar"></i></button>
                <span id="currentSessionDisplay" style="font-weight: 600; font-size: 1.1rem; color: var(--mute);">General</span>
            </div>
            <div style="display:flex; gap:10px;">
                <button class="icon-btn" onclick="toggleTheme()"><i data-lucide="sun" id="tIcon"></i></button>
                <button class="icon-btn" onclick="openModal('memoryModal')"><i data-lucide="database"></i></button>
                <button class="icon-btn" onclick="openModal('infoModal')"><i data-lucide="info"></i></button>
            </div>
        </header>
        <div class="chat-area" id="chats"></div>
        <div class="input-wrap">
            <div class="input-pill">
                <input type="text" id="userInput" placeholder="Ask anything about your global active files..." onkeypress="if(event.key=='Enter') send()">
                <button onclick="send()" class="send-btn"><i data-lucide="arrow-up" style="width:20px;"></i></button>
            </div>
        </div>
        
        <div class="modal" id="infoModal"><div class="modal-card">
            <div style="display: flex; align-items: center; gap: 15px; margin-bottom: 25px;">
                <div style="width: 48px; height: 48px; background: var(--accent); border-radius: 14px; display: flex; align-items: center; justify-content: center;">
                    <i data-lucide="shield-check" style="color: white; width: 28px; height: 28px;"></i>
                </div>
                <div>
                    <h2 style="font-size: 1.5rem; margin: 0;">Project Assistant</h2>
                    <p style="color: var(--mute); font-size: 0.9rem; font-weight: 600; margin: 0;">v1.0 Local Intelligence</p>
                </div>
            </div>
            <p style="font-weight: 600; margin-bottom: 15px;">How your offline assistant works:</p>
            <div class="how-it-works">
                <div class="step-box"><i data-lucide="file-text" style="color:var(--accent); width:24px; flex-shrink:0; margin-top:2px;"></i><div><strong>1. Ingestion</strong><span>Files are processed into mathematical vectors locally using Nomic Embed.</span></div></div>
                <div class="step-box"><i data-lucide="hard-drive" style="color:var(--accent); width:24px; flex-shrink:0; margin-top:2px;"></i><div><strong>2. Local Storage</strong><span>Data is saved securely to ChromaDB on your Mac's SSD. No cloud needed.</span></div></div>
                <div class="step-box"><i data-lucide="cpu" style="color:var(--accent); width:24px; flex-shrink:0; margin-top:2px;"></i><div><strong>3. Retrieval & Reasoning</strong><span>Llama 3.2 pulls the exact context required to answer questions offline.</span></div></div>
            </div>
            <div style="padding:15px; background:rgba(0,122,255,0.08); border-radius:12px; font-weight:700; color:var(--accent); text-align:center; font-size: 1.05rem;">Designed by Arun Thomas</div>
            <button onclick="closeModal('infoModal')" class="btn-close">Close Information</button>
        </div></div>
        
        <div class="modal" id="memoryModal"><div class="modal-card" style="width: 650px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom: 20px;">
                <h2 style="font-size: 1.5rem;">Global Memory Bank</h2>
                <div style="display:flex; gap:10px;">
                    <button onclick="createFolder('')" class="btn-outline"><i data-lucide="folder-plus" style="width:16px;"></i> Folder</button>
                    <button onclick="triggerUpload('')" class="btn-outline"><i data-lucide="upload" style="width:16px;"></i> Document</button>
                </div>
            </div>
            <div id="fileList" style="max-height:400px; overflow-y:auto; margin-bottom:20px; padding-right:8px; border-top: 1px solid var(--border);"></div>
            <input type="file" id="fileIn" style="display:none" onchange="upload()">
            <button onclick="closeModal('memoryModal')" style="width:100%; border:none; background:transparent; color:var(--mute); cursor:pointer; font-weight:600; padding: 10px;">Done</button>
        </div></div>
    </div>
    <script>
        lucide.createIcons();
        let currentSession = localStorage.getItem('lastSession') || 'General';
        let openFolders = new Set(['']);
        let uploadTarget = '';
        marked.setOptions({ breaks: true });
        
        const hashSVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="9" x2="20" y2="9"></line><line x1="4" y1="15" x2="20" y2="15"></line><line x1="10" y1="3" x2="8" y2="21"></line><line x1="16" y1="3" x2="14" y2="21"></line></svg>';
        const trashSVG = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path><line x1="10" y1="11" x2="10" y2="17"></line><line x1="14" y1="11" x2="14" y2="17"></line></svg>';
        const brainSVG = '<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5a3 3 0 1 0-5.997.125 4 4 0 0 0-2.526 5.77 4 4 0 0 0 .556 6.588A4 4 0 1 0 12 18Z"></path><path d="M12 5a3 3 0 1 1 5.997.125 4 4 0 0 1 2.526 5.77 4 4 0 0 1-.556 6.588A4 4 0 1 1 12 18Z"></path><path d="M15 13a4.5 4.5 0 0 1-3-4 4.5 4.5 0 0 1-3 4"></path></svg>';
        const folderSVG = '<svg width="20" height="20" fill="currentColor" viewBox="0 0 24 24"><path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/></svg>';
        const fileTextSVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"></path><polyline points="14 2 14 8 20 8"></polyline></svg>';
        const chevRightSVG = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>';
        const chevDownSVG = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>';
        const folderPlusSVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.93a2 2 0 0 1-1.66-.9l-.82-1.2A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13c0 1.1.9 2 2 2Z"></path><line x1="12" y1="10" x2="12" y2="16"></line><line x1="9" y1="13" x2="15" y2="13"></line></svg>';
        const filePlusSVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="12" y1="18" x2="12" y2="12"></line><line x1="9" y1="15" x2="15" y2="15"></line></svg>';
        const checkSVG = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';

        function getHistory(session) { return JSON.parse(localStorage.getItem(`chat_${session}`)) || []; }
        function saveHistory(session, history) { localStorage.setItem(`chat_${session}`, JSON.stringify(history)); }
        
        function renderFileTree(nodes, level = 0) {
            if (nodes.length === 0 && level === 0) return '<div style="color:var(--mute); text-align:center; padding:30px 0;">No files stored yet.</div>';
            let html = '';
            nodes.forEach(node => {
                const pad = level * 20;
                const safePath = encodeURIComponent(node.path);
                
                if (node.type === 'folder') {
                    const isOpen = openFolders.has(node.path);
                    const chevron = isOpen ? chevDownSVG : chevRightSVG;
                    html += `
                    <div class="tree-row" onclick="toggleFolder('${safePath}')">
                        <div class="tree-row-left" style="padding-left: ${pad}px">
                            <span style="color:var(--mute); display:flex; align-items:center;">${chevron}</span>
                            <span style="color:var(--accent); display:flex; align-items:center;">${folderSVG}</span>
                            <span style="font-weight:600; font-size:1.05rem;">${node.name}</span>
                        </div>
                        <div class="tree-row-actions">
                            <button class="btn-icon-small" onclick="event.stopPropagation(); createFolder('${safePath}')" title="New Folder">${folderPlusSVG}</button>
                            <button class="btn-icon-small" onclick="event.stopPropagation(); triggerUpload('${safePath}')" title="Upload Document">${filePlusSVG}</button>
                            <button class="btn-trash" style="padding:6px; margin-left:10px;" onclick="event.stopPropagation(); deleteItem('${safePath}', true)">${trashSVG}</button>
                        </div>
                    </div>
                    `;
                    if (isOpen) { html += renderFileTree(node.children, level + 1); }
                } else {
                    const actionBtn = node.learned 
                        ? `<div class="badge-active">${checkSVG} Active</div>`
                        : `<button id="btn-${node.path.replace(/[^a-zA-Z0-9]/g, '')}" class="btn-learn" onclick="event.stopPropagation(); learnFile('${safePath}')">Learn</button>`;
                    html += `
                    <div class="tree-row" style="cursor:default;">
                        <div class="file-name-container" style="padding-left: ${pad + 24}px">
                            <div class="file-name"><span style="color:var(--mute); display:flex; align-items:center;">${fileTextSVG}</span> ${node.name}</div>
                            <div class="file-meta">${node.learned ? `Learned ${node.timestamp}` : 'Stored (Not active)'}</div>
                        </div>
                        <div class="tree-row-actions always-show">
                            ${actionBtn}
                            <button class="btn-trash" style="margin-left:5px;" onclick="event.stopPropagation(); deleteItem('${safePath}', false)">${trashSVG}</button>
                        </div>
                    </div>`;
                }
            });
            return html;
        }

        async function loadUI() {
            const sessions = JSON.parse(localStorage.getItem('sessions') || '["General"]');
            const sList = document.getElementById('sessionList'); sList.innerHTML = '';
            sessions.forEach(s => {
                const div = document.createElement('div');
                div.className = `nav-item ${s === currentSession ? 'active' : ''}`;
                div.innerHTML = `<div class="nav-item-content">${hashSVG}<span>${s}</span></div><button class="delete-btn" onclick="deleteSession(event, '${s}')">${trashSVG}</button>`;
                div.onclick = () => { currentSession = s; localStorage.setItem('lastSession', s); renderChat(); loadUI(); };
                sList.appendChild(div);
            });
            try {
                const res = await fetch('/files'); 
                const data = await res.json();
                document.getElementById('fileList').innerHTML = renderFileTree(data.tree || []);
            } catch(e) { console.log("Files not loaded yet"); }
            document.getElementById('currentSessionDisplay').innerText = currentSession;
        }
        
        function renderChat() { 
            const chatBox = document.getElementById('chats'); 
            chatBox.innerHTML = ''; 
            const history = getHistory(currentSession);
            if (history.length === 0) {
                chatBox.innerHTML = `
                    <div class="empty-state">
                        <div class="empty-icon">${brainSVG}</div>
                        <h2 style="font-size: 1.8rem; margin-bottom: 10px; font-weight: 700;">How can I help you today?</h2>
                        <p style="color: var(--mute); font-size: 1.1rem;">I'm your local, private project assistant.</p>
                        <div class="empty-grid">
                            <div class="empty-card"><i data-lucide="folder-plus" style="color:var(--accent); width:24px;"></i><h3>1. Organize & Learn</h3><p>Store files in your Global Memory Bank and click "Learn" to activate them.</p></div>
                            <div class="empty-card"><i data-lucide="message-square" style="color:var(--accent); width:24px;"></i><h3>2. Ask Questions</h3><p>Ask me anything. I'll search through all globally Active documents offline.</p></div>
                        </div>
                    </div>
                `;
            } else {
                history.forEach(msg => { chatBox.innerHTML += `<div class="msg ${msg.type}">${marked.parse(msg.text)}</div>`; }); 
            }
            chatBox.scrollTop = chatBox.scrollHeight; 
            lucide.createIcons();
        }

        function toggleFolder(encPath) {
            const path = decodeURIComponent(encPath);
            if(openFolders.has(path)) openFolders.delete(path); else openFolders.add(path);
            loadUI();
        }
        
        async function createFolder(encParentPath) {
            const parent = decodeURIComponent(encParentPath);
            const name = prompt("New Folder Name:");
            if(!name) return;
            const fd = new FormData(); fd.append('path', parent ? `${parent}/${name}` : name);
            await fetch('/create_folder', { method: 'POST', body: fd });
            openFolders.add(parent); loadUI();
        }

        function triggerUpload(encPath) {
            uploadTarget = decodeURIComponent(encPath);
            document.getElementById('fileIn').click();
        }

        async function upload() { 
            const file = document.getElementById('fileIn').files[0]; 
            if(!file) return; 
            const fd = new FormData(); 
            fd.append('file', file); fd.append('path', uploadTarget);
            await fetch('/upload', { method: 'POST', body: fd }); 
            document.getElementById('fileIn').value = '';
            openFolders.add(uploadTarget); loadUI(); 
        }

        async function learnFile(encPath) {
            const path = decodeURIComponent(encPath);
            const safeId = "btn-" + path.replace(/[^a-zA-Z0-9]/g, '');
            const btn = document.getElementById(safeId);
            if(btn) { btn.innerText = "Learning..."; btn.style.opacity = "0.5"; btn.style.pointerEvents = "none"; }
            const fd = new FormData(); fd.append('filepath', path);
            try { await fetch('/learn', { method: 'POST', body: fd }); loadUI(); } 
            catch(e) { alert("Error learning document."); loadUI(); }
        }

        async function deleteItem(encPath, isFolder) {
            const path = decodeURIComponent(encPath);
            const typeText = isFolder ? "folder and all its contents" : "document";
            if(confirm(`Completely delete this ${typeText} from storage and memory?`)) {
                const fd = new FormData(); fd.append('path', path); fd.append('is_folder', isFolder);
                await fetch('/delete_item', { method: 'POST', body: fd }); loadUI();
            }
        }
        
        function toggleSidebar() { document.getElementById('sidebar').classList.toggle('hidden'); }
        function createNewSession() { const name = prompt("Session Name:"); if (name) { const sess = JSON.parse(localStorage.getItem('sessions') || '["General"]'); if (!sess.includes(name)) sess.push(name); localStorage.setItem('sessions', JSON.stringify(sess)); currentSession = name; localStorage.setItem('lastSession', name); renderChat(); loadUI(); } }
        function deleteSession(e, name) { e.stopPropagation(); if (name === 'General') return; if (confirm("Delete session history?")) { let sess = JSON.parse(localStorage.getItem('sessions')).filter(s => s !== name); localStorage.setItem('sessions', JSON.stringify(sess)); localStorage.removeItem(`chat_${name}`); if (currentSession === name) currentSession = 'General'; renderChat(); loadUI(); } }
        
        async function send() {
            const input = document.getElementById('userInput'); const msg = input.value; if(!msg) return;
            const history = getHistory(currentSession); history.push({ type: 'user', text: msg });
            saveHistory(currentSession, history); renderChat(); input.value = '';
            const loadingId = "loading-" + Date.now();
            document.getElementById('chats').innerHTML += `<div class="msg bot" id="${loadingId}">...</div>`;
            document.getElementById('chats').scrollTop = document.getElementById('chats').scrollHeight;
            
            const fd = new FormData(); 
            fd.append('message', msg);
            fd.append('session_name', currentSession);
            
            try {
                const res = await fetch('/chat', { method: 'POST', body: fd });
                const data = await res.json(); history.push({ type: 'bot', text: data.reply });
                saveHistory(currentSession, history); renderChat();
            } catch (err) { document.getElementById(loadingId).innerText = "Error connecting to AI. Please check terminal."; }
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

# 5. ENVIRONMENT & DEPENDENCIES
printf "  ${BLUE}▶${NC} Powering up local hardware...\n"
ollama serve > /dev/null 2>&1 &
sleep 2
ollama pull nomic-embed-text > /dev/null 2>&1
ollama pull llama3.2 > /dev/null 2>&1
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip > /dev/null 2>&1
pip install fastapi uvicorn python-multipart pandas openpyxl pypdf langchain-community langchain-chroma langchain-ollama > /dev/null 2>&1

# 6. SMART DESKTOP LAUNCHER 
SHORTCUT_PATH="$HOME/Desktop/PA.command"
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

printf "  \${BLUE}▶\${NC} Checking Neural Engine...\n"
if ! pgrep -x "ollama" > /dev/null; then
    ollama serve > /dev/null 2>&1 &
    sleep 2
fi

cd "$ABS_PROJECT_DIR"
source venv/bin/activate
(while ! nc -z 127.0.0.1 8000; do sleep 0.2; done; printf "  \${GREEN}✓\${NC} Server Online\n\n"; open http://127.0.0.1:8000) &
python3 main.py
EOT
chmod +x "$SHORTCUT_PATH"
printf "\n  ${GREEN}✓ Setup Complete.${NC}\n"
printf "  ${BOLD}LAUNCH PA.command FROM YOUR DESKTOP TO LAUNCH THE APP.${NC}\n\n"

<div align="center">
  <img src="https://api.iconify.design/lucide:brain.svg?color=%230a84ff" width="80" height="80" alt="Brain Icon">
  <h1>Project Assistant v1.0</h1>
  <p>Your private, offline AI intelligence powered directly by your Mac's Apple Silicon.</p>
</div>

---

<p align="center">
  <img src="https://img.shields.io/badge/Status-100%25%20Offline-success" alt="Status">
  <img src="https://img.shields.io/badge/Platform-macOS-lightgrey" alt="Platform">
  <img src="https://img.shields.io/badge/AI-Llama%203.2-blue" alt="AI Model">
  <img src="https://img.shields.io/badge/Vectors-ChromaDB-purple" alt="Vectors">
</p>

## 🏛️ Architecture

*   🐍 **Backend**: Python FastAPI
*   🗄️ **Vector Store**: ChromaDB
*   🧠 **LLM Engine**: Ollama (Llama 3.2 for reasoning, `nomic-embed-text` for embeddings)
*   📚 **Document Ingestion**: Langchain
*   🎨 **Frontend**: Vanilla HTML/JS with custom CSS (inspired by Tailwind) and Lucide icons

## ✨ Features

*   🛡️ **Privacy First**: 100% offline, no data is ever sent to the cloud.
*   💾 **Global Memory Bank**: Store your documents securely on your local SSD.
*   🔍 **RAG (Retrieval-Augmented Generation)**: The AI intelligently retrieves context from your active documents to answer questions with precise citations.
*   💬 **Chat & Archives**: Create separate chat sessions to organize queries and archive older ones to keep your workspace clean.
*   📄 **Supported File Types**: `.pdf`, `.txt`.

## 🚀 Installation & Setup

Simply run the `setup.sh` script to install all prerequisites and generate the application.

```bash
chmod +x setup.sh
./setup.sh
```

> **Note:** The script will automatically install Homebrew (if missing), Python 3, and Ollama. It will also pull the necessary AI models, create a virtual environment, install Python dependencies, and generate the application files (`main.py`, `index.html`, etc).

## 💻 Usage

After running the setup script, a Smart Desktop Launcher will be created on your Desktop.

1.  Double-click the **`PA.command`** file on your Desktop to launch the application.
2.  The server will start, and the web interface will automatically open in your default browser at `http://127.0.0.1:8000`.

*Alternatively, you can manually start the application by running:*

```bash
source venv/bin/activate
python3 main.py
```

*(Ensure Ollama is running in the background using `ollama serve`).*

## 🤖 Interacting with the Assistant

1.  **Add Documents**: Click the 🗄️ database icon at the top right to open the Global Memory Bank. You can create folders and upload documents.
2.  **Learn Documents**: For the AI to access your documents, you must click **Learn** next to them in the Memory Bank. This processes the files into mathematical vectors and stores them in ChromaDB.
3.  **Chat**: Use the chat interface to ask questions. The AI will search your "Active" (learned) documents and synthesize an answer based *only* on the retrieved context.

---

<div align="center">
  <em>Designed by Arun Thomas</em>
</div>

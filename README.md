# Project Assistant v1.0

Project Assistant is a 100% offline local AI assistant running directly on your Mac. It provides a private, secure environment for storing documents in a global memory bank, and allows you to chat with your local AI to retrieve information and ask questions.

## Architecture
- **Backend**: Python FastAPI
- **Vector Store**: ChromaDB
- **LLM Engine**: Ollama (Llama 3.2 for reasoning, nomic-embed-text for embeddings)
- **Document Ingestion**: Langchain
- **Frontend**: Vanilla HTML/JS with Tailwind CSS and Lucide icons

## Features
- **Privacy First**: 100% offline, no data is sent to the cloud.
- **Global Memory Bank**: Store your documents securely on your local SSD.
- **RAG (Retrieval-Augmented Generation)**: The AI intelligently retrieves context from your active documents to answer questions.
- **Chat & Archives**: Create separate chat sessions to organize queries.
- **Supported File Types**: PDF, TXT.

## Installation & Setup

1. Simply run the `setup.sh` script to install all prerequisites and generate the application.
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
   *The script will automatically install Homebrew (if missing), Python 3, and Ollama. It will also pull the necessary AI models, create a virtual environment, install Python dependencies, and generate the application files (`main.py`, `index.html`, etc).*

## Usage

After running the setup script, a Smart Desktop Launcher will be created on your Desktop.

1. Double-click the **`PA.command`** file on your Desktop to launch the application.
2. The server will start, and the web interface will automatically open in your default browser at `http://127.0.0.1:8000`.

*Alternatively, you can manually start the application by running:*
```bash
source venv/bin/activate
python3 main.py
```
*(Ensure Ollama is running in the background `ollama serve`).*

## Interacting with the Assistant

1. **Add Documents**: Click the database icon at the top right to open the Global Memory Bank. You can create folders and upload documents (`.pdf`, `.txt`).
2. **Learn Documents**: For the AI to access your documents, you must click **Learn** next to them in the Memory Bank. This processes the files into mathematical vectors and stores them in ChromaDB.
3. **Chat**: Use the chat interface to ask questions. The AI will search your "Active" (learned) documents and synthesize an answer based *only* on the retrieved context.

---
*Designed by Arun Thomas*

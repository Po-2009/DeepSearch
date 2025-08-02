import grpc
from concurrent import futures
import tempfile
import os

import fitz
import docx
from ProtoGenerated import Converter_pb2
from ProtoGenerated import Converter_pb2_grpc
import sys
class ConverterService(Converter_pb2_grpc.ConverterServicer):
    def ConvertFile(self, request_iterator, context):
        all_bytes = bytearray()
        for chunk in request_iterator:
            filename = chunk.filename
            all_bytes.extend(chunk.content)

            with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(filename)[1]) as tmp:
                tmp.write(all_bytes)
                temp_path = tmp.name
            text = extract_text(temp_path)

            os.remove(temp_path)
            yield Converter_pb2.ParsedText(filename=filename, text=text)

def extract_text(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".pdf":
        return extract_text_from_pdf(path)
    elif ext == ".docx":
        return extract_text_from_docx(path)
    elif ext in [".md", ".txt"]:
        return extract_text_from_txt(path)
    else:
        return "Unsupported file type"

def extract_text_from_pdf(path):
    doc = fitz.open(path)
    text = ""
    for page in doc.pages():
        text += page.get_text()
    return text

def extract_text_from_docx(path):
    doc = docx.Document(path)
    return "\n".join(p.text for p in doc.paragraphs)

def extract_text_from_txt(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()

def serve():
    port = 50051
    for arg in sys.argv[1:]:
        if arg.startswith("--port="):
            port = int(arg.split("=")[1])
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=4))
    Converter_pb2_grpc.add_ConverterServicer_to_server(ConverterService(), server)
    server.add_insecure_port('[::]:'+str(port))
    server.start()
    server.wait_for_termination()

if __name__ == "__main__":
    serve()
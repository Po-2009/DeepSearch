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
        current_filename = ""
        temp_file = None

        for chunk in request_iterator:

            if chunk.filename != current_filename:
                if temp_file:
                    temp_file.close()

                    text = extract_text(temp_file.name)

                    os.remove(temp_file.name)
                    yield Converter_pb2.ParsedText(filename=current_filename, text=text)

                current_filename = chunk.filename
                temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(current_filename)[1])

            temp_file.write(chunk.content)
        if temp_file:
            temp_file.close()
            text = extract_text(temp_file.name)
            os.remove(temp_file.name)
            yield Converter_pb2.ParsedText(filename=current_filename, text=text)



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
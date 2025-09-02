import grpc
from concurrent import futures
import io
from ProtoGenerated import Converter_pb2
from ProtoGenerated import Converter_pb2_grpc
import sys
from TextExtractFacade import TextExtractFacade

class ConverterService(Converter_pb2_grpc.ConverterServicer):

    def __init__(self):
        self.text_extraction_facade = TextExtractFacade()
        super().__init__()

    def ConvertFile(self, request_iterator, context):
        current_filename = ""
        memory_file = None

        for chunk in request_iterator:
            if chunk.filename != current_filename:
                if memory_file:
                    text = self.text_extraction_facade.extract_text(memory_file,current_filename)
                    yield Converter_pb2.ParsedText(filename=current_filename, text=text)
                    memory_file.close()

                current_filename = chunk.filename
                memory_file = io.BytesIO()

            memory_file.write(chunk.content)

        if memory_file:
            text = self.text_extraction_facade.extract_text(memory_file, current_filename)
            yield Converter_pb2.ParsedText(filename=current_filename, text=text)
            memory_file.close()

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
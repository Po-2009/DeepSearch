import os
import fitz
import docx

class Extractor:
    def __init__(self, file_object):
        self.file_object = file_object
    def extract(self):
        self.file_object.seek(0)


class PdfExtractor(Extractor):
    def extract(self):
        super().extract()
        doc = fitz.open(stream=self.file_object, filetype="pdf")
        text = ""
        for page in doc.pages():
            text += page.get_text()
            text +=' '
        return text.strip()

class DocxExtractor(Extractor):
    def extract(self):
        super().extract()
        doc = docx.Document(self.file_object)
        return "\n".join(p.text for p in doc.paragraphs)

class TextExtractor(Extractor):
    def extract(self):
        super().extract()
        return self.file_object.read().decode("utf-8", errors="ignore")

class TextExtractFacade:
    def __init__(self):
        self._extractors = {
            ".pdf": PdfExtractor,
            ".docx": DocxExtractor,
            ".txt": TextExtractor,
            ".md":TextExtractor,
        }

    def extract_text(self,file_object, filename):
        extension = os.path.splitext(filename)[1].lower()
        extractor_class = self._extractors.get(extension)
        extractor = extractor_class(file_object)
        return extractor.extract()
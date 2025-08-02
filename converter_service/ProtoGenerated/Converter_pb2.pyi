from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from typing import ClassVar as _ClassVar, Optional as _Optional

DESCRIPTOR: _descriptor.FileDescriptor

class FileChunk(_message.Message):
    __slots__ = ("filename", "content")
    FILENAME_FIELD_NUMBER: _ClassVar[int]
    CONTENT_FIELD_NUMBER: _ClassVar[int]
    filename: str
    content: bytes
    def __init__(self, filename: _Optional[str] = ..., content: _Optional[bytes] = ...) -> None: ...

class ParsedText(_message.Message):
    __slots__ = ("filename", "text")
    FILENAME_FIELD_NUMBER: _ClassVar[int]
    TEXT_FIELD_NUMBER: _ClassVar[int]
    filename: str
    text: str
    def __init__(self, filename: _Optional[str] = ..., text: _Optional[str] = ...) -> None: ...
